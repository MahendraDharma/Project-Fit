<p align="center">
  <img src="assets/logo.png" alt="ProjectFit" width="96" height="96">
</p>

<h1 align="center">Cara memasang ProjectFit di iPhone</h1>

<p align="center">
  Gratis · Pakai Apple ID sendiri · Tanpa jailbreak · ±15 menit
</p>

---

> [!WARNING]
> **Update Oktober 2026:** Apple sedang menolak login dari Sideloadly, AltServer/AltStore dan
> SideStore. Pesan yang muncul misalnya **-80045** *"This action cannot be completed at this
> time"*, **-20970**, *"Apple's login server refused"*, atau *"could not retrieve anisette
> data"*. Selama masih begini, Tutorial A dan B kemungkinan besar gagal. **Punya Mac? Langsung
> pakai [Tutorial C — Mac + Xcode](#tutorial-c--mac--xcode-paling-pasti).** Jangan
> mengulang-ulang login yang gagal, karena Apple bisa mengunci Apple ID sementara.

## 👋 Sebelum mulai

ProjectFit **tidak ada di App Store**, jadi cara pasangnya sedikit berbeda dari aplikasi biasa.
Tenang, cukup ikuti langkahnya satu per satu.

**1. Cek versi iOS Anda:** buka **Pengaturan → Umum → Mengenai**, lalu lihat baris
**Versi iOS**.

| Versi iOS Anda | Ikuti | Perlu komputer? |
|---|---|---|
| **27 ke atas** | 👉 [**Tutorial A** — cukup pakai iPhone](#tutorial-a--cukup-pakai-iphone-ios-27-ke-atas) | ❌ Tidak |
| **15 sampai 26** | 👉 [**Tutorial B** — pakai komputer](#tutorial-b--pakai-komputer-ios-15-sampai-26) | ✅ Ya |
| Punya **Mac**, dan cara A/B ditolak Apple | 👉 [**Tutorial C** — Mac + Xcode](#tutorial-c--mac--xcode-paling-pasti) | ✅ Mac |

**2. Siapkan:**
- ✅ **Apple ID.** Disarankan **Apple ID kedua** khusus untuk ini (gratis, buat di
  [appleid.apple.com](https://appleid.apple.com)). Apple ID di iPhone Anda tidak perlu diganti.
- ✅ **Wi-Fi** untuk pemasangan pertama. Hotspot dari HP orang lain juga bisa.
- ✅ Baterai cukup, minimal 30%.

> [!IMPORTANT]
> Dengan Apple ID gratis, aplikasi **harus diperpanjang setiap 7 hari** (sekali ketuk, data tidak
> hilang). Ini aturan Apple, bukan aturan ProjectFit. Caranya ada di
> [bagian Perpanjang](#-perpanjang-setiap-7-hari).

---

## Tutorial A — cukup pakai iPhone (iOS 27 ke atas)

Anda akan memasang 3 aplikasi, berurutan:

```
LocalDevVPN (App Store)  →  SideInstaller  →  SideStore  →  ProjectFit
     penghubung              pemasang          toko app       aplikasinya
```

> [!WARNING]
> **Unduh SideInstaller hanya dari [sideinstaller.net](https://sideinstaller.net).** Aplikasi ini
> meminta password Apple ID, dan ada situs palsu (misalnya *sideinstaller.com*) yang bisa mencuri
> akun Anda. ProjectFit tidak terafiliasi dengan SideInstaller maupun SideStore.

### Langkah 1 — Pasang LocalDevVPN dari App Store

1. Buka **App Store**, cari **LocalDevVPN**, lalu ketuk **Dapatkan**. Aplikasinya gratis.
2. Buka LocalDevVPN. Kalau muncul **"Tambahkan Konfigurasi VPN"**, ketuk **Izinkan** dan masukkan
   kode sandi iPhone.

ℹ️ VPN ini hanya bekerja **di dalam iPhone Anda sendiri**. Internet Anda tidak dialihkan ke
server lain.

### Langkah 2 — Pasang SideInstaller

1. Buka **Safari** (bukan Chrome), lalu kunjungi **https://sideinstaller.net**.
2. Ketuk tombol pasang (*Install*) di halaman itu, lalu ketuk **Pasang** saat iPhone bertanya.
3. Tunggu ikon SideInstaller muncul di layar utama.
4. **Izinkan aplikasinya:** buka **Pengaturan → Umum → VPN & Manajemen Perangkat**, ketuk profil
   yang baru muncul (nama pemilik sertifikat SideInstaller), lalu ketuk **Percayai** (*Trust*).
   Kalau tidak ada profil baru di sana, lewati langkah ini.

ℹ️ SideInstaller dipasang dengan sertifikat dari pembuatnya, dan Apple bisa sewaktu-waktu
mencabutnya. Kalau pemasangan gagal, kembali ke halaman tadi dan coba pilihan sertifikat lain.

### Langkah 3 — Nyalakan Mode Pengembang

1. Buka **Pengaturan → Privasi & Keamanan**, gulir ke paling bawah, lalu ketuk
   **Mode Pengembang**.
2. Nyalakan, lalu ketuk **Mulai Ulang**.
3. Setelah iPhone menyala, ketuk **Nyalakan** pada pesan yang muncul dan masukkan kode sandi.

### Langkah 4 — Pasang SideStore lewat SideInstaller

1. **Sambungkan ke Wi-Fi.** Ini hanya perlu sekali, saat pemasangan pertama. Tidak punya Wi-Fi?
   Pakai **hotspot HP orang lain** atau Wi-Fi umum (kafe, kantor, kampus). Hotspot dari iPhone
   Anda sendiri **tidak bisa**.
2. Buka **LocalDevVPN** dan ketuk **Connect** sampai tombolnya menyala.
3. Buka **SideInstaller**:
   - Label di bawah judul berubah dari **"Tunnel off"** menjadi aktif. Kalau masih "Tunnel off",
     ulangi langkah 2.
   - Kotak merah **"Wi-Fi required"** hilang. Kalau masih ada, ulangi langkah 1.
4. Login dengan **Apple ID** saat diminta. Password hanya disimpan di iPhone Anda dan dikirim ke
   Apple saja.
5. Di kotak **Install**, pastikan terpilih **SideStore** dan **Stable**, lalu ketuk tombol biru
   **Install SideStore**.
6. Ikuti pertanyaan yang muncul:
   - **"Izinkan Notifikasi"** → **Izinkan**. Kode pairing akan muncul lewat notifikasi.
   - **"Temukan perangkat di jaringan lokal"** → **Izinkan**.
   - Kalau **Pengaturan** meminta kode pairing, ketik kode yang muncul di notifikasi atau di
     Dynamic Island, lalu kembali ke SideInstaller.
7. Tunggu sampai selesai. Ikon **SideStore** akan muncul di layar utama.
8. **Izinkan SideStore:** buka **Pengaturan → Umum → VPN & Manajemen Perangkat**. Di bawah
   *Developer App*, ketuk email Apple ID Anda, lalu ketuk **Percayai**.

✅ **Berhasil kalau** SideStore bisa dibuka. Mulai sekarang Wi-Fi boleh dimatikan.

### Langkah 5 — Pasang ProjectFit dari SideStore

1. **Salin** alamat ini (tekan lama, lalu pilih *Salin*):
   ```
   https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json
   ```
2. Pastikan **LocalDevVPN** dalam keadaan **Connect**.
3. Buka **SideStore** → tab **Sources** → ketuk **+** di pojok kanan atas → tempel alamat tadi →
   ketuk **Add** / **Tambah**.
4. Ketuk sumber **ProjectFit** yang baru muncul, lalu ketuk **Free** / **Get** / **Install** di
   samping ProjectFit.
5. Tunggu sampai ikon **ProjectFit** muncul di layar utama.

✅ **Selesai!** Lanjut ke [Mulai pakai](#-mulai-pakai).

<details>
<summary>Cara lain untuk langkah 5: pakai file .ipa</summary>

1. Di Safari, unduh
   [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa).
2. Di SideStore, buka tab **My Apps**, ketuk **+**, lalu pilih `ProjectFit.ipa` dari folder
   **Unduhan**.

</details>

---

## Tutorial B — pakai komputer (iOS 15 sampai 26)

**Yang dibutuhkan:** komputer **Windows atau Mac**, kabel data iPhone, dan Apple ID.

### Langkah 1 — Unduh ProjectFit di komputer

Klik: **[⬇️ ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)**
(±21 MB), lalu simpan di Desktop. Jangan diekstrak dan jangan diganti namanya.

### Langkah 2 — Pasang Sideloadly di komputer

1. Unduh **Sideloadly** dari situs resminya, **https://sideloadly.io**, lalu pasang seperti
   aplikasi biasa.
2. **Khusus Windows:** pasang juga **iTunes** dan **iCloud** dari **situs Apple**, bukan dari
   Microsoft Store. Tautannya ada di halaman unduh Sideloadly. Kalau sudah terpasang versi
   Microsoft Store, hapus dulu.

### Langkah 3 — Sambungkan iPhone ke komputer

1. Colokkan iPhone dengan kabel, lalu buka kunci layarnya.
2. Kalau muncul **"Percayai Komputer Ini?"**, ketuk **Percayai** dan masukkan kode sandi iPhone.
3. Buka Sideloadly. Nama iPhone Anda harus muncul di kolom **iDevice**.

### Langkah 4 — Pasang ProjectFit

1. **Seret** file `ProjectFit.ipa` ke ikon IPA di kiri atas Sideloadly.
2. Isi kolom **Apple account** dengan email Apple ID.
3. Klik **Start**, lalu masukkan password Apple ID. Kalau diminta **kode verifikasi**, kodenya
   muncul di iPhone atau perangkat Apple Anda yang lain.
4. Tunggu sampai muncul tulisan **Done**.

### Langkah 5 — Izinkan di iPhone

1. Buka **Pengaturan → Umum → VPN & Manajemen Perangkat**. Di bawah *Developer App*, ketuk email
   Apple ID Anda, lalu ketuk **Percayai**.
2. Buka **Pengaturan → Privasi & Keamanan → Mode Pengembang**. Nyalakan, ketuk **Mulai Ulang**,
   lalu setelah iPhone menyala ketuk **Nyalakan**.

✅ **Selesai!** Lanjut ke [Mulai pakai](#-mulai-pakai).

---

## Tutorial C — Mac + Xcode (paling pasti)

Pakai cara ini kalau Tutorial A atau B gagal karena login Apple ditolak (misalnya *"Apple's login
server refused"*, *"-20970"*, atau *"could not retrieve anisette data"*). Xcode adalah alat
resmi Apple, jadi login Apple ID gratis lewat Xcode tidak terkena blokir itu. Bonusnya,
**aplikasi Apple Watch ikut terpasang**.

**Yang dibutuhkan:** Mac, kabel iPhone, ±25 GB ruang kosong, dan ±1 jam untuk pertama kali.
Selanjutnya cukup beberapa menit.

### Langkah 1 — Pasang Xcode
1. Buka **App Store** di Mac, cari **Xcode**, lalu klik **Dapatkan**. Ukurannya besar, jadi
   tunggu sampai selesai.
2. Buka Xcode sekali, lalu klik **Agree** / **Install** kalau diminta. Kalau Xcode menawarkan
   komponen **iOS**, centang lalu unduh.
3. Masuk ke **Xcode → Settings → Accounts**, klik **+** → **Apple ID**, lalu login. Akan muncul
   tim bernama **"(Personal Team)"**.

### Langkah 2 — Pasang alat pendukung (sekali saja)
Buka aplikasi **Terminal** (Cmd+Spasi, ketik *Terminal*). Salin dan tempel **satu baris setiap
kali**, tekan Enter, lalu tunggu sampai selesai:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Perintah di atas memasang Homebrew. Ikuti petunjuknya, termasuk 2 baris `echo … >> ~/.zprofile`
yang ditampilkan di akhir. Setelah itu tutup Terminal dan buka lagi.

```bash
brew install cocoapods
git clone -b 3.41.6 --depth 1 https://github.com/flutter/flutter.git ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zprofile && source ~/.zprofile
flutter --version
```
✅ Berhasil kalau baris terakhir menampilkan **Flutter 3.41.6**.

### Langkah 3 — Unduh ProjectFit dan siapkan tanda tangan
```bash
git clone https://github.com/MahendraDharma/Project-Fit.git ~/Project-Fit
flutter precache --ios
cd ~/Project-Fit/app && flutter pub get && cd ios && pod install
defaults read com.apple.dt.Xcode IDEProvisioningTeams | grep -E "teamID|teamName"
```
Baris terakhir menampilkan **teamID** milik Personal Team Anda (10 huruf/angka, misalnya
`AB12CD34EF`). Masukkan ID itu ke perintah berikut, **ganti `TEAMID_ANDA`**:

```bash
printf 'APPLE_DEVELOPMENT_TEAM = TEAMID_ANDA\n' > ~/Project-Fit/app/ios/Config/Signing.xcconfig
```

### Langkah 4 — Pasang ke iPhone
1. Colokkan iPhone ke Mac dengan kabel, buka kuncinya, lalu ketuk **Percayai**.
2. Pastikan **Mode Pengembang** di iPhone sudah menyala (**Pengaturan → Privasi & Keamanan →
   Mode Pengembang**).
3. Di Terminal:
   ```bash
   cd ~/Project-Fit/app && flutter run --release
   ```
   Kalau ditanya perangkat, pilih nomor iPhone Anda. Proses pertama memakan ±10–20 menit.
4. Kalau iPhone menolak membuka aplikasi: **Pengaturan → Umum → VPN & Manajemen Perangkat** →
   ketuk Apple ID Anda → **Percayai**.

✅ **Selesai!** Lanjut ke [Mulai pakai](#-mulai-pakai).

**Perpanjang setiap 7 hari:** colokkan iPhone, lalu jalankan lagi
`cd ~/Project-Fit/app && git pull && flutter run --release`. Perintah yang sama sekaligus
memperbarui ke versi terbaru, dan data tidak hilang.

> [!NOTE]
> Kalau muncul error soal **Watch**, **provisioning profile**, atau **bundle identifier**,
> kirim screenshot-nya lewat [Issues](https://github.com/MahendraDharma/Project-Fit/issues).
> Apple ID gratis kadang perlu bundle ID yang berbeda, dan itu bisa diatur di
> `Signing.xcconfig` yang sama.

---

## 🚀 Mulai pakai

1. **Putuskan WHOOP dari aplikasi resmi WHOOP** dulu (atau tutup paksa aplikasinya). Satu strap
   hanya bisa tersambung ke satu aplikasi.
2. Buka **ProjectFit** dan izinkan **Bluetooth** saat diminta.
3. Ikuti layar awal untuk memasangkan WHOOP.
4. **Pindahan dari OpenStrap?** Buka **Profile → Export and backup**, lalu pilih file ekspor
   OpenStrap (`.db`). Semua data lama ikut masuk.

---

## 🔄 Perpanjang setiap 7 hari

Kalau tidak diperpanjang, ProjectFit **tidak bisa dibuka setelah 7 hari**. Data Anda tetap aman
dan bisa dipakai lagi setelah diperpanjang.

| Cara pasang | Cara perpanjang |
|---|---|
| **Tutorial A** | Nyalakan **LocalDevVPN** → buka **SideStore** → tab **My Apps** → ketuk **Refresh All** |
| **Tutorial B** | Ulangi **Langkah 3 dan 4** Tutorial B |
| **Tutorial C** | Colokkan iPhone, lalu jalankan `cd ~/Project-Fit/app && flutter run --release` |

> [!CAUTION]
> **Jangan hapus aplikasinya** untuk memperpanjang. Menghapus aplikasi = menghapus data di
> dalamnya.

**💡 Tips:** buat pengingat di aplikasi **Pengingat** setiap 6 hari.

## ⬆️ Memperbarui ke versi baru

- **Tutorial A:** versi baru muncul di SideStore (tab **My Apps**). Ketuk **Update**.
- **Tutorial B:** unduh lagi
  [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa),
  lalu ulangi Langkah 3–4.

Versi baru terpasang di atas versi lama, dan data tetap ada.

---

## 🆘 Kalau ada masalah

| Yang muncul | Artinya | Solusi |
|---|---|---|
| **"Wi-Fi required"** di SideInstaller | Pemasangan pertama butuh Wi-Fi | Sambungkan ke Wi-Fi atau hotspot HP orang lain (bukan hotspot iPhone sendiri) |
| **"Tunnel off"** di SideInstaller | LocalDevVPN belum tersambung | Buka LocalDevVPN, ketuk **Connect**, lalu kembali |
| **"Untrusted Developer" / "Pengembang Tidak Dipercaya"** | Aplikasi belum diizinkan | **Pengaturan → Umum → VPN & Manajemen Perangkat** → **Percayai** (perlu internet) |
| **"Unable to Verify App"** | iPhone tidak bisa mengecek ke Apple | Sambungkan internet, lalu ulangi **Percayai** |
| SideInstaller **tidak bisa dibuka** sama sekali | Sertifikatnya dicabut Apple | Pasang ulang dari [sideinstaller.net](https://sideinstaller.net) dengan sertifikat lain. SideStore dan ProjectFit tidak terpengaruh |
| **ProjectFit tidak bisa dibuka** setelah beberapa hari | Masa 7 hari habis | [Perpanjang](#-perpanjang-setiap-7-hari) |
| **"Reset your Apple Account password"** | Apple mengunci Apple ID karena terlalu sering login | Buka [iforgot.apple.com](https://iforgot.apple.com), reset password, lalu login ulang |
| **"Maximum number of apps"** | Batas 3 aplikasi Apple ID gratis | Hapus aplikasi sideload lain yang tidak dipakai |
| Sideloadly: **"Login failed (-20970)" / "account information was entered incorrectly"**, padahal password benar | Login Apple dari Sideloadly ditolak (sering soal *anisette*, bukan password) | 1) Perbarui Sideloadly ke versi terbaru. 2) Klik **Advanced options**, ubah **Anisette Authentication** dari *Local* ke *Remote* (atau sebaliknya), tutup Sideloadly lalu buka lagi. 3) Login sekali di [appleid.apple.com](https://appleid.apple.com) dan [developer.apple.com](https://developer.apple.com/account), setujui syarat yang muncul. 4) Masih gagal? Punya Mac? Pakai [Tutorial C](#tutorial-c--mac--xcode-paling-pasti) |
| **"-80045" / "This action cannot be completed at this time"** | Apple sedang memblokir login dari alat sideload (Oktober 2026) | Berhenti mencoba supaya Apple ID tidak terkunci. Pakai [Tutorial C](#tutorial-c--mac--xcode-paling-pasti) |
| AltServer: **"could not retrieve anisette data value machineID"** | Plug-in Mail milik AltServer belum aktif | Buka **Mail → Settings → General → Manage Plug-ins**, centang **AltPlugin**, klik Apply, lalu tutup dan buka lagi Mail serta AltServer. Masih gagal? Pakai [Tutorial C](#tutorial-c--mac--xcode-paling-pasti) |
| Sideloadly **tidak menemukan iPhone** | Koneksi kabel atau iTunes | Ganti kabel atau port, buka kunci iPhone, ketuk **Percayai**. Di Windows, pakai iTunes dari situs Apple |
| Mode Pengembang **tidak ada di menu** | Belum ada aplikasi sideload | Muncul setelah aplikasi pertama terpasang. Lanjutkan dulu, lalu kembali ke langkah ini |

Masih bermasalah? Buka [Issues](https://github.com/MahendraDharma/Project-Fit/issues) dan sertakan
**screenshot** serta **versi iOS** Anda.

---

## 📋 Batasan Apple ID gratis

- Maksimal **3 aplikasi** sideload sekaligus. Di Tutorial A, SideStore memakai 1 slot.
- **Aplikasi Apple Watch tidak ikut terpasang.**
- **Widget, Live Activity dan pintasan Siri** mungkin tidak jalan.
- **Apple Health** belum diuji di cara pasang ini. Fitur utama (Bluetooth WHOOP, perhitungan,
  semua layar) tetap jalan.

## 🔒 Soal keamanan

- **Kenapa diminta Apple ID?** Apple ID dipakai untuk membuat "tanda tangan" gratis yang membuat
  aplikasi bisa dibuka di iPhone Anda. Menurut pembuat SideInstaller, password hanya disimpan di
  iPhone dan dikirim ke Apple saja. Ini hanya berlaku untuk unduhan dari sumber resmi.
- **Pakai Apple ID kedua** supaya Apple ID utama Anda (foto, iCloud, pembelian) tidak tersentuh.
- **ProjectFit** sendiri tidak meminta Apple ID, tidak punya akun, dan tidak mengirim data
  kesehatan ke internet.

---

<details>
<summary>🧑‍💻 Untuk pengembang: dari mana file .ipa berasal</summary>

<br>

File dibangun oleh GitHub Actions di runner macOS
([`ios-sideload.yml`](../.github/workflows/ios-sideload.yml)) **tanpa tanda tangan**. Bagian
Apple Watch dibuang karena tidak bisa ditandatangani ulang dengan Apple ID gratis.

- **Rilis baru:** buka **Actions → ios-sideload → Run workflow** dan isi `release_tag`
  (mis. `v0.11.4`), atau push tag `v*`. Rilis berisi `ProjectFit.ipa`,
  `projectfit-<tag>-unsigned.ipa`, dan `apps.json` (sumber SideStore/AltStore).
- **Build uji tanpa rilis:** jalankan workflow dengan `release_tag` kosong. Hasilnya disimpan
  sebagai artifact `projectfit-ipa` selama 30 hari.
- **Mac + Xcode:** aplikasi bisa dibangun langsung dari source. Hanya cara ini yang ikut
  memasang aplikasi Apple Watch.

</details>
