# Riset: menghitung metrik cloud WHOOP di HP, dan metrik jam Garmin dari band WHOOP saja

Status: v0.1 · 2026-11-01 · Perangkat acuan: **WHOOP 4.0** (+ iPhone)

Dokumen ini melanjutkan `docs/WHOOP_PARITY.md`. Pertanyaannya ada dua:

1. **Bagian A.** Metrik apa saja yang dihitung server WHOOP, apa yang diketahui publik tentang
   cara menghitungnya, dan bagaimana menghitungnya secara lokal di HP.
2. **Bagian B.** Metrik apa saja yang ditampilkan jam Garmin, dan mana yang bisa disajikan hanya
   dengan band WHOOP (ditambah HP).

Aturan yang sama dengan dokumen parity: rumus WHOOP dan Firstbeat/Garmin **tidak dipublikasikan**.
"Bisa dihitung lokal" berarti fitur yang sama dengan metode terbitan dan konstanta yang disebut
terbuka, **bukan** angka yang identik dengan WHOOP atau Garmin.

Legenda:
- ✅ sudah ada di ProjectFit
- 🟢 bisa dibuat dari data band, metode terbitan tersedia
- 🟡 bisa dibuat sebagai estimasi, dengan batasan yang harus ditulis di layar
- 📱 butuh sensor HP (GPS, barometer), band saja tidak cukup
- 🔬 menunggu reverse engineering band (kanal/rekaman belum teridentifikasi)
- ⛔ tidak bisa dibuat jujur: tidak ada sensor atau tidak ada metode terbitan

## Ringkasan

**Data yang dimiliki band WHOOP 4.0** (lihat `WHOOP_PARITY.md`): HR 1 Hz, interval RR, akselerometer
100 Hz, kandidat giroskop, 4 kanal optik ±51 Hz (2 hijau + 2 kandidat merah/IR) saat stream R10
dinyalakan. **Tidak ada:** GPS, barometer, ECG (khusus WHOOP MG), dan field suhu kulit yang sudah
teridentifikasi.

**Bagian A (cloud WHOOP → lokal).** Hampir semua metrik cloud WHOOP sudah punya padanan lokal.
Yang tersisa:
- **Stress Monitor 0–3**: WHOOP mempublikasikan bahannya (HR + HRV dibanding baseline 14 hari,
  gerak dikecualikan). Bisa dibuat 🟢 berdampingan dengan Baevsky SI yang sudah ada.
- **SpO₂** 🔬: eksperimen SpO₂ malam v0.15.0 sedang mengumpulkan pasangan kalibrasi dengan Garmin.
- **Suhu kulit** 🔬: field belum ditemukan.
- **Healthspan** ⛔ sebagai satu "usia", tetapi bisa dibuat versi per-input (lihat B.6).

**Bagian B (Garmin → band WHOOP).** Dari 33 fitur Garmin yang didata:

| Status | Jumlah | Fitur |
|---|---|---|
| ✅ | 13 | Langkah, kalori, RHR, HRV Status, laju napas, Training Readiness, training load / rasio, sleep need (Sleep Coach), deteksi tidur siang, Breathing Variations, siklus menstruasi, jurnal, VO₂max lari/jalan (GPS HP) |
| 🟢 | 6 | Intensity Minutes, stress 0–100 ala Garmin, Training Load Focus, Health Snapshot, Morning Report, Fitness Age (Nes 2014) |
| 🟡 | 6 | Sleep Score 0–100, VO₂max tanpa latihan (HUNT), Race Predictor, Aerobic Training Effect, ambang aerobik (DFA-α1), Recovery Time |
| 📱 | 3 | Lantai naik (barometer HP), Hill Score, Performance Condition |
| 🔬 | 2 | Pulse Ox, suhu kulit |
| ⛔ | 3 | Body Battery (sebagai klon), ECG di WHOOP 4.0, Endurance Score |

**Pekerjaan yang paling bernilai** (urutan di §D): Intensity Minutes → Stress 0–3/0–100 →
Training Load Focus → Fitness Age + VO₂max tanpa latihan → Sleep Score terbuka → Health Snapshot.
Semuanya hanya butuh kode, tanpa perangkat tambahan.

**Koreksi untuk `WHOOP_PARITY.md` §6:** VO₂max tertulis ❌, padahal sudah ada estimasi submaksimal
dari split rute GPS HP + HR band (`analytics/.../clinical/vo2max.dart`, `_submaxVo2maxFromSplits`
di `app/lib/data/local_repository_impl.dart`). Statusnya seharusnya 🟡 (butuh lari/jalan dengan
GPS HP).

---

## A. Metrik yang dihitung di cloud WHOOP

Dari analisis APK (`WHOOP_PARITY.md`, 26–28 Okt 2026): aplikasi WHOOP mengirim rekaman mentah ke
`metrics-service` dan menerima angka jadi. **Hanya Strain dan kalori** yang dihitung di HP. Semua
yang lain dihitung di server, jadi rumusnya tidak bisa dibaca dari aplikasi. Yang tersisa hanya
keterangan publik WHOOP dan literatur.

| Metrik WHOOP | Yang diketahui publik | ProjectFit sekarang | Celah / usulan |
|---|---|---|---|
| **HRV** (RMSSD, ms) | RMSSD. Staf data science WHOOP: jendela 5 menit yang tumpang-tindih, bergeser tiap 30 detik sepanjang tidur. Fase bangun dibuang. Rata-rata berbobot: bobot lebih besar untuk jendela yang kemungkinan SWS dan untuk bagian akhir malam. Penjelasan lama ("hanya SWS terakhir") disebut usang. Bobot persisnya tidak dipublikasikan. [1][2] | Rata-rata jendela 5 menit sesi tidur, dengan gerbang kualitas RR (`kAlgoVersion` 110). | 🟢 Bentuk jendelanya sudah sama. Usulan: varian pembanding "berbobot SWS + akhir malam" dengan bobot yang ditulis terbuka, ditampilkan di detail HRV saja. Estimator utama tidak diubah. |
| **RHR** | Diukur saat tidur. Bobot tahap tidur tidak dipublikasikan. | Rata-rata 30 menit terendah saat tidur (Avram 2019) (`clinical/nocturnal.dart`). | ✅ Tidak perlu diubah. |
| **Laju napas** | Dari HRV (RSA). Masuk ke Recovery sejak 2021, tetapi pengaruhnya kecil di kebanyakan hari. [3] | Dari RSA (`respiration/resp_rate.dart`), bertahan melewati celah sensor. | ✅ |
| **Recovery** 0–100% | Input: HRV (dominan), RHR, sleep performance, laju napas. Dokumentasi developer WHOOP juga menyebut suhu kulit dan SpO₂. Baseline pribadi, kalibrasi beberapa hari pertama. Bobot tidak dipublikasikan. [3][4] | Readiness: HRV+RHR sebagai satu input otonom (bobot 0,70), dipetakan lewat sebaran pribadi setelah 14 malam (`kAlgoVersion` 112). | ✅ metode berbeda. Suhu kulit/SpO₂ menunggu 🔬. |
| **Tahap tidur** | Dilatih meniru PSG yang diskor teknisi. Studi independen: sleep/wake cukup baik (TST lebih ±8 menit), REM paling lemah dibanding Fitbit/Garmin, SWS kurang ±15 menit pada mode otomatis. [5][6][7] | `sleep/advanced_stager.dart`, `cardio_stager.dart` (HR + gerak). | 🟡 Wearable tanpa EEG memang terbatas, termasuk WHOOP sendiri. Usulan: validasi malam yang sama dengan aplikasi WHOOP (item 6 di parity). |
| **Sleep performance, need, debt** | Kebutuhan = baseline + strain + utang − tidur siang. | Ada, termasuk kredit tidur siang. | ✅ |
| **Stress Monitor** 0–3 | HR + HRV saat ini dibanding baseline HRV 14 hari dan RHR biasa. Gerak diperhitungkan supaya olahraga tidak dibaca sebagai stres. Pemetaan ke 0–3 tidak dipublikasikan. [8][9] | Baevsky Stress Index (`clinical/stress_si.dart`), skala lain. | 🟢 Lihat §D-2. Bahan WHOOP semuanya ada di band (HR, RR, akselerometer). |
| **Zona HR** | Diambil dari server (`HrZonesApi`), persen min/maks per zona. | `workout/hr_zones.dart`. | ✅ |
| **Strain** 0–21 | Dihitung di HP WHOOP (model logistik di atas cadangan HR, lihat parity). | TRIMP Banister + peta log 0–21, dihargai terhadap level tenang pribadi. | ✅ metode berbeda. Rumus dari APK sengaja tidak disalin. |
| **Kalori** | Di HP WHOOP: Harris-Benedict + Keytel 2005. | Keytel 2005 + Harris-Benedict (`workout/calories.dart`). | ✅ (sumber terbitan yang sama). |
| **SpO₂** | Dari LED merah/IR band, diproses server. | Eksperimen SpO₂ malam v0.15.0: rasio R kanal C/D, dikalibrasi dengan bacaan Garmin. | 🔬 Tunggu ≥20 pasangan kalibrasi. Tanpa Garmin hanya tren relatif. |
| **Suhu kulit** | Sensor di permukaan kulit, diproses server. | Field belum ditemukan di R10/R24. | 🔬 Kandidat: rekaman histori R12 atau tipe dari `SET_DP_TYPE` (lihat parity). |
| **Health Monitor** | Rentang normal pribadi + peringatan. | `wellness/anomaly.dart`, `clinical/illness_cusum.dart`. | ✅ untuk HR/HRV/RHR/napas. |
| **Healthspan / WHOOP Age** | 9 input (tidur, langkah, menit zona HR, latihan kekuatan, VO₂max, RHR, massa tanpa lemak). Model tidak dipublikasikan. | Sengaja tidak dibuat. | ⛔ sebagai satu angka "usia". Versi per-input: lihat B.6 dan §D-4. |

---

## B. Metrik jam Garmin dan apakah band WHOOP bisa menyajikannya

### B.1 Aktivitas harian

| Fitur Garmin | Cara Garmin (yang dipublikasikan) | Dengan band WHOOP + HP | Status |
|---|---|---|---|
| Langkah | Akselerometer. | Gerak band + pedometer HP (`motion/steps.dart`). | ✅ |
| Kalori | Firstbeat (HR + profil). | Keytel 2005 + BMR. | ✅ |
| **Intensity Minutes** | Mode default: HR dibanding RHR rata-rata. Menit sedang = 1, menit berat = 2. Bisa juga per zona HR (default zona 3 = sedang, zona ≥4 = berat). Dihitung setelah ≥10 menit berturut-turut. Tanpa sensor HR: hanya menit sedang dari langkah per menit. Target WHO 150 menit/minggu. [10] | HR 1 Hz + RHR + zona sudah ada. | 🟢 §D-1 |
| Lantai naik | Barometer. | Band tidak punya barometer. iPhone punya (`CMPedometer.floorsAscended`). | 📱 |
| Move IQ / deteksi aktivitas | Gerak. | `workout/auto_detect.dart`. | ✅ |

### B.2 Jantung, stres, energi

| Fitur Garmin | Cara Garmin | Dengan band WHOOP + HP | Status |
|---|---|---|---|
| RHR | Terendah harian. | Nocturnal RHR. | ✅ |
| **HRV Status** | Rata-rata malam 7 hari vs baseline. | `clinical/hrv_status.dart` (Plews). | ✅ |
| **Stress 0–100** | Firstbeat, dari HRV saat tidak aktif. Data saat bergerak diabaikan. Pita: 0–25 istirahat, 26–50 rendah, 51–75 sedang, 76–100 tinggi. Rumus pemetaan tidak dipublikasikan. [11][12] | RR + akselerometer ada. | 🟢 §D-2 (pemetaan sendiri, terbuka) |
| **Body Battery** 5–100 | Firstbeat: keseimbangan stres/pemulihan dari HRV + dampak fisik aktivitas. Diisi saat tidur/istirahat, dikuras oleh aktivitas dan stres. Rumus tidak dipublikasikan (white paper Firstbeat "Stress and Recovery Analysis Method Based on 24-hour HRV" ada, tetapi tidak bisa dibaca dari sesi ini). [13][14] | Bahannya ada, konstanta pengisian/pengurasan tidak ada. | ⛔ sebagai klon. Alternatif jujur di §E-1. |
| Health Snapshot | Rekaman 2 menit: HR, HRV, laju napas, stres, SpO₂. | Stream RR + optik realtime ada. | 🟢 §D-6 (SpO₂ menyusul 🔬) |
| ECG | Sensor ECG khusus. | WHOOP 4.0 tidak punya. | ⛔ (✅ untuk WHOOP MG lewat `lib/ecg/`) |
| Pulse Ox | LED merah/IR. | Eksperimen SpO₂ malam. | 🔬 |
| Laju napas | Dari HRV. | RSA. | ✅ |
| Suhu kulit (jam baru) | Sensor suhu. | Field belum ditemukan. | 🔬 |

### B.3 Tidur

| Fitur Garmin | Cara Garmin | Dengan band WHOOP + HP | Status |
|---|---|---|---|
| **Sleep Score** 0–100 | Durasi, stres rata-rata saat tidur, waktu di tiap tahap (target deep 17–35%), waktu bangun, kegelisahan. Bobot tidak dipublikasikan. [15][16] | Semua komponen tersedia (durasi, staging, RR untuk stres, gerak). | 🟡 §D-5, bobot sendiri yang terbuka |
| Sleep Coach (kebutuhan tidur) | Usia, aktivitas harian dan jangka panjang, riwayat tidur, tidur siang, HRV. Hasil 7–9 jam per 10 menit. [16] | Sleep need WHOOP-style (6–11 jam). | ✅ |
| Deteksi tidur siang | Otomatis. | `sleep/nap.dart`. | ✅ |
| Breathing Variations | SpO₂ malam. | `respiration/cvhr_apnea.dart`, `relative_odi.dart`. | ✅ (dari HR; ODI menunggu SpO₂) |

### B.4 Latihan dan performa

| Fitur Garmin | Cara Garmin | Dengan band WHOOP + HP | Status |
|---|---|---|---|
| **Training Readiness** 1–100 | Sleep score semalam, recovery time, HRV status, acute load, riwayat tidur 3 malam, riwayat stres 3 hari. Pita 95–100 Prime … 1–24 Poor. Bobot tidak dipublikasikan. [17] | Readiness. | ✅ (input berbeda) |
| Acute load / rasio | Jumlah EPOC beberapa hari terakhir, berbobot. Rasio pendek:panjang, pita <0,8 rendah, 0,8–1,4 optimal, 1,5–1,9 tinggi. [18] | ATL/CTL TRIMP + rasio akut:kronis (`clinical/load_ratio.dart`). | ✅ (TRIMP, bukan EPOC) |
| **Training Load Focus** | Beban 4 minggu dibagi tiga: aerobik rendah, aerobik tinggi, anaerobik. Butuh ≥7 hari. [19] | Zona HR per detik dari band. | 🟢 §D-3 (pembagian per zona, bukan EPOC) |
| **Aerobic / Anaerobic Training Effect** 0–5 | Firstbeat: aerobik dari puncak EPOC sesi + kelas aktivitas 0–10. EPOC diprediksi oleh jaringan saraf dari HR, laju napas dari HRV, dan kinetika on/off. Anaerobik dari deteksi interval intensitas tinggi. [20][21] | HR + RR ada. Model EPOC tidak terbuka. | 🟡 struktur model terbuka (paten), konstanta tidak. Lihat §E-3. Sampai itu: jangan dibuat. |
| **Recovery Time** (jam) | Berbasis EPOC. Input yang dilaporkan: load, HRV, VO₂max, riwayat. Tidak ada rumus terbitan. [22] | — | 🟡 Lihat §E-2. Jangan berupa jam palsu. |
| **VO₂max** (lari/jalan) | Hubungan linear HR vs kecepatan di beberapa titik sesi. Kecepatan dari GPS atau footpod. Laporan pihak ketiga atas white paper Firstbeat: MAPE ±5% lari, ±6% jalan. Galat turun bila HR ≥ 0,7 HRmax. [23][24] | **Sudah ada**: ACSM + Swain 1997 dari split rute GPS HP + HR band. | ✅ 📱 (butuh GPS HP saat latihan) |
| VO₂max tanpa latihan GPS | — (Garmin tidak menyediakan) | Persamaan non-latihan: Jackson 1990 (usia, jenis kelamin, BMI, skor aktivitas; R² 0,61, SEE 5,7) atau Jackson 2012 / HUNT (menambah RHR, lingkar pinggang). [25] | 🟡 §D-4. Akurasi bergantung populasi, cenderung overestimasi pada kebugaran rendah. |
| Race Predictor | Dari VO₂max + riwayat lari. | VO₂max GPS → VDOT Daniels / Riegel. | 🟡 hanya bila ada VO₂max dari GPS. |
| Lactate threshold | Butuh HRM dada + lari bertingkat. | Literatur: DFA-α1 RR = 0,75 sebagai ambang aerobik (Rogers 2021). | 🟡 eksperimen. RR optik di pergelangan saat lari sering berderau. Wajib gerbang kualitas RR. |
| Performance Condition | HR vs kecepatan di menit 6–20 lari, dibanding VO₂max. | Butuh kecepatan. | 📱 |
| Hill Score | Lari menanjak (GPS + ketinggian). | Barometer/GPS HP. | 📱 |
| Endurance Score | VO₂max + riwayat beban jangka panjang. Model tidak dipublikasikan. | — | ⛔ (CTL sudah menggambarkan hal serupa secara terbuka) |
| Heat/altitude acclimation | Suhu lingkungan + ketinggian. | Tidak ada sensor. | ⛔ |
| HR Recovery (setelah latihan) | Penurunan HR 2 menit. | `workout/hr_recovery.dart` (Cole 1999). | ✅ |

### B.5 Laporan

| Fitur Garmin | Dengan band WHOOP + HP | Status |
|---|---|---|
| Morning Report | Semua bahannya ada (tidur, HRV status, readiness, beban). Hanya butuh satu layar ringkasan pagi. | 🟢 UI saja |
| Rekap mingguan / bulanan | Sudah ada. | ✅ |
| Siklus menstruasi | Dari tanggal yang dicatat. | ✅ |

### B.6 Fitness Age

Garmin versi baru memakai aktivitas berat (vigorous minutes), RHR, dan BMI atau persen lemak tubuh.
Versi lama memakai VO₂max. Bobotnya tidak dipublikasikan. [26]

Alternatif terbitan: **Fitness Age dari studi HUNT (Nes dkk. 2014)**. Fitness age = usia di mana
VO₂peak rata-rata populasi sama dengan VO₂peak orang tersebut. VO₂peak bisa diambil dari GPS bila
ada, atau dari persamaan non-latihan HUNT (usia, jenis kelamin, lingkar pinggang, RHR, indeks
aktivitas). Semua input tersedia dari band dan profil, kecuali lingkar pinggang yang perlu diisi
manual. Status 🟢, dengan label "estimasi" dan rentang galatnya. Ini juga jawaban jujur untuk
WHOOP Age di Bagian A.

---

## C. Celah sensor (yang tidak bisa diselesaikan dengan kode)

| Sensor | Fitur yang bergantung | Jalan keluar |
|---|---|---|
| GPS | VO₂max dari lari, Race Predictor, Performance Condition, Hill Score | GPS HP saat latihan (sudah ada di `lib/gps/`) |
| Barometer | Lantai naik, Hill Score | Barometer iPhone (`CMPedometer`/`CMAltimeter`), belum dipakai |
| Suhu kulit | Recovery (input tambahan), sinyal sakit, siklus | 🔬 reverse engineering field |
| SpO₂ | Pulse Ox, Breathing Variations berbasis ODI | 🔬 kalibrasi SpO₂ malam dengan Garmin |
| ECG | ECG app | Hanya WHOOP MG |

---

## D. Urutan kerja yang diusulkan

Semua item di bawah hanya butuh kode, tanpa perangkat tambahan. Setiap item ditaruh di
`packages/analytics` sebagai fungsi murni (dengan tes), lalu diberi kartu di app.

### D-1. Intensity Minutes ✅ (2026-11-01)
- Dibuat: `workout/intensity_minutes.dart` + kartu Health. Pita ACSM (Garber 2011): sedang ≥40% cadangan HR, berat ≥60%; hanya blok ≥10 menit berturut-turut; menit berat ×2; minggu Senin–hari ini vs target 150.
- Menit sedang/berat dari HR 1 Hz.
- Ambang awal mengikuti dokumentasi Garmin: zona 3 = sedang, zona ≥4 = berat, menit berat dihitung
  2, hanya blok ≥10 menit berturut-turut. Ambang ditulis sebagai konstanta terbuka.
- Target mingguan WHO: 150 menit sedang atau 75 menit berat.
- Blok di bawah 10 menit dengan HR tidak diketahui (celah) tidak dihitung.
- Menjadi input untuk Fitness Age (D-4) dan Healthspan per-input.

### D-2. Stres 0–3 (gaya WHOOP) dan 0–100 (gaya Garmin) 🟢
- Hanya di jendela tanpa gerak (dari akselerometer), supaya olahraga tidak dibaca sebagai stres.
  Inilah yang dilakukan WHOOP dan Garmin.
- Per jendela (mis. 3–5 menit): ln-RMSSD dan HR dibanding baseline pribadi 14 hari (median + MAD).
- Skor = gabungan z HR (naik = stres) dan z ln-RMSSD (turun = stres).
- Pemetaan ke 0–3 atau 0–100 adalah **pilihan kita**, ditulis terbuka, dan tidak diklaim sama
  dengan WHOOP/Garmin. Pita 0–25/26–50/51–75/76–100 dipakai sebagai label saja.
- Baevsky SI tetap ada sebagai metrik pembanding.

### D-3. Training Load Focus ✅ (2026-11-01)
- Dibuat: `workout/load_focus.dart` + kartu Health. Menit zona per sesi 4 minggu × bobot Edwards (zona n = n); zona 1–3 aerobik rendah, 4 aerobik tinggi, 5 anaerobik (dekat batas Seiler ±82/87% HRmax). Tanpa label "kekurangan".
- Beban 4 minggu (TRIMP yang sudah ada) dibagi menurut zona HR saat beban itu terjadi:
  - aerobik rendah: di bawah ambang aerobik (≈ zona 2 atas)
  - aerobik tinggi: antara ambang aerobik dan anaerobik
  - anaerobik: di atas ambang anaerobik
- Ambang dari %HRR dengan konstanta terbuka. Ambang DFA-α1 (D-7) bisa menggantikannya nanti.
- Butuh ≥7 hari data, sama dengan Garmin.
- Tidak ada label "kekurangan" sampai ada dasar terbitan untuk proporsi idealnya. Proporsi
  polarisasi Seiler (±80/20) bisa disebut sebagai rujukan, bukan target.

### D-4. VO₂max tanpa latihan + Fitness Age 🟡/🟢
- VO₂max non-latihan: persamaan HUNT (Nes 2011) atau Jackson. Inputnya RHR dari band, usia, jenis
  kelamin, BMI/lingkar pinggang dari profil, indeks aktivitas dari workout yang terdeteksi.
- Bila VO₂max dari GPS (sudah ada) tersedia, nilai GPS yang dipakai.
- Tampilkan sumbernya ("dari lari GPS" vs "estimasi tanpa latihan, ±5–6 ml/kg/menit").
- Fitness Age menurut Nes 2014, dari VO₂max tersebut.
- Pelajaran OpenStrap: VO₂max = 15,3 × HRmax/RHR dihapus karena hanya RHR yang diskalakan ulang.
  Persamaan non-latihan juga sangat bergantung pada RHR, jadi **jangan** menampilkannya berdampingan
  dengan RHR seolah dua sinyal independen, dan jangan memasukkannya lagi ke Readiness.

### D-5. Sleep Score 0–100 terbuka 🟡
- Komponen sama dengan Garmin: durasi vs kebutuhan, proporsi tahap (deep 17–35% sebagai rujukan
  Garmin), waktu bangun, kegelisahan (dari gerak), stres saat tidur (D-2).
- Bobot dipilih sendiri dan **ditampilkan** per komponen. Jangan hanya angka total.
- Catatan di layar: REM dari wearable tanpa EEG adalah komponen terlemah (juga untuk WHOOP).
- Keputusan pemilik: apakah satu angka 0–100 diinginkan, atau cukup Sleep performance yang sudah ada.

### D-6. Health Snapshot 🟢
- Sesi 2 menit diam: HR, RMSSD, laju napas RSA, stres (D-2). Nanti SpO₂ bila 🔬 selesai.
- Disimpan sebagai entri bertanggal dan dibandingkan dengan rentang pribadi.

### D-7. Ambang aerobik dari DFA-α1 (eksperimen) 🟡
- DFA-α1 dari RR saat latihan bertingkat. α1 = 0,75 sebagai ambang aerobik (Rogers 2021).
- Hanya bila gerbang kualitas RR lolos; RR optik di pergelangan saat lari sering berderau.
- Bila berhasil: zona pribadi untuk D-1 dan D-3.

### D-8. Lantai naik dari barometer iPhone 📱
- `CMPedometer.floorsAscended` lewat bridge native yang sudah ada.

---

## E. Yang sengaja tidak dibuat (dan penggantinya)

### E-1. Body Battery
Tidak dibuat sebagai klon angka 5–100: konstanta pengisian dan pengurasan Firstbeat tidak
terbitan, dan membuatnya sendiri berarti memilih angka tanpa dasar (sudah diputuskan di parity §6).

Pengganti yang jujur, bila pemilik mau: **garis waktu "istirahat vs beban" harian** dalam satuan
nyata, mis. menit istirahat (stres D-2 di pita istirahat), menit stres, beban latihan (TRIMP), dan
jam tidur, ditumpuk per jam. Bentuknya mirip grafik Body Battery tanpa mengarang satu angka cadangan
energi.

### E-2. Recovery Time (jam)
Tidak ada rumus terbitan. Penggantinya adalah informasi yang sudah ada: rasio beban akut:kronis,
HRV Status, dan Readiness pagi berikutnya. Jangan menampilkan hitung mundur jam.

### E-3. Training Effect 0–5 (yang berhasil dibaca)
**White paper Firstbeat "EPOC Based Training Effect Assessment"** (Feb 2007, dibaca dari salinan
Scribd [27]):
- TE ditentukan oleh **puncak EPOC sesi** dan **kelas aktivitas** pengguna (aktivitas sebulan
  terakhir). Kelas 0–7 = skala Ross & Jackson 1990; 7,5–10 ditambahkan Firstbeat untuk atlet
  (mis. 7,5 = 7–9 jam/minggu … 10 = >15 jam/minggu).
- Orang yang lebih aktif butuh EPOC lebih tinggi untuk TE yang sama.
- Kategori: 1,0–1,9 minor · 2,0–2,9 mempertahankan · 3,0–3,9 meningkatkan · 4,0–4,9 sangat
  meningkatkan · 5,0 overreaching.
- **Tabel/kurva pemetaan EPOC → TE per kelas hanya ada sebagai gambar**; angkanya tidak ada di teks.
- Rumus EPOC sendiri ada di white paper terpisah ("Indirect EPOC Prediction Method Based on Heart
  Rate Measurement"), yang tidak bisa diunduh dari sesi ini.

**Paten Firstbeat US 7,192,401 B2** ("Method for monitoring accumulated body fatigue…", Google
Patents [28]) menjelaskan struktur modelnya secara terbuka:
- Intensitas = VO₂ sebagai % VO₂max, diestimasi dari HR (polinomial).
- Indeks kelelahan (≈ EPOC) dihitung **rekursif**: nilai baru hanya bergantung pada nilai sebelumnya,
  intensitas saat ini, dan Δt.
- Komponen naik: fungsi piecewise-linear dari (EPOC sebelumnya, Δt, intensitas).
- Komponen turun: peluruhan eksponensial (pemulihan tercepat di awal), per "bout" latihan.
- Keduanya digabung dengan bobot fungsi-z (`zmf`, p1 = 0, p2 = 1) terhadap intensitas.
- **Parameter numeriknya ada di Gambar 1–6 paten dan disebut "diselesaikan dengan data empiris"**,
  jadi tidak bisa disalin dari teks.

**Artinya:** bentuk modelnya bisa ditiru, tetapi konstantanya harus dipilih sendiri atau
diturunkan dari literatur EPOC terbuka (mis. hubungan EPOC vs intensitas × durasi). Tanpa itu,
angka TE akan berupa konstanta karangan. Rekomendasi tetap: **jangan buat TE 0–5** sampai ada
konstanta terbitan. Training Load Focus (D-3) memberi informasi serupa secara jujur.

Catatan hukum (bukan nasihat hukum): paten ini diajukan 2003, sehingga masa berlaku 20 tahunnya
kemungkinan sudah habis. Periksa status resminya sebelum meniru strukturnya.

### E-4. Sumber yang masih terblokir
Jaringan sesi riset ini memblokir `www.firstbeat.com`, `assets.firstbeat.com`,
`content.firstbeat.com`, `www.semanticscholar.org` (dan WebFetch ke Scribd). Dokumen yang paling
berguna bila dibuka nanti:
- "Indirect EPOC Prediction Method Based on Heart Rate Measurement" (rumus EPOC)
- "Stress and Recovery Analysis Method Based on 24-hour HRV" (dasar stres & Body Battery)
- "Automated Fitness Level (VO₂max) Estimation with Heart Rate and Speed Data" (2017)
- "Recovery Analysis for Athletic Training Based on HRV" (2015)

---

## F. Keputusan pemilik (1 Nov 2026) dan yang sudah dibuat

| # | Keputusan | Hasil |
|---|---|---|
| 1 | Stres 0–100 gaya Garmin | ✅ `wellness/all_day_stress.dart` + kartu Health. Skor = 100·ln(HRV malam ÷ HRV jendela)/ln 4, hanya jendela diam 5 menit, rujukan = median HRV malam 14 malam, pita Garmin 0–25/26–50/51–75/76–100 |
| 2 | Sleep Score 0–100 bobot terbuka, di samping Sleep performance | ✅ `sleep/sleep_score.dart` + kartu di layar Sleep |
| 3 | Tambahkan Body Battery | ✅ `wellness/body_battery.dart` + kartu Health. Laju per 5 menit: tidur +1,0×(1−stres/100); diam ≤25 +0,25×(25−s)/25; diam >25 −0,6×(s−25)/75; aktif −(0,15+2,5x²); terjaga −0,15. Batas 5–100, burn-in 3 hari dari 50 |
| 4 | Band WHOOP saja (tanpa GPS/barometer HP) | VO₂max dari rutinitas, bukan dari lari GPS; lantai, Hill Score, Performance Condition tetap tidak dibuat |
| 5 | Lingkar pinggang di profil | ✅ Profil › Edit profil. VO₂max HUNT (versi pinggang; BMI sebagai cadangan) + Fitness Age dari rata-rata HUNT3 per dekade (NTNU) |

Semua dihitung saat dibaca dari data yang sudah tersimpan (`daytime_hrv`, kurva HR per menit,
jendela tidur, seri HRV/RHR/stres malam, workout), tanpa perubahan skema atau `kAlgoVersion`, dan
tidak ada yang masuk ke Recovery/Strain.

**Verifikasi sumber HUNT (paper ilmiah):**
- Koefisien versi pinggang dicek di tabel 1 *J Am Heart Assoc* 2020 (PMC7428991): pria
  100,27 − 0,296·usia + 0,226·PA − 0,369·pinggang − 0,155·RHR (SEE 5,70); wanita 74,736 − 0,247·usia
  + 0,198·PA − 0,259·pinggang − 0,114·RHR (SEE 5,14).
- Definisi PA-index dari tim HUNT sendiri (Nauman 2012, PMC3445602; Loe 2013, PMC3654926):
  frekuensi 0/0/1/2,5/5 × intensitas 1/2/3 × durasi 0,10/0,38/0,75/1,0, rentang 0–15.
- Di app, frekuensi dan durasi diambil dari workout 4 minggu terakhir; intensitas dari rata-rata
  cadangan HR sesi (<50% santai, 50–75% terengah, ≥75% hampir habis — ambang kita sendiri).
- Bias yang diketahui: RHR band adalah RHR malam (lebih rendah dari RHR duduk di HUNT), jadi
  VO₂max bisa sedikit terlalu tinggi.

## Referensi

[1] Forum WHOOP, staf data science tentang HRV: https://community.whoop.com/t/hrv-extreme-spikes/6472/31
[2] WHOOP podcast 194 (HRV): https://www.whoop.com/ie/en/thelocker/podcast-194-understanding-heart-rate-variability-and-its-performance-potential/
[3] WHOOP, laju napas masuk Recovery: https://www.whoop.com/ca/en/thelocker/adding-respiratory-rate-to-recovery
[4] WHOOP developer, WHOOP 101: https://developer.whoop.com/docs/whoop-101
[5] WHOOP, akurasi tidur: https://whoop.com/thelocker/how-well-whoop-measures-sleep
[6] Validasi WHOOP vs PSG (Biosensors 2021): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8226553/
[7] Tinjauan sistematis WHOOP/Fitbit/Garmin vs PSG (JMIR mHealth 2024): https://mhealth.jmir.org/2024/1/e52192/PDF
[8] WHOOP, peluncuran Stress Monitor: https://www.whoop.com/thelocker/whoop-launches-new-stress-monitor-feature-first-wearable-to-measure-daily-stress-levels-and-implement-stress-reduction-interventions-in-real-time/
[9] the5krunner, Stress Monitor WHOOP: https://the5krunner.com/2023/03/29/new-whoop-stress-monitor/
[10] Garmin, Intensity Minutes: https://www.garmin.com/en-SG/blog/fitness/helping-garmin-users-take-an-intentional-approach-to-fitness/ ; https://www.shoulditrain.com/blog/garmin-intensity-minutes-explained
[11] Manual Garmin, HRV dan stres: https://www8.garmin.com/manuals/webhelp/vivoactive4_4S/EN-US/GUID-9282196F-D969-404D-B678-F48A13D8D0CB.html
[12] Android Authority, cara Garmin mengukur stres: https://www.androidauthority.com/how-does-garmin-measure-stress-3310535
[13] Garmin, Body Battery: https://www.garmin.com/en-PH/blog/general/5-reasons-your-body-battery-says-youre-running-low-2/
[14] Firstbeat, daftar white paper: https://www.firstbeat.com/en/science-and-physiology/white-papers-and-publications/
[15] Garmin, cara menghitung Sleep Score: https://www.garmin.com/en-CA/blog/fitness/how-garmin-watches-track-your-sleep-calculate-sleep-score/
[16] the5krunner, fitur tidur Garmin: https://the5krunner.com/garmin-features/sleep/
[17] Manual Garmin, Training Readiness: https://www8.garmin.com/manuals/webhelp/GUID-31D23DBB-57C2-4DF7-A0C9-8D1A00AB4BE7/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html
[18] Manual Garmin, Acute Load: https://www8.garmin.com/manuals-apac/webhelp/fenixe/EN-SG/GUID-668BDF9F-C843-4AD0-97F7-39B294D36FE7-941.html
[19] Manual Garmin, Training Load Focus: https://www8.garmin.com/manuals/webhelp/edge830/EN-US/GUID-C3205D96-DAB6-4C93-A225-5B8D7B5A5621.html
[20] Firstbeat, EPOC dan Training Effect: https://firstbeat.com/en/science-and-physiology/epoc-and-training-effect
[21] Firstbeat Sports, Training Effect: https://content.firstbeat.com/en/firstbeat-sports-training-effect
[22] the5krunner, Recovery Time: https://the5krunner.com/garmin-features/training/recovery-time
[23] Firstbeat, Fitness level (VO₂max): https://www.firstbeat.com/en/science-and-physiology/fitness-level/
[24] CSEM, VO₂max dari kecepatan dan HR: https://yoda.csem.ch/items/884e5018-f605-4e29-9a88-bf5b803b1dae/full
[25] Persamaan non-latihan Jackson 1990, ringkasan dan validasi: https://www.topendsports.com/testing/tests/non-exercise.htm ; https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3579753/
[26] Garmin, Fitness Age: https://garmin.ae/garmin-technologies/fitness-age ; https://the5krunner.com/2025/11/04/garmin-fitness-age-lower-whoop-comparison/

[27] Firstbeat, EPOC Based Training Effect Assessment (salinan Scribd): https://www.scribd.com/document/168308330/EPOC-Based-Training-Effect-Assestment
[28] Paten US 7,192,401 B2 (Firstbeat): https://patents.google.com/patent/US7192401B2/en
[29] Persamaan non-latihan, tabel 1 (JAHA 2020): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7428991/
[30] Nauman dkk. 2012, definisi PA-index HUNT: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3445602/
[31] Loe dkk. 2013, rata-rata VO₂max HUNT3: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3654926/
[32] NTNU CERG, Fitness numbers (rata-rata per dekade): https://www.ntnu.edu/cerg/fitness-numbers

Literatur tanpa tautan (untuk dicek saat implementasi):
- Nes BM dkk. 2011, *Med Sci Sports Exerc* 43(11): VO₂peak dari model non-latihan, studi HUNT.
- Nes BM dkk. 2014, *Med Sci Sports Exerc*: Fitness age dari VO₂peak (HUNT).
- Rogers B dkk. 2021, *Front Physiol*: ambang aerobik dari DFA-α1 HRV.
- Swain & Leutholtz 1997, *Med Sci Sports Exerc*: %HRR ≈ %VO₂R.
- Keytel dkk. 2005, *J Sports Sci*: kalori dari HR.
