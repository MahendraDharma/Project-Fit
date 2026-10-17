# ProjectFit

Aplikasi kebugaran local-first yang menggabungkan fondasi **OpenStrap**, model harian ala
**WHOOP** (kesiapan → beban → tidur), dan sisi latihan ala **Garmin Connect**. Semua data
dibaca langsung dari perangkat, diolah di HP, dan tidak dikirim ke server mana pun tanpa
izin eksplisit.

> ProjectFit adalah fork dari [OpenStrap](https://github.com/OpenStrap) (AGPL-3.0). Lihat
> [`NOTICE.md`](NOTICE.md) untuk atribusi dan daftar perubahan. Tidak berafiliasi dengan
> OpenStrap, WHOOP, maupun Garmin. Metrik di aplikasi ini adalah perkiraan, bukan alat medis.

## Struktur repo

| Folder | Isi |
|---|---|
| [`app/`](app) | Aplikasi Flutter (iOS & Android): Bluetooth, database lokal, mesin hitung, UI |
| [`packages/protocol/`](packages/protocol) | Decoder byte perangkat (WHOOP, Garmin, Oura, Polar, dll.). Dart murni tanpa dependensi |
| [`packages/analytics/`](packages/analytics) | Algoritma metrik dari metode terbitan (HRV, tidur, kesiapan, beban, dll.) |
| [`tools/garmin_inventory/`](tools/garmin_inventory) | Alat inventaris data Garmin (ekspor akun / folder `GARMIN` jam) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Rancangan arsitektur dan roadmap |

## Perangkat

- **WHOOP 4.0 / 5.0 / MG**: langsung via Bluetooth.
- **Garmin Forerunner 55**: melalui Apple Health dan impor file FIT (dalam pengerjaan).
- **Strap HR Bluetooth standar**.
- Perangkat lain dari OpenStrap (Oura, Polar, Colmi, dll.) tetap berstatus eksperimental.

## Pengembangan

Butuh Flutter 3.41.6.

```bash
cd packages/protocol  && flutter pub get && flutter test
cd packages/analytics && flutter pub get && flutter test
cd app                && flutter pub get && flutter analyze && flutter test
```

Layanan yang mati secara default dan dinyalakan per build:

| Fitur | Cara menyalakan |
|---|---|
| Telemetri crash (opt-in) | `flutterfire configure` dengan proyek Firebase sendiri |
| Kirim laporan masalah | `--dart-define=REPORT_URL=...` dan `--dart-define=REPORT_PUBLIC_KEY=...` |
| Pengecekan update / impor akun lama | `--dart-define=COMPANION_URL=...` / `BACKEND_URL=...` |

## Lisensi

AGPL-3.0. Lihat [`LICENSE`](LICENSE) dan [`NOTICE.md`](NOTICE.md).
