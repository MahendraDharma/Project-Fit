# Tutorial: unduh dan pasang ProjectFit di iPhone

ProjectFit tidak ada di App Store. Jalur di bawah ini **gratis**: aplikasi ditandatangani dengan
**Apple ID Anda sendiri**. Tidak perlu akun developer berbayar. Jailbreak juga tidak perlu.

**Pilih jalur sesuai versi iOS** (cek di **Pengaturan → Umum → Mengenai**):

| Versi iOS | Jalur | Butuh komputer? |
|---|---|---|
| **iOS 27 ke atas** | [Jalur A — iPhone saja](#jalur-a--iphone-saja-ios-27) | Tidak |
| iOS 15 – 26 | [Jalur B — dengan komputer](#jalur-b--dengan-komputer-windowsmac) | Ya, Windows atau Mac |

Untuk kedua jalur, disarankan memakai **Apple ID kedua** khusus sideload (lihat
[Tanya jawab](#tanya-jawab)).

---

## Jalur A — iPhone saja (iOS 27+)

Jalur ini memakai dua aplikasi gratis:
- **SideInstaller** memasang SideStore langsung dari iPhone, tanpa komputer.
- **SideStore** memasang ProjectFit dan memperpanjangnya setiap 7 hari, juga dari iPhone.

> ⚠️ **Hanya unduh SideInstaller dari sumber resminya:** **https://sideinstaller.net** atau
> https://github.com/FrizzleM/SideInstaller. Aplikasi ini meminta password Apple ID, dan
> pembuatnya sendiri memperingatkan ada salinan palsu (misalnya situs *sideinstaller.com*) yang
> bisa mencuri akun. ProjectFit tidak terafiliasi dengan SideInstaller maupun SideStore.

Waktu: ±15 menit. Butuh Wi-Fi.

### A1 — Pasang SideInstaller
1. Di iPhone, buka **Safari** lalu kunjungi **https://sideinstaller.net**.
2. Ikuti tombol pasang di halaman itu. SideInstaller dipasang memakai sertifikat yang disediakan
   pembuatnya, bukan Apple ID Anda. Sertifikat itu bisa dicabut Apple sewaktu-waktu. Kalau
   gagal, coba sertifikat lain yang ditawarkan di halaman yang sama.
3. Buka **Settings → General → VPN & Device Management**
   (**Pengaturan → Umum → VPN & Manajemen Perangkat**), lalu percayai (Trust) profil
   SideInstaller.
4. Nyalakan **Developer Mode**: **Settings → Privacy & Security → Developer Mode**
   (**Privasi & Keamanan → Mode Pengembang**) → nyalakan → **Restart** → **Turn On**.

### A2 — Pasang SideStore lewat SideInstaller
1. Pasang **LocalDevVPN** dari App Store (gratis), buka, lalu sambungkan VPN-nya. VPN ini hanya
   bekerja di dalam iPhone dan tidak mengirim lalu lintas internet Anda ke luar.
2. Buka **SideInstaller** dan login dengan Apple ID.
3. Ketuk **Install SideStore** dan tunggu sampai selesai.
4. Percayai Apple ID Anda di **VPN & Manajemen Perangkat** (sama seperti A1 langkah 3), lalu
   buka **SideStore**.

### A3 — Pasang ProjectFit dari SideStore
1. Di SideStore buka tab **Sources**, ketuk **+**, lalu tempel alamat ini:
   ```
   https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json
   ```
2. Buka sumber **ProjectFit**, lalu ketuk **Get / Install**.
3. Buka ProjectFit dan izinkan **Bluetooth**. Lanjutkan ke [Mulai pakai](#mulai-pakai).

Cara lain untuk langkah 1–2: unduh
[ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)
di Safari, buka tab **My Apps** di SideStore, ketuk **+**, lalu pilih file itu dari folder
Unduhan.

### A4 — Perpanjang setiap 7 hari, dari iPhone
Buka SideStore dengan LocalDevVPN tersambung, lalu ketuk **Refresh All** di tab **My Apps**.
Lakukan sebelum 7 hari lewat. Data di ProjectFit tidak hilang selama aplikasinya tidak dihapus.
Pembaruan ProjectFit juga muncul di SideStore.

---

## Jalur B — dengan komputer (Windows/Mac)

Untuk iOS 15–26, atau kalau Jalur A gagal.

**Yang dibutuhkan:** kabel data iPhone (Lightning/USB-C), komputer **Windows atau Mac**, dan
Apple ID. Waktu: ±15 menit untuk pertama kali.

### Langkah B1 — Unduh aplikasi

Di komputer, unduh file ini:

**➡️ [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)**

Bisa juga lewat halaman [Releases](https://github.com/MahendraDharma/Project-Fit/releases):
buka rilis teratas, lalu di bagian **Assets** klik `ProjectFit.ipa`. Simpan di tempat yang
mudah ditemukan, misalnya Desktop. Jangan ganti nama atau ekstrak filenya.

### Langkah B2 — Pasang Sideloadly di komputer

1. Unduh Sideloadly dari situs resminya: **https://sideloadly.io**. Pilih versi Windows atau
   macOS, lalu pasang seperti aplikasi biasa.
2. **Khusus Windows**: Sideloadly butuh iTunes dan iCloud **versi dari situs Apple**, bukan
   dari Microsoft Store. Tautannya ada di halaman unduh Sideloadly. Kalau sudah terpasang
   versi Microsoft Store, hapus dulu, lalu pasang versi situs Apple.

### Langkah B3 — Sambungkan iPhone

1. Colokkan iPhone ke komputer dengan kabel.
2. Buka kunci iPhone. Kalau muncul **Trust This Computer?** / **Percayai Komputer Ini?**,
   ketuk **Trust** / **Percayai** lalu masukkan kode sandi iPhone.
3. Buka Sideloadly. Nama iPhone Anda harus muncul di kolom **iDevice**.

### Langkah B4 — Pasang aplikasinya

1. Seret file `ProjectFit.ipa` ke ikon IPA di kiri atas jendela Sideloadly. Cara lain: klik
   ikon itu lalu pilih filenya.
2. Isi kolom **Apple account** dengan email Apple ID Anda.
3. Klik **Start**.
4. Masukkan kata sandi Apple ID. Kalau diminta kode verifikasi dua langkah, kode itu muncul di
   iPhone atau perangkat Apple Anda yang lain.
5. Tunggu sampai muncul tulisan **Done**. Ikon ProjectFit kini ada di layar iPhone, tapi belum
   bisa dibuka. Lanjut ke langkah B5.

### Langkah B5 — Izinkan aplikasi di iPhone

1. Buka **Settings → General → VPN & Device Management**
   (**Pengaturan → Umum → VPN & Manajemen Perangkat**).
2. Di bagian **Developer App**, ketuk email Apple ID Anda, lalu ketuk **Trust** / **Percayai**.
3. **iOS 16 ke atas**: buka **Settings → Privacy & Security → Developer Mode**
   (**Privasi & Keamanan → Mode Pengembang**). Nyalakan, lalu ketuk **Restart**. Setelah
   iPhone menyala lagi, ketuk **Turn On** / **Nyalakan** dan masukkan kode sandi.
   *Menu Developer Mode baru muncul setelah langkah B4 selesai.*
4. Buka ProjectFit. Izinkan akses **Bluetooth** saat diminta.

---

## Mulai pakai

1. **Lepaskan WHOOP dari aplikasi resmi WHOOP** dulu (atau tutup paksa aplikasinya). Satu strap
   hanya bisa tersambung ke satu aplikasi.
2. Di ProjectFit, ikuti layar awal untuk memasangkan WHOOP 4.0.
3. Punya data lama dari OpenStrap? Buka **Profile → Export and backup** di ProjectFit, lalu
   pilih file ekspor OpenStrap (`.db`). Sudah diuji dengan ekspor OpenStrap asli: semua data
   per detik, detak jantung, metrik dan latihan masuk utuh.

---

## Penting: perpanjang setiap 7 hari

Dengan Apple ID gratis, aplikasi **berhenti bisa dibuka setelah 7 hari**. Perpanjang sebelum itu:

- **Jalur A:** buka SideStore (LocalDevVPN tersambung) → **My Apps** → **Refresh All**.
- **Jalur B:** ulangi **langkah B3 dan B4** dengan file `.ipa` yang sama atau versi terbaru.

**Jangan hapus aplikasinya dulu.** Dengan cara ini data Anda tetap aman.

## Memperbarui ke versi baru

- **Jalur A:** pembaruan muncul di SideStore (tab **My Apps**). Ketuk **Update**.
- **Jalur B:** unduh lagi
  [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa),
  lalu ulangi langkah B3 dan B4.

Versi baru terpasang di atas versi lama, dan data tetap ada.

## SideStore di iOS 15–26

Di bawah iOS 27, SideInstaller belum bisa dipakai. SideStore tetap bisa dipasang, tetapi
pemasangan awalnya butuh komputer sekali (panduan resmi: **https://docs.sidestore.io**). Setelah
itu langkah A3 dan A4 berlaku, dan perpanjangan dilakukan dari iPhone tanpa komputer.

AltStore juga bisa memakai sumber `apps.json` yang sama. Bedanya, AltServer di komputer harus
menyala di Wi-Fi yang sama setiap kali memperpanjang.

## Batasan Apple ID gratis

- Paling banyak **3 aplikasi** sideload aktif sekaligus. Di Jalur A, SideStore sendiri memakai
  satu slot.
- **Aplikasi Apple Watch tidak ikut terpasang.** Bagian Watch dibuang dari file `.ipa` karena
  tidak bisa ditandatangani ulang dengan Apple ID gratis.
- **Widget, Live Activity dan pintasan Siri mungkin tidak jalan.** Kalau Sideloadly gagal
  karena batas App ID, buka **Advanced options** dan pilih opsi untuk membuang ekstensi aplikasi
  (*app extensions*).
- **Apple Health** belum diuji di jalur ini. Fitur inti tetap jalan tanpanya: Bluetooth WHOOP,
  perhitungan, dan semua layar.

## Tanya jawab

**Aman memasukkan Apple ID ke SideInstaller, SideStore atau Sideloadly?** Alat-alat ini login ke Apple untuk
membuat sertifikat pengembang gratis atas nama Anda. Menurut pembuat SideInstaller, password
hanya dipakai di iPhone dan tidak dikirim ke server mereka. Ini hanya berlaku untuk unduhan dari
sumber resmi. Supaya lebih tenang, buat **Apple ID kedua** khusus untuk
sideload. Apple ID di iPhone tidak perlu diganti.

**Muncul "Unable to Verify App" / "Untrusted Developer".** Ulangi langkah B5.1–B5.2 (Jalur A: A1 langkah 3). HP harus
tersambung ke internet saat menekan Trust.

**Aplikasi tiba-tiba tidak bisa dibuka.** Masa 7 hari sudah lewat. Lihat
[Penting: perpanjang setiap 7 hari](#penting-perpanjang-setiap-7-hari).

**Sideloadly tidak menemukan iPhone.** Ganti kabel atau port USB, buka kunci iPhone, lalu
pastikan sudah menekan Trust. Di Windows, pastikan iTunes yang terpasang versi situs Apple.

**Punya Mac dan Xcode?** Aplikasi bisa dibangun langsung dari source code. Hanya cara ini yang
ikut memasang aplikasi Apple Watch. Masa berlakunya tetap 7 hari.

---

<details>
<summary>Untuk pengembang: dari mana file <code>.ipa</code> berasal</summary>

File dibangun oleh GitHub Actions di runner macOS
([`ios-sideload.yml`](../.github/workflows/ios-sideload.yml)) **tanpa tanda tangan**:

- Setiap tag `v*` membuat rilis yang berisi `ProjectFit.ipa`, file versi bernama
  `projectfit-<tag>-unsigned.ipa`, dan `apps.json` (sumber AltStore/SideStore).
- Workflow juga bisa dijalankan manual dari tab Actions (**Run workflow**). Hasilnya menjadi
  *artifact* `projectfit-ipa` yang disimpan 30 hari.

</details>
