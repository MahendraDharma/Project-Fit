# Memasang ProjectFit di iPhone tanpa akun developer berbayar

TestFlight dan App Store butuh Apple Developer Program (USD 99/tahun). Jalur ini gratis:
GitHub membangun file `.ipa` **tanpa tanda tangan**, lalu aplikasi sideloading menandatanganinya
dengan **Apple ID gratis Anda sendiri** saat dipasang. OpenStrap memakai jalur yang sama.

## 1. Ambil file `.ipa`

1. Buka https://github.com/MahendraDharma/Project-Fit/actions/workflows/ios-sideload.yml
2. Klik **Run workflow** (kalau tombolnya belum ada, workflow terakhir yang sukses juga bisa dipakai).
3. Tunggu sekitar 15–25 menit sampai selesai (centang hijau).
4. Buka run tersebut → bagian **Artifacts** → unduh `projectfit-ipa` (berisi zip; ekstrak untuk
   mendapatkan `projectfit-…-unsigned.ipa`).

Untuk rilis bertag (`v0.1.0` dst.), file `.ipa` dan `apps.json` (sumber AltStore) juga ditempel
di halaman **Releases**.

## 2. Pilih alat pemasang

| Alat | Butuh komputer? | Cocok untuk |
|---|---|---|
| **Sideloadly** | Ya (Windows/Mac), setiap kali pasang ulang | Paling mudah untuk percobaan pertama |
| **AltStore** | Ya, AltServer di Windows/Mac harus menyala di Wi-Fi yang sama untuk refresh mingguan | Pemakaian rutin dengan komputer di rumah |
| **SideStore** | Hanya sekali saat setup awal; setelah itu refresh langsung dari iPhone | Pemakaian rutin tanpa komputer |

### Sideloadly (disarankan untuk mulai)
1. Pasang Sideloadly dari https://sideloadly.io dan iTunes versi situs Apple (bukan Microsoft
   Store) kalau di Windows.
2. Sambungkan iPhone dengan kabel, buka kunci, pilih **Trust This Computer**.
3. Seret file `.ipa` ke Sideloadly, isi Apple ID, klik **Start**.
4. Di iPhone: **Settings → General → VPN & Device Management** → percayai Apple ID Anda.
5. iOS 16 ke atas: **Settings → Privacy & Security → Developer Mode** → nyalakan, lalu restart.

### SideStore (tanpa komputer setelah setup)
Ikuti panduan resmi https://docs.sidestore.io. Setelah terpasang, buka file `.ipa` dengan
SideStore. Untuk update otomatis dari rilis bertag, tambahkan sumber:
`https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json`

## 3. Batasan Apple ID gratis

- **Kedaluwarsa 7 hari.** Aplikasi berhenti terbuka setelah 7 hari kecuali di-*refresh*
  (AltStore/SideStore melakukannya otomatis; Sideloadly: pasang ulang). Data di dalam aplikasi
  tidak hilang selama aplikasi tidak dihapus.
- **Maksimal 3 aplikasi** sideload aktif sekaligus, dan batas jumlah App ID per minggu.
  Ekstensi (widget, Siri) ikut menghabiskan App ID; kalau kena batas, matikan opsi ekstensi di
  alat pemasangnya.
- **Apple Watch tidak ikut.** Aplikasi Watch dibuang dari `.ipa` karena tidak bisa bertahan saat
  ditandatangani ulang dengan Apple ID gratis.
- **Widget, Live Activity, dan pintasan Siri mungkin tidak berfungsi**, karena App Group ikut
  berganti saat ditandatangani ulang.
- **Apple Health (HealthKit)** belum diverifikasi di jalur ini. Kalau izin Health tidak muncul,
  fitur inti (Bluetooth WHOOP, perhitungan, layar) tetap jalan.
- Disarankan memakai **Apple ID kedua** khusus untuk sideloading, karena alat-alat ini meminta
  kata sandi Apple ID.

## 4. Setelah terpasang

1. Jangan hubungkan WHOOP ke aplikasi resmi WHOOP selama memakai ProjectFit (satu strap hanya
   bisa terhubung ke satu aplikasi; update firmware bisa mengubah protokol).
2. Buka ProjectFit → pasangkan WHOOP 4.0.
3. Data lama dari OpenStrap bisa dibawa masuk: **Profile → Export and backup**, lalu pilih file
   ekspor OpenStrap (`.db`). Sudah diuji dengan ekspor OpenStrap asli (skema v58): semua data per
   detik, interval detak jantung, metrik dan latihan masuk utuh.

## Alternatif lain

- **Build dari source dengan Mac + Xcode** (Apple ID gratis): satu-satunya cara agar aplikasi
  Apple Watch ikut terpasang. Tetap kedaluwarsa 7 hari.
- **HP Android**: tidak ada batasan di atas; `.apk` bisa dipasang langsung.
