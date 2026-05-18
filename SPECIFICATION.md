# KUWRIR Platform — Technical Specification

> **Version:** 0.5.0 · **Last Updated:** 2026-05-11  
> **Target Region:** Kuta, Lombok, NTB, Indonesia  
> **Payment Model:** Cash on Delivery (COD) — MVP

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    KUWRIR Platform Architecture                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Customer │  │  Driver  │  │Restaurant│  Flutter Apps     │
│  │   App    │  │   App   │  │   App    │  (com.kuwrir.*)     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │              │              │                        │
│       └──────────┬───┴──────────────┘                       │
│                  │ HTTPS / JWT                              │
│       ┌──────────▼──────────┐                               │
│       │   KUWRIR Backend API  │  Golang + Gin                 │
│       │   :8080/api/v1      │                               │
│       └──────────┬──────────┘                               │
│                  │                                           │
│    ┌─────────────┼─────────────┐                            │
│    │             │             │                             │
│    ▼             ▼             ▼                             │
│ ┌──────┐   ┌──────┐    ┌──────────┐                         │
│ │ PG16 │   │Redis7│    │ Valhalla │   Docker Compose         │
│ │PostGIS│  │Cache │    │Nominatim │                          │
│ └──────┘   └──────┘    └──────────┘                         │
│                                                             │
│  ┌─────────────┐     ┌────────────────┐                     │
│  │  Admin Panel │     │ Cloudflare R2  │  External           │
│  │  React+Vite  │     │ Image Storage  │                     │
│  │  :5173       │     │ (Zero Egress)  │                     │
│  └─────────────┘     └────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

| Layer | Technology | Version |
|---|---|---|
| **Backend API** | Go + Gin Framework | Go 1.22+, Gin 1.10 |
| **ORM** | GORM | v2 |
| **Database** | PostgreSQL + PostGIS | 16 + 3.4 |
| **Cache** | Redis | 7 Alpine |
| **Routing Engine** | Valhalla | Latest |
| **Geocoding** | Nominatim | Latest |
| **Admin Panel** | React + Vite + TypeScript | React 19, Vite 8 |
| **Admin UI Kit** | shadcn/ui + Tailwind CSS v4 | Latest |
| **Mobile Apps** | Flutter | 3.x |
| **Shared Package** | Dart (kuwrir_shared) | 0.1.0 |
| **Image Storage** | Cloudflare R2 | S3-compatible |
| **Auth** | JWT (access + refresh tokens) | HS256 |

---

## 3. Project Structure

```
kuwrirProject/
├── backend/                          # Golang API Server
│   ├── cmd/server/main.go            # Entry point (auto-migrate, seed, routes)
│   ├── internal/
│   │   ├── config/config.go          # Environment configuration
│   │   ├── handler/
│   │   │   ├── admin/handler.go      # System settings CRUD
│   │   │   ├── auth/handler.go       # Register, Login (JWT)
│   │   │   ├── customer/handler.go   # Orders, Driver orders
│   │   │   └── restaurant/handler.go # Restaurant & menu CRUD
│   │   ├── middleware/auth.go        # JWT, RBAC, CORS
│   │   └── model/models.go          # 14 GORM models
│   ├── docker-compose.yml            # PG, Redis, Valhalla, Nominatim
│   └── .env.example                  # Configuration template
│
├── admin_panel/                      # React Admin Dashboard
│   └── src/
│       ├── components/
│       │   ├── layout/AdminLayout.tsx # Sidebar + navigation
│       │   └── ui/                   # 15 shadcn/ui components
│       ├── pages/
│       │   ├── DashboardPage.tsx      # KPI overview (6 cards)
│       │   ├── LoginPage.tsx          # Phone + password auth
│       │   ├── OrdersPage.tsx         # Order monitoring + revenue
│       │   ├── RestaurantsPage.tsx     # Approve/reject + search
│       │   └── SettingsPage.tsx       # Configurable fees + live calc
│       ├── lib/utils.ts               # shadcn utility functions
│       └── index.css                  # Tailwind + shadcn theme
│
├── customer_app/                     # Flutter Customer App
│   └── lib/
│       ├── main.dart                  # App entry + routing
│       └── screens/
│           ├── home_screen.dart       # Restaurant browsing
│           ├── restaurant_detail_screen.dart # Menu + add to cart
│           ├── search_screen.dart     # Search + categories
│           ├── cart_screen.dart       # Cart + checkout + place order
│           └── order_tracking_screen.dart # Status timeline
│
├── restaurant_app/                   # Flutter Restaurant App
│   └── lib/
│       ├── main.dart                  # App entry + bottom nav
│       └── screens/
│           ├── orders_screen.dart     # Live order queue + actions
│           ├── menu_screen.dart       # Category + item management
│           └── store_screen.dart      # Profile + toggle + stats
│
├── driver_app/                       # Flutter Driver App
│   └── lib/
│       ├── main.dart                  # App entry + Auth provider
│       └── screens/
│           ├── login_screen.dart      # Driver login
│           ├── job_board_screen.dart  # Available orders & acceptance
│           ├── active_delivery_screen.dart # Pickup & dropoff tracking
│           └── wallet_screen.dart     # COD cash balance tracking
│
├── shared/kuwrir_shared/               # Shared Flutter Package
│   └── lib/
│       ├── kuwrir_shared.dart           # Library exports
│       └── src/
│           ├── api/
│           │   ├── api_client.dart    # HTTP client + JWT tokens
│           │   └── api_config.dart    # Endpoints + base URL
│           ├── models/
│           │   ├── user.dart          # User model
│           │   └── auth.dart          # Auth request/response
│           └── theme/
│               ├── kuwrir_theme.dart    # Material 3 theme
│               └── kuwrir_colors.dart   # Brand color palette
│
├── CHANGELOG.md                      # Version history
├── README.md                         # Quick start guide
├── .gitignore                        # Monorepo ignores
└── project_proposal.md               # Original project proposal
```

---

## 4. Database Schema

### 4.1 Entity Relationship

```
User (1) ──── (1) Restaurant
User (1) ──── (1) Driver
User (1) ──── (*) Address
User (1) ──── (*) Order (as customer)

Restaurant (1) ──── (*) MenuCategory
MenuCategory (1) ──── (*) MenuItem
MenuItem (1) ──── (*) ItemAddon

Order (1) ──── (*) OrderItem
Order (*) ──── (1) Restaurant
Order (*) ──── (0..1) Driver
Order (1) ──── (0..1) Review

Driver (1) ──── (*) DriverDeposit
Restaurant (1) ──── (*) RestaurantSettlement
```

### 4.2 Models (14 tables)

| # | Model | Description | Key Fields |
|---|---|---|---|
| 1 | `User` | All platform users | name, email, phone, password, role, is_active |
| 2 | `Address` | Customer delivery addresses | user_id, label, address, lat/lng, is_default |
| 3 | `Restaurant` | Food businesses | user_id, name, slug, address, lat/lng, rating, is_verified, is_open |
| 4 | `MenuCategory` | Menu groupings | restaurant_id, name, sort_order |
| 5 | `MenuItem` | Food/drink items | category_id, name, price (base), image_url, is_available |
| 6 | `ItemAddon` | Item modifiers | menu_item_id, group_name, name, price, is_required |
| 7 | `Driver` | Delivery drivers | user_id, vehicle_type, vehicle_plate, lat/lng, is_online, cash_balance |
| 8 | `Order` | Customer orders | order_number, customer_id, restaurant_id, driver_id, status, pricing fields |
| 9 | `OrderItem` | Ordered items snapshot | order_id, menu_item_id, item_name, quantity, base_price, unit_price |
| 10 | `Review` | Post-delivery reviews | order_id, customer_id, restaurant_rating, driver_rating, comment |
| 11 | `SystemSetting` | Configurable parameters | key, value, label |
| 12 | `DriverDeposit` | Cash deposit records | driver_id, amount, method, verified_at |
| 13 | `RestaurantSettlement` | Monthly payouts | restaurant_id, period, total_orders, total_base_food_amount, status |
| 14 | `Promotion` | Promo codes | code, type, value, min_order, usage_limit, starts_at, expires_at |

### 4.3 User Roles

| Role | Description | Permissions |
|---|---|---|
| `customer` | End-user ordering food | Place/cancel orders, browse restaurants |
| `restaurant` | Restaurant owner | Manage menu, accept/prepare orders, view settlement |
| `driver` | Delivery driver | Accept deliveries, mark pickup/delivered |
| `admin` | Platform administrator | Full access, manage settings, approve restaurants |

---

## 5. API Reference

**Base URL:** `http://localhost:8080/api/v1`  
**Auth:** Bearer JWT token in `Authorization` header

### 5.1 Authentication

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/auth/register` | — | Register new user |
| `POST` | `/auth/login` | — | Login, get JWT tokens |

**Register Request:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "08123456789",
  "password": "securepass",
  "role": "customer"
}
```

**Login Response:**
```json
{
  "token": "eyJhbGci...",
  "refresh_token": "eyJhbGci...",
  "user": { "id": "uuid", "name": "...", "role": "customer" }
}
```

### 5.2 Restaurants (Public)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/restaurants` | — | List all verified restaurants |
| `GET` | `/restaurants/nearby?lat=&lng=&radius=5` | — | Find nearby (haversine) |
| `GET` | `/restaurants/search?q=keyword` | — | Search by name/description |
| `GET` | `/restaurants/:id` | — | Get restaurant detail |
| `GET` | `/restaurants/:id/menu` | — | Full menu (categories → items → addons) |

### 5.3 Restaurant Owner

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/my-restaurant` | restaurant | Register restaurant |
| `GET` | `/my-restaurant` | restaurant | Get my restaurant + menu |
| `PUT` | `/my-restaurant` | restaurant | Update profile |
| `PUT` | `/my-restaurant/toggle-open` | restaurant | Toggle open/closed |
| `POST` | `/my-restaurant/categories` | restaurant | Create category |
| `PUT` | `/my-restaurant/categories/:catId` | restaurant | Update category |
| `DELETE` | `/my-restaurant/categories/:catId` | restaurant | Delete category |
| `POST` | `/my-restaurant/categories/:catId/items` | restaurant | Create menu item |
| `PUT` | `/my-restaurant/items/:itemId` | restaurant | Update item |
| `DELETE` | `/my-restaurant/items/:itemId` | restaurant | Delete item |
| `PUT` | `/my-restaurant/items/:itemId/toggle` | restaurant | Toggle availability |
| `POST` | `/my-restaurant/items/:itemId/addons` | restaurant | Create addon |
| `DELETE` | `/my-restaurant/addons/:addonId` | restaurant | Delete addon |

### 5.4 Customer Orders

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/orders` | customer | Place order (COD) |
| `GET` | `/orders?status=` | customer | List my orders |
| `GET` | `/orders/:id` | customer | Get order detail |
| `POST` | `/orders/:id/cancel` | customer | Cancel (pending only) |

**Place Order Request:**
```json
{
  "restaurant_id": "uuid",
  "items": [
    { "menu_item_id": "uuid", "quantity": 2, "notes": "Extra spicy" }
  ],
  "delivery_address": "Jl. Pantai Kuta",
  "delivery_lat": -8.8953,
  "delivery_lng": 116.2833,
  "notes": "Ring the bell"
}
```

**Place Order Response:**
```json
{
  "order": { "order_number": "KWR-260507091015", "status": "pending", "total": 72500 },
  "pricing_breakdown": {
    "food_subtotal_with_markup": 57500,
    "food_markup_total": 7500,
    "delivery_fee": 15000,
    "delivery_commission_kuwrir": 3750,
    "driver_earning": 11250,
    "total_customer_pays_cash": 72500
  }
}
```

### 5.5 Restaurant Order Management

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/restaurant-orders` | restaurant | Active orders queue |
| `POST` | `/restaurant-orders/:id/accept` | restaurant | Accept (pending → confirmed) |
| `POST` | `/restaurant-orders/:id/preparing` | restaurant | Start cooking (confirmed → preparing) |
| `POST` | `/restaurant-orders/:id/ready` | restaurant | Mark ready (preparing → ready) |

### 5.5b Merchant Self-Delivery

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `PUT` | `/my-store/toggle-self-deliver` | merchant | Toggle self-delivery on/off |
| `PUT` | `/my-store/self-delivery-fee` | merchant | Set custom delivery fee (0 = free) |
| `GET` | `/my-store/my-deliveries` | merchant | Orders to self-deliver (ready/picked_up) |
| `POST` | `/my-store/my-deliveries/:id/pickup` | merchant | Mark self-delivery picked up |
| `POST` | `/my-store/my-deliveries/:id/deliver` | merchant | Mark self-delivery delivered |

### 5.6 Driver Orders

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/driver-orders/available` | driver | Orders ready for pickup |
| `POST` | `/driver-orders/:id/accept` | driver | Accept delivery |
| `POST` | `/driver-orders/:id/pickup` | driver | Mark picked up |
| `POST` | `/driver-orders/:id/deliver` | driver | Mark delivered + update cash balance |

### 5.7 Admin

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/admin/settings` | admin | Get all system settings |
| `PUT` | `/admin/settings/:key` | admin | Update a setting |
| `GET` | `/admin/drivers` | admin | List all drivers |
| `GET` | `/admin/customers` | admin | List all customers |
| `GET` | `/admin/merchants` | admin | List all merchants |
| `GET` | `/admin/orders` | admin | List all orders |
| `GET` | `/admin/settlements` | admin | Financial overview |

### 5.8 Health Check

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/health` | — | Service health status |

---

## 6. COD Financial Model

### 6.1 Configurable Parameters

| Parameter | Default | Description |
|---|---|---|
| `food_markup_percentage` | 15% | Added to restaurant base price → customer pays |
| `delivery_commission_percentage` | 25% | KUWRIR keeps this from delivery fee |
| `delivery_base_fee_inside_zone` | IDR 15,000 | Flat fee within 5km of restaurant |
| `delivery_fee_per_km_outside` | IDR 10,000/km | Additional fee per km beyond 5km |

### 6.2 Calculation Example

```
Order: 1x Nasi Campur (base IDR 50,000) · inside zone delivery

Food Base Price:                    IDR  50,000
+ Food Markup (15%):                IDR   7,500
─────────────────────────────────────────────────
Food Price (customer sees):         IDR  57,500
Delivery Fee (inside zone):         IDR  15,000
═════════════════════════════════════════════════
TOTAL CUSTOMER PAYS (CASH):         IDR  72,500

Distribution:
→ Restaurant Receives:              IDR  50,000  (base food price)
→ Driver Earns:                     IDR  11,250  (75% of delivery fee)
→ KUWRIR Revenue:                     IDR  11,250  (markup + commission)
    ├─ Food Markup:                 IDR   7,500
    └─ Delivery Commission (25%):   IDR   3,750
```

### 6.3 Cash Flow (COD)

```
Customer ──(cash IDR 72,500)──▶ Driver
                                  │
           ┌──────────────────────┤
           │                      │
           ▼                      ▼
   Driver keeps              Driver owes
   IDR 11,250                IDR 61,250
   (earning)                  (deposit to admin)
                                  │
                 ┌────────────────┤
                 │                │
                 ▼                ▼
          KUWRIR keeps        Restaurant gets
          IDR 11,250        IDR 50,000
          (revenue)         (monthly settlement)
```

### 6.4 Cash Flow (Self-Delivery)

When a merchant delivers their own orders, the flow is simpler:

```
Order: 1x Nasi Campur (base IDR 50,000) · self-delivery (fee IDR 0)

Food Base Price:                    IDR  50,000
+ Food Markup (15%):                IDR   7,500
─────────────────────────────────────────────────
Food Price (customer sees):         IDR  57,500
Delivery Fee (merchant-set):        IDR       0
═════════════════════════════════════════════════
TOTAL CUSTOMER PAYS (CASH):         IDR  57,500

Distribution:
→ Restaurant Receives:              IDR  50,000  (base food price + delivery fee)
→ Driver Earns:                     IDR       0  (no platform driver)
→ KUWRIR Revenue:                   IDR   7,500  (food markup only)
    ├─ Food Markup:                 IDR   7,500
    └─ Delivery Commission:         IDR       0  (not charged for self-delivery)
```

```
Customer ──(cash IDR 57,500)──▶ Merchant (delivers directly)
                                    │
                   ┌────────────────┤
                   │                │
                   ▼                ▼
            KUWRIR gets        Merchant keeps
            IDR  7,500        IDR 50,000
            (food markup)     (base food price)
```

---

## 7. Order State Machine

```
             ┌──────────────────────────────┐
             │         ORDER LIFECYCLE       │
             └──────────────────────────────┘

  Customer                Restaurant              Driver
  places order            accepts                 picks up
      │                      │                       │
      ▼                      ▼                       ▼
  ┌────────┐  accept   ┌──────────┐  prepare  ┌──────────┐
  │PENDING │──────────▶│CONFIRMED │──────────▶│PREPARING │
  └────┬───┘           └──────────┘           └────┬─────┘
       │                                           │
   cancel                                     mark ready
       │                                           │
       ▼                                           ▼
  ┌──────────┐                               ┌────────┐
  │CANCELLED │                               │ READY  │
  └──────────┘                               └────┬───┘
                                                   │
                                              driver picks up
                                                   │
                                                   ▼
                                             ┌──────────┐
                                             │PICKED UP │
                                             └────┬─────┘
                                                   │
                                              delivered
                                                   │
                                                   ▼
                                             ┌──────────┐
                                             │DELIVERED │
                                             └──────────┘
```

---

## 8. Security

| Concern | Implementation |
|---|---|
| Password Hashing | bcrypt (cost factor 10) |
| Authentication | JWT (HS256), access + refresh tokens |
| Authorization | Role-based middleware (`customer`, `restaurant`, `driver`, `admin`) |
| API Security | CORS middleware, rate limiting (planned) |
| Data Isolation | Users can only access their own data (user_id scoping) |

---

## 9. Infrastructure

### 9.1 Docker Compose Services

| Service | Image | Port | Purpose |
|---|---|---|---|
| `postgres` | postgis/postgis:16-3.4 | 5432 | Primary database |
| `redis` | redis:7-alpine | 6379 | Caching, sessions |
| `valhalla` | ghcr.io/gis-ops/valhalla | 8002 | Route calculations (Lombok OSM) |
| `nominatim` | mediagis/nominatim | 8003 | Address geocoding |

### 9.2 External Services

| Service | Provider | Purpose |
|---|---|---|
| Image Storage | Cloudflare R2 | Restaurant logos, food images (S3-compatible, zero egress) |
| Domain/CDN | Cloudflare | DNS, CDN, DDoS protection |

### 9.3 Production Cost Estimate

| Component | Monthly Cost |
|---|---|
| Single VPS (4 vCPU, 8GB RAM) | ~$48/month |
| Cloudflare R2 (10GB storage) | ~$0.15/month |
| Domain | ~$1/month |
| **Total** | **~$49/month** |

---

## 10. Current Status

| Phase | Status | Description |
|---|---|---|
| Phase 1 | ✅ Complete | Foundation (Backend, Admin Panel, Flutter scaffolds) |
| Phase 2 | ✅ Complete | Restaurant & Menu System |
| Phase 3 | ✅ Complete | Cart, Orders & COD Pricing Engine |
| Phase 4 | ✅ Complete | Driver App, Map Integration Placeholder, Order Fulfillment |
| Phase 5 | ✅ Complete | Admin Panel Integration (Settlements, Dashboard, Merchants) |
| Phase 6 | ⬜ Planned | POS/Kasir feature for merchants, Image Upload (R2), Reviews |

---

## 11. Getting Started

### Prerequisites
- Go 1.22+, Node.js 20+, Flutter 3.x, Docker

### Quick Start
```bash
# 1. Start infrastructure
cd backend && docker compose up -d

# 2. Configure environment
cd backend && cp .env.example .env

# 3. Start backend API
cd backend && go run cmd/server/main.go

# 4. Start admin panel
cd admin_panel && npm install && npm run dev

# 5. Start mobile app
cd customer_app && flutter pub get && flutter run
```

### Default Admin Credentials
You can log into the Admin Panel using the following seeded credentials:
- **Phone**: `080000000000`
- **Password**: `admin123`
