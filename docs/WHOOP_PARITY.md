# Audit Kesetaraan Fitur: WHOOP vs ProjectFit

Status: v0.2 · 2026-10-17 · Perangkat acuan: **WHOOP 4.0**

Tujuan: daftar fitur aplikasi WHOOP, apa yang sudah ada di ProjectFit (warisan OpenStrap),
apa yang kurang, dan apa yang tidak bisa dibuat secara jujur dari data yang tersedia.

Sumber fitur WHOOP: halaman resmi WHOOP (support & The Locker) dan ulasan independen
(lihat Referensi). Rumus WHOOP sendiri tidak dipublikasikan. Jadi "setara" di sini berarti
fitur yang sama dengan metode terbitan, **bukan** angka yang sama persis dengan WHOOP.

Legenda: ✅ setara · 🟡 sebagian · ❌ belum ada · ⛔ tidak bisa dibuat jujur dengan data saat ini

## Ringkasan

| Status | Jumlah | Fitur |
|---|---|---|
| ✅ | 15 | Recovery, Strain 0–21, Strain target, Sleep performance, Sleep need & debt, konsistensi tidur, Journal, deteksi aktivitas, zona HR, rekap mingguan, Coach AI, langkah, **Strength Trainer (set per otot)**, **laporan bulanan**, **alarm bangun saat target tidur** |
| 🟡 | 8 | Restorative sleep, Sleep Planner, alarm haptic, Stress Monitor, Health Monitor (HR/HRV/RHR/napas ada; SpO₂ & suhu belum), siklus menstruasi, Heart Screener (ECG), Advanced Labs |
| ❌ | 1 | Alarm "bangun saat Recovery hijau" |
| ⛔ | 3 | Healthspan / WHOOP Age, SpO₂ & suhu kulit WHOOP 4.0 (sampai field-nya teridentifikasi), Blood Pressure Insights |

**Temuan terpenting:** pada WHOOP 4.0, SpO₂ dan suhu kulit **tidak bisa dibaca** dari rekaman
1 Hz. OpenStrap membuktikannya pada lebih dari 1 juta baris data asli (lihat §3). Ini menahan
tiga fitur sekaligus: Health Monitor, insight siklus berbasis suhu, dan sinyal sakit dari suhu.
Ini target reverse engineering nomor satu.

## 1. Inti harian

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Recovery** 0–100% | HRV (dominan), RHR, sleep performance, laju napas | Readiness: ln-RMSSD vs baseline, RHR, tidur, laju napas dari RSA; abstain bila data tipis (`analytics/.../human/readiness_glassbox.dart`, `clinical/readiness_lnrmssd.dart`) | ✅ metode berbeda |
| **Strain** 0–21 | Beban kardiovaskular, skala log | TRIMP di atas baseline dipetakan log ke 0–21 (`analytics/.../clinical/load_trimp.dart`) | ✅ |
| **Strain target** (Strain Coach) | Target harian dari Recovery | `strainTarget` di cross-day pipeline, dibatasi oleh readiness | ✅ |
| **Sleep performance** | Tidur aktual ÷ kebutuhan | Ada (`derivation_engine.dart`, Sleep Coach) | ✅ |
| **Sleep need & sleep debt** | Baseline + strain + utang − tidur siang | Ada, termasuk kredit tidur siang (kebutuhan dibatasi 6–11 jam) | ✅ |
| **Konsistensi tidur** | Keteraturan jadwal | Sleep Regularity Index (Phillips 2017) (`sleep/sri.dart`) | ✅ |
| **Restorative sleep** (REM + SWS) | Dari staging WHOOP | Staging dari HR + gerak (`sleep/advanced_stager.dart`, `cardio_stager.dart`); akurasi tahap dari wearable tanpa EEG terbatas | 🟡 |

## 2. Tidur & alarm

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Sleep Planner** | Rekomendasi jam tidur dari kebutuhan & jadwal | Target bedtime di Sleep Coach (`wellnessTargetBedtime`) dan `alertness_forecast` | 🟡 belum dibandingkan alurnya |
| **Alarm haptic** | Jam tetap, setelah target tidur tercapai, atau saat Recovery hijau | Jam tetap + jendela pintar (`smartWindowMinutes`), getar lewat strap | 🟡 |
| Bangun saat target tidur tercapai | Ada | Mode "Wake at sleep goal" di dalam jendela smart wake: buzz saat istirahat malam ini (van Hees) mencapai sleep need yang dipelajari; alarm cadangan tidak berubah (`state/alarm_schedule.dart`, `state/smart_wake.dart`) | ✅ |
| Bangun saat Recovery hijau | Ada | Belum ada (Recovery baru final setelah tidur selesai) | ❌ |

## 3. Kesehatan

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Stress Monitor** 0–3 + breathwork | Skor dari HRV & HR, sesi napas | Baevsky Stress Index (`clinical/stress_si.dart`) + layar napas terpandu (`calm_breathing.dart`), skala berbeda | 🟡 |
| **Health Monitor**: HR, RHR, HRV, laju napas | Rentang normal pribadi + peringatan | Ada, termasuk deteksi anomali & sakit (`wellness/anomaly.dart`, `clinical/illness_cusum.dart`) | ✅ |
| **Health Monitor**: SpO₂ | Ada | **Tidak bisa di WHOOP 4.0.** Byte "red" dan "IR" ternyata satu sinyal yang sama; rasio apa pun mengukur drift, bukan oksigen (`protocol/lib/src/records.dart`). Rekaman v25 juga sudah dibongkar (`parseV25Waveform`): isinya **satu** kanal optik, jadi tetap tidak ada pasangan merah/inframerah untuk SpO₂ | ⛔ sampai teridentifikasi |
| **Health Monitor**: suhu kulit | Ada | **Tidak bisa di WHOOP 4.0.** Field yang dikira suhu berubah 5–10 angka/detik, jauh lebih cepat dari suhu kulit mana pun (`records.dart`, `skinTempRaw` deprecated) | ⛔ sampai teridentifikasi |
| **Siklus menstruasi** | Insight siklus & hormon | Dihitung dari tanggal yang dicatat pengguna; estimasi ovulasi dari suhu sengaja tidak ditampilkan (salah satuan) (`cycle_screen.dart`) | 🟡 |
| **Heart Screener** (ECG, WHOOP MG) | ECG on-demand | Modul ECG ada (`lib/ecg/`), hanya untuk perangkat dengan ECG | 🟡 tidak berlaku untuk WHOOP 4.0 |
| **Blood Pressure Insights** (WHOOP MG) | Estimasi tren setelah kalibrasi manset | Hanya menampilkan bacaan tensi dari Apple Health/alat bersertifikat | ⛔ butuh kalibrasi & validasi |
| **Advanced Labs** | Tes darah berbayar | Input manual hasil lab dengan rentang rujukan (`data/lab_catalogue.dart`) | 🟡 tanpa layanan lab |

## 4. Latihan & aktivitas

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| Deteksi aktivitas otomatis | Ada | `workout/auto_detect.dart` | ✅ |
| **Strength Trainer** (beban otot) | Set, repetisi, berat → muscular load digabung ke Strain | Set per kelompok otot 7 hari (primer 1, sekunder 0,5) + set berat (RPE ≥ 7) + tonase; sengaja **tidak** digabung ke Strain karena tidak ada nilai tukar terbitan (`analytics/.../workout/muscle_volume.dart`, `ui2/activity/muscle_sets.dart`) | ✅ metode berbeda |
| Zona HR | Ada | `workout/hr_zones.dart` | ✅ |
| Langkah | Ada | Dari gerak strap + pedometer HP (`motion/steps.dart`, `health/phone_pedometer.dart`) | ✅ |

## 5. Jangka panjang & wawasan

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Journal** | Kebiasaan → dampak ke Recovery/tidur | Jurnal + uji asosiasi (`human/associations.dart`, `data/journal_fields.dart`) | ✅ |
| Rekap mingguan | Ada | Notifikasi rekap mingguan | ✅ |
| **Monthly Performance Assessment** | Laporan bulanan tren tidur, recovery, strain | Layar "Your month": 30 hari vs 30 hari sebelumnya untuk 7 metrik; perubahan hanya disebut bila melewati SWC 0,2 SD (Hopkins 2004) (`ui2/screens/monthly_report.dart`) | ✅ |
| **Healthspan**: WHOOP Age & Pace of Aging | 9 input: durasi & konsistensi tidur, langkah, menit zona HR, aktivitas kekuatan, VO₂max, RHR, massa tubuh tanpa lemak | **Sengaja dihapus OpenStrap**: versi lama hanya RHR yang dihitung dua kali, dan VO₂max-nya k/RHR. Sebagian besar input tersedia, tetapi VO₂max tidak bisa diestimasi jujur dari data ini | ⛔ sebagai satu angka "usia" |
| **WHOOP Coach** (AI) | Ada | Coach AI dengan kunci milik pengguna, hanya membaca view yang diizinkan (`lib/coach/`) | ✅ |
| Teams / komunitas | Ada | Di luar lingkup (local-first) | — |

## 6. Fitur ala Garmin Connect untuk WHOOP 4.0

| Fitur Garmin | Di ProjectFit dengan WHOOP 4.0 | Status |
|---|---|---|
| **HRV Status** | Rata-rata ln-RMSSD 7 malam vs baseline 60 malam ± SWC (Plews 2012/2013); seimbang / di atas / di bawah (`clinical/hrv_status.dart`, `ui2/screens/hrv_status_card.dart`, tab Health) | ✅ |
| **Training load / load ratio** | ATL 7 hari & CTL 42 hari (sudah ada) + rasio akut:kronis dengan zona Gabbett 2016; diberi catatan kritik Impellizzeri 2020 (`clinical/load_ratio.dart`, kartu beban di tab Workout) | ✅ |
| **Training Readiness** | Setara Readiness (§1) | ✅ |
| **Stress** | Baevsky Stress Index (§3) | 🟡 skala berbeda |
| **Sleep Score** | Sleep performance + staging (§1) | 🟡 |
| **Body Battery** | Tidak dibuat: metode Firstbeat tidak dipublikasikan, dan versi buatan sendiri berarti konstanta yang dipilih tanpa dasar | ⛔ |
| **VO₂max, Race Predictor** | Tidak dibuat: estimasi VO₂max lama OpenStrap hanya k/RHR (dihapus); butuh data kecepatan lari GPS untuk metode yang jujur | ❌ |

## 7. Daftar kerja yang diusulkan

| # | Pekerjaan | Kenapa | Cara | Butuh |
|---|---|---|---|---|
| 1 | **Identifikasi field suhu kulit & SpO₂ WHOOP 4.0** | Membuka Health Monitor, sinyal sakit dari suhu, insight siklus | Rekam data sambil mengukur pembanding (termometer kulit, oksimeter) lalu korelasi per byte, metode yang sama dengan OpenStrap. Ditambah REA pada APK WHOOP Android untuk melihat apakah aplikasi men-decode field ini atau mengirim byte mentah ke cloud | WHOOP 4.0 Anda, alat pembanding, akses HP Android untuk APK |
| ~~2~~ | ~~**Beban otot dari latihan beban**~~ ✅ | Melengkapi Strain untuk latihan kekuatan | Volume load (set × repetisi × beban) dan session-RPE × durasi (Foster 2001), digabung ke Strain dengan bobot yang dinyatakan terbuka | Kode saja |
| ~~3~~ | ~~**Alarm: bangun saat target tidur tercapai**~~ ✅ | Fitur alarm favorit WHOOP | Alarm pintar yang sudah ada + sleep need yang sudah dihitung | Kode saja + uji di strap |
| 4 | **Healthspan versi jujur** | Fitur WHOOP terbaru | Tampilkan tiap input terhadap ambang pedoman (mis. 150 menit zona sedang/minggu, 7–9 jam tidur, langkah harian), **tanpa** meringkasnya jadi satu "usia" | Kode + desain |
| ~~5~~ | ~~**Laporan bulanan**~~ ✅ | Ringkasan jangka panjang | Agregasi metrik yang sudah ada per bulan | Kode saja |
| 6 | Validasi Restorative sleep & Sleep Planner | Pastikan alurnya setara | Bandingkan dengan aplikasi WHOOP di malam yang sama | WHOOP 4.0 + aplikasi WHOOP |

Nomor 2, 3 dan 5 sudah selesai. Nomor 1 paling berdampak, tetapi butuh data dari strap Anda.

## Referensi

- WHOOP Healthspan: https://www.whoop.com/thelocker/healthspan
- WHOOP Healthspan & longevity: https://www.whoop.com/thelocker/Healthspan-Data-Meets-Longevity
- WHOOP Monthly Performance Assessment: https://www.whoop.com/thelocker/monthly-performance-assessment
- WHOOP sleep debt: https://whoop.com/thelocker/sleep-debt-optimal-playbook
- WHOOP Recovery (podcast 40): https://www.whoop.com/thelocker/podcast-40-whoop-recovery-maximize-readiness/
- Ulasan WHOOP 4.0 (Sleep Planner, alarm, Strength Trainer, Stress & Health Monitor): https://connectthewatts.com/2022/06/09/whoop-review-4-0/ , https://wareable.com/wearable-tech/whoop-4-review-8654
- Bukti field WHOOP 4.0: `packages/protocol/lib/src/records.dart`, `OpenStrap/research/PROTOCOL.md`

## Rekaman v25 WHOOP 4.0 (sudah dibongkar)

Diuji pada 11.440 rekaman v25 dari satu WHOOP 4.0, dibandingkan dengan rekaman v24 di detik yang sama:

- Setiap ~19,25 menit, siang dan malam, strap mengirim satu burst berisi tepat 40 rekaman.
- Satu rekaman berisi 24 sampel gelombang optik (~24,96 Hz). Ada juga level optik lambat (bilangan bertanda) dan satu angka gerakan.
- Angka gerakan itu cocok dengan perubahan akselerometer di detik yang sama (Spearman 0,83).
- Gelombangnya adalah denyut jantung. Saat diam, puncak spektrumnya berada dalam 5 bpm dari HR v24 pada 92% burst. Saat banyak bergerak, angka ini turun ke 22–38%.
- **Hanya satu panjang gelombang**: tidak ada pola bergantian antar-slot. Jadi v25 tidak membuka SpO₂ maupun suhu kulit.
- HR dari v25 tidak menambah informasi, karena v24 sudah mengirim HR setiap detik.
- Dekoder field ada di `packages/protocol` (`parseV25Waveform`). Tidak ada metrik yang diturunkan darinya.

## Cara aplikasi WHOOP mengolah data (analisis APK, 26 Okt 2026)

Sumber: WHOOP Android 5.474.0 (`com.whoop.android`, versionCode 627598), ditandatangani
`CN=whoop.com, O=WHOOP Inc.` (SHA-256 sertifikat `4ff1dac8…b9c8e2`). Dibaca statis dengan
JADX + androguard; aplikasinya tidak dijalankan. APK tidak disimpan di repo.

**Kesimpulan: semua angka dihitung di server WHOOP. Aplikasi hanya pengangkut.**

- Rekaman band disimpan utuh di HP (`PersistentStrapPacketDatabase`) lalu dikirim biner apa
  adanya ke `metrics-service/v1/metrics` dan `metrics-service/v1/metrics/sensor`
  (worker "Upload Raw Packets to API"). Header kiriman: `X-WHOOP-HW-Version`,
  `X-WHOOP-FW-Version`, `X-WHOOP-DSP-Version` (versi pengolah sinyal di server),
  `X-WHOOP-Strap-Id`, `X-WHOOP-Binary-Version`, `X-WHOOP-Binary-Flags`.
  Balasannya hanya `MetricsProcessedTime`.
- Kelas paket (`Rev2RawDataPacket`, `Rev2ProcessedResultsPacket`, rekaman historis) hanya
  membungkus byte; tidak ada pengurai field SpO₂/suhu/HRV di HP. Yang diurai di HP hanya
  HR realtime, EKG untuk tampilan, dan balasan perintah.
- SpO₂, suhu kulit, Recovery, dll. datang jadi dari endpoint BFF (`coaching-service/v1/health/bff/monitor`,
  `health-tab-bff`, `core-details-bff/v2/recovery-details`, …).
- **VO₂ max diisi manual**: `vo2max-service/v2/{measurementType}/manual` (formulir dengan batas
  min/maks), lalu ditulis ke Health Connect. Band tidak menghitungnya.
- Unggahan riset terpisah: `research-metrics-service/v1/{raw,optical,imu,research,data-settings}/upload`.
- LiteRT ada sebagai pustaka, tapi tidak ada model `.tflite` di aset dan kode WHOOP yang
  didekompilasi tidak memanggilnya.

**Tipe rekaman** (enum di aplikasi; "Harvard" = WHOOP 4.0, "Maverick" = 5.0/MG):
`HISTORICAL_R10/R11/R12`, `HISTORICAL_RAW_ECG`, `HISTORICAL_OPTICAL_R20_MAVERICK`, `HISTORICAL_IMU`,
`HISTORICAL_METRICS_R24_HARVARD`, `REALTIME_HR`, `REALTIME_OPTICAL_R20_MAVERICK`, `REALTIME_IMU`,
`REALTIME_R10/R11`, `REALTIME_FILTERED_ECG`. Untuk `GEN_4`, aliran mentah realtime = R10.
Rekaman 1 Hz yang dibaca ProjectFit ("v24") cocok dengan `R24` metrics Harvard.

**Opcode perintah gen4 yang belum dipakai ProjectFit** (nama → nilai):
`TOGGLE_GENERIC_HR_PROFILE` 14, `TOGGLE_R7_DATA_COLLECTION` 16, `FORCE_TRIM` 25,
`SET_LED_DRIVE` 39 / `GET_LED_DRIVE` 40, `SET_TIA_GAIN` 41 / `GET_TIA_GAIN` 42,
`SET_BIAS_OFFSET` 43 / `GET_BIAS_OFFSET` 44, `SET_DP_TYPE` 52, `FORCE_DP_TYPE` 53,
`SET_RESEARCH_PACKET` 131 / `GET_RESEARCH_PACKET` 132. Balasan GET LED/TIA/bias berisi satu
nilai (bukan per-LED). Belum diuji di band: `SET_*` mengubah perilaku strap dan bisa menguras
baterai; hanya `GET_*` yang aman dicoba lebih dulu.

**Artinya untuk ProjectFit:** tidak ada rumus WHOOP yang bisa disalin dari aplikasinya. SpO₂ dan
suhu kulit butuh (1) menemukan rekaman/kanal yang membawanya — kandidat: R12 historis atau tipe
yang dipilih lewat `SET_DP_TYPE` — lalu (2) algoritma sendiri. VO₂ max paling jujur tetap dari
Garmin/Apple Health.
