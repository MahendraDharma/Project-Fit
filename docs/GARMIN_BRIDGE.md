# ProjectFit Bridge — jam Garmin bersama Garmin Connect

ProjectFit membaca **stres, Body Battery, SpO₂ dan langkah** dari jam Garmin
tanpa memutus Garmin Connect. Caranya memakai jalur resmi Garmin untuk
aplikasi pendamping (Connect IQ):

- di **jam** terpasang aplikasi kecil **ProjectFit** (ProjectFit Bridge) yang
  membaca angka yang sudah diukur jam;
- di **iPhone**, ProjectFit menerimanya lewat Connect IQ Mobile SDK, di samping
  Garmin Connect yang tetap tersambung seperti biasa.

Garmin Connect tidak perlu dimatikan, dan datanya tidak diubah.

## 1. Unduh file untuk jam Anda

1. Buka halaman rilis **garmin-bridge**:
   <https://github.com/MahendraDharma/Project-Fit/releases/tag/garmin-bridge>
2. Unduh file yang namanya sesuai model jam Anda:

| Jam | File |
| --- | --- |
| Forerunner 165 / 165 Music | `ProjectFit-fr165.prg` / `ProjectFit-fr165m.prg` |
| Forerunner 170 / 170 Music | `ProjectFit-fr170.prg` / `ProjectFit-fr170m.prg` |
| Forerunner 245 / 245 Music | `ProjectFit-fr245.prg` / `ProjectFit-fr245m.prg` |
| Forerunner 255 / 255 Music | `ProjectFit-fr255.prg` / `ProjectFit-fr255m.prg` |
| Forerunner 255S / 255S Music | `ProjectFit-fr255s.prg` / `ProjectFit-fr255sm.prg` |
| Forerunner 265 / 265S | `ProjectFit-fr265.prg` / `ProjectFit-fr265s.prg` |
| Forerunner 55 / 70 | `ProjectFit-fr55.prg` / `ProjectFit-fr70.prg` |
| Forerunner 570 (42 mm / 47 mm) | `ProjectFit-fr57042mm.prg` / `ProjectFit-fr57047mm.prg` |
| Forerunner 645 Music | `ProjectFit-fr645m.prg` |
| Forerunner 745 | `ProjectFit-fr745.prg` |
| Forerunner 945 / 945 LTE | `ProjectFit-fr945.prg` / `ProjectFit-fr945lte.prg` |
| Forerunner 955 / 965 / 970 | `ProjectFit-fr955.prg` / `ProjectFit-fr965.prg` / `ProjectFit-fr970.prg` |

Forerunner 230/235/630/645 (non-Music)/735XT/920XT/935 dan 45 tidak bisa
menjalankan aplikasi ini (versi Connect IQ-nya terlalu lama).

## 2. Salin ke jam lewat kabel USB

1. Sambungkan jam ke komputer dengan kabel charger Garmin.
2. Buka penyimpanan jam:
   - **Windows:** jam muncul di File Explorer sebagai perangkat.
   - **Mac:** pasang aplikasi gratis **OpenMTP** (<https://openmtp.ganeshrvel.com>)
     lalu buka jam di sana. (Finder tidak bisa membuka jam Garmin model baru.)
3. Salin file `.prg` tadi ke folder **`GARMIN/APPS`** di jam.
4. Lepas kabel. Jam akan memasang aplikasinya sendiri dalam beberapa detik.

Di jam, aplikasi **ProjectFit** ada di daftar aktivitas/aplikasi (tekan tombol
START, gulir ke bawah). Kalau dibuka, layarnya menulis `ProjectFit` dan
statusnya (`Sending…`, `Sent to phone`).

Memperbarui: salin file `.prg` yang baru ke tempat yang sama (timpa yang lama).

## 3. Sambungkan di ProjectFit (iPhone)

1. Buka **ProjectFit → Profil → Perangkat**.
2. Di kartu **Jam Garmin (bersama Garmin Connect)**, ketuk
   **Pilih jam di Garmin Connect**.
3. Garmin Connect terbuka: pilih jam Anda lalu izinkan ProjectFit. Anda akan
   dibawa kembali ke ProjectFit.
4. Kartunya sekarang menunjukkan nama jam, **ProjectFit sudah ada di jam**, dan
   tombol **Sinkron sekarang**.

Setelah itu, setiap kali Anda menekan **Sinkron** di Home (atau menarik layar ke
bawah), ProjectFit meminta data baru dari jam. Hasilnya muncul di kartu
**Stress & energy** di Home, layar **Stres** dan **Body Battery**, dengan label
"Data dari Garmin".

## Kalau tidak berhasil

| Pesan di kartu | Artinya / yang perlu dicoba |
| --- | --- |
| *jam tidak terjangkau* | Jam harus dekat HP dan tersambung ke Garmin Connect (lihat di Garmin Connect apakah jam "Terhubung"). |
| *ProjectFit belum ada di jam* | Langkah 2 belum berhasil, atau file `.prg` tidak sesuai model jam. |
| *jam tidak mengirim datanya tepat waktu* | Buka aplikasi ProjectFit di jam (atau ketuk **Buka ProjectFit di jam**), lalu sinkron lagi. Sebagian jam hanya menjawab saat aplikasinya terbuka. |
| Jam tidak muncul di Garmin Connect saat memilih | Perbarui Garmin Connect ke versi terbaru, lalu coba lagi. |

## Catatan teknis

- Kode jam: `garmin-bridge/` (Monkey C). Build: `.github/workflows/garmin-bridge.yml`
  (SDK dan definisi perangkat dari image `ghcr.io/matco/connectiq-tester`).
- Kode iPhone: `app/ios/ConnectIQBridge/` (Connect IQ Mobile SDK, diunduh saat
  `pod install`) dan `app/lib/garmin/connectiq_link.dart`.
- Yang dibaca jam: `SensorHistory` (stres, Body Battery, SpO₂ — hingga 48 jam
  terakhir) dan `ActivityMonitor` (langkah harian 7 hari). HRV dan tahap tidur
  tidak disediakan Connect IQ untuk aplikasi pihak ketiga.
- Jalur Bluetooth langsung yang lama (`ble/garmin_link.dart`) otomatis tidak
  dipakai begitu jam disambungkan lewat Connect IQ, karena jalur itu harus
  merebut saluran jam dari Garmin Connect.
