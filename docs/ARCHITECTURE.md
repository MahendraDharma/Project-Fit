# Project-Fit — Rancangan Arsitektur

Status: **draf v0.2** · Bahasa kerja: Indonesia · Terakhir diperbarui: 2026-10-17

**Keputusan yang sudah diambil:** fork OpenStrap (AGPL-3.0) · nama aplikasi **ProjectFit**.

Satu aplikasi yang menggabungkan apa yang dilakukan tiga aplikasi:

| Sumber inspirasi | Yang diambil |
|---|---|
| **OpenStrap** | Fondasi teknis: baca data langsung dari perangkat via Bluetooth, decode on-device, semua hitungan di HP, local-first |
| **WHOOP** | Model harian *recovery → strain → sleep*, kebutuhan tidur, jurnal kebiasaan → dampak, usia biologis |
| **Garmin Connect** | Sisi latihan: beban latihan, status latihan, VO₂max, prediksi lomba, rencana latihan adaptif, GPS |

Perangkat awal: **WHOOP 4.0/5.0/MG**, **Garmin Forerunner 55**, strap HR Bluetooth standar, sensor HP.
Platform utama: **iPhone** (Android menyusul dari basis kode yang sama).

---

## 0. Keputusan yang harus diambil lebih dulu

### 0.1 Lisensi: fork OpenStrap atau tulis ulang?

Repo inti OpenStrap (`edge`, `protocol`, `analytics`) berlisensi **AGPL-3.0**. `research` dan
`backend` berlisensi MIT. Ada dua jalan:

| | A. Fork OpenStrap (AGPL) | B. Tulis ulang bersih (clean-room) |
|---|---|---|
| Kecepatan | Cepat: ±220 ribu baris aplikasi, decoder dan ±70 algoritma langsung tersedia | Lambat: berbulan-bulan untuk mencapai titik yang sama |
| Kewajiban | Seluruh aplikasi wajib AGPL: source dibuka untuk semua pengguna, termasuk bila dijalankan sebagai layanan | Lisensi bebas dipilih (boleh tertutup) |
| Merek | Wajib ganti nama, logo dan ikon (lihat `TRADEMARKS.md` OpenStrap). Boleh menulis "berbasis OpenStrap" | Tidak terikat |
| Dokumen protokol | Bebas dipakai | `research/PROTOCOL.md` (MIT) tetap boleh dipakai sebagai referensi |

**Diputuskan: A (fork).** ProjectFit berlisensi AGPL-3.0 (lihat `LICENSE`). Alasannya: nilai terbesar
OpenStrap justru ada di bagian yang paling mahal untuk dibuat ulang (decoder yang sudah diuji di
perangkat asli dan mesin metrik).

Catatan yang sama berlaku untuk **Gadgetbridge** (AGPL-3.0): kalau jalan B dipilih, Gadgetbridge
hanya boleh dibaca sebagai referensi perilaku protokol, kodenya tidak disalin.

### 0.2 Nama dan istilah

"WHOOP", "Recovery/Strain" versi WHOOP, "Garmin", "Body Battery", "Training Readiness" adalah merek
atau istilah produk. Aplikasi memakai **nama sendiri** untuk setiap skor (usulan di §5).

---

## 1. Prinsip desain

1. **Local-first.** Data mentah, hasil decode dan semua skor tinggal di HP. Tidak ada akun wajib.
   Cloud hanya opt-in (backup terenkripsi, sinkron antar-perangkat).
2. **Byte mentah tidak pernah dibuang.** Setiap paket/file dari perangkat disimpan apa adanya
   sehingga bisa di-decode ulang saat pemahaman protokol membaik (pola `substrate_archive` OpenStrap).
3. **Jujur soal asal angka.** Setiap angka yang tampil membawa label: *milik kita*, *milik perangkat*,
   *estimasi*, atau *tidak tersedia + alasannya* (pola `canonical.dart` OpenStrap).
4. **Metode terbitan, bukan algoritma rahasia.** Semua skor dibangun dari metode yang dipublikasikan
   dan dicantumkan sumbernya. Tidak menyalin kode atau aset dari aplikasi WHOOP/Garmin.
5. **Tidak merusak ekosistem asli.** Integrasi Garmin tidak boleh membuat jam berhenti sinkron
   dengan Garmin Connect (file tidak ditandai "sudah dibaca", tidak ada perintah destruktif).
6. **Bukan alat medis.** Semua metrik adalah perkiraan untuk kebugaran, ditandai jelas.

---

## 2. Gambaran besar

```
┌─────────────────────────── PERANGKAT & SUMBER ───────────────────────────┐
│ WHOOP (BLE)   Garmin FR55        Strap HR (BLE)   Apple Health   Sensor HP │
│               ├ Apple Health                       / Health Connect  (GPS, │
│               ├ Impor FIT (USB/ekspor)                               langkah)│
│               └ BLE GFDI (eksperimental)                                    │
└──────┬───────────────┬──────────────────┬──────────────┬───────────────┬──┘
       ▼               ▼                  ▼              ▼               ▼
┌──────────────────────── 1. INGEST (adapter per sumber) ──────────────────┐
│ ble/<device>_link  ·  import/fit_importer  ·  health/healthkit_reader     │
└──────┬───────────────────────────────────────────────────────────────────┘
       ▼
┌──────────────────────── 2. ARSIP MENTAH (immutable) ──────────────────────┐
│ raw_frames / raw_files  — byte asli + sumber + waktu terima + hash        │
└──────┬───────────────────────────────────────────────────────────────────┘
       ▼  decode (package protocol — Dart murni, tanpa I/O)
┌──────────────────────── 3. SUBSTRAT KANONIK ──────────────────────────────┐
│ deret 1 Hz (HR, RR, gerak, kulit…) · deret per menit · episode            │
│ (tidur, aktivitas, wear) · nilai bawaan perangkat ("observation")         │
└──────┬───────────────────────────────────────────────────────────────────┘
       ▼  fusi multi-perangkat (§4)  →  mesin hitung (package analytics)
┌──────────────────────── 4. METRIK TURUNAN ────────────────────────────────┐
│ harian: Kesiapan, Beban, Energi, Tidur, Stres · jangka panjang: Status     │
│ Latihan, VO₂max, Usia Kebugaran · wawasan: jurnal → dampak                 │
└──────┬───────────────────────────────────────────────────────────────────┘
       ▼
┌──────────────────────── 5. APLIKASI (Flutter) ────────────────────────────┐
│ Hari Ini · Tidur · Latihan · Kesehatan · Jurnal · Coach (BYOK AI)          │
└──────────────────────────────────────────────────────────────────────────┘
       ┆ opt-in saja
┌──────────────────────── 6. CLOUD OPSIONAL ────────────────────────────────┐
│ backup terenkripsi end-to-end · info update · telemetri crash (opt-in)    │
└──────────────────────────────────────────────────────────────────────────┘
```

Pemisahan package mengikuti OpenStrap:

| Package | Isi | Aturan |
|---|---|---|
| `protocol` | Codec byte semua perangkat | Dart murni, nol dependensi, tanpa I/O |
| `analytics` | Semua algoritma metrik | Dart murni, deterministik, tiap metrik punya `confidence` dan `tier` |
| `app` (fork `edge`) | BLE, database, impor, UI, notifikasi | Satu-satunya yang boleh menyentuh platform |

---

## 3. Sumber data per perangkat

### 3.1 WHOOP 4.0 / 5.0 / MG — langsung via Bluetooth
Sudah dibuktikan oleh OpenStrap: framing, ACK sinkron historis, rekaman 1 Hz (HR, RR, akselerometer,
ADC PPG/suhu), event wrist on/off, live stream. Kualitas data **tertinggi** dari semua sumber.

Batasan: BLE satu central. Selama WHOOP dipakai di aplikasi ini, aplikasi resmi WHOOP tidak boleh
terhubung (risiko update firmware mengubah protokol).

### 3.2 Garmin Forerunner 55 — empat jalur, dipakai bertahap

FR55 punya: HR per menit, stres, Body Battery, tidur (tahap + skor), respirasi, langkah, VO₂max,
recovery time, aktivitas GPS. **Tidak punya** HRV Status dan Training Readiness.

| Jalur | Data | Kelebihan | Kekurangan | Tahap |
|---|---|---|---|---|
| **a. Apple Health** (`health` plugin) | Yang ditulis Garmin Connect ke Health: langkah, HR, tidur, workout, kalori (daftar pasti perlu diverifikasi) | Resmi, otomatis, Garmin Connect tetap jalan | Tidak ada stres/Body Battery; resolusi bisa turun | 1 |
| **b. Impor file FIT** (USB folder `GARMIN/` atau zip ekspor akun) | Semua yang disimpan jam: HR per menit, stres, Body Battery (`stress_level` field 3), tidur, respirasi, aktivitas lengkap | Data terlengkap, bisa offline | Manual (colok kabel / minta ekspor) | 1 |
| **c. BLE GFDI langsung** | Sama dengan (b), otomatis | Tanpa Garmin Connect | FR55 hanya bisa dipasangkan ke satu aplikasi; protokol eksperimental; menggantikan Garmin Connect | 3 (opsional) |
| **d. Garmin Health API** (cloud resmi) | Ringkasan harian, tidur, stres, Body Battery | Resmi, otomatis | Butuh pendaftaran & persetujuan bisnis Garmin; data lewat server | Evaluasi |

Rekomendasi: **(a) + (b) dulu.** Jalur (c) hanya bila pengguna memilih melepas Garmin Connect.

### 3.3 Strap HR standar (BLE Heart Rate Service 0x180D)
HR + interval RR saat latihan. Sumber HRV yang bagus untuk Garmin FR55 yang tidak mengekspos RR.

### 3.4 Sensor HP
GPS untuk aktivitas, langkah dari pedometer HP sebagai cadangan.

---

## 4. Model data

### 4.1 Lapisan penyimpanan (SQLite on-device)

| Lapisan | Tabel (usulan) | Isi | Bisa dihitung ulang? |
|---|---|---|---|
| Arsip mentah | `raw_frame`, `raw_file` | Byte asli + `source`, `device_id`, `received_at`, `sha256` | Tidak (sumber kebenaran) |
| Substrat | `sample_1hz`, `sample_minute` | Deret waktu ter-decode per sinyal | Ya, dari arsip |
| Episode | `sleep_episode`, `activity`, `wear_span` | Rentang waktu bermakna | Ya |
| Observasi perangkat | `observation` | Angka asli perangkat (mis. Body Battery Garmin, sleep score Garmin) | Ya |
| Metrik | `daily_metric`, `metric_series` | Skor kita + `method`, `confidence`, `tier`, `inputs_hash` | Ya |
| Pengguna | `journal_entry`, `profile`, `goal`, `plan` | Input manual | Tidak |

### 4.2 Kosakata sinyal kanonik
`hr_bpm`, `rr_ms`, `accel_g[3]`, `steps`, `skin_temp_raw`, `spo2_pct`, `resp_rate`,
`stress_device`, `energy_device`, `sleep_stage_device`, `speed`, `position`, …
Setiap adapter hanya memetakan ke kosakata ini (pola `compute/inputs/*_inputs.dart`).

### 4.3 Fusi multi-perangkat
Kalau dua perangkat mengirim sinyal yang sama pada waktu yang sama:

1. **Resolusi lebih tinggi menang**: WHOOP 1 Hz > strap HR > Garmin per menit > Apple Health.
2. **Yang sedang dipakai menang**: perangkat dengan wear-span aktif mengalahkan yang off-wrist.
3. **Tidak dirata-ratakan diam-diam**: pilihan sumber per jendela waktu dicatat, dan UI bisa
   menunjukkan "HR malam ini dari WHOOP, latihan pagi dari strap".
4. **Angka bawaan perangkat tidak menjadi input** skor kita. Angka itu ditampilkan berdampingan
   untuk pembanding.

---

## 5. Peta fitur gabungan

Nama skor di kolom pertama adalah usulan nama sendiri (bukan merek WHOOP/Garmin).

### 5.1 Inti harian

| Fitur (nama kita) | Mirip | Input | Metode terbitan | Di OpenStrap | Prioritas |
|---|---|---|---|---|---|
| **Kesiapan** 0–100 | WHOOP Recovery, Garmin Training Readiness | HRV malam (ln RMSSD), RHR, tidur, respirasi, suhu | Plews/Buchheit ln-RMSSD vs baseline 7/60 hari | ✅ `readiness_*` | P0 |
| **Beban harian** | WHOOP Strain | HR sepanjang hari & latihan | Banister TRIMP / Edwards zones, skala logaritmik sendiri | ✅ `load_trimp`, `session_cost` | P0 |
| **Tidur** + kebutuhan tidur | WHOOP Sleep, Garmin Sleep Score | Tahap tidur, durasi, efisiensi, regularitas, utang tidur | Cole-Kripke / van Hees, SRI (Phillips 2017) | ✅ sebagian; kebutuhan tidur ❌ | P0 |
| **Energi** 0–100 sepanjang hari | Garmin Body Battery | HRV/stres (menguras), istirahat & tidur (mengisi), aktivitas | Model anggaran energi dari stres HRV (pendekatan Firstbeat yang dipublikasikan) | ❌ | P1 |
| **Stres** | Garmin Stress, WHOOP Stress Monitor | HRV & HR saat diam | Baevsky Stress Index | ✅ `stress_si` | P1 |

### 5.2 Latihan (dari Garmin)

| Fitur | Input | Metode | Di OpenStrap | Prioritas |
|---|---|---|---|---|
| **Beban akut/kronis** + rasio | TRIMP per hari | Banister fitness-fatigue (ATL 7 hari / CTL 42 hari / TSB), ACWR | ❌ | P1 |
| **Status latihan** (produktif, mempertahankan, berlebih, …) | Tren CTL + tren VO₂max + Kesiapan | Aturan transparan di atas ATL/CTL/TSB | ❌ | P2 |
| **VO₂max** | HR vs kecepatan lari | Uth–Sørensen (diam) dan regresi HR-kecepatan (aktivitas) | ✅ `vo2max` | P1 |
| **Prediksi lomba** 5K–maraton | VO₂max / lomba terbaru | Daniels VDOT, Riegel | ❌ | P2 |
| **Zona HR & pemulihan HR** | HR max/istirahat | Karvonen, HRR 1 menit | ✅ | P0 |
| **Waktu pemulihan** | Beban sesi + Kesiapan | Aturan transparan | ❌ | P2 |
| **Rencana latihan adaptif** | Tujuan + semua di atas | Periodisasi + penyesuaian harian dari Kesiapan | ❌ | P3 |
| **Rekam aktivitas GPS** | GPS HP / file FIT jam | — | ✅ sebagian (`gps/`) | P2 |

### 5.3 Kesehatan & wawasan (dari WHOOP)

| Fitur | Input | Metode | Di OpenStrap | Prioritas |
|---|---|---|---|---|
| **Jurnal → dampak** | Jurnal harian + Kesiapan/Tidur | Perbandingan berpasangan dengan uji signifikansi | ✅ `associations` | P1 |
| **Deteksi anomali / sakit** | RHR, suhu, respirasi | CUSUM, change-point | ✅ `illness_cusum`, `anomaly` | P2 |
| **Siklus menstruasi** | Suhu kulit + log | Cosinor / deteksi kenaikan suhu | ✅ `cycle_lengths`, `temp_*` | P2 |
| **Usia kebugaran** | VO₂max, RHR, tidur, aktivitas | Model terbitan (mis. fitness age dari VO₂max, Nes 2013) | ❌ | P3 |
| **Coach AI** | Ringkasan metrik lokal | LLM dengan kunci milik pengguna (BYOK) | ✅ `ai/` | P2 |

---

## 6. Aplikasi (lapisan UI)

Tab usulan: **Hari Ini** (Kesiapan · Beban · Energi · Tidur) → **Tidur** → **Latihan**
(beban akut/kronis, status, VO₂max, aktivitas) → **Kesehatan** (tren, anomali, siklus) →
**Jurnal** → **Profil & Perangkat**.

Stack mengikuti OpenStrap: Flutter, `flutter_blue_plus`, `sqflite`, `health`, `workmanager`.
Hitungan berat dijalankan di isolate terpisah (OpenStrap pernah kena ANR karena staging tidur di
main thread).

Catatan iOS: sinkron latar belakang dibatasi iOS. Rencananya: sinkron saat aplikasi dibuka,
BLE state restoration untuk WHOOP, dan `BGTaskScheduler` untuk impor Apple Health.

---

## 7. Privasi & keamanan

- Data kesehatan tidak pernah meninggalkan HP tanpa tindakan eksplisit pengguna.
- Backup cloud (bila dibuat) dienkripsi di HP dengan kunci pengguna.
- Telemetri crash opt-in, tanpa data kesehatan, dimatikan di level platform sampai ada izin
  (pola Firebase OpenStrap: `*_collection_enabled=false` di Info.plist/Manifest).
- Endpoint backend apa pun yang menerima data wajib terautentikasi. Pelajaran dari backend
  OpenStrap: unggahan keyed `device_id` tanpa autentikasi, dan README menjanjikan `DELETE /data`
  yang tidak ada di kode.

---

## 8. Batasan legal & etika

- Tidak menyalin kode, aset, atau teks dari aplikasi WHOOP/Garmin. Reverse engineering hanya untuk
  **interoperabilitas** dengan perangkat milik pengguna sendiri dan untuk memahami perilaku,
  lalu diimplementasikan ulang dengan metode terbitan.
- Tidak membongkar langganan, DRM, atau layanan berbayar.
- Tidak memakai nama/merek pihak lain sebagai nama fitur. Penyebutan kompatibilitas ("bekerja
  dengan Garmin Forerunner 55") boleh.
- Disclaimer medis di onboarding dan di setiap layar metrik kesehatan.

---

## 9. Roadmap

| Fase | Isi | Hasil |
|---|---|---|
| **0. Fondasi** | Fork/setup repo; CI; ganti nama & branding ke ProjectFit ✅ (build iOS/Android belum diverifikasi) | App build di iPhone (TestFlight) |
| **1. Data masuk** | WHOOP BLE (dari OpenStrap); impor FIT Garmin (+ Body Battery field 3); Apple Health reader; alat inventaris data ✅ (`tools/garmin_inventory`) | Semua data FR55 + WHOOP pengguna terbaca |
| **2. Inti harian** | Kesiapan, Beban, Tidur + kebutuhan tidur, Stres dengan fusi multi-perangkat | Layar Hari Ini lengkap |
| **3. Latihan** | ATL/CTL/TSB, VO₂max, Energi, zona, aktivitas GPS | Tab Latihan |
| **4. Wawasan** | Jurnal → dampak, anomali, prediksi lomba, status latihan | Tab Kesehatan & Jurnal |
| **5. Lanjutan** | Rencana latihan adaptif, Coach AI, BLE Garmin langsung (opsional), Android | — |

---

## 10. Pertanyaan terbuka

1. Data apa yang ditulis Garmin Connect iOS ke Apple Health untuk FR55? → diverifikasi dari data
   ekspor/HP pengguna.
2. Apakah ekspor akun Garmin berisi data per menit, atau hanya ringkasan harian? → diverifikasi saat
   ekspor tiba.
3. Perlu cloud sync antar-perangkat, atau cukup backup?

## Referensi

- OpenStrap: https://github.com/OpenStrap (edge, protocol, analytics: AGPL-3.0; research, backend: MIT)
- Protokol WHOOP 4.0: `OpenStrap/research/PROTOCOL.md`
- Protokol Garmin: https://gadgetbridge.org/internals/specifics/garmin-protocol/
- Format FIT: https://developer.garmin.com/fit/protocol/
- Katalog algoritma: `OpenStrap/analytics/ALGORITHMS.md`
