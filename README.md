<p align="center">
  <img src="docs/assets/logo.png" alt="ProjectFit" width="128" height="128">
</p>

<h1 align="center">ProjectFit</h1>

<p align="center">
  <strong>Aplikasi kebugaran gratis untuk WHOOP &amp; Garmin</strong><br>
  Kesiapan · Beban · Tidur · Latihan — semua dihitung di HP Anda sendiri
</p>

<p align="center">
  <a href="https://github.com/MahendraDharma/Project-Fit/releases/latest"><img alt="Download" src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F_DOWNLOAD-untuk_iPhone-2ea44f?style=for-the-badge&amp;logo=apple&amp;logoColor=white"></a>
  &nbsp;
  <a href="docs/IOS_SIDELOAD.md"><img alt="Cara install" src="https://img.shields.io/badge/%F0%9F%93%96_CARA_INSTALL-tutorial_lengkap-0969da?style=for-the-badge"></a>
</p>

<p align="center">
  <a href="https://github.com/MahendraDharma/Project-Fit/releases/latest"><img alt="Versi terbaru" src="https://img.shields.io/github/v/release/MahendraDharma/Project-Fit?label=versi&amp;color=2ea44f"></a>
  <img alt="iOS 15 ke atas" src="https://img.shields.io/badge/iOS-15%2B-black?logo=apple">
  <img alt="Gratis" src="https://img.shields.io/badge/harga-gratis-success">
  <a href="LICENSE"><img alt="Lisensi AGPL-3.0" src="https://img.shields.io/badge/lisensi-AGPL--3.0-blue"></a>
</p>

---

## 📲 Cara pasang di iPhone

ProjectFit **tidak ada di App Store**. Anda tetap bisa memasangnya **gratis** dengan Apple ID
sendiri, tanpa jailbreak. Pilih cara sesuai versi iOS (cek di **Pengaturan → Umum → Mengenai**):

| iPhone Anda | Cara pasang | Perlu komputer? |
|---|---|---|
| **iOS 27 ke atas** | 👉 **[Tutorial A: cukup pakai iPhone](docs/IOS_SIDELOAD.md#tutorial-a--cukup-pakai-iphone-ios-27-ke-atas)** | ❌ Tidak |
| **iOS 15 – 26** | 👉 **[Tutorial B: pakai komputer](docs/IOS_SIDELOAD.md#tutorial-b--pakai-komputer-ios-15-sampai-26)** | ✅ Ya (Windows/Mac) |

**Gambaran singkat (iOS 27):**

1. Pasang **SideInstaller** dari [sideinstaller.net](https://sideinstaller.net), lalu pakai untuk
   memasang **SideStore**.
2. Di SideStore, tambahkan sumber ProjectFit (salin alamat di bawah):
   ```
   https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json
   ```
3. Ketuk **Install** pada ProjectFit. Selesai! Setiap 7 hari, ketuk **Refresh** di SideStore.

> [!TIP]
> Baru pertama kali? Ikuti **[tutorial lengkapnya](docs/IOS_SIDELOAD.md)**. Setiap langkah
> dijelaskan, termasuk apa yang muncul di layar dan cara mengatasi error.

<details>
<summary><b>⬇️ Hanya butuh file aplikasinya (.ipa)?</b></summary>

<br>

Unduh langsung: **[ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)**
(±21 MB). File ini dipasang dengan SideStore atau Sideloadly. Membukanya langsung di iPhone tidak
akan memasang apa-apa.

</details>

---

## ✨ Apa yang bisa dilakukan ProjectFit?

- **Kesiapan harian** dari detak jantung istirahat dan HRV, plus **status HRV** 7 hari.
- **Beban harian (strain)** dan **rasio beban latihan** (akut vs kronis).
- **Tidur**: durasi, kebutuhan tidur, dan **alarm yang membangunkan saat target tidur tercapai**.
- **Latihan beban**: jumlah set per kelompok otot.
- **Laporan bulanan**: apa yang benar-benar berubah dibanding bulan sebelumnya.
- **Privasi**: semua data dibaca langsung dari perangkat dan diolah di HP. Tidak ada akun, dan
  data tidak dikirim ke server mana pun.

**Perangkat yang didukung**

| Perangkat | Status |
|---|---|
| WHOOP 4.0 / 5.0 / MG | ✅ Langsung via Bluetooth |
| Strap detak jantung Bluetooth standar | ✅ |
| Garmin (mis. Forerunner 55) | 🛠️ Lewat Apple Health dan file FIT, sedang dikerjakan |
| Oura, Polar, Colmi, dll. | 🧪 Eksperimental |

> [!NOTE]
> ProjectFit adalah fork dari [OpenStrap](https://github.com/OpenStrap) dan tidak berafiliasi
> dengan OpenStrap, WHOOP, maupun Garmin. Angka di aplikasi ini adalah perkiraan, **bukan alat
> medis**.

---

## ❓ Pertanyaan umum

**Aman?** Kodenya terbuka untuk dibaca siapa saja. Aplikasi tidak butuh akun dan tidak mengirim
data kesehatan ke internet.

**Kenapa harus diperpanjang setiap 7 hari?** Itu aturan Apple untuk aplikasi yang dipasang dengan
Apple ID gratis. Di SideStore cukup ketuk **Refresh**, dan data Anda tidak hilang.

**Pakai WHOOP resmi juga?** Satu strap hanya bisa tersambung ke satu aplikasi. Putuskan dulu
WHOOP dari aplikasi resminya sebelum memakai ProjectFit.

**Pindah dari OpenStrap?** Data lama bisa dibawa: **Profile → Export and backup → pilih file
ekspor OpenStrap**.

Ada masalah? Lihat [bagian "Kalau ada masalah"](docs/IOS_SIDELOAD.md#-kalau-ada-masalah) di
tutorial, atau buka [Issues](https://github.com/MahendraDharma/Project-Fit/issues).

---

<details>
<summary><b>🧑‍💻 Untuk pengembang</b></summary>

### Struktur repo

| Folder | Isi |
|---|---|
| [`app/`](app) | Aplikasi Flutter (iOS & Android): Bluetooth, database lokal, mesin hitung, UI |
| [`packages/protocol/`](packages/protocol) | Decoder byte perangkat (WHOOP, Garmin, Oura, Polar, dll.). Dart murni tanpa dependensi |
| [`packages/analytics/`](packages/analytics) | Algoritma metrik dari metode terbitan (HRV, tidur, kesiapan, beban, dll.) |
| [`tools/garmin_inventory/`](tools/garmin_inventory) | Alat inventaris data Garmin (ekspor akun / folder `GARMIN` jam) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Rancangan arsitektur dan roadmap |

### Build dan tes

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

### Membuat rilis iPhone

**Actions → ios-sideload → Run workflow**, lalu isi `release_tag` (mis. `v0.11.4`). Workflow
membangun `.ipa` tanpa tanda tangan dan menerbitkannya di Releases.

</details>

## Lisensi

AGPL-3.0. Lihat [`LICENSE`](LICENSE) dan [`NOTICE.md`](NOTICE.md).
