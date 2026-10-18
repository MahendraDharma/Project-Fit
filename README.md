<p align="center">
  <img src="docs/assets/logo.png" alt="ProjectFit" width="128" height="128">
</p>

<h1 align="center">ProjectFit</h1>

<p align="center">
  <strong>Aplikasi kebugaran local-first untuk WHOOP &amp; Garmin</strong><br>
  Kesiapan · Beban · Tidur · Beban latihan — semua dihitung di HP Anda
</p>

<p align="center">
  <a href="LICENSE"><img alt="Lisensi AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-blue"></a>
  <img alt="Flutter 3.41.6" src="https://img.shields.io/badge/Flutter-3.41.6-02569B?logo=flutter">
  <img alt="iOS dan Android" src="https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey">
  <a href="docs/IOS_SIDELOAD.md"><img alt="Pasang di iPhone" src="https://img.shields.io/badge/iPhone-sideload-black?logo=apple"></a>
</p>

Aplikasi kebugaran local-first yang menggabungkan fondasi **OpenStrap**, model harian ala
**WHOOP** (kesiapan → beban → tidur), dan sisi latihan ala **Garmin Connect**. Semua data
dibaca langsung dari perangkat, diolah di HP, dan tidak dikirim ke server mana pun tanpa
izin eksplisit.

> ProjectFit adalah fork dari [OpenStrap](https://github.com/OpenStrap) (AGPL-3.0). Lihat
> [`NOTICE.md`](NOTICE.md) untuk atribusi dan daftar perubahan. Tidak berafiliasi dengan
> OpenStrap, WHOOP, maupun Garmin. Metrik di aplikasi ini adalah perkiraan, bukan alat medis.

## Pasang di iPhone

Gratis, dengan Apple ID sendiri. Tidak perlu App Store, akun developer, maupun jailbreak.

- **iOS 27 ke atas, cukup iPhone:** pasang [SideInstaller](https://sideinstaller.net) → SideStore,
  lalu tambahkan sumber `https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json`.
- **iOS 15–26:** unduh
  **[ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)**
  di komputer, lalu pasang dengan [Sideloadly](https://sideloadly.io).

Tutorial langkah demi langkah, cara perpanjang setiap 7 hari, dan tanya jawab:
**[docs/IOS_SIDELOAD.md](docs/IOS_SIDELOAD.md)**.

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
