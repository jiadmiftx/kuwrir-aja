# Cocourir (Kuwrir) — Dokumentasi Flow & Aturan Bisnis

> **Versi:** 2026-06-23 (mencerminkan kondisi kode terkini, commit `bc8c2e2`)
> **Cakupan:** customer_app, driver_app, merchant_app, admin_panel, backend Go
> **Status data harga:** Cash on Delivery + Online Payment (Duitku), area operasi Mataram, Lombok

---

## 1. Ringkasan Sistem

Cocourir adalah platform super-app yang menghubungkan tiga peran inti — **Customer**, **Merchant** (restoran/jasa), dan **Driver** — diawasi oleh **Admin** lewat panel web. Ada dua jenis layanan:

| Layanan | Deskripsi |
|---|---|
| **Pesan Makanan/Barang** | Customer pesan dari merchant → merchant siapkan → driver antar |
| **Jasa Panggilan** | Laundry/bengkel/salon dll — driver jemput barang dari customer → diservis di merchant → driver antar balik |

### Stack Teknologi

```
┌─────────────────────────────────────────────────────────────────┐
│                         COCOURIR PLATFORM                       │
│                                                                   │
│   ┌────────────┐   ┌────────────┐   ┌────────────┐               │
│   │ customer_app│   │merchant_app│   │ driver_app │  (Flutter)   │
│   └─────┬──────┘   └─────┬──────┘   └─────┬──────┘               │
│         │                │                │                      │
│         └────────────────┼────────────────┘                      │
│                           │  REST + JWT (Bearer)                  │
│                  ┌────────▼─────────┐                            │
│                  │   backend (Go)    │   Gin + GORM + PostgreSQL  │
│                  │  /api/v1/...      │                            │
│                  └────────▲─────────┘                            │
│                           │                                        │
│                  ┌────────┴─────────┐                            │
│                  │   admin_panel     │   React + TypeScript       │
│                  │   (React SPA)     │   (Base UI components)     │
│                  └───────────────────┘                            │
│                                                                   │
│   Shared:  shared/kuwrir_shared  → model & ApiClient dipakai      │
│            bersama oleh 3 app Flutter                            │
│                                                                   │
│   External: Duitku (payment gateway), Firebase Cloud Messaging   │
│             (push notif), OpenStreetMap-style reverse geocoding   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Role & Autentikasi

### 2.1 Empat Role

| Role | Kemampuan |
|---|---|
| `customer` | Pesan makanan/jasa, chat, lihat profil, support chat ke admin |
| `merchant` | Kelola toko, produk, terima/proses order, wallet, settlement |
| `driver` | Terima job antar, update status delivery, wallet, COD holding |
| `admin` | Kelola seluruh sistem lewat admin_panel |

### 2.2 Pendaftaran & Login

**Customer** — daftar `is_active=true` langsung bisa login.

**Driver & Merchant** — daftar dengan `is_active=false`. Tidak bisa login sampai aplikasi mereka disetujui admin:

```
DRIVER                                    MERCHANT
──────                                    ────────
1. Register (email/pass)                  1. Register (email/pass)
   → is_active=false                         → is_active=false
2. POST /driver/apply                     2. POST /my-store
   (vehicle info + 5 dokumen:                (info toko + lokasi
    KTP, SIM, STNK, selfie,                   + dokumen opsional)
    foto kendaraan)                           → Merchant.is_verified=false
   → DriverApplication status=pending         → Merchant.is_active=false
3. Admin review                           3. Admin review
   PUT /admin/driver-applications/:id/review  PUT /admin/merchants/:id/verify
   ├─ approve → is_active=true,              ├─ approve → is_verified=true,
   │   buat record Driver                    │   is_active=true (user & merchant)
   └─ reject  → tetap inactive,              └─ reject → tetap inactive,
       bisa resubmit                              note dikirim
4. Driver bisa login & online             4. Merchant bisa login, toggle toko
                                              buka (is_open, default false)
```

**Google Sign-In** — `POST /auth/google` dengan `id_token` + `role`. Auto-register kalau user baru. Untuk merchant: response menyertakan `has_merchant_profile`. Kalau `false` → app arahkan ke flow lengkapi profil toko (skip step akun, langsung ke step toko) — supaya tidak nyangkut "merchant not found" tanpa jalan keluar (fix batch terakhir).

### 2.3 Token

JWT (HS256), payload: `user_id`, `role`, expiry sesuai config. Header: `Authorization: Bearer <token>`.

Admin panel: setelah konsolidasi ke `lib/api.ts`, setiap response `401` otomatis hapus token & redirect ke `/login` — supaya tidak ada lagi kondisi "data hilang" diam-diam karena token expired.

---

## 3. Siklus Hidup Order

### 3.1 Order Barang/Makanan (sequential, one-way kecuali cancel)

```
 pending ──accept(merchant)──▶ confirmed ──prepare──▶ preparing ──ready──▶ ready
    │                                                                        │
    │ cancel (customer, HANYA saat masih pending)                           │ driver accept
    │                                                                        ▼
    ▼                                                                  picked_up
 cancelled ◀──── admin-cancel (admin, kapan saja sebelum delivered) ────┐    │
                                                                          │   │ deliver
                                                                          │   ▼
                                                                          └ delivered (FINAL)
```

- Customer **hanya bisa cancel** saat status masih `pending`.
- Admin bisa cancel order **kapan pun sebelum delivered**; kalau order online-payment → otomatis refund ke wallet customer. Kalau COD → refund manual cash oleh admin.

### 3.2 Order Jasa (laundry/bengkel/salon — round-trip)

```
pending → confirmed → awaiting_pickup → item_picked_up → in_service
                                                              │
                                                  ready_for_return
                                                              │
                                                         returning
                                                              │
                                                         returned (FINAL, bayar COD)
```

### 3.3 Penugasan Driver

Tidak ada algoritma matching otomatis. Dua cara:

1. **Self-accept** — driver online & available melihat daftar order `ready` (yang `driver_id` masih null ATAU sudah jadi miliknya) lewat `GET /driver-orders/available`, lalu klaim sendiri.
2. **Admin assign manual** — admin lihat `GET /admin/orders/:id/nearby-drivers` (diurutkan jarak via Haversine), lalu `POST /admin/orders/:id/assign-driver` menetapkan driver tertentu — order itu jadi eksklusif untuk driver tersebut.

---

## 4. Aturan Harga & Komisi

### 4.1 Parameter Sistem (default, bisa diubah admin di Settings)

| Key | Default | Fungsi |
|---|---|---|
| `platform_markup_percentage` | 15% | Markup/ujrah di atas subtotal produk |
| `delivery_commission_percentage` | 25% | Potongan platform dari ongkir |
| `app_service_fee_percentage` | 5% | Biaya jasa aplikasi (dibebankan ke customer) |
| `self_deliver_commission_percentage` | 10% | Komisi platform kalau merchant antar sendiri |
| `delivery_base_fee_inside_zone` | Rp 15.000 | Ongkir dasar dalam radius zona (5km) |
| `delivery_fee_per_km_outside` | Rp 10.000/km | Tambahan per km di luar zona |
| `service_delivery_fee_round_trip` | Rp 20.000 | Ongkir flat pulang-pergi utk jasa |
| `tax_percentage` | 11% | PPN atas subtotal produk |
| `max_cod_amount` | Rp 500.000 | Limit order COD |

### 4.2 Perhitungan — Antar oleh Driver Platform

Contoh: subtotal produk Rp 50.000, jarak 8 km.

```
1. subtotal_markup = 50.000 × 1.15            = 57.500   (markup masuk kantong platform)
2. tax             = 57.500 × 11%              =  6.325
3. delivery_fee    = 15.000 + (8-5)×10.000     = 45.000
4. delivery_commission = 45.000 × 25%          = 11.250   (potongan platform)
5. driver_earning  = 45.000 - 11.250           = 33.750   (masuk wallet driver)
6. app_service_fee = 45.000 × 5%               =  2.250   (platform)
─────────────────────────────────────────────────────────
GRAND TOTAL (customer bayar) = 57.500+6.325+45.000+2.250 = 111.075

Alokasi akhir:
  Merchant terima  : 50.000  (subtotal asli, tanpa markup)
  Driver terima    : 33.750
  Platform terima  : 15.000 (markup) + 11.250 (komisi ongkir) + 2.250 (app fee) = 28.500
```

### 4.3 Perhitungan — Merchant Antar Sendiri (Self-Deliver)

Pakai `merchant.self_delivery_fee` (ditentukan merchant sendiri), bukan zona:

```
self_delivery_commission = self_delivery_fee × 10%
merchant_delivery_earning = self_delivery_fee - self_delivery_commission
driver_earning = 0
app_service_fee tetap dipungut dari customer
```

### 4.4 Order Jasa

Pakai ongkir flat round-trip (`service_delivery_fee_round_trip`), markup & komisi mengikuti rumus yang sama.

### 4.5 Zona Pengantaran

Pencarian zona terdekat via Haversine distance. Kalau ada `DeliveryZone` aktif dalam radius 50km → pakai `base_fee`/`per_km_fee` zona itu. Kalau tidak ada → fallback ke zona `is_default=true`, lalu fallback terakhir ke setting global.

---

## 5. Wallet, COD Holding & Settlement

```
                     ORDER DELIVERED
                            │
            ┌───────────────┴────────────────┐
            ▼                                ▼
     payment = CASH (COD)              payment = ONLINE (sudah lunas)
            │                                │
   Wallet driver + merchant kredit   Wallet driver + merchant kredit
   Driver.cod_holding bertambah      (uang sudah ada di platform,
   (uang tunai masih di tangan        tidak ada cod_holding)
   driver, belum disetor)
            │
            ▼
   POST /driver/cod/deposit  →  cod_holding berkurang
   (driver setor tunai ke kantor/admin; wallet balance TIDAK berubah
   lagi di sini — sudah dikredit saat delivery)
```

- **Wallet** = saldo yang bisa ditarik (withdraw), terpisah dari **cod_holding** (uang tunai fisik yang masih di tangan driver).
- **Withdraw**: `POST /driver/wallet/withdraw` atau `/my-store/wallet/withdraw` → integrasi Duitku disbursement → `WithdrawalRequest(status=processing)` → sukses baru kurangi saldo wallet.
- **Merchant Settlement**: admin proses periodik (`POST /admin/settlements/merchants/:id/process`) → rekap order delivered dalam periode → `MerchantSettlement(status=pending)` → admin tandai `mark-paid` setelah transfer manual/lainnya.

---

## 6. Chat & Support

Dua jalur chat yang **sudah berjalan**:

### 6.1 Chat per-Order (Customer ↔ Driver)

```
Customer                                              Driver
   │  GET/POST /orders/:id/chat                          │
   │ ───────────────────────────────────────────────────▶│
   │           FCM: "Pesan dari Customer 💬"              │
   │                                                       │
   │◀───────────────────────────────────────────────────  │
   │  GET/POST /driver-orders/:id/chat                    │
   │           FCM: "Pesan dari Driver 💬"                 │
```
Tidak ada chat dengan merchant di dalam order — hanya customer↔driver.

### 6.2 Support Chat (Customer ↔ Admin)

```
Customer App                Backend                    Admin Panel
─────────────                ───────                    ───────────
SupportChatScreen      GET/POST /support/messages
  (polling 3s)    ──▶  (model: SupportMessage)
                        sender_role: customer|admin
                              │
                  FCM ke semua admin online
                  "Pesan Support Baru"
                                                    SupportChatsPage.tsx
                                              GET /admin/support/users
                                          (list user + unread count)
                                              ◀── pilih user ──▶
                                     GET /admin/support/users/:id/messages
                                     POST /admin/support/users/:id/messages
                              │
                  FCM ke customer
                  "Balasan dari Admin"
```

Customer mengakses lewat tab **Chat** di bottom nav: section "Pesanan Aktif" (order dengan status `confirmed|preparing|ready|picked_up`) + tombol "Chat dengan Admin".

---

## 7. Notifikasi (FCM)

| Event | Penerima | Judul |
|---|---|---|
| Order baru masuk | Merchant | "Pesanan Baru! 🛍️" |
| Order dikonfirmasi merchant | Customer | "Pesanan Dikonfirmasi ✅" |
| Order siap diambil | Customer | "Pesanan Siap! 📦" |
| Driver ditemukan/accept | Customer | "Driver Ditemukan! 🏍️" |
| Driver pickup | Customer | "Pesanan Sedang Diantar 🛵" |
| Order delivered | Customer | "Pesanan Tiba! 🎉" |
| Chat order baru | Lawan chat (customer/driver) | "Pesan dari [Role] 💬" |
| Support chat baru | Semua admin online | "Pesan Support Baru" |
| Balasan admin | Customer | "Balasan dari Admin" |

FCM no-op aman kalau `FIREBASE_SERVICE_ACCOUNT_JSON` tidak diset (tidak crash, cuma skip kirim).

---

## 8. Admin Panel — Peta Fitur

```
┌─────────────────────────────────────────────────────────────┐
│  Dashboard      → KPI: order hari ini, merchant/driver aktif,│
│                    revenue bulan ini, cash driver pending     │
│  Orders         → list + filter status & TANGGAL (Hari Ini/  │
│                    Minggu/Bulan/Tahun/Custom), hover-card     │
│                    preview merchant & driver, assign driver,  │
│                    admin-cancel                               │
│  Drivers        → list, COD holding & deposit history         │
│  Driver Apps     → review aplikasi driver (approve/reject)    │
│  Merchants      → list, verifikasi/approve toko baru          │
│  Customers      → list                                        │
│  Promotions     → CRUD kode promo, toggle aktif               │
│  Delivery Zones → CRUD zona ongkir                             │
│  Settlements    → proses settlement merchant per periode       │
│  Withdrawals    → monitor permintaan tarik saldo                │
│  Refunds        → proses refund (approve/reject)               │
│  Revenue        → analitik GMV/markup/komisi/fee/tax per periode│
│  Support Chats  → balas pesan support dari customer            │
│  Settings       → ubah semua parameter sistem di §4.1           │
└─────────────────────────────────────────────────────────────┘
```

Semua page (kecuali login) pakai shared `apiFetch` (`lib/api.ts`) yang otomatis redirect ke login saat token 401 — fix untuk bug "data hilang setelah idle lama".

---

## 9. Struktur Route API (ringkas)

```
/api/v1
├── [PUBLIC]            /auth/register, /auth/login, /auth/google,
│                       /merchants (list/nearby/search/popular/:id),
│                       /service-merchants, /payment/callback
├── [customer]          /auth/me, /orders/*, /service-orders/*,
│                       /support/messages, /payment/*
├── [merchant]          /my-store/*, /merchant-orders/*, /my-service-orders/*
├── [driver]            /driver/status, /driver-orders/*, /driver/wallet/*,
│                       /driver/cod/deposit, /driver/apply, /driver/service-orders/*
└── [admin]             /admin/dashboard, /admin/settings, /admin/drivers,
                        /admin/merchants, /admin/customers, /admin/orders,
                        /admin/revenue, /admin/refunds, /admin/settlements,
                        /admin/driver-applications, /admin/withdrawals,
                        /admin/promotions, /admin/delivery-zones,
                        /admin/support/*
```

Middleware: CORS global → `AuthMiddleware` (validasi JWT, inject `user_id`/`role`) → `RoleMiddleware` (cek role sesuai grup).

---

## 10. Aturan Bisnis Kunci (Ringkasan)

1. Order bergerak **satu arah** secara berurutan — tidak bisa lompat status, kecuali dibatalkan.
2. **Tiga gerbang approval**: driver & merchant tidak bisa beroperasi sebelum disetujui admin.
3. Model harga **transparan**: markup, komisi ongkir, app fee dipisah jelas — driver tahu pasti penghasilannya sebelum antar.
4. **COD ditrack dua lapis**: wallet balance (saldo bisa ditarik) vs cod_holding (uang tunai fisik di tangan driver) — terpisah.
5. Refund online payment otomatis ke wallet customer; refund COD harus manual oleh admin.
6. Merchant hanya menerima **subtotal produk asli** — semua markup/komisi/fee jadi milik platform.
7. Admin punya **override penuh**: bisa batalkan order kapan saja sebelum delivered, dan assign driver manual.
8. Chat order (customer↔driver) dan support chat (customer↔admin) adalah **dua kanal terpisah** dengan tujuan berbeda.

---

## 11. Yang Sudah Selesai vs Belum (per 2026-06-23)

**Selesai & sudah di-push (commit `bc8c2e2`):**
- Fix bug nama driver/merchant tidak muncul di admin Orders (root cause: mismatch casing JSON)
- Hover-card preview profil merchant/driver di Orders
- Filter tanggal (Hari Ini/Minggu/Bulan/Tahun/Custom) di Orders
- Auto-redirect login saat token 401 di semua page admin (fix "data hilang")
- Profile screen + icon di customer app
- Reverse-geocoding lokasi customer (bukan lat/long mentah)
- Recent search & Popular section pakai data asli (bukan dummy)
- Rebrand referensi Kuta → Mataram di customer app
- Pesan error login merchant lebih ramah
- Google sign-in merchant → flow lengkapi profil toko kalau belum punya merchant record
- Upload foto produk + field SKU + lacak stok di merchant app

**Sudah ada sebelumnya (terverifikasi saat audit dokumen ini, bukan baru):**
- Chat tab customer app: order chat aktif + support chat ke admin — **sudah implementasi penuh**, bukan rencana lagi.

**Belum dikerjakan / perlu tindak lanjut:**
- Deploy manual backend (Go) & admin_panel (React) ke VPS — CI/CD Firebase Distribution hanya cover 3 app Flutter (`customer_app`, `driver_app`, `merchant_app`), tidak cover backend/admin_panel.
- Dokumen lama (`SYSTEM_OVERVIEW.md`, `SYSTEM_FLOW.md`, `SPECIFICATION.md`) masih bertanggal Juni 2026 dan menyebut model COD-only + fokus Kuta — sudah tidak sinkron dengan kondisi kode saat ini (online payment Duitku sudah ada, fokus area sudah Mataram). Dokumen ini (`PROJECT_FLOW_AND_RULES.md`) dibuat untuk menggantikan referensi yang lebih akurat.

---

*Dokumen ini dihasilkan berdasarkan audit langsung terhadap kode backend (`backend/internal/...`), bukan asumsi — semua nilai persentase, nama endpoint, dan status order diverifikasi dari source code.*
