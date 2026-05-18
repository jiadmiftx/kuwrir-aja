# 📦 KUWRIR — Food Delivery Platform

A full-stack food delivery platform for the Kuta, Lombok tourist area.  
**MVP Model:** Cash on Delivery (COD) exclusively.

## 📚 Documentation

| Document | Description |
|---|---|
| [Project Proposal](project_proposal.md) | Business scope, financial logic, infrastructure plan |
| [Technical Specification](SPECIFICATION.md) | Architecture, DB schema, full API reference (37 endpoints) |
| [Changelog](CHANGELOG.md) | Version history and detailed release notes |

## 🏗️ Architecture

| Component | Technology | Directory |
|---|---|---|
| **Backend API** | Golang + Gin + GORM | `backend/` |
| **Admin Panel** | React + Vite + shadcn/ui | `admin_panel/` |
| **Customer App** | Flutter | `customer_app/` |
| **Driver App** | Flutter | `driver_app/` |
| **Restaurant App** | Flutter | `restaurant_app/` |
| **Shared Packages** | Dart | `shared/kuwrir_shared/` |

## 🚀 Quick Start

### 1. Start Infrastructure (PostgreSQL, Redis, Valhalla, Nominatim)
```bash
cd backend
docker compose up -d
```

### 2. Start Backend API
```bash
cd backend
cp .env.example .env  # Update values as needed
go run cmd/server/main.go
```

### 3. Start Admin Panel
```bash
cd admin_panel
npm install
npm run dev
```

### 4. Start Mobile Apps
```bash
cd customer_app   # or driver_app, restaurant_app
flutter pub get
flutter run
```

## 📡 API Endpoints (37 total)

### Auth
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Register new user |
| `POST` | `/api/v1/auth/login` | Login, get JWT tokens |

### Restaurants (Public)
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/restaurants` | List verified restaurants |
| `GET` | `/api/v1/restaurants/nearby` | Find nearby (geospatial) |
| `GET` | `/api/v1/restaurants/search` | Search by keyword |
| `GET` | `/api/v1/restaurants/:id` | Restaurant detail |
| `GET` | `/api/v1/restaurants/:id/menu` | Full menu tree |

### Restaurant Owner (13 endpoints)
`POST/GET/PUT` `/api/v1/my-restaurant` · Categories CRUD · Items CRUD · Addons CRUD

### Customer Orders
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/orders` | Place order (COD pricing) |
| `GET` | `/api/v1/orders` | List my orders |
| `GET` | `/api/v1/orders/:id` | Order detail |
| `POST` | `/api/v1/orders/:id/cancel` | Cancel pending order |

### Restaurant Orders
`GET /restaurant-orders` · `POST accept/preparing/ready`

### Driver Orders
`GET /driver-orders/available` · `POST accept/pickup/deliver`

### Admin
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/admin/settings` | Get all system settings |
| `PUT` | `/api/v1/admin/settings/:key` | Update a setting |

### Health
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Health check |

## 💰 COD Financial Model

```
Food IDR 50,000 → +15% markup → IDR 57,500
+ Delivery IDR 15,000 (inside zone)
= Customer pays IDR 72,500 (cash)

→ Restaurant: IDR 50,000
→ Driver:     IDR 11,250 (75% delivery)
→ KUWRIR:       IDR 11,250 (markup + commission)
```

## 📊 Current Status

| Phase | Status |
|---|---|
| Phase 1 — Foundation | ✅ Complete |
| Phase 2 — Restaurant & Menu | ✅ Complete |
| Phase 3 — Cart & Orders + COD | ✅ Complete |
| Phase 4 — Driver App + Image Upload | ⬜ Next |
| Phase 5 — Reviews + Promotions | ⬜ Planned |
