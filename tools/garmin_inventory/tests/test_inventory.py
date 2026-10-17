"""Tests for the FIT decoder and the Garmin inventory.

Run: python3 -m unittest discover -s tools/garmin_inventory/tests

Set FIT_SAMPLES_DIR to a folder of real .fit files (for example
python-fitparse's tests/files) to also check that every file decodes without
raising.
"""

import io
import json
import os
import struct
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import fit  # noqa: E402
import inventory  # noqa: E402

UINT8, SINT8, UINT16, SINT16, UINT32, STRING = 0x02, 0x01, 0x84, 0x83, 0x86, 0x07
BASE_CODES = {UINT8: "B", SINT8: "b", UINT16: "H", SINT16: "h", UINT32: "I"}

T0 = 1_100_000_000  # FIT epoch seconds (2024-11-08)


class FitWriter:
    """Builds FIT files for tests: definitions, data, compressed timestamps."""

    def __init__(self, big_endian=False):
        self.body = bytearray()
        self.defs = {}
        self.endian = ">" if big_endian else "<"

    def define(self, local, global_num, fields):
        """fields: list of (field_num, base_type, count)."""
        self.defs[local] = fields
        self.body += bytes([0x40 | local, 0, 1 if self.endian == ">" else 0])
        self.body += struct.pack(f"{self.endian}H", global_num)
        self.body += bytes([len(fields)])
        for num, bt, count in fields:
            size = count if bt == STRING else struct.calcsize(BASE_CODES[bt]) * count
            self.body += bytes([num, size, bt])
        return self

    def data(self, local, values, compressed_offset=None):
        if compressed_offset is None:
            self.body += bytes([local])
        else:
            self.body += bytes([0x80 | (local << 5) | compressed_offset])
        for (num, bt, count), v in zip(self.defs[local], values):
            if bt == STRING:
                raw = v.encode()[:count]
                self.body += raw + b"\x00" * (count - len(raw))
            else:
                vs = v if isinstance(v, list) else [v]
                self.body += struct.pack(f"{self.endian}{count}{BASE_CODES[bt]}", *vs)
        return self

    def bytes(self, header_size=14, corrupt_crc=False):
        hdr = struct.pack("<BBHI4s", header_size, 0x20, 2132, len(self.body), b".FIT")
        if header_size == 14:
            hdr += struct.pack("<H", fit.crc16(hdr))
        out = hdr + bytes(self.body)
        crc = fit.crc16(out) ^ (1 if corrupt_crc else 0)
        return out + struct.pack("<H", crc)


def file_id(w, file_type=32):
    w.define(0, 0, [(0, UINT8, 1), (1, UINT16, 1), (2, UINT16, 1), (4, UINT32, 1)])
    return w.data(0, [file_type, 1, 3869, T0])


class FitDecoderTest(unittest.TestCase):
    def test_crc16_reference_value(self):
        # FIT SDK test vector: CRC of b"123456789" is 0xBB3D.
        self.assertEqual(fit.crc16(b"123456789"), 0xBB3D)

    def test_basic_file_and_crcs(self):
        data = file_id(FitWriter()).bytes()
        [ff] = fit.parse(data)
        self.assertTrue(ff.header_crc_ok)
        self.assertTrue(ff.file_crc_ok)
        self.assertIsNone(ff.error)
        m = ff.messages[0]
        self.assertEqual(m.global_num, 0)
        self.assertEqual(m.fields, {0: 32, 1: 1, 2: 3869, 4: T0})

    def test_bad_file_crc_is_reported(self):
        [ff] = fit.parse(file_id(FitWriter()).bytes(corrupt_crc=True))
        self.assertFalse(ff.file_crc_ok)

    def test_twelve_byte_header(self):
        [ff] = fit.parse(file_id(FitWriter()).bytes(header_size=12))
        self.assertIsNone(ff.header_crc_ok)
        self.assertEqual(len(ff.messages), 1)

    def test_big_endian_definition(self):
        w = FitWriter(big_endian=True)
        w.define(0, 211, [(253, UINT32, 1), (0, UINT8, 1)]).data(0, [T0, 52])
        [ff] = fit.parse(w.bytes())
        self.assertEqual(ff.messages[0].global_num, 211)
        self.assertEqual(ff.messages[0].fields[0], 52)
        self.assertEqual(ff.messages[0].timestamp, T0 + fit.FIT_EPOCH_OFFSET)

    def test_invalid_values_are_dropped_and_arrays_keep_positions(self):
        w = FitWriter()
        w.define(0, 78, [(0, UINT16, 4), (1, UINT8, 1), (2, SINT16, 1)])
        w.data(0, [[1093, 0xFFFF, 850, 0xFFFF], 0xFF, 0x7FFF])
        m = fit.parse(w.bytes())[0].messages[0]
        self.assertEqual(m.fields, {0: [1093, None, 850, None]})

    def test_all_invalid_array_is_absent(self):
        w = FitWriter()
        w.define(0, 78, [(0, UINT16, 2)]).data(0, [[0xFFFF, 0xFFFF]])
        self.assertEqual(fit.parse(w.bytes())[0].messages[0].fields, {})

    def test_string_field(self):
        w = FitWriter()
        w.define(0, 0, [(8, STRING, 16)]).data(0, ["Forerunner 55"])
        self.assertEqual(fit.parse(w.bytes())[0].messages[0].fields[8], "Forerunner 55")

    def test_compressed_timestamp_rolls_over(self):
        w = FitWriter()
        start = T0 + 30  # low 5 bits = 30 when T0 is a multiple of 32
        self.assertEqual(T0 % 32, 0)
        w.define(0, 297, [(253, UINT32, 1), (0, UINT16, 1)]).data(0, [start, 1500])
        w.define(1, 297, [(0, UINT16, 1)])
        w.data(1, [1550], compressed_offset=31)   # +1 s
        w.data(1, [1600], compressed_offset=2)    # wraps: +3 s
        msgs = fit.parse(w.bytes())[0].messages
        ts = [m.timestamp - fit.FIT_EPOCH_OFFSET for m in msgs]
        self.assertEqual(ts, [start, start + 1, start + 4])

    def test_monitoring_timestamp_16(self):
        w = FitWriter()
        w.define(0, 55, [(253, UINT32, 1), (3, UINT32, 1)]).data(0, [T0, 100])
        w.define(1, 55, [(26, UINT16, 1), (27, UINT8, 1)])
        w.data(1, [(T0 + 60) & 0xFFFF, 61])
        w.data(1, [(T0 + 120) & 0xFFFF, 63])
        msgs = fit.parse(w.bytes())[0].messages
        self.assertEqual([m.timestamp - fit.FIT_EPOCH_OFFSET for m in msgs], [T0, T0 + 60, T0 + 120])

    def test_relative_system_time_is_not_a_date(self):
        w = FitWriter()
        w.define(0, 20, [(253, UINT32, 1), (3, UINT8, 1)]).data(0, [5000, 120])
        self.assertIsNone(fit.parse(w.bytes())[0].messages[0].timestamp)

    def test_developer_fields_are_kept(self):
        w = FitWriter()
        w.body += bytes([0x60, 0, 0]) + struct.pack("<H", 20) + bytes([1, 3, 1, UINT8, 1, 0, 2, 0])
        w.body += bytes([0, 140]) + struct.pack("<H", 777)
        m = fit.parse(w.bytes())[0].messages[0]
        self.assertEqual(m.fields, {3: 140})
        self.assertEqual(m.dev_fields, {(0, 0): struct.pack("<H", 777)})

    def test_misaligned_field_keeps_bytes(self):
        w = FitWriter()
        w.body += bytes([0x40, 0, 0]) + struct.pack("<H", 20) + bytes([1, 7, 3, UINT16])
        w.body += bytes([0]) + bytes(range(1, 4))
        m = fit.parse(w.bytes())[0].messages[0]
        self.assertEqual(m.fields[7], b"\x01\x02\x03")

    def test_truncated_file_keeps_decoded_messages(self):
        w = file_id(FitWriter())
        w.define(1, 211, [(253, UINT32, 1), (0, UINT8, 1)]).data(1, [T0, 52])
        data = w.bytes()[:-5]
        [ff] = fit.parse(data)
        self.assertEqual(len(ff.messages), 1)
        self.assertIn("truncated", ff.error)
        self.assertIsNone(ff.file_crc_ok)

    def test_undefined_local_type_is_reported(self):
        w = FitWriter()
        w.body += bytes([3, 0])
        [ff] = fit.parse(w.bytes())
        self.assertIn("undefined local type 3", ff.error)

    def test_chained_files_and_trailing_garbage(self):
        a = file_id(FitWriter(), 4).bytes()
        b = file_id(FitWriter(), 32).bytes()
        files = fit.parse(a + b + b"\x00garbage")
        self.assertEqual([f.messages[0].fields[0] for f in files], [4, 32])
        self.assertIn("trailing bytes", files[-1].error)

    def test_not_fit_raises(self):
        with self.assertRaises(fit.FitError):
            fit.parse(b"hello world, not a fit file")


def wellness_file():
    """A small monitoring file like a Forerunner writes: HR, stress + Body Battery, unknown msg."""
    w = file_id(FitWriter(), 32)
    w.define(1, 55, [(253, UINT32, 1), (27, UINT8, 1), (3, UINT32, 1)])
    w.define(2, 227, [(0, SINT16, 1), (1, UINT32, 1), (3, SINT8, 1)])
    w.define(3, 233, [(253, UINT32, 1), (0, UINT8, 1), (7, UINT16, 1)])
    for i in range(10):
        w.data(1, [T0 + 60 * i, 55 + i, 100 * i])
    for i in range(5):
        w.data(2, [20 + i, T0 + 180 * i, 80 - i])
    w.data(2, [-1, T0 + 900, 75])  # no stress reading, battery still present
    w.data(3, [T0, 9, 1234])
    return w.bytes()


class InventoryTest(unittest.TestCase):
    def run_inventory(self, *paths):
        out = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp:
            js = os.path.join(tmp, "inv.json")
            md = os.path.join(tmp, "inv.md")
            inventory.main([*paths, "-o", md, "--json", js])
            with open(md, encoding="utf-8") as f:
                out.write(f.read())
            with open(js, encoding="utf-8") as f:
                data = json.load(f)
        return out.getvalue(), data

    def test_signals_found_in_watch_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            mon = os.path.join(tmp, "GARMIN", "Monitor")
            os.makedirs(mon)
            with open(os.path.join(mon, "A1B2C3D4.FIT"), "wb") as f:
                f.write(wellness_file())
            with open(os.path.join(tmp, "GARMIN", "notes.txt"), "w") as f:
                f.write("not fit")
            md, data = self.run_inventory(tmp)

        msgs = data["fit_messages"]
        self.assertEqual(msgs["55"]["count"], 10)
        self.assertEqual(msgs["55"]["fields"]["27"]["min"], 55)
        self.assertEqual(msgs["227"]["fields"]["3"]["present"], 6)   # Body Battery
        self.assertEqual(msgs["227"]["fields"]["0"]["min"], -1)
        self.assertEqual(data["fit_files"][0]["type"], "monitoring_b")
        self.assertIn("| HR per menit | monitoring.heart_rate | 10 |", md)
        self.assertIn("| 1 mnt |", md)
        self.assertIn("| Body Battery | stress_level.body_energy (nama dari komunitas) | 6 |", md)
        self.assertIn("### 233 `unknown_233`", md)
        self.assertNotIn("### 55 ", md)  # every monitoring field here is named

    def test_nested_zip_export_with_json(self):
        daily = [{"calendarDate": "2026-10-01", "bodyBatteryHighestValue": 88,
                  "averageStressLevel": 31, "totalSteps": 9000},
                 {"calendarDate": "2026-10-02", "bodyBatteryHighestValue": 79,
                  "averageStressLevel": 35, "totalSteps": 7000}]
        inner = io.BytesIO()
        with zipfile.ZipFile(inner, "w") as z:
            z.writestr("UploadedFiles/run.fit", wellness_file())
        outer = io.BytesIO()
        with zipfile.ZipFile(outer, "w") as z:
            z.writestr("DI_CONNECT/DI-Connect-Aggregator/UDSFile_1.json", json.dumps(daily))
            z.writestr("DI_CONNECT/DI-Connect-Uploaded-Files/Part1.zip", inner.getvalue())
            z.writestr("DI_CONNECT/broken.json", "{not json")
        with tempfile.TemporaryDirectory() as tmp:
            p = os.path.join(tmp, "export.zip")
            with open(p, "wb") as f:
                f.write(outer.getvalue())
            md, data = self.run_inventory(p)

        [uds] = [f for f in data["json_files"] if f["path"].endswith("UDSFile_1.json")]
        self.assertEqual(uds["records"], 2)
        self.assertEqual((uds["from"], uds["to"]), ("2026-10-01", "2026-10-02"))
        self.assertIn("bodyBatteryHighestValue", uds["interesting_keys"])
        self.assertTrue(any("bukan JSON valid" in f.get("error", "") for f in data["json_files"]))
        self.assertTrue(data["fit_files"][0]["path"].endswith("Part1.zip!/UploadedFiles/run.fit"))
        self.assertIn("## File JSON (ekspor akun)", md)

    def test_corrupt_zip_is_reported_not_raised(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = os.path.join(tmp, "bad.zip")
            with open(p, "wb") as f:
                f.write(b"PK\x03\x04 not really")
            md, data = self.run_inventory(p)
        self.assertEqual(data["skipped"], [[p, "zip rusak"]])


@unittest.skipUnless(os.environ.get("FIT_SAMPLES_DIR"), "FIT_SAMPLES_DIR not set")
class RealSamplesTest(unittest.TestCase):
    def test_every_sample_decodes_without_raising(self):
        d = os.environ["FIT_SAMPLES_DIR"]
        names = [n for n in os.listdir(d) if n.lower().endswith(".fit")]
        self.assertTrue(names)
        for n in names:
            with open(os.path.join(d, n), "rb") as f:
                data = f.read()
            with self.subTest(n):
                files = fit.parse(data)
                self.assertTrue(files)


if __name__ == "__main__":
    unittest.main()
