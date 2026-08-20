# CLAUDE.md

Instructions for Claude Code working in this repo. For product/architecture detail, read
`SPECIFICATION.md` (DB schema, full API reference), `SYSTEM_OVERVIEW.md` (roles, financial model),
`SYSTEM_FLOW.md` (status machines, endpoint flows), and `deploy/README.md` (VPS/CI-CD setup) —
this file is about how to work here, not what the product does.

## What this is

Cocourir (formerly "Kuwrir Aja") — a local food/goods courier and delivery platform serving Lombok
(not limited to Kuta), integrating local Lombok merchants, customers across the Lombok community,
and local drivers. Supports both COD and online payment (Duitku gateway), not COD-only. Monorepo:
Go/Gin backend, 3 Flutter apps, a React admin panel, a Next.js customer PWA, a shared Dart
package, and a couple of standalone side-projects that happen to live in the same repo.

## Directory map

| Path | What | Stack |
|---|---|---|
| `backend/` | REST API, single Gin binary | Go, GORM, PostgreSQL, Postgis |
| `customer_app/`, `driver_app/`, `merchant_app/` | Mobile apps | Flutter |
| `shared/kuwrir_shared/` | Dart package shared by all 3 Flutter apps — `ApiClient`, `OtpFlow`, `PaymentStatusWatcher`, `KuwrirColors`/theme, etc. **Check here before writing new client-side logic that isn't app-specific.** | Flutter package |
| `web_app/` | Customer-facing PWA at `app.cocourir.com` — iOS users' way in without an App Store release | Next.js 16 (Turbopack), Tailwind v4, React Query |
| `admin_panel/` | Backoffice at `platform.cocourir.com` | React + Vite + shadcn/ui |
| `deploy/` | `docker-compose.yml`, nginx vhost configs, `.env.production` (not committed), deploy docs |
| `landing/` | Static marketing site, own deploy pipeline |
| `whatsapp-gateway/` | **Dormant.** Backend actually sends OTP WhatsApp messages through a *separate* multi-tenant `wa-gateway` repo/deployment (`WHATSAPP_GATEWAY_URL` in `docker-compose.yml`, shared with an unrelated tenant on the same VPS) — see the comment at `deploy/docker-compose.yml:50-54`. This in-repo copy has its own deploy workflow but nothing points at it. Don't assume it's live. |
| `mockup_app/`, `finansial-mac/` | Unrelated internal tools, not part of the platform |
| Root `*.md`/`*.pdf` (equity, legal, SPECIFICATION, etc.) | Product/legal docs, not code — see cleanup notes below |

## Build / lint / test

```bash
# Backend
cd backend && go build ./... && go vet ./...

# Any Flutter app (customer_app / driver_app / merchant_app / shared/kuwrir_shared)
flutter pub get && flutter analyze && dart format <changed files>

# web_app
cd web_app && npx tsc --noEmit && npm run build && npm run lint

# admin_panel
cd admin_panel && npm run build && npm run lint
```

Run the relevant one after every change before considering it done — none of these are optional,
all are cheap and catch real regressions (see git history: several sessions caught real breakage
this way).

## Scope: order jasa is on hold

Order jasa (laundry/bengkel/salon — the `awaiting_pickup → item_picked_up → in_service →
ready_for_return → returning → returned` status cycle, `/service-orders`, `/my-service-orders`,
`/driver/service-orders`) is paused. Development is focused on order barang/makanan
(`pending → confirmed → preparing → ready → picked_up → delivered`) until the user says
otherwise. Don't add features or fix non-critical bugs on the jasa flow unless explicitly asked —
treat it as legacy/inactive, not dead code to clean up.

## Deploy pipeline — auto-deploys on push to `main`, path-triggered

Every `git push` to `main` that touches a given directory **immediately deploys to production** —
there is no staging environment and no manual approval step, except where noted:

| Push touches | Workflow | Deploys to |
|---|---|---|
| `backend/**` | `deploy-backend.yml` | `api.cocourir.com` (`kuwrir-backend` container) |
| `admin_panel/**` | `deploy-admin.yml` | `platform.cocourir.com` |
| `web_app/**` | `deploy-webapp.yml` | `app.cocourir.com` |
| `landing/**` | `deploy-landing.yml` | landing site |
| `whatsapp-gateway/**` | `deploy-whatsapp-gateway.yml` | dormant, see above |
| `customer_app/**`, `driver_app/**`, `merchant_app/**`, `shared/**` | `firebase-distribution.yml` | Firebase App Distribution (internal testers), **not** the Play Store |
| — | `deploy-playstore.yml` | **`workflow_dispatch` only, on purpose** — a human always picks the app/track/notes explicitly |

Because of this, **never `git push origin main` without the user explicitly saying so** (e.g.
"push", "deploy") — a push is a production deploy, not a save point. Committing locally is fine
without asking; pushing is not. This has been the working pattern all along — don't regress it.

VPS specifics: single instance (`cocourir-vps`), so backend features should default to
**in-process** patterns (in-memory broadcaster/cache/etc) rather than reaching for Redis —
`docker-compose.yml` provisions a Redis container but nothing in `backend/` actually uses it
(dead config in `internal/config/config.go`). Only wire real Redis pub/sub if the backend is ever
horizontally scaled; don't add the dependency preemptively.

The same VPS also hosts an unrelated project ("sekolah-madrasah" / Ihtada school management
system, ports 3000/8080 and its own Postgres) and the shared `wa-gateway` WhatsApp tenant
mentioned above. **Never touch either without the user explicitly asking** — confirmed in past
sessions this is a hard boundary, not just tidiness.

Production backend env vars live in `deploy/.env.production` **on the VPS** (not committed, not
mirrored anywhere in this repo) — `docker-compose.yml` reads `env_file: .env.production` relative
to `deploy/`, so a copy placed anywhere else (e.g. the VPS home directory) silently never reaches
the container. VPS IP, SSH access, and the release-signing keystore path/credentials
(`kuwrir-release.keystore`, gitignored at repo root, used via `./deploy_android.sh`) are
intentionally not written into this file since it's committed — ask the user if you need them.

## Conventions worth knowing before editing

- **`merchant_app/pubspec.yaml`** tends to sit locally modified (a version bump) independent of
  whatever else is being worked on. It's not yours to commit unless the user is specifically
  working on `merchant_app` release versioning — check `git status` before any broad `git add` and
  exclude it if it's unrelated to your change.
- **Flutter shared logic**: before writing a new cubit/service/widget in one app, check
  `shared/kuwrir_shared/lib/src/` first — `OtpFlow`, `ApiClient`, `PaymentStatusWatcher`, theme
  colors, etc. all live there specifically so customer/driver/merchant apps don't drift. A fix
  made only in one app while the same pattern exists in the other two is usually a bug, not a
  feature.
- **web_app design system** (`app/globals.css`): OKLCH color tokens (`--color-ink`,
  `--color-accent`, etc.), a shared `--content-width` token for page max-width. Icons are
  `@hugeicons/react` + `@hugeicons/core-free-icons` exclusively — **no emoji anywhere in the UI**,
  that was a deliberate rebrand away from the original scaffolded look. Match this when touching
  any page.
- **Payment status** (`Order.payment_status`) is pushed over SSE
  (`GET /payment/:orderId/stream`, `backend/internal/handler/payment/handler.go`) instead of
  polled, backed by an in-process broadcaster (`backend/internal/service/payment_events.go`). If
  you're adding another "wait for some field to change" flow, this is the pattern to copy — not a
  new polling loop.
- Order/chat/dashboard refresh elsewhere in the apps still uses **FCM push as primary, a slow
  poll as fallback** (not SSE) — that's intentional per-feature, not inconsistency to "fix".
- Root-level `*.md` legal/equity docs (`SYARAT_KETENTUAN_*`, `PERJANJIAN_KEMITRAAN_*`,
  `EQUITY_AGREEMENT_*`, `PROFIT_SHARING_*`) are either mirrored into the Go binary via
  `//go:embed` (the `SYARAT_KETENTUAN_CUSTOMER.md`/`PERJANJIAN_KEMITRAAN_*.md` ones — see
  `backend/internal/legal/legal.go`) or are real legal/financial agreements. Don't delete or
  restructure any of them without the user explicitly asking — this has come up before.
  `EQUITY_AGREEMENT_FOUNDERS.md`/`.pdf` and `PROFIT_SHARING_AGREEMENT_*.md`/`.pdf` hold the actual
  cap table and profit-sharing splits — treat any change to the numbers/clauses in those as
  editing a real legal agreement, not a docs tweak; if asked to revise, edit those files in place
  rather than drafting new ones from scratch.

## Commit style

Recent commit messages in this repo explain *why*, not just *what*, in 1-3 short paragraphs, no
bullet-point changelogs. Match that. `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` on
every commit made here.
