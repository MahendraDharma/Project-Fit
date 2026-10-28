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

## Model Strain & kalori WHOOP yang ada di HP (analisis APK lanjutan, 28 Okt 2026)

Recovery, tidur, HRV, SpO₂ dan suhu dihitung di server (lihat bagian sebelumnya). Tetapi aplikasi
membawa **model Strain dan kalori** sendiri di HP: pustaka `com.whoop.analytics.strain` (dipakai untuk
skor strain di HP) dan versi live di modul `track-activity` (strain saat aktivitas berjalan).
Rumus di bawah dibaca dari kode yang didekompilasi; dicatat sebagai pengetahuan, bukan disalin.

**HR maksimum (bila belum terukur):**
`HRmax = 204,427 − 0,27262 × usia + bobot_kebugaran + bobot_jenis_kelamin`
(usia dari tanggal lahir, dibatasi 12–120 tahun). Bobot kebugaran: collegiate 0; serious enthusiast
−0,698; tactical / professional −2,993; recreational enthusiast −3,295; inactive −3,669. Bobot jenis
kelamin: pria −2,023; wanita 0; non-biner −1,011. HR yang pernah tercatat lebih tinggi menggantikannya.

**Penghalusan HR:** untuk setiap sampel, persentil ke-25 dari ±30 sampel di sekitarnya (≈1 menit pada
1 Hz); jendela dipotong di celah ≥30 detik. Persentil rendah membuang lonjakan HR palsu karena gerakan.

**Beban per sampel:**
- cadangan `r = clamp((HR − RHR) / ((HRmax + 3) − RHR), 0, 1)`; `r ≤ 0,3` dianggap 0;
- bobot logistik `w(r) = 16 / (e^((1 − r)/0,15) + 1)` — r 0,5 → 0,55; 0,6 → 1,04; 0,7 → 1,91;
  0,8 → 3,34; 0,9 → 5,43;
- `dt` = jarak ke sampel berikutnya dalam detik, **maksimal 3 detik** (celah tidak ikut dihitung);
- beban mentah `= Σ w(r)·dt / 691200`, dibatasi 0–1 (691200 = 16 × 12 jam × 3600).

**Skala 0–21:** tabel 211 titik (0,0–21,0, langkah 0,1) yang memetakan beban mentah ke strain;
nilainya hampir linear-logaritmik sampai ~20 lalu melonjak tajam (20 → 21 butuh ~23× beban).
Gambaran: strain 8 ≈ 14 menit di 70% cadangan HR; 10 ≈ 22 menit; 12 ≈ 33; 14 ≈ 52; 16 ≈ 79;
18 ≈ 119; 20 ≈ 181 menit (di 80% cadangan kira-kira 0,57× waktunya).

**Kalori (versi "New"):**
- istirahat: Harris-Benedict revisi (Roza & Shizgal 1984), per detik = kkal/hari ÷ 86 400;
- ambang = `RHR + 0,3 × (HRmax − RHR)`; di bawahnya hanya kalori istirahat;
- di atasnya garis lurus dari (ambang, kalori istirahat) ke (HRmax, rumus Keytel dkk. 2005 di HRmax);
  Keytel memberi kJ/menit, dibagi 251,04 menjadi kkal/detik;
- total kJ = kkal × 4,184.

**Yang tidak ada di HP:** zona HR diambil dari server (`HrZonesApi`, persen min/maks per zona); Stress
Monitor, Recovery, tidur, HRV, SpO₂, suhu — semuanya hasil jadi dari server.

**Perangkat keras WHOOP 4.0** (siaran pers WHOOP): 5 LED — 3 hijau (HR), 1 merah, 1 inframerah (SpO₂) —
dan 4 fotodioda; suhu kulit diukur di permukaan kulit. Jadi kanal merah/IR memang ada di band; yang
belum ditemukan adalah rekaman yang membawanya (kandidat: R10/R11/R12 — lihat fitur Rekam data mentah).

**Dibanding ProjectFit sekarang:** ProjectFit memakai TRIMP Banister per menit + peta log ke 0–21.
Perbedaan utama dengan WHOOP: (1) WHOOP per detik dengan HR dihaluskan persentil-25, (2) ambang 30%
cadangan, (3) bobot logistik (bukan eksponensial Banister), (4) `HRmax + 3`, (5) tabel skala sendiri.

## Rekaman mentah live ProjectFit (WHOOP 4.0, 28 Okt 2026, 5 menit)

Rekaman dari layar "Rekam data mentah" (v0.14.1). Isinya 4047 frame:

| Tipe paket | Jumlah | Laju |
|---|---|---|
| 0x28 HR | 303 | 1/s |
| 0x2B R10 | 624 | 1/s per subtipe |
| 0x33 IMU | 3120 | 10/s |

Saat rekaman berjalan, offload histori juga aktif. Live stream tetap jalan.

**0x2B subtipe 0x0b (optik, 1924 byte).** Blok sampel adalah u32 little-endian. Satu paket = 50 sampel tiap kanal. Paket datang tiap ±0,98 detik, jadi ±51 Hz. Sampel menyambung tanpa lompatan antar-paket.

| Kanal | Lokasi | DC | Isi |
|---|---|---|---|
| A | slot 1, byte 38+ (sampel 0–49) | ±294 rb | Pulsa jelas. Frekuensi puncaknya cocok dengan HR band (78–88 bpm). Diduga hijau. |
| B | slot 1 (sampel 50–99) | ±299 rb | Pulsa jelas, koheren dengan A. Diduga hijau, fotodioda lain. |
| C | slot 3, byte 1313+ (sampel 0–49) | ±188 rb | Pulsa lemah. Koherensi dengan A 0,2–0,98. Kandidat merah atau IR. |
| D | slot 3 (sampel 50–99) | ±15,6 rb | Pulsa lemah, berkorelasi 0,74 dengan C. Kandidat merah, IR, atau ambient. |

- Slot 2 (byte 864) ada header-nya tetapi selalu kosong.
- Header slot 1 dimulai `32 04 78 05 05 78 05 01 78 05 04`. Byte `0x32` = 50 sampel.
- Header slot 3 dimulai `32 02 c8 00 05`.
- Rasio AC/DC C dan D belum stabil: C/D berkisar 0,09–0,93 per jendela 20 detik. Ini rekaman siang hari, tangan bergerak, jadi belum cukup untuk rumus SpO2. Perlu rekaman saat diam atau tidur.

**0x2B subtipe 0x0a (gerak, 1920 byte).**

| Lokasi | Isi |
|---|---|
| byte 17 | HR (sama dengan 0x28) |
| f32 @42 | Magnitudo gerak (0,005–1,0) |
| f32 @46/50/54 | Vektor gravitasi satuan (norma ≈ 1), diulang di @62 |
| mulai byte 92 | 3×100 sampel akselerometer i16. Sama persis dengan isi 0x33, jadi 100 Hz. |
| byte 680 | 3×100 sampel i16 di sekitar nol (kandidat giroskop) |
| ±1508 | 100 sampel i32 kecil |

- u16 @74 dan @76 selalu berselisih 19 (566–585 dan 585–604). Nilainya naik-turun bersama HR, jadi kemungkinan besar bukan suhu.
- Belum ada medan yang naik pelan seperti suhu kulit. Kemungkinan suhu hanya ada di record histori, yang juga diolah server WHOOP.
