"""Inventory of Garmin data: what is in a watch's GARMIN folder or an account export.

Usage:
    python3 -I tools/garmin_inventory/inventory.py PATH [PATH ...] [-o report.md] [--json out.json]

PATH may be a folder, a .zip (nested zips are opened too), a .fit file or a
.json file. FIT files are recognised by their header, not their extension.
The report says which signals the data actually holds, at what resolution
and over which dates, and lists every FIT message and field nobody has named
yet (the reverse-engineering targets).

Standard library only. All input is treated as untrusted data.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import zipfile
from collections import Counter, defaultdict
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fit  # noqa: E402
import fit_profile as profile  # noqa: E402

MAX_MEMBER_BYTES = 512 * 1024 * 1024    # one FIT/JSON file
MAX_NESTED_ZIP_BYTES = 4 * 1024 ** 3    # one zip inside a zip
MAX_ZIP_DEPTH = 4
JSON_SAMPLE_ITEMS = 2000

INTERESTING_KEY = re.compile(
    r"body.?battery|bodyenergy|stress|sleep|hrv|spo2|pulse.?ox|respiration|"
    r"resting.?heart|restinghr|vo2|intensity|steps|training.?(load|status|readiness)|"
    r"recovery|heart.?rate|calorie|floors|fitness.?age|endurance|hill",
    re.IGNORECASE)
DATE_KEY = re.compile(r"date|time|timestamp", re.IGNORECASE)
ISO_DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})")
_NOW_LIMIT = int(datetime.now(timezone.utc).timestamp()) + 366 * 86400


# ---------------------------------------------------------------- sources

def _read(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


class Sources:
    """Walks folders and zips, yielding (logical path, bytes) for FIT and JSON files."""

    def __init__(self):
        self.extensions = Counter()
        self.skipped: list[tuple[str, str]] = []

    def walk(self, path: str):
        if os.path.isdir(path):
            for root, dirs, files in os.walk(path, followlinks=False):
                dirs.sort()
                for name in sorted(files):
                    p = os.path.join(root, name)
                    if not os.path.islink(p):
                        yield from self._file(p, lambda p=p: _read(p), os.path.getsize(p), 0)
        elif os.path.isfile(path):
            yield from self._file(path, lambda: _read(path), os.path.getsize(path), 0)
        else:
            self.skipped.append((path, "tidak ditemukan"))

    def _file(self, logical: str, read, size: int, depth: int):
        ext = os.path.splitext(logical)[1].lower() or "(tanpa ekstensi)"
        self.extensions[ext] += 1
        if ext == ".zip":
            if depth >= MAX_ZIP_DEPTH:
                self.skipped.append((logical, "zip terlalu dalam"))
            elif size > MAX_NESTED_ZIP_BYTES:
                self.skipped.append((logical, "zip terlalu besar"))
            else:
                yield from self._zip(logical, read(), depth + 1)
            return
        if ext not in (".fit", ".json") and size > 64 * 1024 * 1024:
            return
        if size > MAX_MEMBER_BYTES:
            self.skipped.append((logical, "file terlalu besar"))
            return
        data = read()
        if fit.is_fit(data[:14]) or ext == ".json":
            yield logical, data

    def _zip(self, logical: str, data: bytes, depth: int):
        try:
            zf = zipfile.ZipFile(io.BytesIO(data))
        except zipfile.BadZipFile:
            self.skipped.append((logical, "zip rusak"))
            return
        with zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                inner = f"{logical}!/{info.filename}"
                yield from self._file(inner, lambda i=info: zf.read(i), info.file_size, depth)


# ---------------------------------------------------------------- FIT stats

def _fmt_ts(ts: int | None) -> str:
    if ts is None:
        return "-"
    return datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d %H:%M")


def _short(v) -> str:
    if isinstance(v, bytes):
        return "0x" + v[:8].hex() + ("…" if len(v) > 8 else "")
    s = repr(v)
    return s if len(s) <= 40 else s[:39] + "…"


class Range:
    def __init__(self):
        self.lo = None
        self.hi = None

    def add(self, v):
        if v is None:
            return
        self.lo = v if self.lo is None or v < self.lo else self.lo
        self.hi = v if self.hi is None or v > self.hi else self.hi


class FieldStats:
    def __init__(self):
        self.present = 0
        self.sizes = set()
        self.values = Range()
        self.example = None

    def add(self, v, size):
        self.present += 1
        self.sizes.add(size)
        if self.example is None:
            self.example = v
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            self.values.add(v)


class MessageStats:
    def __init__(self):
        self.count = 0
        self.files = set()
        self.time = Range()
        self.fields: dict[int, FieldStats] = defaultdict(FieldStats)
        self.dev_fields = Counter()
        self.stamps: set[int] = set()


def _message_time(m: fit.Message) -> int | None:
    if m.timestamp is not None:
        return m.timestamp
    if m.global_num == 227 and isinstance(m.fields.get(1), int):
        return fit.to_unix(m.fields[1])
    return None


class FitInventory:
    def __init__(self):
        self.files: list[dict] = []
        self.messages: dict[int, MessageStats] = defaultdict(MessageStats)
        self.file_types = Counter()

    def add(self, logical: str, data: bytes):
        try:
            parsed = fit.parse(data)
        except fit.FitError as e:
            self.files.append({"path": logical, "error": str(e)})
            return
        for idx, ff in enumerate(parsed):
            name = logical if len(parsed) == 1 else f"{logical}#{idx + 1}"
            info = {"path": name, "bytes": len(data), "messages": len(ff.messages),
                    "header_crc_ok": ff.header_crc_ok, "file_crc_ok": ff.file_crc_ok,
                    "error": ff.error}
            span = Range()
            for m in ff.messages:
                if m.global_num == 0 and "type" not in info:
                    t = m.fields.get(0)
                    info["type"] = profile.FILE_TYPES.get(t, f"type_{t}")
                    info["manufacturer"] = profile.MANUFACTURERS.get(m.fields.get(1), m.fields.get(1))
                    info["product"] = m.fields.get(2)
                    tc = m.fields.get(4)
                    info["time_created"] = _fmt_ts(fit.to_unix(tc)) if isinstance(tc, int) else None
                st = self.messages[m.global_num]
                st.count += 1
                st.files.add(name)
                ts = _message_time(m)
                if ts is not None and ts > _NOW_LIMIT:
                    ts = None  # a date in the future is a broken clock, not data
                st.time.add(ts)
                span.add(ts)
                if ts is not None:
                    st.stamps.add(ts)
                for num, v in m.fields.items():
                    st.fields[num].add(v, m.field_sizes.get(num))
                for key in m.dev_fields:
                    st.dev_fields[key] += 1
            info.setdefault("type", "(tanpa file_id)")
            info["from"], info["to"] = _fmt_ts(span.lo), _fmt_ts(span.hi)
            self.file_types[info["type"]] += 1
            self.files.append(info)

    def signal_rows(self):
        rows = []
        for label, msg, fld, note in profile.SIGNALS:
            st = self.messages.get(msg)
            if st is None:
                rows.append((label, note, 0, "-", "-", "-", "-"))
                continue
            if fld is None:
                n = st.count
                example = "-"
            else:
                fs = st.fields.get(fld)
                n = fs.present if fs else 0
                example = _short(fs.example) if fs and fs.example is not None else "-"
            res = _resolution(st) if n else "-"
            rows.append((label, note, n, _fmt_ts(st.time.lo) if n else "-",
                         _fmt_ts(st.time.hi) if n else "-", res, example))
        return rows


def _resolution(st: MessageStats) -> str:
    """Median gap between consecutive timestamps, ignoring gaps of a day or more."""
    stamps = sorted(st.stamps)
    gaps = sorted(b - a for a, b in zip(stamps, stamps[1:]) if 0 < b - a < 86400)
    if not gaps:
        return "-"
    g = gaps[len(gaps) // 2]
    if g < 60:
        return f"{g} dtk"
    if g < 3600:
        return f"{g / 60:.0f} mnt"
    return f"{g / 3600:.1f} jam"


# ---------------------------------------------------------------- JSON stats

def _collect_dates(obj, out: Range, depth=0):
    if depth > 3:
        return
    if isinstance(obj, dict):
        for k, v in obj.items():
            if DATE_KEY.search(k):
                if isinstance(v, str) and (m := ISO_DATE.match(v)):
                    out.add(m.group(1))
                elif isinstance(v, (int, float)) and 1e12 < v < 1e13:
                    out.add(datetime.fromtimestamp(v / 1000, timezone.utc).strftime("%Y-%m-%d"))
            if isinstance(v, (dict, list)):
                _collect_dates(v, out, depth + 1)
    elif isinstance(obj, list):
        for v in obj[:50]:
            _collect_dates(v, out, depth + 1)


def _keys(obj, prefix="", depth=0, out=None):
    out = out if out is not None else Counter()
    if depth > 2:
        return out
    if isinstance(obj, dict):
        for k, v in obj.items():
            out[prefix + k] += 1
            if isinstance(v, dict):
                _keys(v, prefix + k + ".", depth + 1, out)
            elif isinstance(v, list) and v and isinstance(v[0], dict):
                _keys(v[0], prefix + k + "[].", depth + 1, out)
    return out


class JsonInventory:
    def __init__(self):
        self.files: list[dict] = []

    def add(self, logical: str, data: bytes):
        try:
            obj = json.loads(data.decode("utf-8-sig"))
        except (UnicodeDecodeError, json.JSONDecodeError) as e:
            self.files.append({"path": logical, "error": f"bukan JSON valid: {e.__class__.__name__}"})
            return
        items = obj if isinstance(obj, list) else [obj]
        keys = Counter()
        dates = Range()
        for it in items[:JSON_SAMPLE_ITEMS]:
            _keys(it, out=keys)
            _collect_dates(it, dates)
        interesting = sorted(k for k in keys if INTERESTING_KEY.search(k))
        self.files.append({
            "path": logical, "bytes": len(data),
            "kind": "list" if isinstance(obj, list) else type(obj).__name__,
            "records": len(items), "from": dates.lo, "to": dates.hi,
            "keys": len(keys), "interesting_keys": interesting,
        })


# ---------------------------------------------------------------- report

def _table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    for r in rows:
        out.append("| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |")
    return "\n".join(out)


def render_markdown(src: Sources, fi: FitInventory, ji: JsonInventory) -> str:
    L = ["# Inventaris Data Garmin", ""]
    fit_ok = [f for f in fi.files if "messages" in f]
    L.append(f"- File FIT: **{len(fit_ok)}** terbaca, "
             f"{sum(1 for f in fi.files if f.get('error'))} dengan error")
    L.append(f"- File JSON: **{len(ji.files)}**")
    L.append("- Ekstensi yang ditemui: " + ", ".join(f"`{e}` {n}" for e, n in src.extensions.most_common()))
    if src.skipped:
        L.append(f"- Dilewati: {len(src.skipped)} (lihat bagian akhir)")
    L.append("")

    L += ["## Ketersediaan sinyal (FIT)", "",
          "Resolusi = median jarak antar-titik (jeda sehari atau lebih diabaikan).", ""]
    L.append(_table(["Sinyal", "Sumber", "Titik", "Dari", "Sampai", "Resolusi", "Contoh"],
                    fi.signal_rows()))
    L.append("")

    if fi.file_types:
        L += ["## Jenis file FIT", "",
              _table(["Jenis", "Jumlah"], fi.file_types.most_common()), ""]

    if fi.messages:
        L += ["## Pesan FIT", ""]
        rows = []
        for num in sorted(fi.messages):
            st = fi.messages[num]
            unknown = [] if profile.is_documented_elsewhere(num) else [
                f for f in st.fields
                if f not in profile.FIELDS.get(num, {}) and f not in profile.COMMON_FIELDS]
            rows.append((num, profile.message_name(num), st.count, len(st.files),
                         _fmt_ts(st.time.lo), _fmt_ts(st.time.hi), len(st.fields),
                         len(unknown)))
        L.append(_table(["#", "Pesan", "Jumlah", "File", "Dari", "Sampai", "Field", "Field tak dikenal"], rows))
        L.append("")

        L += ["## Target reverse engineering: pesan & field yang belum dikenal", "",
              "Berisi pesan yang tidak ada di profil FIT publik (semua field-nya), dan pesan "
              "kesehatan yang kita petakan (hanya field yang belum bernama). Pesan publik "
              "lain seperti `session`/`lap` sudah terdokumentasi di FIT SDK dan tidak "
              "dicantumkan di sini.", ""]
        for num in sorted(fi.messages):
            st = fi.messages[num]
            if profile.is_documented_elsewhere(num):
                continue
            known = profile.FIELDS.get(num, {})
            fields = sorted(f for f in st.fields
                            if f not in known and f not in profile.COMMON_FIELDS)
            if not fields and not st.dev_fields:
                continue
            L.append(f"### {num} `{profile.message_name(num)}` ({st.count} pesan)")
            L.append("")
            rows = []
            for f in fields:
                fs = st.fields[f]
                rng = f"{fs.values.lo} … {fs.values.hi}" if fs.values.lo is not None else "-"
                rows.append((f, profile.field_name(num, f), fs.present,
                             ",".join(str(s) for s in sorted(fs.sizes)), rng, _short(fs.example)))
            if rows:
                L.append(_table(["Field", "Nama", "Terisi", "Ukuran (byte)", "Rentang", "Contoh"], rows))
            if st.dev_fields:
                L.append("")
                L.append("Developer field: " + ", ".join(f"dev{d}.{n} ×{c}" for (d, n), c in st.dev_fields.items()))
            L.append("")

    if ji.files:
        L += ["## File JSON (ekspor akun)", ""]
        rows = [(f["path"], f.get("records", "-"), f.get("from") or "-", f.get("to") or "-",
                 ", ".join(f.get("interesting_keys", [])[:12]) + (" …" if len(f.get("interesting_keys", [])) > 12 else "")
                 if not f.get("error") else f["error"]) for f in ji.files]
        L.append(_table(["File", "Record", "Dari", "Sampai", "Key relevan"], rows))
        L.append("")

    problems = [f for f in fi.files if f.get("error") or f.get("file_crc_ok") is False or f.get("header_crc_ok") is False]
    if problems or src.skipped:
        L += ["## Masalah", ""]
        for f in problems:
            bits = []
            if f.get("error"):
                bits.append(f["error"])
            if f.get("header_crc_ok") is False:
                bits.append("CRC header salah")
            if f.get("file_crc_ok") is False:
                bits.append("CRC file salah")
            L.append(f"- `{f['path']}`: {'; '.join(bits)}")
        for p, why in src.skipped:
            L.append(f"- `{p}`: dilewati ({why})")
        L.append("")
    return "\n".join(L)


def to_json(src: Sources, fi: FitInventory, ji: JsonInventory) -> dict:
    msgs = {}
    for num, st in sorted(fi.messages.items()):
        msgs[num] = {
            "name": profile.message_name(num), "count": st.count, "files": len(st.files),
            "from": _fmt_ts(st.time.lo), "to": _fmt_ts(st.time.hi),
            "fields": {f: {"name": profile.field_name(num, f), "present": fs.present,
                           "sizes": sorted(s for s in fs.sizes if s is not None),
                           "min": fs.values.lo, "max": fs.values.hi,
                           "example": _short(fs.example)}
                       for f, fs in sorted(st.fields.items())},
            "dev_fields": {f"{d}.{n}": c for (d, n), c in st.dev_fields.items()},
        }
    return {"fit_files": fi.files, "fit_messages": msgs, "json_files": ji.files,
            "extensions": dict(src.extensions), "skipped": src.skipped}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="+", help="folder, .zip, .fit atau .json")
    ap.add_argument("-o", "--output", help="tulis laporan Markdown ke file ini (default: stdout)")
    ap.add_argument("--json", help="tulis inventaris lengkap sebagai JSON ke file ini")
    args = ap.parse_args(argv)

    src, fi, ji = Sources(), FitInventory(), JsonInventory()
    for p in args.paths:
        for logical, data in src.walk(p):
            if fit.is_fit(data[:14]):
                fi.add(logical, data)
            else:
                ji.add(logical, data)

    md = render_markdown(src, fi, ji)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(md + "\n")
    else:
        print(md)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(to_json(src, fi, ji), f, ensure_ascii=False, indent=1, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
