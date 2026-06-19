# KUWRIR Platform — CHANGELOG

All notable changes to the KUWRIR food delivery platform are documented in this file.
Format: Added · Changed · Fixed · Removed

---

## [1.0.0] — 2026-06-01 · Full MVP Release

### Summary
Complete MVP encompassing food delivery, jasa (service) orders, POS/Kasir, full admin panel, driver/merchant verification with document upload, and service order flow for laundry/bengkel/salon/cleaning.

---

## [0.7.0] — 2026-06-01 · Phase 6d: Service (Jasa) Orders

### Backend
#### Added
- **Service order models** in `models.go`:
  - `OrderStatus` extended: `awaiting_pickup`, `item_picked_up`, `in_service`, `ready_for_return`, `returning`, `returned`
  - `MerchantType` enum: `food` | `service`
  - `Merchant`: fields `type`, `service_category` (laundry/bengkel/cleaning/salon/other)
  - `Product`: fields `price_unit` (per_item/per_kg/per_service/per_hour), `duration_estimate`
  - `Order`: fields `pickup_scheduled_at`, `service_notes`, `return_address`, `return_lat/lng`, `weight_kg`, timestamps `item_picked_up_at`, `in_service_at`, `ready_for_return_at`, `returned_at`

- **Service Handler** (`internal/handler/service/handler.go`) — 13 new endpoints:
  - **Public:** `GET /service-merchants` (filter by category + geospatial), `GET /service-merchants/:id/services`
  - **Customer:** `POST /service-orders` (booking + COD pricing breakdown), `GET /service-orders`, `GET /service-orders/:id`, `POST /service-orders/:id/cancel`
  - **Merchant:** `GET /my-service-orders`, `POST /my-service-orders/:id/confirm`, `POST /my-service-orders/:id/in-service`, `POST /my-service-orders/:id/ready`
  - **Driver:** `GET /driver/service-orders/available` (returns two job types: pickup + return), `POST .../accept-pickup`, `POST .../item-picked-up`, `POST .../accept-return`, `POST .../returned` (COD collected → updates driver cash_balance)
- Service COD pricing: `base + 15% markup + flat round-trip delivery fee`
- New system setting: `service_delivery_fee_round_trip` (default IDR 20,000)

### Customer App (Flutter)
#### Added
- **ServiceHomeScreen** (`service_home_screen.dart`): browse service merchants by category (laundry/bengkel/cleaning/salon) with category filter chips, merchant cards with service previews
- **ServiceBookingScreen** (`service_booking_screen.dart`): select services with per-kg/per-item support, weight slider for laundry, pickup schedule picker, address input, COD pricing summary, confirm dialog
- **ServiceTrackingScreen** (`service_tracking_screen.dart`): 8-step status timeline (pending → confirmed → awaiting_pickup → item_picked_up → in_service → ready_for_return → returning → returned), COD reminder card
- `main.dart` updated: 4-tab bottom nav (Makanan | Jasa | Pesanan | Profil)

### Restaurant App (Flutter)
#### Added
- **ServiceOrdersScreen** (`service_orders_screen.dart`): 4-tab order management (Baru/Diambil/Dikerjakan/Siap), action buttons per status, service notes display, special instructions highlight

### Driver App (Flutter)
#### Added
- **ServiceJobsScreen** (`service_jobs_screen.dart`): 2-tab (Jemput / Antar Balik), job cards with route, earnings, COD amount for return jobs, active job screen with step-by-step navigation
- `job_board_screen.dart`: 2-tab (Makanan / Jasa)

---

## [0.6.3] — 2026-06-01 · Phase 6c: Registration & Verification

### Backend
#### Added
- **DriverApplication model**: vehicle info + 5 doc URL fields (KTP, SIM, STNK, selfie, vehicle photo) + status + review note
- **Upload helper** (`internal/upload/upload.go`): saves files to `./uploads/<folder>/` locally. Single function `upload.Save()` to swap for R2.
- **Static file server**: `r.Static("/uploads", "./uploads")` — serves uploaded docs
- `auth.Register` updated: driver/merchant accounts start `is_active=false` and receive no JWT token
- **Driver Registration Handler** (`internal/handler/driverreg/handler.go`):
  - `POST /driver/apply` — multipart upload of 5 documents + vehicle info. Upserts application.
  - `GET /driver/application` — returns application status + `is_active` flag
- **Admin endpoints for driver review** (via `driverreg` functions registered in admin handler):
  - `GET /admin/driver-applications?status=` — list applications
  - `PUT /admin/driver-applications/:id/review` — approve (creates Driver record, activates user) or reject
- **Merchant registration updated** (`merchant.CreateMerchant`): accepts multipart/form-data, uploads KTP/biz license/store photo, stores `verification_status=pending`, `is_active=false`
- `GET /my-store/status` — merchant polls verification status
- `PUT /admin/merchants/:id/verify` updated: sets `verification_status`, `verification_note`, `verified_by_id`, `verified_at`
- **Merchant model**: added `owner_ktp_url`, `business_license_url`, `store_photo_url`, `verification_status`, `verification_note`, `verified_by_id`, `verified_at`

### Driver App (Flutter)
#### Added
- `register_screen.dart` — Step 1: account data (name, phone, email, password)
- `onboarding_screen.dart` — Step 2: vehicle info + upload 5 documents (camera/gallery picker per doc), all-docs-uploaded progress indicator
- `pending_screen.dart` — Step 3: polls `GET /driver/application` every 30s, shows pending/approved/rejected state, auto-navigates to job board on approval
- `login_screen.dart` updated: "Daftar sebagai Driver" link added

### Restaurant App (Flutter)
#### Added
- `login_screen.dart` — Merchant login with register link, detects `is_active=false` → redirects to pending screen
- `register_screen.dart` — 3-step form: (1) owner account, (2) store details + coordinates, (3) doc upload (KTP, SIUP, store photo)
- `pending_screen.dart` — polls `GET /my-store/status` every 30s, shows verification state + admin note, re-register link on rejection
- `main.dart` updated: initialRoute `/login`, named routes for `/register`, `/pending`, `/home`

### Admin Panel (React)
#### Added
- **DriverApplicationsPage** (`DriverApplicationsPage.tsx`): 3-tab (Menunggu/Disetujui/Ditolak), table with document status badges, detail dialog with 5 doc image previews, Approve/Reject with note, live status update in table
- `App.tsx`: route `/driver-applications` added
- `AdminLayout.tsx`: "Driver Applications" nav link added (ClipboardList icon, between Drivers and Customers)

---

## [0.6.2] — 2026-06-01 · Phase 6b: Admin Panel Full Completion

### Backend
#### Added
- `GET /admin/dashboard/stats` — live KPIs: orders (total/today/active), merchants (total/verified/open/pending), drivers (total/online), customers, monthly revenue, pending driver cash
- `PUT /admin/merchants/:id/verify` — approve/reject with note
- `PUT /admin/users/:id/toggle-active` — suspend/activate any user
- `GET /admin/drivers/:id/deposits` — deposit history per driver
- `POST /admin/drivers/:id/deposits` — record COD deposit, deducts `cash_balance`
- `GET /admin/settlements/merchants` — per-merchant breakdown + settlement history
- `POST /admin/settlements/merchants/:id/process` — create settlement for a period
- `PUT /admin/settlements/:id/mark-paid` — mark paid + reference
- `GET/POST/PUT/DELETE /admin/promotions` — full promo CRUD
- `PUT /admin/promotions/:id/toggle` — activate/deactivate

### Admin Panel (React)
#### Changed
- **DashboardPage**: all 6 KPI cards now fetch from `GET /admin/dashboard/stats`, loading skeleton, pending merchant alert banner
- **MerchantsPage**: Approve/Reject calls API, loading state per button, updates UI without reload
- **DriversPage**: suspend/activate button connected, "Setor" button (only when cash_balance > 0), deposit dialog (amount + method + reference), deposit history dialog
- **CustomersPage**: suspend/activate toggle connected to API, badge shows Active/Suspended, stats cards
- **SettlementsPage**: 2 tabs (Payout ke Merchant / Riwayat Settlement), per-merchant breakdown table, "Proses Payout" dialog with period picker, "Mark as Paid" dialog
- **PromotionsPage**: full CRUD — create/edit dialog (code, type, value, min_order, max_discount, usage_limit, dates), toggle active, delete confirm, expired badge

---

## [0.6.1] — 2026-06-01 · Phase 6a: POS/Kasir + Financial Integration

### Backend
#### Added
- `Product`: `cost_price` (HPP/harga beli), `min_stock` (low-stock alert threshold)
- **POS models** (7 new tables): `StockMovement`, `PosTransaction`, `PosTransactionItem`, `MerchantReceivable`, `MerchantReceivablePayment`, `MerchantPayable`, `MerchantPayablePayment`
- **Kasir Handler** (`internal/handler/kasir/handler.go`) — 17 endpoints at `/my-store/pos`:
  - Transactions: create (with stock auto-decrement + piutang auto-create for tab), list, get, void (reverses stock)
  - Stock: list with low-stock alerts, adjust (in/opname), history
  - Receivables (piutang): list, create, get, pay
  - Payables (hutang): list, create, get, pay
  - Reports: summary (daily breakdown), laba-rugi (P&L), arus-kas (by payment method), stok

### Restaurant App (Flutter)
#### Added
- `kasir_screen.dart` — POS Terminal: 2-tab (product grid / cart), category filter, low-stock badges, cart with HPP display, real-time gross profit, 4 payment methods (cash/qris/card/tab), cash change calculator, discount dialog, order confirmation with breakdown
- `kasir_reports_screen.dart` — 3-tab laporan: Laba Rugi (P&L with %, outstanding), Arus Kas (breakdown by method + piutang/hutang flow), Stok (value, low-stock alerts)
- `kasir_receivables_screen.dart` — piutang list with filter, payment dialog, manual create, overdue detection
- `kasir_payables_screen.dart` — hutang supplier list, payment dialog, manual create
- `main.dart` updated: "Kasir" tab added to bottom nav, `KasirHub` widget as entry point

---

## [0.5.0] — 2026-05-11 · Phase 5: Admin Panel Integration

### Backend
#### Added
- Admin endpoints: `GET /admin/drivers`, `/admin/customers`, `/admin/merchants`, `/admin/orders`, `/admin/settlements`

### Admin Panel (React)
#### Added
- OrdersPage with status filter tabs, search, KUWRIR revenue column
- RestaurantsPage with approve/reject UI
- SettlementsPage (basic — enhanced in 0.6.2)

---

## [0.4.0] — 2026-05-10 · Phase 4: Driver App + Order Fulfillment

### Backend
#### Added
- Driver order endpoints: `GET /driver-orders/available`, `POST .../accept`, `POST .../pickup`, `POST .../deliver` (updates driver cash balance)
- Self-delivery: `PUT /my-store/toggle-self-deliver`, `PUT /my-store/self-delivery-fee`, `GET /my-store/my-deliveries`, pickup/deliver endpoints
- Merchant cash flow (self-delivery): no platform delivery commission charged

### Driver App (Flutter)
#### Added
- `job_board_screen.dart` — available orders with earnings + distance
- `active_delivery_screen.dart` — pickup/deliver actions
- `wallet_screen.dart` — COD cash balance tracking
- Auth provider + routing

---

## [0.3.0] — 2026-05-07 · Phase 3: Cart & Orders + COD

### Backend
#### Added
- **COD Pricing Engine** (`POST /orders`): reads system settings, haversine distance, applies markup + delivery commission, generates order number (`KWR-YYMMDDHHMMSS`), returns full pricing breakdown
- **Order State Machine**: pending → confirmed → preparing → ready → picked_up → delivered; cancel only from pending
- Customer order endpoints: list, detail, cancel
- Restaurant order management: accept, preparing, ready
- Driver order endpoints: available, accept, pickup, deliver

### Admin Panel
#### Added
- Orders page with status tabs, search, revenue column

### Customer App (Flutter)
#### Added
- Cart screen with quantity controls, COD badge
- Checkout screen with delivery address, order summary, place order
- Order tracking with 6-step timeline

### Restaurant App (Flutter)
#### Added
- Live order queue with status action buttons (Accept/Preparing/Ready)

---

## [0.2.0] — 2026-05-07 · Phase 2: Restaurant & Menu System

### Backend
#### Added
- Restaurant handler: public (list, nearby, search, detail, menu) + owner CRUD (categories, items, addons)
- Full menu preloading: Categories → Items → Addons

### Admin Panel
#### Added
- Restaurants page with stats, search, approve/reject UI

### Customer App (Flutter)
#### Added
- Home screen (location header, category chips, nearby restaurants)
- Restaurant detail screen (collapsible app bar, menu by category, add-to-cart)
- Search screen

### Restaurant App (Flutter)
#### Added
- Bottom nav (Orders / Menu / Store)
- Menu management (category + item CRUD, availability toggle)
- Store profile screen

---

## [0.1.0] — 2026-05-06 · Phase 1: Foundation

### Backend
#### Added
- Go project scaffold (Gin + GORM + JWT)
- 14 initial models (User, Address, Merchant, ProductCategory, Product, ProductVariant, Driver, Order, OrderItem, Review, SystemSetting, DriverDeposit, MerchantSettlement, Promotion)
- Auth: register + login (bcrypt + JWT access/refresh)
- Admin: system settings GET/PUT
- Docker Compose: PostgreSQL 16+PostGIS, Redis, Valhalla, Nominatim
- Default settings seed: 15% markup, 25% delivery commission, IDR 15K zone fee

### Admin Panel
#### Added
- Vite + React + TypeScript scaffold
- Tailwind CSS v4 + shadcn/ui (15 components)
- Sidebar layout with all nav links
- Dashboard (6 KPI cards)
- Login page (phone + password)
- Settings page with live revenue calculator

### Flutter Apps
#### Added
- `customer_app` scaffold
- `driver_app` scaffold
- `merchant_app` scaffold
- `kuwrir_shared` package: ApiClient, ApiConfig, User model, Auth models, KuwrirTheme, KuwrirColors
