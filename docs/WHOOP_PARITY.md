# Audit Kesetaraan Fitur: WHOOP vs ProjectFit

Status: v0.1 · 2026-10-17 · Perangkat acuan: **WHOOP 4.0**

Tujuan: daftar fitur aplikasi WHOOP, apa yang sudah ada di ProjectFit (warisan OpenStrap),
apa yang kurang, dan apa yang tidak bisa dibuat secara jujur dari data yang tersedia.

Sumber fitur WHOOP: halaman resmi WHOOP (support & The Locker) dan ulasan independen
(lihat Referensi). Rumus WHOOP sendiri tidak dipublikasikan. Jadi "setara" di sini berarti
fitur yang sama dengan metode terbitan, **bukan** angka yang sama persis dengan WHOOP.

Legenda: ✅ setara · 🟡 sebagian · ❌ belum ada · ⛔ tidak bisa dibuat jujur dengan data saat ini

## Ringkasan

| Status | Jumlah | Fitur |
|---|---|---|
| ✅ | 11 | Recovery, Strain 0–21, Strain target, Sleep performance, Sleep need & debt, konsistensi tidur, Journal, deteksi aktivitas, rekap mingguan, Coach AI, langkah |
| 🟡 | 7 | Restorative sleep, Sleep Planner, alarm haptic, Stress Monitor, Health Monitor, siklus menstruasi, Heart Screener (ECG) |
| ❌ | 3 | Strength Trainer (beban otot), Monthly Performance Assessment, mode alarm "bangun saat target tercapai" |
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
| Bangun saat target tidur / Recovery tercapai | Ada | Tidak ada | ❌ |

## 3. Kesehatan

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Stress Monitor** 0–3 + breathwork | Skor dari HRV & HR, sesi napas | Baevsky Stress Index (`clinical/stress_si.dart`) + layar napas terpandu (`calm_breathing.dart`), skala berbeda | 🟡 |
| **Health Monitor**: HR, RHR, HRV, laju napas | Rentang normal pribadi + peringatan | Ada, termasuk deteksi anomali & sakit (`wellness/anomaly.dart`, `clinical/illness_cusum.dart`) | ✅ |
| **Health Monitor**: SpO₂ | Ada | **Tidak bisa di WHOOP 4.0.** Byte "red" dan "IR" ternyata satu sinyal yang sama; rasio apa pun mengukur drift, bukan oksigen (`protocol/lib/src/records.dart`) | ⛔ sampai teridentifikasi |
| **Health Monitor**: suhu kulit | Ada | **Tidak bisa di WHOOP 4.0.** Field yang dikira suhu berubah 5–10 angka/detik, jauh lebih cepat dari suhu kulit mana pun (`records.dart`, `skinTempRaw` deprecated) | ⛔ sampai teridentifikasi |
| **Siklus menstruasi** | Insight siklus & hormon | Dihitung dari tanggal yang dicatat pengguna; estimasi ovulasi dari suhu sengaja tidak ditampilkan (salah satuan) (`cycle_screen.dart`) | 🟡 |
| **Heart Screener** (ECG, WHOOP MG) | ECG on-demand | Modul ECG ada (`lib/ecg/`), hanya untuk perangkat dengan ECG | 🟡 tidak berlaku untuk WHOOP 4.0 |
| **Blood Pressure Insights** (WHOOP MG) | Estimasi tren setelah kalibrasi manset | Hanya menampilkan bacaan tensi dari Apple Health/alat bersertifikat | ⛔ butuh kalibrasi & validasi |
| **Advanced Labs** | Tes darah berbayar | Input manual hasil lab dengan rentang rujukan (`data/lab_catalogue.dart`) | 🟡 tanpa layanan lab |

## 4. Latihan & aktivitas

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| Deteksi aktivitas otomatis | Ada | `workout/auto_detect.dart` | ✅ |
| **Strength Trainer** (beban otot) | Set, repetisi, berat → muscular load digabung ke Strain | Log latihan beban ada (katalog wger, `log_workout.dart`), tapi tidak ada metrik beban otot | ❌ |
| Zona HR | Ada | `workout/hr_zones.dart` | ✅ |
| Langkah | Ada | Dari gerak strap + pedometer HP (`motion/steps.dart`, `health/phone_pedometer.dart`) | ✅ |

## 5. Jangka panjang & wawasan

| Fitur WHOOP | Di WHOOP | Di ProjectFit | Status |
|---|---|---|---|
| **Journal** | Kebiasaan → dampak ke Recovery/tidur | Jurnal + uji asosiasi (`human/associations.dart`, `data/journal_fields.dart`) | ✅ |
| Rekap mingguan | Ada | Notifikasi rekap mingguan | ✅ |
| **Monthly Performance Assessment** | Laporan bulanan tren tidur, recovery, strain | Tidak ada | ❌ |
| **Healthspan**: WHOOP Age & Pace of Aging | 9 input: durasi & konsistensi tidur, langkah, menit zona HR, aktivitas kekuatan, VO₂max, RHR, massa tubuh tanpa lemak | **Sengaja dihapus OpenStrap**: versi lama hanya RHR yang dihitung dua kali, dan VO₂max-nya k/RHR. Sebagian besar input tersedia, tetapi VO₂max tidak bisa diestimasi jujur dari data ini | ⛔ sebagai satu angka "usia" |
| **WHOOP Coach** (AI) | Ada | Coach AI dengan kunci milik pengguna, hanya membaca view yang diizinkan (`lib/coach/`) | ✅ |
| Teams / komunitas | Ada | Di luar lingkup (local-first) | — |

## 6. Daftar kerja yang diusulkan

| # | Pekerjaan | Kenapa | Cara | Butuh |
|---|---|---|---|---|
| 1 | **Identifikasi field suhu kulit & SpO₂ WHOOP 4.0** | Membuka Health Monitor, sinyal sakit dari suhu, insight siklus | Rekam data sambil mengukur pembanding (termometer kulit, oksimeter) lalu korelasi per byte, metode yang sama dengan OpenStrap. Ditambah REA pada APK WHOOP Android untuk melihat apakah aplikasi men-decode field ini atau mengirim byte mentah ke cloud | WHOOP 4.0 Anda, alat pembanding, akses HP Android untuk APK |
| 2 | **Beban otot dari latihan beban** | Melengkapi Strain untuk latihan kekuatan | Volume load (set × repetisi × beban) dan session-RPE × durasi (Foster 2001), digabung ke Strain dengan bobot yang dinyatakan terbuka | Kode saja |
| 3 | **Alarm: bangun saat target tidur tercapai** | Fitur alarm favorit WHOOP | Alarm pintar yang sudah ada + sleep need yang sudah dihitung | Kode saja + uji di strap |
| 4 | **Healthspan versi jujur** | Fitur WHOOP terbaru | Tampilkan tiap input terhadap ambang pedoman (mis. 150 menit zona sedang/minggu, 7–9 jam tidur, langkah harian), **tanpa** meringkasnya jadi satu "usia" | Kode + desain |
| 5 | **Laporan bulanan** | Ringkasan jangka panjang | Agregasi metrik yang sudah ada per bulan | Kode saja |
| 6 | Validasi Restorative sleep & Sleep Planner | Pastikan alurnya setara | Bandingkan dengan aplikasi WHOOP di malam yang sama | WHOOP 4.0 + aplikasi WHOOP |

Nomor 2, 3 dan 5 bisa dikerjakan sekarang tanpa perangkat. Nomor 1 paling berdampak, tetapi
butuh data dari strap Anda.

## Referensi

- WHOOP Healthspan: https://www.whoop.com/thelocker/healthspan
- WHOOP Healthspan & longevity: https://www.whoop.com/thelocker/Healthspan-Data-Meets-Longevity
- WHOOP Monthly Performance Assessment: https://www.whoop.com/thelocker/monthly-performance-assessment
- WHOOP sleep debt: https://whoop.com/thelocker/sleep-debt-optimal-playbook
- WHOOP Recovery (podcast 40): https://www.whoop.com/thelocker/podcast-40-whoop-recovery-maximize-readiness/
- Ulasan WHOOP 4.0 (Sleep Planner, alarm, Strength Trainer, Stress & Health Monitor): https://connectthewatts.com/2022/06/09/whoop-review-4-0/ , https://wareable.com/wearable-tech/whoop-4-review-8654
- Bukti field WHOOP 4.0: `packages/protocol/lib/src/records.dart`, `OpenStrap/research/PROTOCOL.md`
