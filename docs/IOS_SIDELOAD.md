# Tutorial: unduh dan pasang ProjectFit di iPhone

ProjectFit tidak ada di App Store. Jalur ini **gratis**: Anda mengunduh file aplikasi (`.ipa`),
lalu alat pemasang menandatanganinya dengan **Apple ID Anda sendiri**. Tidak perlu akun
developer berbayar. Jailbreak juga tidak perlu.

**Yang dibutuhkan**
- iPhone dengan iOS 15 atau lebih baru.
- Kabel data iPhone (Lightning/USB-C).
- Komputer **Windows atau Mac** untuk pemasangan pertama.
- Apple ID. Disarankan Apple ID kedua khusus untuk ini (lihat [Tanya jawab](#tanya-jawab)).

Waktu: ±15 menit untuk pertama kali.

---

## Langkah 1 — Unduh aplikasi

Di komputer, unduh file ini:

**➡️ [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa)**

Bisa juga lewat halaman [Releases](https://github.com/MahendraDharma/Project-Fit/releases):
buka rilis teratas, lalu di bagian **Assets** klik `ProjectFit.ipa`. Simpan di tempat yang
mudah ditemukan, misalnya Desktop. Jangan ganti nama atau ekstrak filenya.

## Langkah 2 — Pasang Sideloadly di komputer

1. Unduh Sideloadly dari situs resminya: **https://sideloadly.io**. Pilih versi Windows atau
   macOS, lalu pasang seperti aplikasi biasa.
2. **Khusus Windows**: Sideloadly butuh iTunes dan iCloud **versi dari situs Apple**, bukan
   dari Microsoft Store. Tautannya ada di halaman unduh Sideloadly. Kalau sudah terpasang
   versi Microsoft Store, hapus dulu, lalu pasang versi situs Apple.

## Langkah 3 — Sambungkan iPhone

1. Colokkan iPhone ke komputer dengan kabel.
2. Buka kunci iPhone. Kalau muncul **Trust This Computer?** / **Percayai Komputer Ini?**,
   ketuk **Trust** / **Percayai** lalu masukkan kode sandi iPhone.
3. Buka Sideloadly. Nama iPhone Anda harus muncul di kolom **iDevice**.

## Langkah 4 — Pasang aplikasinya

1. Seret file `ProjectFit.ipa` ke ikon IPA di kiri atas jendela Sideloadly. Cara lain: klik
   ikon itu lalu pilih filenya.
2. Isi kolom **Apple account** dengan email Apple ID Anda.
3. Klik **Start**.
4. Masukkan kata sandi Apple ID. Kalau diminta kode verifikasi dua langkah, kode itu muncul di
   iPhone atau perangkat Apple Anda yang lain.
5. Tunggu sampai muncul tulisan **Done**. Ikon ProjectFit kini ada di layar iPhone, tapi belum
   bisa dibuka. Lanjut ke langkah 5.

## Langkah 5 — Izinkan aplikasi di iPhone

1. Buka **Settings → General → VPN & Device Management**
   (**Pengaturan → Umum → VPN & Manajemen Perangkat**).
2. Di bagian **Developer App**, ketuk email Apple ID Anda, lalu ketuk **Trust** / **Percayai**.
3. **iOS 16 ke atas**: buka **Settings → Privacy & Security → Developer Mode**
   (**Privasi & Keamanan → Mode Pengembang**). Nyalakan, lalu ketuk **Restart**. Setelah
   iPhone menyala lagi, ketuk **Turn On** / **Nyalakan** dan masukkan kode sandi.
   *Menu Developer Mode baru muncul setelah langkah 4 selesai.*
4. Buka ProjectFit. Izinkan akses **Bluetooth** saat diminta.

## Langkah 6 — Mulai pakai

1. **Lepaskan WHOOP dari aplikasi resmi WHOOP** dulu (atau tutup paksa aplikasinya). Satu strap
   hanya bisa tersambung ke satu aplikasi.
2. Di ProjectFit, ikuti layar awal untuk memasangkan WHOOP 4.0.
3. Punya data lama dari OpenStrap? Buka **Profile → Export and backup** di ProjectFit, lalu
   pilih file ekspor OpenStrap (`.db`). Sudah diuji dengan ekspor OpenStrap asli: semua data
   per detik, detak jantung, metrik dan latihan masuk utuh.

---

## Penting: perpanjang setiap 7 hari

Dengan Apple ID gratis, aplikasi **berhenti bisa dibuka setelah 7 hari**. Untuk
memperpanjangnya, ulangi **langkah 3 dan 4** dengan file `.ipa` yang sama atau versi
terbaru. **Jangan hapus aplikasinya dulu**: dengan cara ini data Anda tetap aman.

Ingin perpanjangan otomatis tanpa komputer? Pakai **SideStore** (lihat di bawah).

## Memperbarui ke versi baru

Unduh lagi [ProjectFit.ipa](https://github.com/MahendraDharma/Project-Fit/releases/latest/download/ProjectFit.ipa),
lalu ulangi langkah 3 dan 4. Versi baru terpasang di atas versi lama, dan data tetap ada.

## Alternatif: SideStore (tanpa komputer setelah setup)

SideStore memperpanjang aplikasi langsung dari iPhone. Komputer hanya dibutuhkan sekali, saat
pemasangan awal SideStore.

1. Ikuti panduan resmi: **https://docs.sidestore.io**.
2. Di SideStore, buka tab **Sources**, ketuk **+**, lalu masukkan:
   `https://github.com/MahendraDharma/Project-Fit/releases/latest/download/apps.json`
3. Pasang ProjectFit dari sumber itu. Pembaruan akan muncul otomatis di SideStore.

AltStore juga bisa memakai sumber yang sama, tetapi AltServer di komputer harus menyala di
Wi-Fi yang sama setiap kali perpanjangan.

## Batasan Apple ID gratis

- Paling banyak **3 aplikasi** sideload aktif sekaligus.
- **Aplikasi Apple Watch tidak ikut terpasang.** Bagian Watch dibuang dari file `.ipa` karena
  tidak bisa ditandatangani ulang dengan Apple ID gratis.
- **Widget, Live Activity dan pintasan Siri mungkin tidak jalan.** Kalau Sideloadly gagal
  karena batas App ID, buka **Advanced options** dan pilih opsi untuk membuang ekstensi aplikasi
  (*app extensions*).
- **Apple Health** belum diuji di jalur ini. Fitur inti tetap jalan tanpanya: Bluetooth WHOOP,
  perhitungan, dan semua layar.

## Tanya jawab

**Aman memasukkan Apple ID ke Sideloadly?** Sideloadly login ke Apple untuk membuat sertifikat
pengembang gratis atas nama Anda. Supaya lebih tenang, buat **Apple ID kedua** khusus untuk
sideload. Apple ID di iPhone tidak perlu diganti.

**Muncul "Unable to Verify App" / "Untrusted Developer".** Ulangi langkah 5.1–5.2. HP harus
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
