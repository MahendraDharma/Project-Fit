<p align="center">
  <img src="assets/logo.png" alt="ProjectFit" width="96" height="96">
</p>

# Memasang ProjectFit di Android

ProjectFit untuk Android dipasang langsung dari file **APK**, tanpa Play Store. Gratis.

**Butuh:** HP Android 8.0 (Oreo) ke atas, Bluetooth, dan band WHOOP 4.0/5.0/MG
(atau jam Garmin lewat ProjectFit Bridge).

## 1. Unduh

Buka halaman rilis terbaru di HP Anda dan unduh **ProjectFit.apk**:

<https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.apk>

## 2. Pasang

1. Buka file yang baru diunduh (dari notifikasi unduhan atau aplikasi **File**).
2. Android akan bilang aplikasi dari sumber ini tidak diizinkan. Ketuk **Setelan**, lalu nyalakan
   **Izinkan dari sumber ini** untuk browser atau aplikasi File yang Anda pakai.
3. Kembali, lalu ketuk **Pasang**.
4. Kalau muncul peringatan Play Protect ("aplikasi tidak dikenal"), ketuk **Detail lainnya →
   Tetap pasang**. Peringatan ini muncul karena ProjectFit tidak dari Play Store.

## 3. Izin yang diminta saat pertama dibuka

| Izin | Untuk apa |
|---|---|
| **Perangkat di sekitar** (Bluetooth) | Menyambung ke band |
| **Notifikasi** | Pengingat, alarm, dan status sinkron |
| **Health Connect** (opsional) | Membaca/menulis data ke Health Connect |
| **Lokasi** (opsional, hanya saat latihan) | Rute GPS saat latihan |
| **Abaikan pengoptimalan baterai** (disarankan) | Agar sinkron di latar belakang tidak dimatikan sistem |

Semua data tetap di HP Anda. Tidak ada akun dan tidak ada server.

## 4. Memperbarui

Unduh **ProjectFit.apk** dari rilis yang lebih baru lalu pasang seperti langkah 2. Data Anda tetap
ada, karena setiap rilis ditandatangani dengan kunci yang sama.

> File bernama **ProjectFit-test.apk** adalah versi uji dengan kunci sementara. Versi uji **tidak
> bisa** diperbarui di tempat: untuk pindah ke versi resmi, aplikasi harus dihapus dulu, dan data di
> HP ikut terhapus. Cadangkan data dulu dari menu **Profil › Data** bila perlu.

## Masalah umum

| Gejala | Solusi |
|---|---|
| "Aplikasi tidak terpasang" | Ada versi lain dengan kunci berbeda (mis. versi uji). Hapus dulu, lalu pasang lagi. |
| Band tidak ditemukan | Nyalakan Bluetooth dan Lokasi, beri izin **Perangkat di sekitar**, dekatkan band. |
| Sinkron berhenti di latar belakang | Setelan › Aplikasi › ProjectFit › Baterai › **Tidak dibatasi**. |

---

## Untuk pemilik repo: kunci rilis

Workflow **android-release** menandatangani APK dengan kunci dari GitHub Secrets. Pasang sekali di
**Settings → Secrets and variables → Actions → New repository secret**:

| Nama secret | Isi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | isi file `keystore.base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | kata sandi keystore |
| `ANDROID_KEY_ALIAS` | `projectfit` |
| `ANDROID_KEY_PASSWORD` | kata sandi kunci |

Simpan cadangan `projectfit-release.jks` dan kata sandinya di tempat aman. Kunci ini **tidak boleh
hilang**: tanpa kunci yang sama, pengguna tidak bisa memperbarui aplikasi tanpa menghapusnya.

Membuat rilis: **Actions → android-release → Run workflow**, isi `release_tag` (misalnya `v0.16.0`).
APK akan ditambahkan ke rilis dengan tag itu.
