# garmin_inventory

Alat untuk melihat **isi data Garmin** sebelum kita menulis kode impor untuk ProjectFit:
sinyal apa saja yang ada, resolusinya, rentang tanggalnya, dan pesan/field FIT mana yang
belum dikenal siapa pun (target reverse engineering).

Python 3.10+, hanya library standar.

## Masukan yang didukung

- **Folder `GARMIN` dari jam** (Forerunner 55 muncul sebagai drive USB). Salin seluruh folder
  atau zip-kan.
- **Zip ekspor akun Garmin** (Akun Garmin → Data Management → Export Your Data). Zip di dalam zip
  ikut dibuka. File JSON di dalamnya diringkas: jumlah record, rentang tanggal, dan key yang relevan
  (Body Battery, stres, tidur, HRV, SpO₂, dll.).
- File `.fit` / `.json` satuan.

File FIT dikenali dari header-nya, bukan dari ekstensi.

## Pemakaian

```bash
python3 -I tools/garmin_inventory/inventory.py ~/Downloads/garmin_export.zip GARMIN/ \
    -o garmin_report.md --json garmin_report.json
```

Laporan Markdown berisi:

1. **Ketersediaan sinyal**: HR per menit, HR istirahat, langkah, stres, Body Battery, SpO₂,
   respirasi, tahap & skor tidur, HRV, rekaman aktivitas, GPS. Masing-masing dengan jumlah titik,
   rentang tanggal, resolusi (median jarak antar-titik) dan contoh nilai.
2. **Jenis file FIT** (activity, monitoring_b, sleep, …).
3. **Semua pesan FIT** dengan jumlah, rentang waktu dan jumlah field.
4. **Target reverse engineering**: pesan yang tidak ada di profil FIT publik, dan field tanpa nama
   di pesan kesehatan, lengkap dengan ukuran, rentang nilai dan contoh.
5. **File JSON ekspor** dan **masalah** (CRC salah, file terpotong, zip rusak).

> ⚠️ Laporan berisi data kesehatan Anda. Pola `garmin_report*` dan `reports/` sudah ada di
> `.gitignore`. Jangan commit laporan atau data mentah ke repo.

## Test

```bash
python3 -I -m unittest discover -s tools/garmin_inventory/tests
```

Opsional, uji dengan file FIT nyata (misalnya `tests/files` dari
[python-fitparse](https://github.com/dtcooper/python-fitparse)):

```bash
FIT_SAMPLES_DIR=/path/to/python-fitparse/tests/files \
    python3 -I -m unittest discover -s tools/garmin_inventory/tests
```

Decoder (`fit.py`) sudah diuji silang dengan python-fitparse pada 42 file contoh. Hasilnya identik
untuk ke-36 file yang bisa dibaca fitparse. Enam file lainnya ditolak fitparse (header rusak,
terpotong, field tidak sejajar). Di file-file itu decoder kita tetap membaca bagian yang utuh dan
melaporkan kerusakannya.

## Isi

| File | Isi |
|---|---|
| `fit.py` | Decoder FIT generik dari spesifikasi publik: file berantai, compressed timestamp, `timestamp_16` monitoring, developer field, big-endian, field tidak sejajar, file terpotong |
| `fit_profile.py` | Nama pesan/field (profil publik + yang ditandai `community` dari Gadgetbridge) dan peta sinyal kanonik |
| `inventory.py` | Penjelajah folder/zip, statistik, dan laporan |
