# KUWRIR — System Overview & Design Proposal

> **Version 1.0** · 2026-06-01
> **Platform:** Food Delivery + Jasa Panggilan · Lombok, NTB, Indonesia (local courier platform, not limited to Kuta)
> **Model:** Cash on Delivery (COD) and Online Payment (Duitku gateway)
> **Note (2026-08-20):** scope corrected from the original MVP framing below — this platform now
> serves the wider Lombok community (not just Kuta), integrating local Lombok merchants, customers,
> and drivers, with online payment (Duitku) live alongside COD, not COD-only. The rest of this
> section is kept as the original MVP-era planning narrative; treat "Kuta" and "COD-only" mentions
> below as historical starting-point context, not current scope. See CLAUDE.md for current scope.

---

## 1. Executive Summary

KUWRIR adalah platform super-app berbasis mobile yang menghubungkan pelanggan, mitra merchant (restoran & jasa), dan mitra pengemudi di Lombok. Platform ini beroperasi dengan model **Cash on Delivery (COD) dan Online Payment** (Duitku gateway).

**Dua layanan utama:**

| Layanan | Deskripsi |
|---|---|
| **Pesan Makanan** | Customer memesan makanan dari restoran, driver mengantarkan, customer bayar tunai atau online |
| **Jasa Panggilan** | Customer booking laundry, bengkel, cleaning, salon — driver jemput barang/item ke tempat jasa, lalu antar kembali ke customer |

**Keunggulan kompetitif:**

- Infrastruktur peta 100% gratis (OpenStreetMap + Valhalla + Nominatim) — hemat ~Rp 330 juta/tahun vs Google Maps
- POS/Kasir terintegrasi untuk merchant — manajemen keuangan tanpa aplikasi tambahan
- Mendukung merchant food DAN jasa dalam satu platform
- Biaya server hanya ~$49/bulan untuk area Kuta, Lombok

---

## 2. Stakeholders & User Roles

```
┌─────────────────────────────────────────────────────────────┐
│                    KUWRIR ECOSYSTEM                         │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   CUSTOMER   │    │   MERCHANT   │    │    DRIVER    │  │
│  │              │    │              │    │              │  │
│  │ • Wisatawan  │    │ • Restoran   │    │ • Pengemudi  │  │
│  │ • Warga Lokal│    │ • Laundry    │    │   Motor      │  │
│  │              │    │ • Bengkel    │    │ • Terverif.  │  │
│  │ App: Customer│    │ • Salon      │    │              │  │
│  │              │    │ • Cleaning   │    │ App: Driver  │  │
│  └──────────────┘    │              │    └──────────────┘  │
│                      │ App: Merchant│                       │
│                      └──────────────┘                       │
│                                                             │
│                    ┌──────────────┐                         │
│                    │    ADMIN     │                         │
│                    │              │                         │
│                    │ • Verifikasi │                         │
│                    │ • Settlement │                         │
│                    │ • Monitoring │                         │
│                    │              │                         │
│                    │ Web: React   │                         │
│                    └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. System Architecture

```
                        ┌─────────────────────────────┐
                        │      CLIENT APPLICATIONS      │
                        │                               │
         ┌──────────────┼──────────────┬───────────────┤
         │              │              │               │
   Customer App   Driver App    Merchant App     Admin Panel
   (Flutter)      (Flutter)     (Flutter)       (React+Vite)
         │              │              │               │
         └──────────────┼──────────────┘               │
                        │ HTTPS / JWT Bearer Token      │
                        ▼                               │
              ┌─────────────────────┐                   │
              │   KUWRIR Backend    │◀──────────────────┘
              │   Go + Gin + GORM   │
              │   :8080/api/v1      │
              └────────┬────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────────┐
    │PostgreSQL│ │  Redis   │ │   Valhalla   │
    │+PostGIS  │ │  Cache   │ │  + Nominatim │
    │(Database)│ │          │ │  (Free Maps) │
    └──────────┘ └──────────┘ └──────────────┘
                                      │
                              ┌───────┴───────┐
                              │  OpenStreetMap │
                              │  (Lombok Data) │
                              └───────────────┘
```

### Technology Stack

| Layer | Technology |
|---|---|
| Backend | Go 1.22 + Gin + GORM |
| Database | PostgreSQL 16 + PostGIS 3.4 |
| Cache | Redis 7 |
| Routing | Valhalla (self-hosted, Lombok OSM) |
| Geocoding | Nominatim (self-hosted) |
| Admin Panel | React 19 + Vite + shadcn/ui + Tailwind v4 |
| Mobile Apps | Flutter 3.x (shared codebase pattern) |
| Auth | JWT HS256 + bcrypt |
| File Storage | Local disk → Cloudflare R2 (swap-ready) |
| Maps Savings | ~Rp 330 juta/tahun vs Google Maps |

---

## 4. Application Overview

### 4.1 Customer App

| Fitur | Deskripsi |
|---|---|
| **Tab Makanan** | Browse restoran terdekat, kategori makanan, rating |
| **Tab Jasa** | Browse merchant jasa per kategori (laundry/bengkel/cleaning/salon) |
| **Pesan Makanan** | Pilih item → keranjang → checkout → tracking 6 langkah |
| **Booking Jasa** | Pilih layanan → atur berat/qty → jadwal pickup → COD saat kembali |
| **Tracking** | Status real-time (food: 6 step, jasa: 8 step) |
| **Tab Pesanan** | Riwayat semua order |

### 4.2 Merchant App (Restoran & Jasa)

| Fitur | Deskripsi |
|---|---|
| **Registrasi** | 3-step: data diri → data toko → upload dokumen (KTP, foto toko) |
| **Status Verifikasi** | Polling status, notif approval/rejection + catatan admin |
| **Antrian Order Makanan** | Confirm → Preparing → Ready |
| **Antrian Order Jasa** | Confirm → In-Service → Ready for Return |
| **Manajemen Menu** | Tambah/edit/hapus kategori, produk, varian |
| **Self-Delivery** | Toggle self-delivery, set custom fee |
| **Kasir / POS** | Terminal penjualan: produk grid, cart, 4 metode bayar |
| **Laporan Keuangan** | Laba Rugi, Arus Kas, Status Stok |
| **Piutang (Tab)** | Kelola kredit pelanggan kasir |
| **Hutang Supplier** | Catat & track pembelian bahan dari supplier |

### 4.3 Driver App

| Fitur | Deskripsi |
|---|---|
| **Registrasi** | 3-step: akun → upload 5 dokumen → menunggu verifikasi |
| **Status Verifikasi** | Polling 30 detik, auto-login saat disetujui |
| **Job Board Makanan** | Lihat order tersedia, terima, pickup, deliver + COD |
| **Job Board Jasa** | Dua jenis: job jemput (customer→merchant) + job antar balik (merchant→customer) |
| **Active Job** | Step-by-step: heading → picked up → dropoff → konfirmasi COD |
| **Wallet** | COD cash balance tracker, riwayat setoran |

### 4.4 Admin Panel (Web)

| Fitur | Deskripsi |
|---|---|
| **Dashboard** | Live KPI: orders, merchants, drivers, customers, revenue, driver cash |
| **Driver Applications** | Review pendaftaran driver + preview 5 foto dokumen, approve/reject |
| **Merchants** | Approve/reject pendaftaran, suspend, detail view |
| **Drivers** | Suspend, catat setoran COD, riwayat deposit |
| **Customers** | Suspend/activate user |
| **Orders** | Monitor semua order dengan status filter |
| **Settlements** | Per-merchant payout, Mark as Paid, riwayat settlement |
| **Promotions** | Full CRUD promo code (%, nominal, gratis ongkir) |
| **Settings** | Configurable fees tanpa update app |

---

## 5. Financial Model (COD)

### 5.1 Food Order

```
CUSTOMER MEMBAYAR:
  Harga Makanan (base)        IDR 50,000
  + Markup Platform (15%)     IDR  7,500
  + Ongkos Kirim              IDR 15,000
  ─────────────────────────────────────
  Total COD ke Driver         IDR 72,500

DISTRIBUSI:
  → Merchant terima           IDR 50,000  (harga dasar)
  → Driver dapat              IDR 11,250  (75% ongkir)
  → KUWRIR revenue            IDR 11,250  (markup + 25% ongkir)
```

### 5.2 Service (Jasa) Order

```
CUSTOMER MEMBAYAR (saat barang dikembalikan):
  Harga Jasa (base, e.g. laundry 4kg × 8.000)  IDR 32,000
  + Markup Platform (15%)                        IDR  4,800
  + Ongkir Pulang-Pergi (flat)                   IDR 20,000
  ─────────────────────────────────────────────────────────
  Total COD ke Driver                            IDR 56,800

DISTRIBUSI:
  → Merchant terima           IDR 32,000  (harga dasar jasa)
  → Driver dapat              IDR 15,000  (75% ongkir PP)
  → KUWRIR revenue            IDR  9,800  (markup + 25% ongkir)
```

### 5.3 POS / Kasir (Walk-in)

```
Untuk pelanggan yang datang langsung ke merchant:
  → Tidak ada markup platform
  → Tidak ada ongkir
  → 100% uang masuk ke merchant
  → KUWRIR tidak mengambil komisi dari transaksi walk-in
  
Merchant mendapat fitur gratis:
  → Manajemen stok (TrackStock per produk)
  → Laporan Laba Rugi, Arus Kas
  → Piutang / tab pelanggan
  → Hutang supplier
```

### 5.4 COD Cash Flow

```
                     ┌─────────────────────────────────┐
                     │        CASH FLOW SIKLUS          │
                     └─────────────────────────────────┘

Customer ──────(bayar cash)──────▶ Driver (kumpulkan)
                                      │
              ┌───────────────────────┤ (akhir shift)
              │                       │
              ▼                       ▼
        Driver Simpan            Driver Setor ke Admin
        (earning-nya)            (lewat bank/cash)
                                       │
              ┌────────────────────────┤
              │                        │
              ▼                        ▼
       KUWRIR Revenue            Merchant Settlement
       (markup + komisi)         (monthly transfer)
```

---

## 6. Payment System — Rules, Flows & Schemes

Bagian ini menjelaskan secara lengkap aturan pembayaran untuk setiap pihak (Customer, Merchant, Driver, Admin) dalam dua skenario: **COD (MVP saat ini)** dan **Payment Gateway (rencana Phase 8)**.

---

### 6.1 Aturan Pembayaran per Role

#### Customer — Hak & Kewajiban

| Kondisi | Aturan |
|---|---|
| **Food order COD** | Bayar tunai kepada driver saat makanan diterima di depan pintu. Nominal = harga makanan (dengan markup) + ongkir. |
| **Service (Jasa) order COD** | Bayar tunai kepada driver **saat barang dikembalikan** (returned). Bukan saat pickup. Jika jasa belum selesai, customer tidak dikenakan biaya. |
| **POS / Walk-in Cash** | Bayar tunai langsung ke kasir merchant. KUWRIR tidak mengambil komisi. |
| **POS / Walk-in QRIS & Kartu** | Bayar via QRIS atau kartu di kasir merchant (fase future). |
| **POS Tab (Kredit)** | Customer bisa bayar nanti ke merchant. Dicatat sebagai piutang merchant. KUWRIR tidak terlibat. |
| **Pembatalan order** | Jika dibatalkan saat `pending` — tidak ada biaya. Setelah confirmed — kebijakan cancellation fee ditentukan merchant (fitur future). |
| **Promo Code** | Diskon diterapkan sebelum checkout. Mengurangi total yang dibayarkan customer. |
| **Pembayaran lebih / kembalian** | Untuk COD: driver wajib memberikan kembalian. Nominal kembalian dihitung di app. |

---

#### Driver — Hak & Kewajiban

| Kondisi | Aturan |
|---|---|
| **Terima COD** | Driver menerima **full nominal COD** dari customer (makanan + ongkir + markup). |
| **Simpan earning** | Driver berhak menyimpan bagiannya: **75% dari ongkir**. Contoh: ongkir Rp 15.000 → driver dapat Rp 11.250. |
| **Hutang ke platform** | Sisa COD setelah earning adalah **hutang driver ke KUWRIR**: harga dasar merchant + 25% ongkir + markup food. Contoh: Rp 72.500 - Rp 11.250 = **Rp 61.250 harus disetor**. |
| **Batas waktu setor** | Driver wajib menyetor saldo COD ke admin **maksimal akhir shift hari kerja**. (Kebijakan: setiap hari atau saat saldo ≥ Rp 500.000 — dikonfigurasi admin). |
| **Metode setor** | Transfer bank ke rekening KUWRIR, atau setor tunai langsung di kantor. Admin menginput konfirmasi di panel. |
| **Service order (Jasa)** | Sama seperti food. COD dikumpulkan saat **leg 2** (antar balik ke customer). Jika leg 1 dan leg 2 diambil driver berbeda, **hanya driver leg 2** yang menerima COD dan wajib menyetor. |
| **Pemblokiran** | Jika `cash_balance` melebihi batas yang ditentukan admin, driver dapat diblokir dari menerima order baru (fitur future). |
| **Tidak ada advance** | Driver tidak mendapatkan pembayaran di muka. Earning direalisasi dari saldo COD yang dikumpulkan. |

**Contoh Akuntansi Driver per Hari:**
```
Order 1 — Food:
  COD Diterima         Rp  72,500
  Earning Driver       Rp  11,250  (simpan)
  Wajib Disetor        Rp  61,250

Order 2 — Food:
  COD Diterima         Rp  45,000
  Earning Driver       Rp   9,375
  Wajib Disetor        Rp  35,625

Order 3 — Jasa Laundry:
  COD Diterima         Rp  56,800
  Earning Driver       Rp  15,000
  Wajib Disetor        Rp  41,800

─────────────────────────────────────
Total COD Diterima     Rp 174,300
Total Earning Driver   Rp  35,625  (disimpan)
Total Wajib Disetor    Rp 138,675  (ke KUWRIR hari ini)
```

---

#### Merchant — Hak & Kewajiban

| Kondisi | Aturan |
|---|---|
| **Harga yang diterima** | Merchant menerima **harga dasar** yang mereka tetapkan sendiri. Markup 15% dibayar oleh customer, bukan diambil dari merchant. |
| **Kapan menerima uang** | Pembayaran dari KUWRIR dilakukan secara **bulanan** (atau sesuai periode yang disepakati). Bukan per transaksi. |
| **Cara menerima** | Transfer bank dari KUWRIR ke rekening merchant yang didaftarkan saat verifikasi. |
| **Yang dihitung** | `SUM(base_product_price)` dari semua order dengan status `delivered`/`returned` dalam periode tersebut. Ongkir dan markup tidak termasuk karena sudah ditangani KUWRIR. |
| **Self-delivery** | Jika merchant menggunakan self-delivery, **tidak ada delivery commission** yang dipotong. Merchant menerima: harga dasar + fee self-delivery yang mereka tetapkan sendiri. |
| **POS Walk-in** | Uang masuk 100% ke merchant — tidak ada potongan KUWRIR. Merchant bertanggung jawab penuh atas manajemen kas POS-nya. |
| **Biaya platform** | Merchant tidak membayar biaya platform di muka. Revenue KUWRIR diambil dari markup yang sudah dimasukkan ke harga customer. |
| **Dispute** | Jika ada order yang bermasalah, merchant dapat mengajukan sengketa melalui admin sebelum settlement diproses. |

**Contoh Laporan Settlement Bulanan Merchant:**
```
Periode: 1–30 Juni 2026
Merchant: Warung Ayam Pak Made

Order completed:        47 order
Total base food price:  Rp 2,350,000

Settlement dibayar:     Rp 2,350,000 (transfer BCA)
Referensi:              TRF-BCA-20260701-001
Status:                 PAID ✓
```

---

#### Admin KUWRIR — Hak & Kewajiban

| Tanggung Jawab | Detail |
|---|---|
| **Verifikasi deposit driver** | Admin mengkonfirmasi setiap setoran driver (manual atau bukti transfer). Saldo driver berkurang setelah konfirmasi. |
| **Menghitung settlement** | Admin memilih merchant + periode → sistem hitung otomatis total order completed → buat settlement record. |
| **Transfer ke merchant** | Admin melakukan transfer bank ke merchant, lalu klik "Mark as Paid" di panel untuk menutup settlement. |
| **Menyimpan revenue** | Revenue KUWRIR = semua COD yang diterima driver − earning driver − bagian merchant. Tidak perlu jurnal manual — sudah tercatat di `Order.platform_markup` + `Order.delivery_commission`. |
| **Konfigurasi fee** | Admin dapat mengubah markup %, komisi ongkir %, dan tarif ongkir di `Settings` tanpa update app. Perubahan berlaku untuk order baru saja. |
| **Rekonsiliasi** | Admin dapat melihat saldo driver yang masih outstanding di dashboard (`pending_driver_cash`). |
| **Audit trail** | Setiap deposit dan settlement dicatat permanen dengan timestamp, ID admin yang memproses, dan referensi transfer. |

---

### 6.2 COD Flow — Diagram Lengkap

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FOOD ORDER — COD FULL FLOW                       │
└─────────────────────────────────────────────────────────────────────┘

Customer                Driver                  KUWRIR Admin          Merchant
    │                      │                         │                    │
    │  Pesan makanan        │                         │                    │
    │  Total: Rp 72.500     │                         │                    │
    │──────────────────────▶│ (order assigned)        │                    │
    │                       │                         │                    │
    │                       │──── jemput makanan ────▶│                   [merchant]
    │                       │                         │                    │
    │                       │◀─── terima makanan ────[merchant]            │
    │                       │                         │                    │
    │◀── driver datang ─────│                         │                    │
    │                       │                         │                    │
    │── bayar Rp 72.500 ───▶│  [COD collected]        │                    │
    │   (tunai, di pintu)   │                         │                    │
    │                       │                         │                    │
    │                       │  Driver simpan:         │                    │
    │                       │  Rp 11.250 (earning)    │                    │
    │                       │                         │                    │
    │                       │── setor Rp 61.250 ─────▶│                    │
    │                       │  (akhir shift)          │                    │
    │                       │                         │  Admin konfirmasi   │
    │                       │                         │  driver.cash_balance│
    │                       │                         │  berkurang          │
    │                       │                         │                    │
    │                       │                         │  KUWRIR simpan:     │
    │                       │                         │  Rp 11.250 (markup │
    │                       │                         │  + komisi ongkir)   │
    │                       │                         │                    │
    │                       │                         │── transfer ────────▶│
    │                       │                         │  Rp 50.000          │
    │                       │                         │  (settlement)       │
    │                       │                         │                    │
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                  SERVICE ORDER — COD FULL FLOW (2 LEG)              │
└─────────────────────────────────────────────────────────────────────┘

Customer          Driver Leg 1      Merchant (Jasa)    Driver Leg 2
    │                  │                  │                  │
    │  Booking laundry  │                  │                  │
    │  Rp 56.800 COD    │                  │                  │
    │──────────────────▶│  [leg 1 assigned]│                  │
    │                   │                  │                  │
    │◀── driver menuju ─│                  │                  │
    │                   │                  │                  │
    │── serahkan baju ─▶│                  │                  │
    │   (belum bayar)   │                  │                  │
    │                   │── antar baju ───▶│                  │
    │                   │                  │                  │
    │                   │     [laundry     │                  │
    │                   │      proses      │                  │
    │                   │      1-2 hari]   │                  │
    │                   │                  │── ready ─────────│
    │                   │                  │                  │── [leg 2 assigned]
    │                   │                  │                  │
    │                   │                  │◀── ambil baju ───│
    │                   │                  │                  │
    │◀────────────────────────── driver datang ───────────────│
    │                   │                  │                  │
    │── bayar Rp 56.800 ──────────────────────────────────── ▶│
    │   (COD saat terima│                  │                  │  COD collected
    │    baju bersih)   │                  │                  │
    │                   │                  │    Driver simpan  │
    │                   │                  │    Rp 15.000      │
    │                   │                  │    (earning)      │
    │                   │                  │                  │
    │                   │                  │  Setor Rp 41.800 ─▶ [Admin]
    │                   │                  │                   │
    │                   │                  │  Admin → transfer Rp 32.000 ke merchant
```

---

### 6.3 Aturan Khusus: Edge Cases COD

| Skenario | Penanganan |
|---|---|
| **Customer tidak ada di rumah** | Driver tunggu maksimal 10 menit, foto bukti kedatangan, laporkan ke admin. Order tetap dihitung delivered jika bukti cukup. |
| **Customer tidak punya uang pas** | Driver wajib siapkan kembalian. Jika customer tidak bisa bayar → driver laporkan ke admin, order ditandai payment_issue (fitur future). |
| **Driver kehilangan uang COD** | Driver tetap bertanggung jawab atas saldo COD. Harus disetor sesuai jumlah order yang completed, bukan jumlah uang yang dipegang. |
| **Order dibatalkan setelah driver pickup** | COD tidak terjadi. Driver kembali ke merchant. Biaya kerugian diputuskan admin case-by-case. |
| **Merchant tidak siap saat driver datang (food)** | Driver menunggu maksimal 15 menit lalu lapor. Admin dapat reschedule atau assign driver lain. |
| **Service: barang rusak di merchant** | Diselesaikan antara merchant dan customer. KUWRIR bertindak sebagai mediator jika dibutuhkan. Pembayaran di-hold hingga resolved. |

---

### 6.4 Payment Gateway — Skema Implementasi (Phase 8)

Ketika payment gateway diintegrasikan (rencana menggunakan **Xendit** atau **Midtrans**), alur pembayaran berubah fundamental. Platform tidak lagi bergantung pada cash flow driver.

#### Metode Pembayaran Digital yang Didukung

| Metode | Provider | Tipe |
|---|---|---|
| QRIS (scan QR) | Semua e-wallet + bank | Real-time |
| GoPay / OVO / Dana | via QRIS atau direct | E-wallet |
| Transfer Bank (VA) | BCA, BNI, Mandiri, BRI | Virtual Account |
| Kartu Debit / Kredit | Visa, Mastercard | Card |
| ShopeePay | Shopee | E-wallet |
| Paylater (BNPL) | Kredivo, Akulaku | Cicilan |

#### Flow Pembayaran Digital — Food Order

```
┌─────────────────────────────────────────────────────────────────────┐
│              FOOD ORDER — PAYMENT GATEWAY FLOW                      │
└─────────────────────────────────────────────────────────────────────┘

Customer App          KUWRIR Backend        Xendit/Midtrans       Merchant
    │                      │                      │                  │
    │  Pilih QRIS/VA/Card  │                      │                  │
    │  di checkout screen  │                      │                  │
    │──────────────────────▶│                      │                  │
    │                       │── create invoice ───▶│                  │
    │                       │◀── payment URL/QR ───│                  │
    │◀──── tampilkan QR ────│                      │                  │
    │                       │                      │                  │
    │── scan & bayar ───────────────────────────── ▶│                 │
    │                       │                      │  payment received│
    │                       │◀── webhook callback ─│                  │
    │                       │   (payment_success)   │                  │
    │                       │                      │                  │
    │                       │── update order       │                  │
    │                       │   payment_status=paid│                  │
    │◀── konfirmasi order ──│                      │                  │
    │                       │──────────────────────────────────────── ▶│
    │                       │   (notify merchant)  │                  │
    │                       │                      │                  │
                        [Driver pickup & deliver — tanpa terima COD]
    │                       │                      │                  │
    │◀── delivered ─────────│                      │                  │
    │                       │                      │                  │
    │                       │── auto disburse ────▶│                  │
    │                       │                      │── transfer ──── ▶│
    │                       │                      │   merchant share │
    │                       │                      │── transfer ──── ▶│ Driver
    │                       │                      │   driver earning  │ (earning)
    │                       │   KUWRIR keeps:       │                  │
    │                       │   markup + komisi    │                  │
```

#### Perbedaan COD vs Payment Gateway

| Aspek | COD (MVP) | Payment Gateway (Phase 8) |
|---|---|---|
| **Waktu bayar** | Setelah menerima barang | Di awal saat checkout |
| **Siapa terima uang** | Driver (cash) | Payment gateway (digital) |
| **Risiko tidak bayar** | Ada (customer kabur) | Tidak ada (pre-paid) |
| **Risiko driver** | Pegang cash, bisa hilang | Tidak pegang uang sama sekali |
| **Settlement merchant** | Bulanan manual (admin) | Otomatis setelah deliver |
| **Driver earning** | Ambil dari saldo COD | Transfer langsung dari gateway |
| **Biaya tambahan** | Tidak ada | MDR gateway ~0.7%–2.9% |
| **Refund** | Manual (admin decide) | Otomatis via gateway API |
| **Kompleksitas operasional** | Tinggi (deposit, reconcile) | Rendah (otomatis) |
| **Kesiapan customer** | Semua (tidak butuh rekening) | Butuh e-wallet/kartu |

#### Arsitektur Payment Gateway (Hybrid COD + Digital)

```
┌─────────────────────────────────────────────────────────────────────┐
│              HYBRID PAYMENT ARCHITECTURE (Phase 8)                  │
└─────────────────────────────────────────────────────────────────────┘

Customer memilih saat checkout:

┌─────────┐    ┌─────────────────────────────────────────────────┐
│ Checkout│    │             PILIH METODE BAYAR                  │
│  Screen │    │                                                  │
│         │───▶│  ○ COD (Bayar saat terima)         [tersedia]   │
│         │    │  ● QRIS (Scan QR sekarang)          [tersedia]   │
│         │    │  ○ Transfer Bank (Virtual Account)  [tersedia]   │
│         │    │  ○ Kartu Debit/Kredit                [tersedia]   │
│         │    │  ○ GoPay / OVO / Dana               [tersedia]   │
└─────────┘    └──────────────────┬──────────────────────────────┘
                                  │
               ┌──────────────────┼──────────────────┐
               │                  │                  │
          [COD path]        [QRIS path]        [VA path]
               │                  │                  │
               ▼                  ▼                  ▼
          Order dibuat      Xendit create       Xendit create
          payment_type      QR code             Virtual Account
          = "cash"          (expired 15 mnt)    (expired 24 jam)
               │                  │                  │
               │             Customer scan       Customer transfer
               │             & bayar             ke nomor VA
               │                  │                  │
               │            Xendit webhook       Xendit webhook
               │            payment_success      payment_success
               │                  │                  │
               └──────────────────┴──────────────────┘
                                  │
                         Order payment_status = PAID
                         Order diproses ke merchant
```

#### Disbursement (Pencairan) dengan Payment Gateway

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AUTO DISBURSEMENT FLOW                           │
└─────────────────────────────────────────────────────────────────────┘

Setelah order status = DELIVERED:

Order Total: Rp 72,500
│
├── Platform Markup (Rp 7,500) ────────────────────▶ KUWRIR Account
│
├── Delivery Commission 25% (Rp 3,750) ────────────▶ KUWRIR Account
│
├── Driver Earning 75% ongkir (Rp 11,250) ─────────▶ Driver Wallet/Bank
│   (via Xendit disbursement API)
│
└── Merchant Base Price (Rp 50,000) ───────────────▶ Merchant Bank
    (via Xendit disbursement API, atau batch harian)

Total ke KUWRIR:   Rp 11,250 (otomatis, real-time)
Total ke Driver:   Rp 11,250 (otomatis, real-time atau batch)
Total ke Merchant: Rp 50,000 (otomatis atau batch harian)
```

#### Implementasi di Backend (API Changes untuk Phase 8)

```go
// Order model: tambah fields untuk digital payment
PaymentMethod   string  // "cash" | "qris" | "va_bca" | "gopay" | "card"
PaymentStatus   string  // "pending" | "paid" | "failed" | "refunded"
PaymentRef      string  // Xendit payment ID / reference number
PaymentExpiredAt *time.Time

// Endpoint baru:
POST /orders/create-payment          // Buat payment intent ke Xendit
POST /webhooks/xendit/payment        // Terima webhook payment success
POST /webhooks/xendit/disbursement   // Terima webhook disbursement result
POST /orders/:id/refund              // Trigger refund via Xendit (admin only)
GET  /driver/wallet/balance          // Saldo driver wallet (digital earning)
POST /driver/wallet/withdraw         // Driver request withdrawal ke rekening
```

#### Fee Structure dengan Payment Gateway

```
Biaya yang muncul saat menggunakan payment gateway:

Per transaksi digital:
  MDR QRIS:          0.70% dari total
  MDR Kartu Kredit:  2.90% dari total
  Transfer VA:       Rp 4,000 flat per transaksi
  E-wallet (GoPay):  ~1.50% dari total

Siapa yang menanggung?
  Option A: KUWRIR tanggung (potong dari revenue)
  Option B: Customer tanggung (tambah payment fee)
  Option C: Hybrid (QRIS ditanggung KUWRIR, kartu oleh customer)

Rekomendasi MVP Phase 8:
  → QRIS: KUWRIR tanggung (cost sangat rendah, UX bagus)
  → Kartu: Customer tanggung (fee tinggi, adil)
  → VA: KUWRIR tanggung (flat fee, prediktable)
```

#### Refund Policy

| Skenario | COD | Payment Gateway |
|---|---|---|
| **Cancel saat pending** | Tidak ada uang yang berpindah | Refund otomatis 100% |
| **Cancel setelah confirmed** | Merchant dikompensasi jika sudah masak | Refund customer dikurangi merchant compensation |
| **Makanan tidak sesuai** | Admin mediasi, bisa partial refund manual | Partial refund via Xendit API |
| **Tidak diterima / hilang** | Admin investigasi | Full refund otomatis setelah bukti verifikasi |
| **Service: barang rusak** | Merchant tanggung (asuransi ke depan) | Refund partial, diselesaikan merchant + admin |
| **Timeline refund** | 1–7 hari kerja (manual) | 1–3 hari kerja (otomatis gateway) |

---

### 6.5 Roadmap Pembayaran

```
Phase MVP (Sekarang):
├── ✅ COD — Food order
├── ✅ COD — Service (Jasa) order
├── ✅ Cash/QRIS/Kartu — POS Walk-in (merchant input manual)
└── ✅ Tab (Kredit) — POS Walk-in

Phase 8 (Rencana):
├── ⬜ QRIS dinamis via Xendit/Midtrans
├── ⬜ Virtual Account (BCA, BNI, Mandiri, BRI)
├── ⬜ E-wallet direct (GoPay, OVO, Dana)
├── ⬜ Auto-disbursement ke driver dan merchant
├── ⬜ Driver wallet digital (earning langsung ke wallet)
└── ⬜ Refund system

Phase 9 (Future):
├── ⬜ Paylater / BNPL (Kredivo, Akulaku)
├── ⬜ Subscription merchant (tagihan bulanan)
├── ⬜ Loyalty points / cashback
└── ⬜ Split bill (customer bayar sebagian, sisanya COD)
```

---

## 7. Registration & Verification Flow

### 6.1 Customer Registration

```
Download App
     │
     ▼
Isi Form: Nama, No HP, Email, Password
     │
     ▼
POST /auth/register (role=customer)
     │
     ▼
Akun AKTIF langsung ✓
     │
     ▼
Bisa pesan makanan / booking jasa
```

### 6.2 Driver Registration & Verification

```
Download Driver App
     │
     ▼
Step 1 — Data Akun
  Nama, No HP, Email, Password
     │
     ▼
POST /auth/register (role=driver)
  → is_active = FALSE (belum bisa login operasional)
     │
     ▼
Step 2 — Upload Dokumen (multipart)
  ┌─────────────────────────────┐
  │ 1. Foto KTP                 │
  │ 2. Foto SIM C/A             │
  │ 3. Foto STNK                │
  │ 4. Selfie + KTP             │
  │ 5. Foto Kendaraan           │
  │ + Data: jenis/plat/tahun/   │
  │         warna/merek         │
  └─────────────────────────────┘
     │
     ▼
POST /driver/apply
  → DriverApplication dibuat (status=pending)
     │
     ▼
Step 3 — Menunggu Verifikasi
  (polling GET /driver/application setiap 30 detik)
     │
     ├─── Admin APPROVE ──▶ is_active=TRUE, Driver record dibuat
     │                        → Auto-navigate ke Job Board ✓
     │
     └─── Admin REJECT  ──▶ Tampilkan catatan, bisa upload ulang
```

### 6.3 Merchant Registration & Verification

```
Download Merchant App
     │
     ▼
Step 1 — Data Pemilik
  Nama, No HP, Email, Password
     │
     ▼
POST /auth/register (role=merchant)
  → is_active = FALSE
     │
     ▼
Step 2 — Data Toko
  Nama toko, Deskripsi, Alamat, Koordinat GPS
     │
     ▼
Step 3 — Upload Dokumen
  ┌──────────────────────────────┐
  │ 1. Foto KTP Pemilik (wajib)  │
  │ 2. Izin Usaha SIUP/IUMK      │
  │    (opsional untuk MVP)      │
  │ 3. Foto Toko (wajib)         │
  └──────────────────────────────┘
     │
     ▼
POST /my-store
  → Merchant dibuat (verification_status=pending, is_active=false)
     │
     ▼
Menunggu Verifikasi Admin
  (polling GET /my-store/status setiap 30 detik)
     │
     ├─── Admin APPROVE ──▶ is_verified=TRUE, is_active=TRUE
     │                        → Merchant bisa mulai buka toko ✓
     │
     └─── Admin REJECT  ──▶ Tampilkan catatan, bisa daftar ulang
```

---

## 8. Order Flow Design

### 7.1 Food Delivery Order Flow

```
CUSTOMER                  BACKEND                MERCHANT              DRIVER
    │                        │                      │                    │
    │── POST /orders ────────▶│                      │                    │
    │                        │── notify merchant ──▶│                    │
    │                        │   (pending)           │                    │
    │                        │                      │── confirm ─────────▶│
    │                        │◀── confirmed ─────────│                    │
    │                        │                      │── preparing ───────▶│
    │                        │◀── preparing ─────────│                    │
    │                        │                      │── ready ───────────▶│
    │                        │◀── ready ─────────────│                    │
    │                        │                      │                    │
    │                        │── find nearby driver ▶│                    │
    │                        │                                           │
    │                        │── accept delivery ──────────────────────▶│
    │                        │◀──────────────────────── picked_up ───────│
    │                        │                                           │
    │◀─── live tracking ─────│◀────────── GPS updates ────────────────── │
    │                        │                                           │
    │                        │◀──────────────────────── delivered ───────│
    │                        │                      │                    │
    │◀─── receipt ───────────│                      │                    │
                             │── update driver.cash_balance ────────────▶│
```

### 7.2 Service (Jasa) Order Flow — 2 Driver Legs

```
CUSTOMER          BACKEND            MERCHANT           DRIVER LEG 1       DRIVER LEG 2
    │                │                  │                    │                   │
    │─ POST          │                  │                    │                   │
    │  /service- ──▶│                  │                    │                   │
    │  orders        │─ notify ────────▶│                    │                   │
    │                │  (pending)       │─ confirm ─────────▶│                   │
    │                │◀─ confirmed ─────│  (awaiting_pickup)  │                   │
    │                │                  │                    │                   │
    │                │─ find driver ────────────────────────▶│                   │
    │                │◀──────────────── accept-pickup ───────│                   │
    │                │                  │                    │                   │
    │                │              [driver goes to customer address]             │
    │                │                  │                    │                   │
    │ ◀─ driver coming│                  │                    │                   │
    │                │                  │                    │─ item-picked-up ▶│ │
    │                │              [driver takes items to merchant]              │
    │                │                  │◀─────────────── at merchant ──────────│ │
    │                │                  │─ in-service ─────▶│                   │
    │                │              [merchant performs service]                   │
    │                │                  │─ ready ──────────▶│                   │
    │                │                  │  (ready_for_return)│                   │
    │                │─ find driver (return leg) ──────────────────────────────▶│
    │                │◀────────────────────────────────── accept-return ────────│
    │                │              [driver picks up from merchant, goes to customer]
    │                │◀────────────────────────────────── returning ────────────│
    │                │              [driver arrives at customer]                  │
    │ ─ pays COD ──▶ │                  │                    │                   │
    │                │◀────────────────────────────────── returned ──────────── │
    │                │─ update cash_balance ──────────────────────────────────▶│
    │ ◀─ receipt ─── │                  │                    │                   │
```

### 7.3 POS / Kasir Transaction Flow

```
                    MERCHANT (Kasir Mode)
                           │
                    Buka Kasir Screen
                           │
                    ┌──────┴──────┐
                    │             │
             Product Grid       Keranjang
             (kategori,          (qty +/-,
              search,             HPP real-time,
              stok badge)         gross profit)
                    │             │
                    └──────┬──────┘
                           │
                    Pilih Metode Bayar
                    ┌──────┬──────┬──────┐
                    │      │      │      │
                  Cash   QRIS   Kartu   Tab
                    │      │      │    (piutang
                    │      │      │   auto-create)
                    └──────┴──────┘
                           │
                    Konfirmasi Dialog
                    (breakdown: subtotal,
                     HPP, laba kotor,
                     kembalian jika cash)
                           │
                    Transaksi Dicatat
                    ┌──────┴──────┐
                    │             │
               Stok berkurang  Jurnal dicatat
               (jika trackStock) (untuk laporan)
                    │
                    Struk / Nomor POS
```

---

## 9. Admin Verification Flow

### 8.1 Driver Application Review

```
ADMIN PANEL — Driver Applications Page
            │
      List Antrian Pending
      ┌─────────────────────────────────────────┐
      │ Driver Name    | Kendaraan | Dokumen  |  │
      │ Budi Santoso   | DR1234AB  | ✓✓✓✓✓   | [👁] [✓] [✗] │
      │ Made Suardana  | DK5678CD  | ✓✓✓✗✓   | [👁] [✓] [✗] │
      └─────────────────────────────────────────┘
            │
      Klik Detail (👁)
            │
      ┌─────────────────────────────────────────┐
      │ REVIEW DIALOG                            │
      │ Nama: Budi Santoso · HP: 0812-xxx        │
      │ Motor: Yamaha NMAX, DR1234AB, 2022       │
      │                                          │
      │ [KTP foto]  [SIM foto]  [STNK foto]      │
      │ [Selfie+KTP foto]  [Kendaraan foto]      │
      │                                          │
      │ Catatan: ________________________        │
      │                                          │
      │ [Tolak]              [Setujui]           │
      └─────────────────────────────────────────┘
            │
      ┌─────┴─────┐
      │           │
   SETUJUI       TOLAK
      │           │
  is_active=TRUE  Status=rejected
  Driver record   + catatan terkirim
  dibuat          ke driver app
```

### 8.2 Settlement Flow

```
ADMIN PANEL — Settlements Page
            │
      Tab: "Payout ke Merchant"
      ┌─────────────────────────────────────────┐
      │ Merchant         | Orders | Amount       │
      │ Warung Pak Made  |   47   | Rp 2.350.000 │ [Proses Payout]
      │ Laundry Kilat    |   23   | Rp 1.150.000 │ [Proses Payout]
      └─────────────────────────────────────────┘
            │
      Klik "Proses Payout"
            │
      ┌─────────────────────────────────────────┐
      │ Periode: 01/06/2026 — 30/06/2026         │
      │ Total orders: 47                          │
      │ Total transfer ke merchant: Rp 2.350.000  │
      │ Referensi: TRF-BCA-20260701-001           │
      │ [Buat Settlement]                         │
      └─────────────────────────────────────────┘
            │
      Settlement record dibuat (status=pending)
            │
      (setelah transfer bank dilakukan)
            │
      Klik "Mark as Paid" → status=paid
```

---

## 10. POS/Kasir Financial Reports

Terinspirasi dari fitur akuntansi `finansial-mac`:

### 9.1 Laporan Laba Rugi (P&L)

```
Periode: 01-30 Juni 2026

Pendapatan Penjualan            Rp  4,750,000
(-) HPP / Harga Pokok           Rp  2,180,000
─────────────────────────────────────────────
Laba Kotor                      Rp  2,570,000   (54.1%)
(-) Beban Operasional           Rp    850,000
─────────────────────────────────────────────
Laba Bersih                     Rp  1,720,000   (36.2%)
```

### 9.2 Laporan Arus Kas

```
Kas Masuk:
  + Penjualan Tunai/QRIS/Kartu  Rp  4,100,000
  + Piutang Terbayar            Rp    180,000
                                ─────────────
  Total Masuk                   Rp  4,280,000

Kas Keluar:
  - Bayar Hutang Supplier       Rp    650,000
                                ─────────────
Arus Kas Bersih                 Rp  3,630,000
```

---

## 11. Merchant Type Comparison

| Aspek | Food Merchant | Service Merchant |
|---|---|---|
| **Order Type** | Ecommerce | Service (2-leg) |
| **Driver Trips** | 1 (merchant → customer) | 2 (customer → merchant, merchant → customer) |
| **COD Timing** | Saat makanan diterima | Saat barang dikembalikan |
| **Ongkir Model** | Per-km / zona | Flat round-trip |
| **Produk Satuan** | per_item | per_kg / per_item / per_service / per_hour |
| **POS/Kasir** | ✓ (walk-in) | ✓ (walk-in juga) |
| **Self-Delivery** | ✓ (optional) | ✗ (selalu via driver) |
| **Contoh** | Restoran, Warung | Laundry, Bengkel, Salon, Cleaning |

---

## 12. Technology: Free Map Stack

Penghematan ~Rp 330 juta per tahun dengan stack maps open-source:

| Kebutuhan | Solusi Berbayar | Solusi KUWRIR | Hemat/tahun |
|---|---|---|---|
| Tampilan peta | Google Maps SDK ($7/1000 loads) | MapLibre GL + OpenStreetMap | ~$2,500 |
| Routing / ETA | Google Directions API ($10/1000 req) | Valhalla (self-hosted, Lombok OSM) | ~$15,000 |
| Geocoding | Google Geocoding API ($5/1000 req) | Nominatim (self-hosted) | ~$5,000 |
| **Total** | | | **~$22,500/tahun** |

**Mengapa Valhalla vs OSRM?**
Valhalla mendukung profil kendaraan motor/skuter, routing bergantung waktu, dan navigasi turn-by-turn — semuanya penting untuk driver di Lombok.

---

## 13. Production Deployment (Option A — Single VPS)

Untuk MVP di Kuta, Lombok, semua service bisa berjalan di satu VPS karena:
- Data OSM Lombok sangat kecil → Valhalla hanya butuh ~1GB RAM
- Load awal terbatas pada area Kuta

```
┌─────────────────────────────────────────────────────┐
│          VPS: 4 vCPU, 8GB RAM, 100GB SSD            │
│          ~$48/bulan (DigitalOcean/Hetzner)           │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │              Docker Compose                   │   │
│  │                                               │   │
│  │  Go API (:8080)   PostgreSQL+PostGIS (:5432) │   │
│  │  Redis (:6379)    Valhalla (:8002)            │   │
│  │  Nominatim (:8003)                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Admin Panel (Nginx static)                          │
│  Cloudflare R2 (external — image storage)            │
└─────────────────────────────────────────────────────┘

Total infrastruktur: ~$49/bulan
```

---

## 14. Development Phases

| Phase | Status | Deliverables |
|---|---|---|
| **Phase 1** | ✅ Complete | Backend scaffold, Auth, Docker infra, Flutter scaffolds |
| **Phase 2** | ✅ Complete | Restaurant & Menu CRUD |
| **Phase 3** | ✅ Complete | Cart, Food Orders, COD Pricing Engine |
| **Phase 4** | ✅ Complete | Driver App, Order Fulfillment, Self-Delivery |
| **Phase 5** | ✅ Complete | Admin Panel Integration |
| **Phase 6a** | ✅ Complete | POS/Kasir + Financial Integration (finansial-mac inspired) |
| **Phase 6b** | ✅ Complete | Admin Panel full completion (live KPI, deposits, settlements, promos) |
| **Phase 6c** | ✅ Complete | Driver & Merchant Registration + Verification + Document Upload |
| **Phase 6d** | ✅ Complete | Service (Jasa) Orders — Laundry, Bengkel, Salon, Cleaning |
| **Phase 7** | ⬜ Planned | WebSocket real-time tracking, Push Notifications (Firebase) |
| **Phase 8** | ⬜ Planned | Image Upload → Cloudflare R2, QRIS/Digital Payments (Xendit) |
| **Phase 9** | ⬜ Planned | Reviews & Ratings, Promo Engine, Customer Loyalty |

---

## 15. API Endpoint Summary

**Total endpoints: 60+**

| Category | Count |
|---|---|
| Auth | 2 |
| Public (browse merchants/services) | 7 |
| Customer (food + service orders) | 8 |
| Merchant (store, menu, orders, POS) | 31 |
| Driver (food + service deliveries) | 11 |
| Admin (dashboard, users, settlements, promos) | 21 |

---

## 16. Data Model Summary

**22+ database tables across 4 domains:**

| Domain | Models |
|---|---|
| **Users & Auth** | User, Address, DriverApplication |
| **Merchants & Products** | Merchant, ProductCategory, Product, ProductVariant |
| **Orders** | Order, OrderItem, Review |
| **Drivers & Logistics** | Driver, DriverDeposit |
| **Financials** | MerchantSettlement, Promotion, SystemSetting |
| **POS/Kasir** | StockMovement, PosTransaction, PosTransactionItem, MerchantReceivable, MerchantReceivablePayment, MerchantPayable, MerchantPayablePayment |

---

## 17. Security

| Concern | Implementation |
|---|---|
| Password Hashing | bcrypt (cost factor 10) |
| Authentication | JWT HS256, access + refresh tokens |
| Authorization | Role-based middleware (customer, merchant, driver, admin) |
| Data Isolation | Users can only access their own data (user_id scoping) |
| File Upload | Extension whitelist (.jpg, .jpeg, .png, .webp, .pdf), max 20MB |
| CORS | Configured per environment |
| Account Control | Admin can suspend/activate any user |
| Verification | Driver & Merchant must be approved before accessing operational features |

---

## 18. Glossary

| Term | Definition |
|---|---|
| **COD** | Cash on Delivery — bayar tunai saat barang/makanan diterima |
| **Markup** | Selisih harga yang diambil platform dari harga dasar merchant |
| **Settlement** | Transfer bulanan dari platform ke merchant atas order yang selesai |
| **Tab** | Sistem kredit POS — customer bayar nanti (dicatat sebagai piutang) |
| **Piutang** | Tagihan yang belum dibayar customer ke merchant (POS) |
| **Hutang** | Kewajiban bayar merchant ke supplier (POS) |
| **HPP** | Harga Pokok Penjualan — biaya produk/bahan sebelum dijual |
| **Laba Kotor** | Pendapatan dikurangi HPP |
| **Laba Bersih** | Laba kotor dikurangi semua beban operasional |
| **Arus Kas** | Aliran uang masuk dan keluar dalam suatu periode |
| **Leg 1 / Leg 2** | Dua perjalanan driver untuk service order: jemput barang (leg 1) dan antar balik (leg 2) |
| **OSM** | OpenStreetMap — peta open-source yang digunakan KUWRIR |
| **Valhalla** | Routing engine open-source untuk hitung rute + ETA |
| **Nominatim** | Geocoding engine open-source (alamat → koordinat) |

---

*Dokumen ini merupakan gambaran menyeluruh sistem KUWRIR v1.0. Untuk detail teknis, lihat SPECIFICATION.md.*
