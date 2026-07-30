# Checklist Alur & Poin Marketing — Kuwrir Aja (Cocourir)

## Tujuan Dokumen

Dokumen ini fokus ke **alur pemakaian nyata di app** — dari login sampai logout, per role (Customer, Merchant, Driver) — bukan materi pitch/perbandingan vs kompetitor. Tujuannya supaya tim bisa:

1. Cek alur yang sudah benar-benar jalan di app (bukan asumsi).
2. Nemuin poin di setiap tahap yang layak diangkat jadi materi marketing.
3. Nandain hal yang masih perlu diputuskan/didiskusikan sebelum dipakai buat campaign.

**Legenda:**
- `[ ]` — tahap ini sudah ada & jalan di app (dicek langsung dari kode, bukan dokumentasi lama)
- 📣 — poin yang layak diangkat untuk marketing/pitching
- ⚠️ — catatan atau keputusan yang masih perlu dibahas tim sebelum dipakai untuk materi promosi

---

## 1. Customer Journey

### 1.1 Login & Registrasi
- [ ] Buka app → verifikasi nomor HP pakai OTP via WhatsApp (bukan email/password)
  - 📣 *"Daftar cukup nomor WhatsApp — nggak perlu bikin password, nggak perlu verifikasi email."*
  - ⚠️ OTP dikirim lewat gateway WhatsApp yang kita host sendiri (bukan API resmi Meta) — ada resiko downtime (baru kejadian minggu ini gara-gara kebijakan WhatsApp berubah). Perlu diputuskan: tetap pakai ini, atau migrasi ke WhatsApp Business API resmi/SMS gateway sebagai cadangan.
- [ ] Lengkapi profil dasar
- [ ] Tambah alamat pengiriman (bisa lebih dari satu, pilih lewat peta)

### 1.2 Home & Discovery
- [ ] Lihat carousel banner di halaman depan — gabungan dari 3 sumber:
  - Banner kurasi admin (promo platform)
  - Banner berbayar dari merchant (slot iklan, fitur baru)
  - Rotasi otomatis toko rating tertinggi (kalau slot iklan kosong, bukan cuma dibiarkan sepi)
  - 📣 *"Toko dengan rating bagus otomatis tampil gratis di halaman depan — makin rajin jaga kualitas, makin sering muncul."*
- [ ] Filter berdasarkan kategori makanan
- [ ] Cari toko/produk lewat pencarian
- [ ] Lihat produk & merchant populer

### 1.3 Pilih & Checkout
- [ ] Buka halaman detail toko — menu, rating, produk yang lagi diskon
- [ ] Pilih produk + varian (ukuran, topping, dll)
- [ ] Masuk keranjang, atur jumlah
- [ ] Checkout:
  - [ ] Pilih/isi alamat pengiriman
  - [ ] **Masukkan kode promo** — beneran motong harga saat checkout, bukan cuma tampil di katalog
    - 📣 *"Kode promo beneran ngasih diskon nyata — bisa dari platform, atau langsung dari toko favoritmu."*
  - [ ] Pilih metode bayar: Cash (COD) atau online (QRIS, Virtual Account, e-wallet, kartu, gerai retail — lewat Duitku, dikelompokkan per kategori biar gampang dicari)
    - 📣 *"COD tetap ada buat yang belum nyaman bayar online — nggak dipaksa pakai dompet digital."*
  - [ ] Lihat rincian biaya lengkap sebelum konfirmasi: subtotal, ongkir, pajak, biaya layanan, diskon — semua kelihatan di awal, bukan muncul dadakan di akhir

### 1.4 Pembayaran Non-Tunai
- [ ] Bayar langsung di dalam app (WebView) — nggak perlu keluar ke browser terpisah
- [ ] Setelah bayar sukses, otomatis balik ke halaman detail order dengan status ter-update
- [ ] Kalau belum bayar dan klik "Bayar Sekarang" lagi, pakai link pembayaran yang sama (selama belum kedaluwarsa) — nggak generate kode bayar baru tiap kali

### 1.5 Tracking & Komunikasi
- [ ] Lacak status pesanan real-time (auto-update + bisa refresh manual)
- [ ] Chat langsung dengan driver dan/atau merchant dari dalam app
- [ ] Notifikasi push untuk setiap perubahan status penting
  - 📣 *"Update pesanan real-time — nggak perlu buka app terus buat ngecek."*

### 1.6 Riwayat & Wallet
- [ ] Lihat riwayat pesanan
- [ ] Wallet customer — bisa top up & tarik dana, tapi **bukan** metode bayar pesanan langsung (dipakai buat kebutuhan lain seperti refund)
  - ⚠️ ini perlu dikomunikasikan jelas ke customer biar nggak salah paham "kenapa saldo wallet nggak bisa buat bayar order"

### 1.7 Support & Profil
- [ ] Chat support langsung ke admin dari dalam app
  - 📣 *"Komplain direspons langsung oleh tim, bukan chatbot atau sistem tiket berlapis."*
- [ ] Kelola profil pribadi
- [ ] Logout

### 1.8 Fitur yang Di-hold
- ⚠️ Ada alur pemesanan layanan jasa (booking & tracking untuk laundry/bengkel/salon dll) yang sudah dibangun di kode, tapi **sedang tidak difokuskan** — prioritas sekarang di order barang/makanan dulu. Jangan dipakai dalam materi marketing sampai tim putuskan dilanjutkan.

---

## 2. Merchant Journey

### 2.1 Registrasi & Verifikasi
- [ ] Daftar akun — isi data toko & upload dokumen pendukung
- [ ] Preview & setujui perjanjian kemitraan sebelum submit
- [ ] Submit, lalu menunggu verifikasi admin
  - ⚠️ SLA verifikasi belum didefinisikan secara resmi — perlu diputuskan angka pastinya (misal "maks. 2×24 jam") sebelum dijanjikan di materi marketing
- [ ] Kalau profil toko belum lengkap, diarahkan lanjut dari tahap yang kurang — bukan mulai ulang dari awal

### 2.2 Setup Toko
- [ ] Upload logo & banner toko
- [ ] Isi info toko: nama, alamat, telepon, titik lokasi di peta
- [ ] Atur kategori & daftar produk, termasuk varian, harga diskon, biaya kemasan, dan jam tayang produk (misal produk sarapan cuma tampil pagi)
- [ ] Atur stok per produk (opsional, bisa nyala/mati per item)
  - 📣 *"Setup dan kelola toko sepenuhnya sendiri, kapan aja — nggak perlu nunggu admin platform bantu input."*

### 2.3 Operasional Harian
- [ ] Terima notifikasi pesanan baru secara real-time
- [ ] Kelola alur pesanan: terima → proses → siap
- [ ] Pilih antar sendiri (atur ongkir sendiri) atau pakai driver platform
  - 📣 *"Fleksibel — mau pakai armada Cocourir atau antar sendiri, dua-duanya didukung."*
- [ ] Buka/tutup toko kapan saja lewat toggle satu klik
- [ ] Lihat ringkasan dashboard: pesanan hari ini, pendapatan, rating

### 2.4 Promosi Mandiri (Fitur Baru)
- [ ] Buat kode promo sendiri (persen, potongan tetap, atau gratis ongkir) — hanya berlaku di toko sendiri
  - 📣 *"Bikin promo sendiri kapan aja tanpa nunggu admin platform bikinin — full kendali di tangan merchant."*
- [ ] Beli slot iklan banner di halaman depan customer, bayar per hari langsung dari saldo wallet
  - 📣 *"Mau lebih menonjol di halaman depan? Bisa beli slot banner utama. Kalau nggak ada yang beli, toko rating terbaik otomatis dapat slot gratis — jadi selalu ada insentif buat jaga kualitas."*
  - ⚠️ harga slot banner per hari belum ditentukan tim — perlu disepakati sebelum fitur ini diumumkan ke merchant

### 2.5 POS / Kasir (Sering Terlewat, Padahal Pembeda Kuat)
- [ ] Terminal POS untuk transaksi tatap muka langsung di toko
- [ ] Kelola piutang (pelanggan yang belum lunas bayar)
- [ ] Kelola hutang ke supplier
- [ ] Laporan penjualan
  - 📣 *"Bukan cuma app pesan-antar — ada sistem kasir lengkap buat transaksi langsung di toko, semua kecatat dalam satu aplikasi yang sama."*
  - ⚠️ fitur ini belum pernah masuk materi marketing sama sekali, padahal GoFood/GrabFood/ShopeeFood nggak nyediain ini — **worth jadi salah satu pembeda utama** di pitch merchant.

### 2.6 Keuangan
- [ ] Pantau saldo wallet real-time
- [ ] Tarik dana ke rekening bank
- [ ] Atur status pajak (PKP aktif/nonaktif, rate custom kalau perlu)
- [ ] Chat langsung dengan customer soal pesanan

### 2.7 Logout
- [ ] Keluar akun
  - ⚠️ opsi hapus akun sudah dibangun di kode tapi sengaja disembunyikan dari menu (masih under review) — jangan disebut di materi marketing dulu

---

## 3. Driver Journey

### 3.1 Registrasi & Verifikasi
- [ ] Daftar akun
- [ ] Lengkapi data kendaraan, NIK, SIM, alamat
- [ ] Preview & setujui perjanjian kemitraan driver
- [ ] Submit, tunggu verifikasi admin

### 3.2 Cari & Ambil Order
- [ ] Buka job board — lihat pesanan tersedia di sekitar
  - 📣 *"Order baru langsung kelihatan dan dapat notifikasi — nggak perlu buka app terus-terusan buat mantengin."*
- [ ] Terima notifikasi push real-time untuk job baru
- [ ] Terima (accept) order pilihan

### 3.3 Jalankan Order
- [ ] Proses antar: ambil di merchant → antar ke customer
- [ ] Chat langsung dengan customer
- [ ] Kelola pembayaran tunai (COD) yang dipegang sampai disetor

### 3.4 Keuangan
- [ ] Pantau saldo wallet real-time
- [ ] Tarik dana ke rekening bank kapan saja
  - 📣 *"Saldo langsung masuk begitu order selesai — bisa ditarik kapan aja, nggak nunggu jadwal pencairan tertentu."*

### 3.5 Logout
- [ ] Keluar akun

### 3.6 Fitur yang Di-hold
- ⚠️ Ada alur job untuk layanan jasa yang sudah dibangun tapi belum difokuskan — sama seperti sisi customer, ikut prioritas order barang/makanan dulu.

---

## 4. Fitur Lintas-Platform (Berlaku di Ketiga App)

- [ ] Login tanpa password — semua lewat OTP WhatsApp
- [ ] Notifikasi push real-time (order baru, perubahan status, pesan chat, dst)
- [ ] Chat in-app antar pihak — nggak perlu keluar ke WhatsApp/SMS eksternal
- [ ] Tracking status pesanan real-time
- [ ] Payment gateway lengkap: QRIS, Virtual Account, e-wallet, kartu, gerai retail, COD
- [ ] Ongkir berbasis zona — flat per area, bukan surge pricing dinamis

*(Dokumen ini fokus ke alurnya saja — perbandingan detail vs kompetitor per poin di atas belum ada dokumen terpisah, bisa disusun kalau tim butuh.)*

---

## 5. Yang Perlu Dibahas Tim Sebelum Dipakai untuk Materi Marketing

- ⚠️ **SLA verifikasi** merchant & driver — berapa hari kerja maksimal, biar bisa dijanjikan dengan angka pasti.
- ⚠️ **Harga slot iklan banner** per hari untuk merchant — belum ditentukan.
- ⚠️ **Ketergantungan WhatsApp gateway self-hosted** untuk OTP — perlu opsi cadangan (SMS gateway atau WhatsApp Business API resmi) mengingat baru terjadi downtime akibat kebijakan WhatsApp berubah.
- ⚠️ **Fitur hapus akun** (customer & merchant) — kapan diaktifkan kembali di menu.
- ⚠️ **Order layanan jasa** (laundry/bengkel/salon) — kapan dilanjutkan pengembangannya, jangan disebut di materi marketing sebelum aktif lagi.
- ⚠️ **POS/Kasir merchant** — fitur ini kuat secara kompetitif tapi belum pernah masuk materi marketing sama sekali. Rekomendasi: jadikan salah satu poin utama di pitch ke merchant baru.
