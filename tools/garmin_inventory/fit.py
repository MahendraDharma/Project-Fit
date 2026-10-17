"""Minimal FIT decoder, written from the published FIT protocol.

Decodes every message generically (global number + field number -> value) so
the inventory can report fields nobody has named yet. Handles chained FIT
files, compressed-timestamp headers, developer fields, big-endian definitions,
fields whose size is not a multiple of their base type, and truncated files
(everything decoded before the break is kept and the error is reported).

Standard library only. Input bytes are untrusted.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field

FIT_EPOCH_OFFSET = 631065600  # seconds from 1970-01-01 to 1989-12-31T00:00Z
# A date_time below this is relative system time (seconds since power-on),
# not a calendar date.
FIT_MIN_ABSOLUTE = 0x10000000
FIELD_TIMESTAMP = 253
MSG_MONITORING = 55
MONITORING_TIMESTAMP_16 = 26

_CRC_TABLE = (
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
)


def crc16(data: bytes, crc: int = 0) -> int:
    for b in data:
        tmp = _CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ _CRC_TABLE[b & 0xF]
        tmp = _CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ _CRC_TABLE[(b >> 4) & 0xF]
    return crc


# base type number (low 5 bits) -> (struct code, size, invalid value)
_BASE_TYPES = {
    0x00: ("B", 1, 0xFF),                # enum
    0x01: ("b", 1, 0x7F),                # sint8
    0x02: ("B", 1, 0xFF),                # uint8
    0x03: ("h", 2, 0x7FFF),              # sint16
    0x04: ("H", 2, 0xFFFF),              # uint16
    0x05: ("i", 4, 0x7FFFFFFF),          # sint32
    0x06: ("I", 4, 0xFFFFFFFF),          # uint32
    0x07: (None, 1, None),               # string
    0x08: ("f", 4, None),                # float32 (invalid = all bits set)
    0x09: ("d", 8, None),                # float64
    0x0A: ("B", 1, 0x00),                # uint8z
    0x0B: ("H", 2, 0x0000),              # uint16z
    0x0C: ("I", 4, 0x00000000),          # uint32z
    0x0D: (None, 1, None),               # byte array
    0x0E: ("q", 8, 0x7FFFFFFFFFFFFFFF),  # sint64
    0x0F: ("Q", 8, 0xFFFFFFFFFFFFFFFF),  # uint64
    0x10: ("Q", 8, 0x0000000000000000),  # uint64z
}


class FitError(Exception):
    pass


@dataclass
class FieldDef:
    num: int
    size: int
    base_type: int  # low 5 bits; -1 for developer fields
    dev_index: int | None = None


@dataclass
class Definition:
    global_num: int
    endian: str  # "<" or ">"
    fields: list[FieldDef]
    dev_fields: list[FieldDef]


@dataclass
class Message:
    global_num: int
    fields: dict[int, object]          # invalid values are absent
    dev_fields: dict[tuple[int, int], bytes]
    timestamp: int | None              # Unix seconds, when known
    field_sizes: dict[int, int] = field(default_factory=dict)


@dataclass
class FitFile:
    header_size: int
    protocol_version: int
    profile_version: int
    data_size: int
    header_crc_ok: bool | None         # None: 12-byte header or CRC field 0
    file_crc_ok: bool | None           # None: file truncated before the CRC
    messages: list[Message]
    error: str | None = None


def _decode_value(raw: bytes, base_type: int, endian: str):
    code, size, invalid = _BASE_TYPES.get(base_type, (None, 1, None))
    if base_type == 0x07:
        s = raw.split(b"\x00", 1)[0]
        return s.decode("utf-8", "replace") if s else None
    if code is None or len(raw) % size:
        # Byte arrays, unknown base types, or a size that is not a multiple of
        # the base type (seen in the wild): keep the bytes unless all 0xFF.
        return None if all(b == 0xFF for b in raw) else bytes(raw)
    n = len(raw) // size
    vals = struct.unpack(f"{endian}{n}{code}", raw)
    if base_type in (0x08, 0x09):
        all_ones = b"\xff" * size
        out = [None if raw[i * size:(i + 1) * size] == all_ones else v for i, v in enumerate(vals)]
    else:
        out = [None if v == invalid else v for v in vals]
    if n == 1:
        return out[0]
    # Array elements keep their positions; an invalid element stays as None.
    return out if any(v is not None for v in out) else None


def _parse_one(data: bytes, start: int) -> tuple[FitFile, int]:
    """Parse one FIT file starting at data[start]; return it and the next offset."""
    if len(data) - start < 12:
        raise FitError("too short for a FIT header")
    hsize = data[start]
    if hsize not in (12, 14) or data[start + 8:start + 12] != b".FIT":
        raise FitError("no FIT header")
    proto = data[start + 1]
    profile, dsize = struct.unpack_from("<HI", data, start + 2)
    header_crc_ok = None
    if hsize == 14:
        (hcrc,) = struct.unpack_from("<H", data, start + 12)
        if hcrc != 0:
            header_crc_ok = crc16(data[start:start + 12]) == hcrc

    ff = FitFile(hsize, proto, profile, dsize, header_crc_ok, None, [])
    pos = start + hsize
    end = pos + dsize
    if end + 2 <= len(data):
        (fcrc,) = struct.unpack_from("<H", data, end)
        ff.file_crc_ok = crc16(data[start:end]) == fcrc

    defs: dict[int, Definition] = {}
    last_ts: int | None = None  # FIT epoch seconds
    limit = min(end, len(data))

    def take(n: int) -> bytes:
        nonlocal pos
        if pos + n > limit:
            raise FitError(f"truncated record at offset {pos - start}")
        b = data[pos:pos + n]
        pos += n
        return b

    try:
        while pos < limit:
            hdr = take(1)[0]
            compressed_offset = None
            if hdr & 0x80:
                local = (hdr >> 5) & 0x03
                compressed_offset = hdr & 0x1F
                is_def = False
                has_dev = False
            else:
                local = hdr & 0x0F
                is_def = bool(hdr & 0x40)
                has_dev = bool(hdr & 0x20)

            if is_def:
                _, arch = take(2)
                endian = ">" if arch == 1 else "<"
                (gnum,) = struct.unpack(f"{endian}H", take(2))
                nf = take(1)[0]
                fields = []
                for _ in range(nf):
                    num, size, bt = take(3)
                    fields.append(FieldDef(num, size, bt & 0x1F))
                dev_fields = []
                if has_dev:
                    nd = take(1)[0]
                    for _ in range(nd):
                        num, size, idx = take(3)
                        dev_fields.append(FieldDef(num, size, -1, idx))
                defs[local] = Definition(gnum, endian, fields, dev_fields)
                continue

            d = defs.get(local)
            if d is None:
                raise FitError(f"data record for undefined local type {local} at offset {pos - start - 1}")
            values: dict[int, object] = {}
            sizes: dict[int, int] = {}
            for f in d.fields:
                v = _decode_value(take(f.size), f.base_type, d.endian)
                sizes[f.num] = f.size
                if v is not None:
                    values[f.num] = v
            devs = {(f.dev_index, f.num): take(f.size) for f in d.dev_fields}

            ts = None
            if compressed_offset is not None and last_ts is not None:
                ts = (last_ts & ~0x1F) + compressed_offset
                if compressed_offset < (last_ts & 0x1F):
                    ts += 0x20
                last_ts = ts
            elif isinstance(values.get(FIELD_TIMESTAMP), int):
                ts = values[FIELD_TIMESTAMP]
                last_ts = ts
            elif (d.global_num == MSG_MONITORING and last_ts is not None
                  and isinstance(values.get(MONITORING_TIMESTAMP_16), int)):
                # Monitoring rows carry only the low 16 bits of the time,
                # relative to the last full timestamp.
                ts16 = values[MONITORING_TIMESTAMP_16]
                ts = last_ts + ((ts16 - (last_ts & 0xFFFF)) & 0xFFFF)
                last_ts = ts
            ff.messages.append(Message(
                d.global_num, values, devs,
                to_unix(ts), sizes))
    except FitError as e:
        ff.error = str(e)
        return ff, len(data)

    if end > len(data):
        ff.error = f"file declares {dsize} data bytes but only {len(data) - start - hsize} present"
    return ff, end + 2


def parse(data: bytes) -> list[FitFile]:
    """Parse every chained FIT file in data. Raises FitError if the first is not FIT."""
    out = []
    pos = 0
    while pos < len(data):
        if out and not is_fit(data[pos:pos + 12]):
            out[-1].error = (f"{len(data) - pos} trailing bytes after the last FIT file "
                             "are not a valid FIT header")
            break
        ff, pos = _parse_one(data, pos)
        out.append(ff)
        if ff.error:
            break
    return out


def to_unix(fit_ts: int | None) -> int | None:
    """FIT date_time to Unix seconds; None for relative system time."""
    if fit_ts is None or fit_ts < FIT_MIN_ABSOLUTE:
        return None
    return fit_ts + FIT_EPOCH_OFFSET


def is_fit(head: bytes) -> bool:
    return len(head) >= 12 and head[0] in (12, 14) and head[8:12] == b".FIT"
