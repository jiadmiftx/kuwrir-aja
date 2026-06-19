# KUWRIR — System Flow & Database Schema
> Dokumen analisis lengkap untuk keperluan revamp. Dibuat 2026-06-19.
> Target: Kuta, Lombok, NTB · MVP: COD Only · Go + Flutter + React

---

## Daftar Isi

1. [Arsitektur Sistem](#1-arsitektur-sistem)
2. [Database Schema](#2-database-schema)
3. [Auth & User Management](#3-auth--user-management)
4. [Registration & Verification Flows](#4-registration--verification-flows)
5. [Food Order Flow](#5-food-order-flow)
6. [Service (Jasa) Order Flow](#6-service-jasa-order-flow)
7. [POS / Kasir Flow](#7-pos--kasir-flow)
8. [Financial Model & Pricing Engine](#8-financial-model--pricing-engine)
9. [Driver COD Balance System](#9-driver-cod-balance-system)
10. [Merchant Settlement System](#10-merchant-settlement-system)
11. [Promotion System](#11-promotion-system)
12. [Admin Panel Capabilities](#12-admin-panel-capabilities)
13. [API Reference Lengkap](#13-api-reference-lengkap)
14. [Konfigurasi & System Settings](#14-konfigurasi--system-settings)
15. [Infrastruktur & Deployment](#15-infrastruktur--deployment)
16. [Catatan Revamp & Gap Analysis](#16-catatan-revamp--gap-analysis)

---

## 1. Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         KUWRIR Platform                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Flutter Apps                    Web                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ Customer App │  │  Driver App  │  │ Merchant App │  │  Admin Panel   │  │
│  │ (Flutter)    │  │  (Flutter)   │  │  (Flutter)   │  │  (React/Vite)  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └───────┬────────┘  │
│         └─────────────────┼─────────────────┘                  │           │
│                           │ HTTP/JWT (Bearer token)             │ HTTP/JWT  │
│              ┌────────────▼────────────────────────────────────┘           │
│              │           Go + Gin API                                        │
│              │           Port :8090 (prod) / :8080 (dev)                    │
│              │           /api/v1/*                                           │
│              └─────┬──────────────┬───────────────┬────────────             │
│                    │              │               │                          │
│              ┌─────▼──────┐  ┌───▼────┐  ┌──────▼──────┐                  │
│              │ PostgreSQL │  │ Redis  │  │ ./uploads/  │                   │
│              │ 16+PostGIS │  │ 7 Alp. │  │ (local→R2)  │                   │
│              └────────────┘  └────────┘  └─────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Deployment (Production)

| Komponen | Host | Port |
|---|---|---|
| VPS | ubuntu@43.134.172.254 | — |
| Backend API | VPS container `kuwrir-backend` | 8090 |
| Admin Panel | VPS container `kuwrir-admin` | 8091 |
| PostgreSQL | VPS container `kuwrir-postgres` | internal only |
| Redis | VPS container `kuwrir-redis` | internal only |
| CI/CD | GitHub Actions → SSH deploy | on push to `main` |
| Firebase | Project `kuwrir-3495d` | FCM + App Distribution |

---

## 2. Database Schema

### Gambaran Relasi Antar Tabel

```
users ──────────────────────────────────────────────┐
  │                                                  │
  ├─── addresses (1:N)                               │
  │                                                  │
  ├─── merchants (1:1) ───┬── product_categories     │
  │       │               │     └── products ────────┤
  │       │               │           └── product_variants
  │       │               │     
  │       ├── merchant_settlements (1:N)             │
  │       ├── merchant_receivables (1:N via pos)     │
  │       ├── merchant_payables (1:N)                │
  │       └── pos_transactions (1:N) ───── pos_transaction_items
  │                                                  │
  ├─── drivers (1:1) ─────── driver_deposits (1:N)  │
  │       │                                          │
  │       └── driver_applications (1:1)              │
  │                                                  │
  └─── orders (customer=1:N, driver=1:N)            │
         │                                           │
         ├── order_items (1:N) ─── products          │
         └── reviews (1:1)                           │
```

---

### 2.1 Tabel `users`

**Primary key:** UUID (gen_random_uuid())  
**Soft delete:** `deleted_at` (GORM)

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK, default gen_random_uuid() | |
| `created_at` | timestamptz | | |
| `updated_at` | timestamptz | | |
| `deleted_at` | timestamptz | nullable, index | soft delete |
| `name` | varchar | NOT NULL | |
| `email` | varchar | UNIQUE INDEX | bisa kosong? perlu dicek |
| `phone` | varchar | UNIQUE INDEX, NOT NULL | dipakai untuk login |
| `password` | varchar | NOT NULL | bcrypt hash |
| `avatar_url` | varchar | nullable | |
| `role` | varchar(20) | NOT NULL, index | `customer` / `driver` / `merchant` / `admin` |
| `is_active` | boolean | NOT NULL, **no DB default** | customer=true saat register; driver/merchant=false sampai admin approve |
| `email_verified_at` | timestamptz | nullable | belum diimplementasi |

**Catatan penting:**
- `is_active` sengaja tidak punya DB-level `default` tag karena GORM akan skip zero-value pada INSERT jika ada `default:`, menyebabkan merchant/driver baru tidak sengaja menjadi aktif.
- Login dicek `is_active`; akun suspended tidak bisa masuk.

---

### 2.2 Tabel `addresses`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, NOT NULL, index | |
| `label` | varchar | NOT NULL | "Rumah", "Kantor", dll |
| `address` | varchar | NOT NULL | teks alamat lengkap |
| `latitude` | float8 | NOT NULL | |
| `longitude` | float8 | NOT NULL | |
| `is_default` | boolean | default false | |

---

### 2.3 Tabel `merchants`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, UNIQUE INDEX | 1 user = 1 merchant |
| `name` | varchar | NOT NULL | |
| `slug` | varchar | UNIQUE INDEX, NOT NULL | lowercase-hyphenated dari name |
| `description` | varchar | nullable | |
| `phone` | varchar | nullable | nomor WA/telepon toko |
| `logo_url` | varchar | nullable | |
| `banner_url` | varchar | nullable | |
| `address` | varchar | NOT NULL | |
| `latitude` | float8 | NOT NULL | |
| `longitude` | float8 | NOT NULL | |
| `rating` | float8 | default 0 | rata-rata rating dari reviews |
| `total_reviews` | int | default 0 | |
| `is_active` | boolean | default false | jadi true setelah admin approve |
| `is_verified` | boolean | default false | jadi true setelah admin approve |
| `is_open` | boolean | default false | toggle buka/tutup oleh merchant |
| `can_self_deliver` | boolean | default false | merchant antar sendiri tanpa driver platform |
| `self_delivery_fee` | float8 | default 0 | ongkir custom jika self-deliver |
| `owner_ktp_url` | varchar | nullable | URL foto KTP pemilik |
| `business_license_url` | varchar | nullable | URL SIUP/IUMK (opsional) |
| `store_photo_url` | varchar | nullable | URL foto toko |
| `type` | varchar(20) | default 'food' | `food` / `service` |
| `service_category` | varchar(50) | nullable | `laundry` / `bengkel` / `cleaning` / `salon` / `other` |
| `verification_status` | varchar(20) | default 'pending' | `pending` / `approved` / `rejected` |
| `verification_note` | varchar | nullable | alasan reject dari admin |
| `verified_by_id` | uuid | nullable, FK → users.id | admin yang approve |
| `verified_at` | timestamptz | nullable | |

---

### 2.4 Tabel `product_categories`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `name` | varchar | NOT NULL | nama kategori |
| `sort_order` | int | default 0 | urutan tampil |

---

### 2.5 Tabel `products`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `category_id` | uuid | FK → product_categories.id, NOT NULL, index | |
| `name` | varchar | NOT NULL | |
| `description` | varchar | nullable | |
| `price` | float8 | NOT NULL | harga jual (base price merchant) |
| `cost_price` | float8 | default 0 | HPP / harga beli — untuk margin analysis di kasir |
| `price_unit` | varchar(20) | default 'per_item' | `per_item` / `per_kg` / `per_service` / `per_hour` |
| `duration_estimate` | varchar | nullable | estimasi durasi layanan, e.g. "1-2 hari" |
| `image_url` | varchar | nullable | |
| `is_available` | boolean | default true | |
| `track_stock` | boolean | default false | aktifkan manajemen stok |
| `stock_quantity` | int | default 0 | stok saat ini |
| `min_stock` | int | default 0 | batas alert low-stock |
| `sku` | varchar | nullable | kode produk internal |
| `sort_order` | int | default 0 | |

---

### 2.6 Tabel `product_variants`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `product_id` | uuid | FK → products.id, NOT NULL, index | |
| `group_name` | varchar | NOT NULL | nama grup, e.g. "Ukuran", "Level Pedas" |
| `name` | varchar | NOT NULL | nama opsi, e.g. "Besar", "Extra Pedas" |
| `price` | float8 | default 0 | harga tambahan dari varian |
| `is_required` | boolean | default false | wajib dipilih atau opsional |

---

### 2.7 Tabel `drivers`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, UNIQUE INDEX | dibuat saat driver application di-approve |
| `vehicle_type` | varchar | NOT NULL | `motorcycle` / `bicycle` |
| `vehicle_plate` | varchar | NOT NULL | nomor plat kendaraan |
| `license_number` | varchar | nullable | nomor SIM |
| `latitude` | float8 | nullable | posisi GPS terakhir |
| `longitude` | float8 | nullable | posisi GPS terakhir |
| `is_online` | boolean | default false | driver sedang aktif cari order |
| `is_available` | boolean | default true | tidak sedang mengerjakan order |
| `rating` | float8 | default 5.0 | |
| `total_delivered` | int | default 0 | total order selesai |
| `cash_balance` | float8 | default 0 | total COD cash yang belum disetor ke platform |

---

### 2.8 Tabel `driver_applications`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK → users.id, UNIQUE INDEX | 1 user = 1 aplikasi |
| `vehicle_type` | varchar | NOT NULL | `motorcycle` / `bicycle` / `car` |
| `vehicle_plate` | varchar | NOT NULL | |
| `vehicle_year` | int | nullable | tahun kendaraan |
| `vehicle_color` | varchar | nullable | |
| `vehicle_brand` | varchar | nullable | |
| `ktp_url` | varchar | nullable | URL foto KTP |
| `sim_url` | varchar | nullable | URL foto SIM C/A |
| `stnk_url` | varchar | nullable | URL foto STNK |
| `selfie_url` | varchar | nullable | URL selfie + KTP |
| `vehicle_photo_url` | varchar | nullable | URL foto kendaraan |
| `status` | varchar(20) | default 'pending' | `pending` / `approved` / `rejected` |
| `review_note` | varchar | nullable | catatan dari admin |
| `reviewed_by_id` | uuid | nullable, FK → users.id | admin yang review |
| `reviewed_at` | timestamptz | nullable | |

---

### 2.9 Tabel `orders`

Satu tabel untuk semua tipe order (food, service, POS).

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `order_number` | varchar | UNIQUE INDEX, NOT NULL | e.g. "ORD-260601143022" |
| `service_type` | varchar(20) | NOT NULL, default 'ecommerce', index | `ecommerce` / `service` / `pos` |
| `customer_id` | uuid | nullable, FK → users.id, index | null untuk POS anonymous |
| `merchant_id` | uuid | nullable, FK → merchants.id, index | |
| `driver_id` | uuid | nullable, FK → drivers.id, index | null sampai driver accept |
| `status` | varchar(20) | NOT NULL, default 'pending', index | lihat status machine di bawah |
| `delivery_type` | varchar(20) | NOT NULL, default 'platform' | `platform` / `self` |
| `payment_type` | varchar(20) | NOT NULL, default 'cash' | `cash` / `qris` / `card` (semua COD di MVP) |
| `subtotal` | float8 | NOT NULL, default 0 | total base price semua item |
| `platform_markup` | float8 | NOT NULL, default 0 | 15% markup oleh platform |
| `delivery_fee` | float8 | NOT NULL, default 0 | ongkir yang dibayar customer |
| `delivery_commission` | float8 | NOT NULL, default 0 | 25% dari delivery fee — bagian platform |
| `driver_earning` | float8 | NOT NULL, default 0 | 75% dari delivery fee — bagian driver |
| `total` | float8 | NOT NULL, default 0 | grand total yang dibayar customer |
| `pickup_address` | varchar | nullable | alamat penjemputan (untuk service order) |
| `pickup_lat` | float8 | nullable | |
| `pickup_lng` | float8 | nullable | |
| `sender_name` | varchar | nullable | |
| `sender_phone` | varchar | nullable | |
| `dropoff_address` | varchar | nullable | alamat pengiriman |
| `dropoff_lat` | float8 | nullable | |
| `dropoff_lng` | float8 | nullable | |
| `receiver_name` | varchar | nullable | |
| `receiver_phone` | varchar | nullable | |
| `distance_km` | float8 | nullable | jarak pengiriman |
| `notes` | varchar | nullable | catatan dari customer |
| `pickup_scheduled_at` | timestamptz | nullable | jadwal jemput (service order) |
| `service_notes` | varchar | nullable | instruksi khusus, e.g. "pisahkan baju putih" |
| `return_address` | varchar | nullable | alamat antar balik (default = pickup) |
| `return_lat` | float8 | nullable | |
| `return_lng` | float8 | nullable | |
| `weight_kg` | float8 | default 0 | berat (untuk laundry per-kg) |
| `placed_at` | timestamptz | nullable | |
| `confirmed_at` | timestamptz | nullable | merchant confirm |
| `ready_at` | timestamptz | nullable | merchant mark ready |
| `picked_up_at` | timestamptz | nullable | driver pickup dari merchant |
| `delivered_at` | timestamptz | nullable | driver selesai antar |
| `cancelled_at` | timestamptz | nullable | |
| `item_picked_up_at` | timestamptz | nullable | [service] barang dijemput dari customer |
| `in_service_at` | timestamptz | nullable | [service] barang mulai dikerjakan |
| `ready_for_return_at` | timestamptz | nullable | [service] selesai, siap diantarkan balik |
| `returned_at` | timestamptz | nullable | [service] barang sudah dikembalikan ke customer |

---

### 2.10 Tabel `order_items`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `order_id` | uuid | FK → orders.id, NOT NULL, index | |
| `product_id` | uuid | nullable, FK → products.id | null untuk custom item |
| `item_name` | varchar | NOT NULL | snapshot nama produk saat order |
| `quantity` | int | NOT NULL | |
| `base_price` | float8 | NOT NULL | harga asli merchant saat order |
| `unit_price` | float8 | NOT NULL | base_price + markup per unit |
| `total_price` | float8 | NOT NULL | unit_price × quantity + variant prices |
| `variants_json` | jsonb | nullable | snapshot pilihan varian |
| `notes` | varchar | nullable | catatan item |

---

### 2.11 Tabel `reviews`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `order_id` | uuid | FK → orders.id, UNIQUE INDEX | 1 order = 1 review |
| `customer_id` | uuid | FK → users.id, NOT NULL, index | |
| `merchant_id` | uuid | nullable, FK → merchants.id, index | |
| `driver_id` | uuid | nullable, FK → drivers.id, index | |
| `merchant_rating` | int | nullable | 1–5 |
| `driver_rating` | int | nullable | 1–5 |
| `comment` | varchar | nullable | |

**Catatan:** Review model ada di DB tapi endpoint belum diimplementasi (Phase 7).

---

### 2.12 Tabel `system_settings`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `key` | varchar(100) | PRIMARY KEY | string key unik |
| `value` | varchar | NOT NULL | nilai sebagai string |
| `label` | varchar | NOT NULL | label human-readable |
| `updated_at` | timestamptz | | |

**Default values:**

| Key | Default | Deskripsi |
|---|---|---|
| `platform_markup_percentage` | `15` | % markup pada base price food/service |
| `delivery_commission_percentage` | `25` | % dari delivery fee yang masuk platform |
| `delivery_base_fee_inside_zone` | `15000` | Ongkir food dalam zona (IDR) |
| `delivery_fee_per_km_outside` | `10000` | Tambahan per km di luar zona 5km (IDR) |
| `service_delivery_fee_round_trip` | `20000` | Ongkir service round-trip flat (IDR) |

---

### 2.13 Tabel `driver_deposits`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `driver_id` | uuid | FK → drivers.id, NOT NULL, index | |
| `amount` | float8 | NOT NULL | jumlah yang disetor |
| `method` | varchar | NOT NULL | `cash` / `bank_transfer` |
| `reference` | varchar | nullable | nomor bukti transfer |
| `notes` | varchar | nullable | |
| `verified_by_id` | uuid | nullable, FK → users.id | admin yang catat |
| `verified_at` | timestamptz | nullable | |

---

### 2.14 Tabel `merchant_settlements`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `period_start` | timestamptz | NOT NULL | awal periode settlement |
| `period_end` | timestamptz | NOT NULL | akhir periode settlement |
| `total_orders` | int | NOT NULL | jumlah order di periode ini |
| `total_base_product_amount` | float8 | NOT NULL | total subtotal (base price) yang harus dibayar ke merchant |
| `status` | varchar(20) | default 'pending' | `pending` / `paid` |
| `paid_at` | timestamptz | nullable | |
| `paid_by_id` | uuid | nullable, FK → users.id | admin yang proses |
| `reference` | varchar | nullable | nomor referensi transfer bank |

---

### 2.15 Tabel `promotions`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `code` | varchar | UNIQUE INDEX, NOT NULL | kode promo |
| `title` | varchar | NOT NULL | nama/deskripsi promo |
| `type` | varchar(20) | NOT NULL | `percentage` / `fixed` / `free_delivery` |
| `value` | float8 | NOT NULL | nilai diskon (% atau IDR) |
| `min_order` | float8 | default 0 | minimum order untuk pakai promo |
| `max_discount` | float8 | default 0 | batas maksimal diskon (untuk type percentage) |
| `usage_limit` | int | default 0 | 0 = unlimited |
| `used_count` | int | default 0 | berapa kali sudah dipakai |
| `is_active` | boolean | default true | |
| `starts_at` | timestamptz | NOT NULL | |
| `expires_at` | timestamptz | NOT NULL | |

---

### 2.16–2.22 Tabel POS / Kasir

#### `pos_transactions`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `transaction_number` | varchar | UNIQUE INDEX | e.g. "POS-260601143022" |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `date` | timestamptz | NOT NULL | tanggal transaksi |
| `customer_name` | varchar | nullable | untuk struk / tab |
| `customer_phone` | varchar | nullable | |
| `payment_method` | varchar(20) | NOT NULL, default 'cash' | `cash` / `qris` / `card` / `tab` |
| `status` | varchar(20) | NOT NULL, default 'completed' | `completed` / `voided` |
| `notes` | varchar | nullable | |
| `subtotal` | float8 | NOT NULL, default 0 | total sebelum diskon |
| `discount` | float8 | default 0 | diskon keseluruhan |
| `tax` | float8 | default 0 | pajak (jika ada) |
| `grand_total` | float8 | NOT NULL, default 0 | yang dibayar pelanggan |
| `total_cost` | float8 | default 0 | total HPP semua item |
| `gross_profit` | float8 | default 0 | grand_total − total_cost |
| `cash_received` | float8 | default 0 | uang yang diterima (untuk cash) |
| `cash_change` | float8 | default 0 | kembalian |
| `voided_at` | timestamptz | nullable | |
| `voided_reason` | varchar | nullable | |

#### `pos_transaction_items`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `transaction_id` | uuid | FK → pos_transactions.id, NOT NULL, index | |
| `product_id` | uuid | nullable, FK → products.id | null untuk item custom |
| `product_name` | varchar | NOT NULL | snapshot nama |
| `sku` | varchar | nullable | |
| `quantity` | int | NOT NULL | |
| `unit_price` | float8 | NOT NULL | harga jual per unit |
| `unit_cost` | float8 | default 0 | HPP per unit |
| `discount` | float8 | default 0 | diskon item |
| `subtotal` | float8 | NOT NULL | (unit_price × qty) − discount |
| `notes` | varchar | nullable | |

#### `stock_movements`

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `product_id` | uuid | FK → products.id, NOT NULL, index | |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `date` | timestamptz | NOT NULL | |
| `type` | varchar(20) | NOT NULL | `in` / `out` / `opname` / `void` |
| `quantity` | int | NOT NULL | jumlah unit bergerak |
| `cost_price` | float8 | default 0 | harga beli saat gerakan ini |
| `reason` | varchar | nullable | keterangan |
| `reference` | varchar | nullable | nomor transaksi POS atau manual |

#### `merchant_receivables` (Piutang)

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `transaction_id` | uuid | nullable, FK → pos_transactions.id | link ke POS asal |
| `customer_name` | varchar | NOT NULL | |
| `customer_phone` | varchar | nullable | |
| `description` | varchar | nullable | |
| `due_date` | timestamptz | nullable | |
| `amount` | float8 | NOT NULL | total piutang |
| `paid_amount` | float8 | default 0 | sudah dibayar |
| `status` | varchar(20) | default 'unpaid' | `unpaid` / `partial` / `paid` |

#### `merchant_receivable_payments` (Bayar Piutang)

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `receivable_id` | uuid | FK → merchant_receivables.id, NOT NULL, index | |
| `date` | timestamptz | NOT NULL | |
| `amount` | float8 | NOT NULL | |
| `method` | varchar(20) | default 'cash' | `cash` / `transfer` |
| `notes` | varchar | nullable | |

#### `merchant_payables` (Hutang Supplier)

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `merchant_id` | uuid | FK → merchants.id, NOT NULL, index | |
| `supplier_name` | varchar | NOT NULL | |
| `supplier_phone` | varchar | nullable | |
| `description` | varchar | nullable | barang yang dibeli |
| `due_date` | timestamptz | nullable | |
| `amount` | float8 | NOT NULL | total hutang |
| `paid_amount` | float8 | default 0 | sudah dibayar |
| `status` | varchar(20) | default 'unpaid' | `unpaid` / `partial` / `paid` |

#### `merchant_payable_payments` (Bayar Hutang)

| Kolom | Tipe | Constraint | Catatan |
|---|---|---|---|
| `id` | uuid | PK | |
| `payable_id` | uuid | FK → merchant_payables.id, NOT NULL, index | |
| `date` | timestamptz | NOT NULL | |
| `amount` | float8 | NOT NULL | |
| `method` | varchar(20) | default 'cash' | |
| `notes` | varchar | nullable | |

---

## 3. Auth & User Management

### 3.1 Register

**Endpoint:** `POST /api/v1/auth/register`  
**Auth:** Tidak diperlukan

**Request:**
```json
{
  "name": "Budi Santoso",
  "email": "budi@email.com",
  "phone": "081234567890",
  "password": "password123",
  "role": "customer"  // customer | driver | merchant
}
```

**Logika:**
```
1. Cek phone sudah terdaftar → 409 Conflict jika ada
2. Hash password dengan bcrypt (cost=10)
3. Set is_active:
   - role=customer  → is_active = TRUE
   - role=driver    → is_active = FALSE
   - role=merchant  → is_active = FALSE
4. Simpan user ke DB
5. Generate JWT access token + refresh token
6. Return:
   - customer  → AuthResponse (token, refresh_token, user)
   - driver    → token + pesan "pending_application"
   - merchant  → token + pesan "pending_application"
```

**Penting:** Driver dan merchant menerima token saat register agar bisa langsung submit dokumen aplikasi, tapi akun tetap `is_active=false` sehingga login berikutnya akan ditolak sampai admin approve.

### 3.2 Login

**Endpoint:** `POST /api/v1/auth/login`  
**Auth:** Tidak diperlukan

**Request:**
```json
{
  "phone": "081234567890",
  "password": "password123"
}
```

**Logika:**
```
1. Cari user berdasarkan phone
2. Cek is_active → 403 Forbidden jika false ("Account is deactivated")
3. Bandingkan password dengan bcrypt
4. Generate JWT tokens
5. Return AuthResponse
```

### 3.3 JWT Token

- **Access token:** HS256, expiry dikonfigurasi di `.env` (default 24 jam)
- **Refresh token:** HS256, expiry lebih lama
- **Claims:** `user_id` (UUID string), `role`
- **Header:** `Authorization: Bearer <token>`
- **Middleware:** Cek signature + expiry; ekstrak `user_id` dan `role` ke Gin context

### 3.4 Role Middleware

Setiap grup route dilindungi oleh middleware yang cek `role` dari JWT claim:

| Grup Route | Role yang Diizinkan |
|---|---|
| `/api/v1/admin/*` | `admin` |
| `/api/v1/my-store/*` | `merchant` |
| `/api/v1/restaurant-orders/*` | `merchant` |
| `/api/v1/my-service-orders/*` | `merchant` |
| `/api/v1/my-store/pos/*` | `merchant` |
| `/api/v1/orders/*` | `customer` |
| `/api/v1/service-orders/*` | `customer` |
| `/api/v1/driver/*` | `driver` |
| `/api/v1/driver-orders/*` | `driver` |

---

## 4. Registration & Verification Flows

### 4.1 Customer Registration

```
Customer
  │
  ├─ POST /auth/register (role=customer)
  │    ├─ is_active = TRUE
  │    └─ Return token
  │
  └─ Langsung bisa order ✓
```

### 4.2 Driver Registration

```
Calon Driver
  │
  ├─ POST /auth/register (role=driver)
  │    ├─ is_active = FALSE
  │    └─ Return token (untuk submit aplikasi)
  │
  ├─ POST /api/v1/driver/apply  [role: driver, multipart/form-data]
  │    Fields: vehicle_type, vehicle_plate, vehicle_year, vehicle_color, vehicle_brand
  │    Files:  ktp (foto KTP), sim (foto SIM C/A), stnk (foto STNK),
  │            selfie (selfie + KTP), vehicle_photo (foto kendaraan)
  │    ├─ Simpan file ke ./uploads/driver-docs/
  │    └─ Buat DriverApplication (status=pending)
  │
  │                     Admin
  │                       │
  │    GET /admin/driver-applications?status=pending
  │                       │
  │    PUT /admin/driver-applications/:id/review
  │         { "approved": true, "note": "..." }
  │         ├─ Jika approved:
  │         │    ├─ DriverApplication.status = "approved"
  │         │    ├─ User.is_active = TRUE
  │         │    └─ Buat record Driver baru (vehicle_type, vehicle_plate, dll)
  │         └─ Jika rejected:
  │              ├─ DriverApplication.status = "rejected"
  │              └─ review_note diisi (bisa re-submit)
  │
  └─ Driver bisa login dan mulai cari order ✓
```

**Dokumen yang diperlukan:** KTP + SIM C/A + STNK + Selfie + Foto Kendaraan (5 files)

### 4.3 Merchant Registration

```
Calon Merchant
  │
  ├─ POST /auth/register (role=merchant)
  │    ├─ is_active = FALSE
  │    └─ Return token
  │
  ├─ POST /api/v1/my-store  [role: merchant, multipart/form-data]
  │    Fields: name, description, phone, address, latitude, longitude
  │    Files:  owner_ktp, business_license (opsional SIUP/IUMK), store_photo
  │    ├─ Simpan file ke ./uploads/merchant-docs/
  │    ├─ Slug dibuat dari name (lowercase-hyphenated)
  │    ├─ is_active = FALSE, is_verified = FALSE
  │    └─ Buat Merchant (verification_status=pending)
  │
  │  [Merchant cek status via]
  │  GET /api/v1/my-store/status
  │    └─ Return: status, is_active, is_verified, verification_note, name
  │
  │                     Admin
  │                       │
  │    GET /admin/merchants  (list semua merchants)
  │                       │
  │    PUT /admin/merchants/:id/verify
  │         { "verified": true, "note": "..." }
  │         ├─ Jika approved:
  │         │    ├─ Merchant.is_verified = TRUE
  │         │    ├─ Merchant.is_active = TRUE
  │         │    ├─ Merchant.verification_status = "approved"
  │         │    └─ User.is_active = TRUE  ← penting! biar merchant bisa login
  │         └─ Jika rejected:
  │              ├─ Merchant.verification_status = "rejected"
  │              └─ verification_note diisi alasan
  │
  └─ Merchant bisa login, kelola toko, terima order ✓
```

**Penting:** Saat approve merchant, sistem juga update `User.is_active = true` karena merchant user mendaftar dengan `is_active=false` dan login akan ditolak sampai flag ini di-flip.

---

## 5. Food Order Flow

### 5.1 Status Machine

```
                        Customer
                            │
                    POST /orders
                            │
                            ▼
                   ┌─────────────┐
                   │   PENDING   │──── cancel ──→ CANCELLED
                   └──────┬──────┘
                           │ Merchant confirm
                           ▼
                   ┌─────────────┐
                   │  CONFIRMED  │
                   └──────┬──────┘
                           │ Merchant mark preparing
                           ▼
                   ┌─────────────┐
                   │  PREPARING  │
                   └──────┬──────┘
                           │ Merchant mark ready
                           ▼
                   ┌─────────────┐
                   │    READY    │
                   └──────┬──────┘
                           │ Driver accept
                           ▼
                   ┌─────────────┐
                   │  PICKED_UP  │
                   └──────┬──────┘
                           │ Driver deliver + terima COD
                           ▼
                   ┌─────────────┐
                   │  DELIVERED  │
                   └─────────────┘
```

### 5.2 Detail Setiap Transisi

#### Customer: Place Order
`POST /api/v1/orders` [role: customer]
```json
{
  "merchant_id": "uuid",
  "items": [
    { "product_id": "uuid", "quantity": 2, "notes": "tanpa bawang", "variant_ids": [] }
  ],
  "dropoff_address": "Jl. Raya Senggigi No. 10",
  "dropoff_lat": -8.455,
  "dropoff_lng": 116.023,
  "notes": "depan gang hijau",
  "promo_code": "DISKON10"  // opsional
}
```

Sistem menghitung:
- `subtotal` = sum(base_price × qty) untuk setiap item
- `platform_markup` = subtotal × 15%
- `delivery_fee` = 15.000 (dalam zona) atau distance_km × 10.000 (luar zona >5km)
- `delivery_commission` = delivery_fee × 25%
- `driver_earning` = delivery_fee × 75%
- `total` = subtotal + platform_markup + delivery_fee

#### Merchant: Manage Orders
```
GET  /api/v1/restaurant-orders              → lihat antrian order masuk
POST /api/v1/restaurant-orders/:id/accept   → ubah status PENDING → CONFIRMED
POST /api/v1/restaurant-orders/:id/preparing → ubah status CONFIRMED → PREPARING
POST /api/v1/restaurant-orders/:id/ready    → ubah status PREPARING → READY
```

#### Driver: Accept & Deliver
```
GET  /api/v1/driver-orders/available        → lihat order yang READY (tersedia)
POST /api/v1/driver-orders/:id/accept       → accept order → status = PICKED_UP (langsung?)
POST /api/v1/driver-orders/:id/pickup       → konfirmasi pickup dari merchant → status = PICKED_UP
POST /api/v1/driver-orders/:id/deliver      → selesai antar → status = DELIVERED
                                              + driver.cash_balance += delivery_fee (COD dikumpul)
```

#### Customer: Cancel
```
POST /api/v1/orders/:id/cancel  → hanya bisa dari status PENDING
```

### 5.3 Self-Delivery Mode (Merchant Antar Sendiri)

Jika merchant aktifkan `can_self_deliver = true`:
- Order baru akan `delivery_type = "self"`
- Driver platform tidak terlibat
- Merchant mengelola pengiriman sendiri via:

```
GET  /api/v1/my-store/my-deliveries         → lihat order yang perlu diantar
POST /api/v1/my-store/my-deliveries/:id/pickup   → mark picked_up
POST /api/v1/my-store/my-deliveries/:id/deliver  → mark delivered
```

---

## 6. Service (Jasa) Order Flow

### 6.1 Merchant Types

Service order berlaku untuk merchant dengan `type = "service"`:

| Kategori | Contoh layanan | Proses |
|---|---|---|
| `laundry` | Cuci kiloan, dry clean | Ambil baju → cuci → antar balik |
| `bengkel` | Servis motor, ganti oli | Ambil kendaraan → servis → antar balik |
| `cleaning` | Bersihkan rumah | Ambil alat → datang ke lokasi → selesai |
| `salon` | Potong rambut, creambath | Home visit |

### 6.2 Status Machine (8 Status, 2 Driver Legs)

```
Customer                Merchant              Driver Leg 1           Merchant
place order             confirm               jemput dari customer   kerjakan
    │                       │                     │                      │
    ▼                       ▼                     ▼                      ▼
PENDING ──confirm──→ CONFIRMED ──accept──→ AWAITING_PICKUP ──tiba──→ ITEM_PICKED_UP
                                          [driver leg 1]             [di merchant]
                                                                           │
                                                                    merchant confirm
                                                                           │
                                                                           ▼
Driver Leg 2         Customer                                         IN_SERVICE
antar balik          bayar COD                                             │
    │                   │                                           selesai dikerjakan
    ▼                   ▼                                                  │
RETURNING ──selesai──→ RETURNED ◀───────────── READY_FOR_RETURN ──────────┘
                     [customer bayar]          [driver leg 2 accept]
```

### 6.3 Detail Setiap Transisi

#### Customer: Book Service
`POST /api/v1/service-orders` [role: customer]
```json
{
  "merchant_id": "uuid",
  "items": [
    { "product_id": "uuid", "quantity": 1, "weight_kg": 4.5 }
  ],
  "pickup_address": "Jl. Senggigi No. 5",
  "pickup_lat": -8.455,
  "pickup_lng": 116.023,
  "pickup_scheduled_at": "2026-06-20T09:00:00Z",
  "service_notes": "Pisahkan baju putih",
  "return_address": "Jl. Senggigi No. 5"  // default sama dengan pickup
}
```

Pricing:
- `subtotal` = sum(base_price × qty atau per_kg × weight)
- `platform_markup` = subtotal × 15%
- `delivery_fee` = 20.000 (round-trip flat)
- `driver_earning` = 15.000 (75% dari 20.000)
- `delivery_commission` = 5.000 (25% dari 20.000)
- `total` = subtotal + platform_markup + delivery_fee

#### Merchant: Confirm & Process
```
GET  /api/v1/my-service-orders                    → lihat antrian service order
POST /api/v1/my-service-orders/:id/confirm        → PENDING → CONFIRMED
POST /api/v1/my-service-orders/:id/in-service     → ITEM_PICKED_UP → IN_SERVICE
POST /api/v1/my-service-orders/:id/ready          → IN_SERVICE → READY_FOR_RETURN
```

#### Driver Leg 1: Jemput Barang dari Customer
```
GET  /api/v1/driver/service-orders/available      → lihat job tersedia (pickup + return)
POST /api/v1/driver/service-orders/:id/accept-pickup  → CONFIRMED → AWAITING_PICKUP
POST /api/v1/driver/service-orders/:id/item-picked-up → AWAITING_PICKUP → ITEM_PICKED_UP
                                                          (barang sudah diambil dari customer)
```

#### Driver Leg 2: Antar Balik ke Customer
```
POST /api/v1/driver/service-orders/:id/accept-return  → READY_FOR_RETURN → RETURNING
POST /api/v1/driver/service-orders/:id/returned       → RETURNING → RETURNED
                                                          + terima COD dari customer
                                                          + driver.cash_balance += delivery_fee
```

#### Customer: Cancel
```
POST /api/v1/service-orders/:id/cancel  → hanya dari PENDING
```

---

## 7. POS / Kasir Flow

### 7.1 Gambaran Umum

POS adalah fitur terpisah dari delivery order. Berlaku untuk:
- Merchant `type=food` yang punya pelanggan walk-in
- Merchant `type=service` (semua kategori) untuk catat transaksi langsung

Tidak ada customer account yang terlibat. Transaksi `service_type = "pos"`.

### 7.2 Buat Transaksi POS

`POST /api/v1/my-store/pos/transactions` [role: merchant]

```json
{
  "date": "2026-06-19T10:30:00Z",
  "customer_name": "Pak Eko",
  "customer_phone": "081234567890",
  "payment_method": "cash",  // cash | qris | card | tab
  "notes": "makan siang 4 orang",
  "cash_received": 100000,
  "items": [
    {
      "product_id": "uuid",  // atau null untuk item custom
      "product_name": "Nasi Goreng",
      "quantity": 2,
      "unit_price": 25000,
      "unit_cost": 15000,    // HPP — untuk laporan laba
      "discount": 0
    }
  ]
}
```

**Otomasi di backend saat create transaksi:**
1. Hitung `subtotal`, `grand_total`, `total_cost`, `gross_profit`
2. Simpan `PosTransaction` + `PosTransactionItems`
3. Jika `track_stock = true` pada produk: kurangi `products.stock_quantity` + buat `StockMovement` (type=out)
4. Jika `payment_method = "tab"`: otomatis buat `MerchantReceivable` (piutang) dengan amount = grand_total

### 7.3 Void / Retur

`POST /api/v1/my-store/pos/transactions/:id/void` [role: merchant]

```json
{ "reason": "Pesanan salah, customer cancel" }
```

**Otomasi:**
1. Set `PosTransaction.status = "voided"`
2. Untuk setiap item yang `track_stock=true`: kembalikan stok + buat `StockMovement` (type=void)

### 7.4 Manajemen Stok Manual

```
GET /api/v1/my-store/pos/products                   → produk + status stok + alert low-stock
PUT /api/v1/my-store/pos/products/:id/stock         → tambah/koreksi stok manual
    { "type": "in", "quantity": 50, "cost_price": 8000, "reason": "Restok dari supplier" }
GET /api/v1/my-store/pos/products/:id/stock-history → riwayat pergerakan stok
```

### 7.5 Piutang (Receivables / Tab)

```
GET  /api/v1/my-store/pos/receivables           → list semua piutang
POST /api/v1/my-store/pos/receivables           → buat piutang manual (tanpa transaksi POS)
GET  /api/v1/my-store/pos/receivables/:id       → detail + riwayat pembayaran
POST /api/v1/my-store/pos/receivables/:id/pay   → catat pembayaran
     { "amount": 25000, "method": "cash", "date": "2026-06-19" }
```

Status otomatis berubah: `paid_amount` vs `amount`:
- `paid_amount = 0` → `unpaid`
- `0 < paid_amount < amount` → `partial`
- `paid_amount >= amount` → `paid`

### 7.6 Hutang Supplier (Payables)

```
GET  /api/v1/my-store/pos/payables           → list semua hutang
POST /api/v1/my-store/pos/payables           → buat hutang baru
GET  /api/v1/my-store/pos/payables/:id       → detail + riwayat pembayaran
POST /api/v1/my-store/pos/payables/:id/pay  → catat pembayaran ke supplier
```

### 7.7 Laporan Keuangan

```
GET /api/v1/my-store/pos/reports/summary
    ?start=2026-06-01&end=2026-06-30
    → { total_revenue, total_cost, gross_profit, transaction_count }

GET /api/v1/my-store/pos/reports/laba-rugi
    → Pendapatan → HPP → Laba Kotor → Beban → Laba Bersih

GET /api/v1/my-store/pos/reports/arus-kas
    → Breakdown per payment_method + ringkasan piutang/hutang

GET /api/v1/my-store/pos/reports/stok
    → Status stok semua produk + total nilai stok
```

---

## 8. Financial Model & Pricing Engine

### 8.1 Food / Ecommerce Order

```
Base Price (harga merchant):            Rp  50.000
Platform Markup 15%:                    Rp   7.500
                                       ────────────
Harga produk ke customer:               Rp  57.500
Delivery Fee (dalam zona):              Rp  15.000
                                       ════════════
TOTAL DIBAYAR CUSTOMER (COD):           Rp  72.500

DISTRIBUSI:
→ Merchant menerima:    Rp 50.000   (base price, 100%)
→ Driver mendapat:      Rp 11.250   (75% dari Rp 15.000)
→ KUWRIR revenue:       Rp 11.250   (Rp 7.500 markup + Rp 3.750 komisi delivery)
```

**Catatan delivery fee:**
- Dalam zona (≤5km): flat Rp 15.000
- Luar zona (>5km): Rp 10.000/km (no flat fee minimum)

### 8.2 Service (Jasa) Order

```
Base Price laundry 4kg × Rp 8.000:     Rp  32.000
Platform Markup 15%:                    Rp   4.800
Round-trip Delivery Fee:                Rp  20.000
                                       ════════════
TOTAL DIBAYAR CUSTOMER (COD saat barang kembali): Rp 56.800

DISTRIBUSI:
→ Merchant menerima:    Rp 32.000   (base price)
→ Driver mendapat:      Rp 15.000   (75% dari Rp 20.000, cover 2 leg)
→ KUWRIR revenue:       Rp  9.800   (Rp 4.800 markup + Rp 5.000 komisi delivery)
```

**Catatan:** Customer membayar COD satu kali saat barang dikembalikan (leg 2), bukan saat pickup.

### 8.3 POS / Kasir (Walk-in, No Delivery)

```
Harga jual:             Rp 50.000  (100% masuk merchant, 0% platform markup)
Payment:                cash | qris | card | tab

Tab → MerchantReceivable (piutang) dibuat otomatis
```

### 8.4 Promo Code Calculation

Tipe promo dan cara hitungnya:

| Type | Formula | Contoh |
|---|---|---|
| `percentage` | discount = min(total × value%, max_discount) | 10% maks Rp 20.000 |
| `fixed` | discount = min(value, total) | Rp 15.000 off |
| `free_delivery` | discount = delivery_fee | gratis ongkir |

Validasi promo:
- `is_active = true`
- Waktu sekarang antara `starts_at` dan `expires_at`
- `total >= min_order`
- `used_count < usage_limit` (jika usage_limit > 0)

---

## 9. Driver COD Balance System

### 9.1 Alur Uang COD

```
Customer bayar COD ke driver saat pengiriman selesai
              │
              ▼
driver.cash_balance += driver_earning (75% delivery fee)
              │
[Driver mengumpulkan cash dari beberapa order]
              │
              ▼
Driver setor cash ke admin KUWRIR
              │
    Admin catat via:
    POST /admin/drivers/:id/deposits
    { "amount": 150000, "method": "cash", "reference": "..." }
              │
              ▼
    driver.cash_balance -= amount  (atomic transaction)
    DriverDeposit record dibuat
```

### 9.2 Dashboard Driver COD

```
GET /admin/drivers/:id/deposits
→ {
    driver: { ...driver info, cash_balance: 150000 },
    deposits: [ ...riwayat setoran ],
    cash_balance: 150000  // saldo yang masih perlu disetor
  }
```

### 9.3 KPI di Admin Dashboard

```
pending_driver_cash = SUM(driver.cash_balance) untuk semua driver
```
Ini menunjukkan total uang COD yang masih ada di tangan driver seluruh platform.

---

## 10. Merchant Settlement System

### 10.1 Alur Settlement

```
[Admin inisiasi settlement per merchant per periode]

POST /admin/settlements/merchants/:merchantId/process
{
  "period_start": "2026-06-01",
  "period_end": "2026-06-30",
  "reference": "BCA-20260630-001"
}

Backend hitung:
  SELECT COUNT(id), SUM(subtotal) FROM orders
  WHERE merchant_id = ? 
    AND status = 'delivered'
    AND delivered_at BETWEEN period_start AND period_end

Buat MerchantSettlement:
  - total_orders = count
  - total_base_product_amount = sum(subtotal)  ← INI yang ditransfer ke merchant
  - status = "pending"

[Admin transfer uang ke merchant via bank]

PUT /admin/settlements/:id/mark-paid
{ "reference": "TRANSFER-20260701-001" }
```

### 10.2 Yang Termasuk dalam Settlement

- `total_base_product_amount` = jumlah `subtotal` dari semua order yang delivered di periode itu
- `subtotal` = sum(base_price × qty) dari order items
- **Tidak termasuk:** markup 15% dan delivery fee — itu revenue KUWRIR
- **Tidak termasuk:** POS transactions (merchant langsung terima kas dari walk-in)

### 10.3 Platform-Level Financial Overview

```
GET /admin/settlements
→ {
    total_driver_cash: SUM(driver.cash_balance),     // total COD di driver
    total_platform_revenue: SUM(markup + commission), // pendapatan KUWRIR dari delivered orders
    pending_merchant_payout: SUM(settlement.amount where status=pending)
  }
```

---

## 11. Promotion System

### 11.1 CRUD Promo (Admin Only)

```
GET    /admin/promotions          → list semua promo
POST   /admin/promotions          → buat promo baru
PUT    /admin/promotions/:id      → update promo
DELETE /admin/promotions/:id      → hapus promo (soft delete)
PUT    /admin/promotions/:id/toggle → toggle aktif/nonaktif
```

### 11.2 Tipe Promo

| Type | Deskripsi | Field yang Relevan |
|---|---|---|
| `percentage` | Diskon persen dari total | `value` (%), `max_discount` (batas IDR) |
| `fixed` | Potongan langsung IDR | `value` (IDR) |
| `free_delivery` | Gratis ongkir | `value` (diabaikan) |

### 11.3 Validasi Saat Apply

1. Code ditemukan dan `is_active = true`
2. Waktu sekarang: `starts_at ≤ now ≤ expires_at`
3. `order.total ≥ promo.min_order`
4. `promo.usage_limit = 0` ATAU `promo.used_count < promo.usage_limit`

**Catatan:** Setelah order berhasil, `used_count` harus di-increment. Saat ini belum ada mekanisme ini di handler customer — ini adalah gap.

---

## 12. Admin Panel Capabilities

### 12.1 Dashboard KPI

`GET /admin/dashboard/stats`

```json
{
  "orders": {
    "total": 1250,
    "today": 23,
    "active": 5      // status bukan delivered/cancelled
  },
  "merchants": {
    "total": 45,
    "verified": 38,
    "open": 12,
    "pending": 7     // belum diverifikasi
  },
  "drivers": {
    "total": 30,
    "online": 8
  },
  "customers": {
    "total": 580
  },
  "revenue": {
    "this_month": 4250000  // platform_markup + delivery_commission dari delivered orders bulan ini
  },
  "pending_driver_cash": 1875000  // total COD di tangan semua driver
}
```

### 12.2 User Management

| Aksi | Endpoint | Detail |
|---|---|---|
| Lihat semua merchant | `GET /admin/merchants` | Semua record, termasuk yang pending |
| Approve/reject merchant | `PUT /admin/merchants/:id/verify` | `{ verified: true/false, note: "..." }` |
| Lihat semua driver | `GET /admin/drivers` | Preload user info |
| Lihat semua customer | `GET /admin/customers` | Filter by role=customer |
| Suspend / aktifkan user | `PUT /admin/users/:id/toggle-active` | Toggle is_active |
| Lihat aplikasi driver | `GET /admin/driver-applications?status=` | Filter by pending/approved/rejected |
| Review aplikasi driver | `PUT /admin/driver-applications/:id/review` | `{ approved: true/false, note: "..." }` |

### 12.3 Order Management

`GET /admin/orders?status=` — list semua order dengan filter status opsional, preload merchant + customer + driver + items.

### 12.4 Financial Management

| Aksi | Endpoint |
|---|---|
| Platform overview | `GET /admin/settlements` |
| Per-merchant pending payout | `GET /admin/settlements/merchants` |
| Buat settlement | `POST /admin/settlements/merchants/:merchantId/process` |
| Mark paid | `PUT /admin/settlements/:id/mark-paid` |
| Lihat deposit history driver | `GET /admin/drivers/:id/deposits` |
| Catat deposit dari driver | `POST /admin/drivers/:id/deposits` |

### 12.5 Settings

```
GET /admin/settings          → list semua system settings
PUT /admin/settings/:key     → update satu setting
    { "value": "20" }
```

---

## 13. API Reference Lengkap

### Base URL
- **Prod:** `http://43.134.172.254:8090/api/v1`
- **Dev:** `http://localhost:8080/api/v1`

### Public (No Auth)

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/auth/register` | Register user |
| POST | `/auth/login` | Login |
| GET | `/merchants` | List food merchants (verified + active) |
| GET | `/merchants/nearby?lat=&lng=&radius=` | Merchant terdekat (Haversine, default 5km) |
| GET | `/merchants/search?q=` | Cari merchant by keyword |
| GET | `/merchants/:id` | Detail merchant |
| GET | `/merchants/:id/products` | Katalog produk merchant |

### Customer [role: customer]

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/orders` | Buat food order |
| GET | `/orders` | List food orders saya |
| GET | `/orders/:id` | Detail food order |
| POST | `/orders/:id/cancel` | Cancel (hanya dari PENDING) |
| POST | `/service-orders` | Book service order |
| GET | `/service-orders` | List service orders saya |
| GET | `/service-orders/:id` | Detail service order |
| POST | `/service-orders/:id/cancel` | Cancel (hanya dari PENDING) |

### Merchant [role: merchant]

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/my-store` | Register toko (multipart) |
| GET | `/my-store/status` | Status verifikasi |
| GET | `/my-store` | Info toko + katalog lengkap |
| PUT | `/my-store` | Update profil toko |
| PUT | `/my-store/toggle-open` | Toggle buka/tutup |
| PUT | `/my-store/toggle-self-deliver` | Toggle self-delivery |
| PUT | `/my-store/self-delivery-fee` | Set self-delivery fee |
| GET | `/my-store/my-deliveries` | Order yang perlu diantar sendiri |
| POST | `/my-store/my-deliveries/:id/pickup` | Mark picked up |
| POST | `/my-store/my-deliveries/:id/deliver` | Mark delivered |
| POST | `/my-store/categories` | Buat kategori |
| PUT | `/my-store/categories/:catId` | Update kategori |
| DELETE | `/my-store/categories/:catId` | Hapus kategori |
| POST | `/my-store/categories/:catId/products` | Buat produk |
| PUT | `/my-store/products/:productId` | Update produk |
| DELETE | `/my-store/products/:productId` | Hapus produk |
| PUT | `/my-store/products/:productId/toggle` | Toggle available |
| POST | `/my-store/products/:productId/variants` | Buat varian |
| DELETE | `/my-store/variants/:variantId` | Hapus varian |
| GET | `/restaurant-orders` | Antrian food order masuk |
| POST | `/restaurant-orders/:id/accept` | Accept → CONFIRMED |
| POST | `/restaurant-orders/:id/preparing` | → PREPARING |
| POST | `/restaurant-orders/:id/ready` | → READY |
| GET | `/my-service-orders` | Antrian service order |
| POST | `/my-service-orders/:id/confirm` | → CONFIRMED |
| POST | `/my-service-orders/:id/in-service` | → IN_SERVICE |
| POST | `/my-service-orders/:id/ready` | → READY_FOR_RETURN |
| **POS** | | |
| POST | `/my-store/pos/transactions` | Buat transaksi POS |
| GET | `/my-store/pos/transactions` | List transaksi |
| GET | `/my-store/pos/transactions/:id` | Detail + items |
| POST | `/my-store/pos/transactions/:id/void` | Void transaksi |
| GET | `/my-store/pos/products` | Produk + stok |
| PUT | `/my-store/pos/products/:id/stock` | Koreksi stok manual |
| GET | `/my-store/pos/products/:id/stock-history` | Riwayat pergerakan stok |
| GET/POST | `/my-store/pos/receivables` | List + buat piutang |
| GET | `/my-store/pos/receivables/:id` | Detail piutang |
| POST | `/my-store/pos/receivables/:id/pay` | Bayar piutang |
| GET/POST | `/my-store/pos/payables` | List + buat hutang |
| GET | `/my-store/pos/payables/:id` | Detail hutang |
| POST | `/my-store/pos/payables/:id/pay` | Bayar hutang |
| GET | `/my-store/pos/reports/summary` | Ringkasan keuangan |
| GET | `/my-store/pos/reports/laba-rugi` | Laporan P&L |
| GET | `/my-store/pos/reports/arus-kas` | Laporan arus kas |
| GET | `/my-store/pos/reports/stok` | Status stok |

### Driver [role: driver]

| Method | Endpoint | Deskripsi |
|---|---|---|
| POST | `/driver/apply` | Submit aplikasi + dokumen (multipart) |
| GET | `/driver/application` | Status aplikasi |
| GET | `/driver-orders/available` | Food order yang READY |
| POST | `/driver-orders/:id/accept` | Accept food order |
| POST | `/driver-orders/:id/pickup` | Pickup dari merchant |
| POST | `/driver-orders/:id/deliver` | Delivered + COD dikumpul |
| GET | `/driver/service-orders/available` | Service jobs tersedia |
| POST | `/driver/service-orders/:id/accept-pickup` | Accept leg 1 |
| POST | `/driver/service-orders/:id/item-picked-up` | Barang sudah diambil |
| POST | `/driver/service-orders/:id/accept-return` | Accept leg 2 |
| POST | `/driver/service-orders/:id/returned` | Selesai antar balik |

### Admin [role: admin]

| Method | Endpoint | Deskripsi |
|---|---|---|
| GET | `/admin/dashboard/stats` | KPI live |
| GET | `/admin/settings` | Semua settings |
| PUT | `/admin/settings/:key` | Update setting |
| GET | `/admin/merchants` | Semua merchants |
| PUT | `/admin/merchants/:id/verify` | Approve/reject merchant |
| GET | `/admin/drivers` | Semua drivers |
| GET | `/admin/customers` | Semua customers |
| PUT | `/admin/users/:id/toggle-active` | Suspend/aktifkan |
| GET | `/admin/driver-applications?status=` | Aplikasi driver |
| PUT | `/admin/driver-applications/:id/review` | Review aplikasi driver |
| GET | `/admin/drivers/:id/deposits` | Riwayat deposit driver |
| POST | `/admin/drivers/:id/deposits` | Catat deposit COD |
| GET | `/admin/orders?status=` | Semua order |
| GET | `/admin/settlements` | Overview keuangan platform |
| GET | `/admin/settlements/merchants` | Per-merchant payout |
| POST | `/admin/settlements/merchants/:merchantId/process` | Buat settlement |
| PUT | `/admin/settlements/:id/mark-paid` | Mark paid |
| GET | `/admin/promotions` | List promo |
| POST | `/admin/promotions` | Buat promo |
| PUT | `/admin/promotions/:id` | Update promo |
| DELETE | `/admin/promotions/:id` | Hapus promo |
| PUT | `/admin/promotions/:id/toggle` | Toggle aktif |

---

## 14. Konfigurasi & System Settings

### Environment Variables (`.env`)

```env
# Database
DATABASE_DSN=postgres://kuwrir:password@localhost:5432/kuwrir_db?sslmode=disable

# Redis
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-secret-here
JWT_EXPIRY_HOURS=24
JWT_REFRESH_EXPIRY_HOURS=720  # 30 hari

# Server
SERVER_PORT=8080
SERVER_MODE=debug  # atau release
```

### System Settings (Configurable via Admin)

| Key | Default | Satuan |
|---|---|---|
| `platform_markup_percentage` | 15 | % |
| `delivery_commission_percentage` | 25 | % |
| `delivery_base_fee_inside_zone` | 15000 | IDR |
| `delivery_fee_per_km_outside` | 10000 | IDR/km |
| `service_delivery_fee_round_trip` | 20000 | IDR |

---

## 15. Infrastruktur & Deployment

### Docker Services

| Service | Image | Port | Keterangan |
|---|---|---|---|
| `kuwrir-backend` | ghcr.io/jiadmiftx/kuwrir-aja/backend | 8090 | API Go |
| `kuwrir-admin` | ghcr.io/jiadmiftx/kuwrir-aja/admin | 8091 | React/Nginx |
| `kuwrir-postgres` | postgis/postgis:16-3.4 | internal | DB |
| `kuwrir-redis` | redis:7-alpine | internal | Cache |

### CI/CD (GitHub Actions)

| Workflow | Trigger | Aksi |
|---|---|---|
| `deploy-backend.yml` | Push ke `main`, path `backend/**` | Build → Push GHCR → SSH deploy |
| `deploy-admin.yml` | Push ke `main`, path `admin_panel/**` | Build → Push GHCR → SSH deploy |
| `firebase-distribution.yml` | Push ke `main`, path `customer_app/` atau `driver_app/` atau `merchant_app/` | Flutter build APK → Firebase App Distribution |

### File Storage

**Saat ini:** Local disk `./uploads/driver-docs/` dan `./uploads/merchant-docs/`

**Swap ke R2:** Ganti body `upload.Save()` di `backend/internal/upload/upload.go` — tidak ada kode lain yang perlu diubah.

### Default Admin

- **Phone:** `080000000000`
- **Password:** `admin123`
- Dibuat manual via register API + SQL: `UPDATE users SET role='admin', is_active=true WHERE phone='080000000000'`

---

## 16. Catatan Revamp & Gap Analysis

### 16.1 Gap yang Sudah Diidentifikasi

| # | Gap | Dampak | Prioritas |
|---|---|---|---|
| 1 | `used_count` promo tidak di-increment saat order placed | Promo bisa dipakai unlimited meski ada limit | TINGGI |
| 2 | Tidak ada endpoint untuk service merchants public browsing | Customer tidak bisa browse merchant jasa | TINGGI |
| 3 | Tidak ada validasi status transition (misal: bisa deliver langsung dari pending) | Data inconsistency | TINGGI |
| 4 | Review/rating belum ada endpoint (Phase 7) | `rating` dan `total_reviews` tidak pernah terupdate | SEDANG |
| 5 | `email` bisa kosong tapi punya UNIQUE INDEX → akan error jika 2 user tanpa email | Registration tidak validate email properly | SEDANG |
| 6 | Driver bisa accept order padahal `is_available=false` atau `is_online=false` | Konflik order | SEDANG |
| 7 | `slug` merchant tidak handle collision (jika 2 merchant sama namanya) | DB error saat create | SEDANG |
| 8 | Tidak ada pagination di semua GET list endpoint | Performance issue saat data banyak | SEDANG |
| 9 | JWT refresh token tidak bisa di-revoke / tidak ada blacklist | Security: token valid sampai expiry meski logout | RENDAH |
| 10 | `settlement` tidak di-exclude order yang sudah di-settle sebelumnya | Double-counting jika settlement dibuat 2x untuk periode sama | TINGGI |
| 11 | Tidak ada WebSocket / real-time update (Phase 7) | Driver/customer harus polling manual | RENDAH (scope Phase 7) |
| 12 | Push notification FCM belum dihubungkan ke backend | Firebase terpasang di Flutter tapi backend tidak kirim notif | SEDANG |
| 13 | Tidak ada address selector di flow customer order | Customer harus input alamat manual setiap order | SEDANG (UX) |

### 16.2 Area yang Perlu Dipertimbangkan untuk Revamp

**Order Assignment:**
- Saat ini driver *pull* (lihat list, pilih sendiri)
- Alternatif: *push* (sistem assign ke driver terdekat secara otomatis)

**Settlement Logic:**
- Saat ini: admin hitung manual per periode
- Perlu: exclude orders yang sudah masuk settlement sebelumnya (add `settlement_id` ke `orders`)

**Merchant Type:**
- `service_category` saat ini di level `Merchant`
- Pertimbangkan: satu merchant bisa punya multi-kategori layanan?

**Pricing:**
- Saat ini: satu flat fee semua zone
- Revamp: distance-based dengan Valhalla routing (infrastruktur sudah ada tapi belum terhubung)

**Driver Availability:**
- Tidak ada sistem yang cegah driver ambil 2 order sekaligus
- Perlu: lock `is_available=false` saat driver aktif mengerjakan order

**Auth:**
- Tidak ada `/auth/logout` yang invalidate token
- Tidak ada `/auth/refresh` endpoint
- Refresh token disimpan di mana? (client-side, tidak ada server-side storage)

### 16.3 Phase Roadmap

| Phase | Status | Isi |
|---|---|---|
| 1–6 | ✅ Done | Backend penuh, admin panel, Flutter apps, POS/Kasir, service orders, registration |
| 7 | ⬜ Planned | Reviews & ratings, WebSocket real-time, FCM push notifications |
| 8 | ⬜ Planned | File upload → Cloudflare R2, pembayaran digital (QRIS/Xendit) |
| 9 | ⬜ Belum ada | Distance-based pricing (Valhalla), driver auto-assignment, pagination |
