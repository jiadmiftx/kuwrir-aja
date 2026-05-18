# KUWRIR Platform — CHANGELOG

All notable changes to the KUWRIR food delivery platform are documented in this file.

---

## [0.3.0] — 2026-05-07 · Phase 3: Cart & Orders + COD

### Backend (Golang)
#### Added
- **Order Placement API** (`POST /api/v1/orders`) — Full COD pricing engine that:
  - Reads configurable system settings (food markup %, delivery commission %, zone fees)
  - Calculates haversine distance between restaurant and delivery address
  - Applies inside-zone flat fee or outside-zone per-km pricing
  - Splits delivery fee between driver earning and platform commission
  - Generates unique order numbers (`KWR-YYMMDDHHMMSS`)
  - Returns complete pricing breakdown in response
- **Order State Machine** — Strict status transitions:
  - `pending` → `confirmed` → `preparing` → `ready` → `picked_up` → `delivered`
  - Cancel only allowed from `pending` status
- **Customer Orders API**:
  - `GET /api/v1/orders` — List orders (with optional `?status=` filter)
  - `GET /api/v1/orders/:id` — Order detail with restaurant and items
  - `POST /api/v1/orders/:id/cancel` — Cancel pending order
- **Restaurant Order Management API**:
  - `GET /api/v1/restaurant-orders` — Active orders for restaurant owner
  - `POST /api/v1/restaurant-orders/:id/accept` — Accept new order
  - `POST /api/v1/restaurant-orders/:id/preparing` — Mark as preparing
  - `POST /api/v1/restaurant-orders/:id/ready` — Mark ready for pickup
- **Driver Order API**:
  - `GET /api/v1/driver-orders/available` — Orders ready for driver pickup
  - `POST /api/v1/driver-orders/:id/accept` — Accept delivery assignment
  - `POST /api/v1/driver-orders/:id/pickup` — Mark picked up from restaurant
  - `POST /api/v1/driver-orders/:id/deliver` — Mark delivered, update driver cash balance
- Role-based route middleware (customer, restaurant, driver roles)

### Admin Panel (React)
#### Added
- **Orders Page** (`/orders`) with:
  - Status filter tabs (All / Pending / Preparing / Ready / Delivered / Cancelled)
  - Search by order number or customer name
  - Stats cards: Total Orders, Active, Delivered, KUWRIR Revenue
  - Data table with KUWRIR cut column (food_markup + delivery_commission)
  - Color-coded status badges

### Customer App (Flutter)
#### Added
- **Cart Screen** — Item list with quantity +/- controls, price breakdown, COD badge
- **Checkout Screen** — Delivery address selector, COD payment method, order summary with itemized receipt, optional notes, Place Order button with success dialog
- **Order Tracking Screen** — 6-step visual timeline (Placed → Confirmed → Preparing → Ready → Picked Up → Delivered), estimated delivery time, payment info card

### Restaurant App (Flutter)
#### Added
- **Live Order Queue** with status-specific action buttons:
  - Accept Order (pending → confirmed) — yellow
  - Start Preparing (confirmed → preparing) — blue
  - Mark Ready (preparing → ready) — purple
  - Waiting for Driver (ready) — green
- Color-coded status badges and order cards with customer name, total, item count

---

## [0.2.0] — 2026-05-07 · Phase 2: Restaurant & Menu System

### Backend (Golang)
#### Added
- **Restaurant Handler** (`internal/handler/restaurant/handler.go`) with 18 endpoints:
  - Public: List, Nearby (geospatial haversine), Search, Get detail, Get full menu
  - Owner: Create, Get my restaurant, Update profile, Toggle open/closed
  - Categories: Create, Update, Delete
  - Menu Items: Create, Update, Delete, Toggle availability
  - Addons: Create, Delete
- Full menu preloading: `Categories → Items → Addons` with sort order

### Admin Panel (React)
#### Added
- **Restaurants Page** (`/restaurants`) with:
  - Stats cards (Total / Verified / Currently Open)
  - Searchable data table with restaurant name, location, rating, status
  - Approve / Reject action buttons for pending verification
  - Restaurant detail dialog
- Route registered in `App.tsx`

### Customer App (Flutter)
#### Added
- **Home Screen** with:
  - Location header ("Kuta, Lombok")
  - Tappable search bar linking to search screen
  - Horizontal food category chips (All, Popular, Nasi, Sate, Drinks, Dessert)
  - Nearby restaurant cards with rating, distance, delivery time
  - Bottom navigation (Home / Orders / Profile)
- **Restaurant Detail Screen** with:
  - Collapsible app bar with restaurant banner
  - Restaurant info (rating, address, delivery time, delivery fee)
  - Full menu organized by categories with food items
  - Add-to-cart buttons on each item
  - Sticky bottom "View Cart" bar
- **Search Screen** with recent searches and popular category tags
- App routing: Home → Search, Home → Restaurant Detail

### Restaurant App (Flutter)
#### Added
- **Main App** with bottom navigation (Orders / Menu / Store)
- **Orders Screen** — Active order queue placeholder with store status indicator
- **Menu Management Screen** with:
  - Category listing with edit/add buttons
  - Menu items with name, price, and availability toggle switch
  - Add Category dialog, Edit Category dialog, Add Item dialog
  - FAB for adding new categories
- **Store Profile Screen** with:
  - Banner upload area
  - Info tiles (Name, Phone, Address, Rating)
  - Store open/closed toggle
  - Today's summary stats (Orders, Revenue)

### Shared Package (`kuwrir_shared`)
#### Added
- Shared package dependency added to all 3 Flutter apps (`customer_app`, `restaurant_app`, `driver_app`)

---

## [0.1.0] — 2026-05-06 · Phase 1: Foundation

### Backend (Golang)
#### Added
- **Project scaffold** with clean architecture:
  - `cmd/server/main.go` — Entry point with GORM auto-migrate and settings seeding
  - `internal/config/` — Environment-based configuration (DB, Redis, R2, JWT, Valhalla)
  - `internal/model/` — 14 GORM models (User, Address, Restaurant, MenuCategory, MenuItem, ItemAddon, Driver, Order, OrderItem, Review, SystemSetting, DriverDeposit, RestaurantSettlement, Promotion)
  - `internal/handler/auth/` — Register & Login with bcrypt + JWT (access + refresh tokens)
  - `internal/handler/admin/` — System settings GET/PUT API
  - `internal/middleware/` — JWT authentication, role-based access control, CORS
- **Docker Compose** (`docker-compose.yml`) with:
  - PostgreSQL 16 + PostGIS 3.4
  - Redis 7 Alpine
  - Valhalla routing engine (Lombok OSM data)
  - Nominatim geocoding (Indonesia extract)
- `.env.example` with all configuration variables
- `go.mod` initialized with Gin, GORM, UUID, JWT dependencies
- Default settings seeding (15% food markup, 25% delivery commission, IDR 15K zone fee)

### Admin Panel (React + Vite)
#### Added
- **Project scaffold** with Vite + React + TypeScript
- **Tailwind CSS v4** + **shadcn/ui** initialized (15 components)
- **Sidebar Layout** (`AdminLayout.tsx`) with navigation links:
  - Dashboard, Orders, Restaurants, Drivers, Customers, Promotions, Settlements, Settings
- **Dashboard Page** with 6 KPI cards (Orders, Restaurants, Drivers, Customers, Revenue, Pending Deposits)
- **Login Page** with phone + password form
- **Settings Page** with:
  - Configurable financial parameters (food markup, delivery commission, zone fees)
  - Live revenue split calculator preview
- React Router with route guards

### Flutter Apps
#### Added
- **Customer App** (`kuwrir_customer`) scaffold with `com.kuwrir` org
- **Driver App** (`kuwrir_driver`) scaffold
- **Restaurant App** (`kuwrir_restaurant`) scaffold
- **Shared Package** (`kuwrir_shared`) with:
  - `ApiClient` — HTTP client with JWT token management (GET/POST/PUT/PATCH)
  - `ApiConfig` — Endpoint constants and base URL
  - `User` model with JSON serialization
  - `AuthResponse`, `LoginRequest`, `RegisterRequest` models
  - `KuwrirTheme` — Material 3 theme (light + dark mode)
  - `KuwrirColors` — Brand color palette (warm orange primary, dark charcoal secondary)

### Infrastructure
#### Added
- Monorepo `.gitignore`
- Root `README.md` with quick start guide
