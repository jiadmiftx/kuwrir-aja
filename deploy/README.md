# KUWRIR Deployment

This directory holds everything needed to run the production stack on the VPS
and to wire up the GitHub Actions CI/CD pipelines.

## How it works

- **Push to `main` touching `backend/**`** → `.github/workflows/deploy-backend.yml`
  builds a Docker image, pushes it to GHCR (`ghcr.io/jiadmiftx/kuwrir-aja/backend`),
  then SSHes into the VPS to pull + restart only the `backend` container.
- **Push to `main` touching `admin_panel/**`** → `.github/workflows/deploy-admin.yml`
  does the same for the admin panel (`ghcr.io/jiadmiftx/kuwrir-aja/admin`),
  restarting only the `admin` container.
- **Push to `main` touching `customer_app/**`, `driver_app/**`, `restaurant_app/**`
  or `shared/**`** → `.github/workflows/firebase-distribution.yml` builds release
  APKs for the affected app(s) and uploads them to Firebase App Distribution.
  A change in `shared/**` rebuilds all 3 apps.

`postgres` and `redis` are started **once** during VPS provisioning (see
below) and are never touched by the CI/CD pipelines — their data lives in
named Docker volumes.

> **Note:** this VPS already hosts another app (the "sekolah" stack, using
> ports 80, 443, 3000, 8080, and native PostgreSQL on 5432). KUWRIR's
> `backend` and `admin` containers are mapped to **8090** and **8091**
> instead of their usual 8080/80 to avoid conflicts — see
> `deploy/docker-compose.yml`. Valhalla/Nominatim (routing + geocoding) are
> intentionally not deployed yet: the backend doesn't use them, and their OSM
> import is too heavy for this box's resources alongside the existing app.

## 1. GitHub Secrets to configure

Repo → Settings → Secrets and variables → Actions:

| Secret | Used by | Description |
|---|---|---|
| `VPS_HOST` | deploy-backend, deploy-admin | VPS IP or hostname |
| `VPS_USER` | deploy-backend, deploy-admin | SSH user (e.g. `deploy`) |
| `VPS_SSH_KEY` | deploy-backend, deploy-admin | Private key for that user (PEM format) |
| `FIREBASE_SERVICE_ACCOUNT` | firebase-distribution | Raw JSON of a Firebase service account key |
| `FIREBASE_APP_ID_CUSTOMER` | firebase-distribution | Firebase App ID for `com.enak.enak_customer` |
| `FIREBASE_APP_ID_DRIVER` | firebase-distribution | Firebase App ID for `com.enak.enak_driver` |
| `FIREBASE_APP_ID_RESTAURANT` | firebase-distribution | Firebase App ID for `com.enak.enak_restaurant` |

`GITHUB_TOKEN` (used to push to GHCR) is provided automatically by Actions —
no setup needed, but the repo's package visibility defaults to **private**,
which is why the VPS needs to `docker login ghcr.io` once (step 2.3 below).

## 2. VPS provisioning (one-time)

### 2.1 Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# log out/in for the group change to take effect
```

### 2.2 Clone the repo

```bash
git clone git@github.com:jiadmiftx/kuwrir-aja.git ~/kuwrir-aja
cd ~/kuwrir-aja
```

The deploy workflows run `git pull` in this directory before redeploying, so
this clone must use a key/remote the VPS can pull from non-interactively
(e.g. a deploy key, or just clone over HTTPS if the repo is public).

### 2.3 Authenticate to GHCR (so `docker compose pull` works)

GHCR packages tied to a private repo are private by default. Create a GitHub
**classic PAT** with `read:packages` scope, then on the VPS:

```bash
echo '<PAT>' | docker login ghcr.io -u <your-github-username> --password-stdin
```

(Alternatively, make the `kuwrir-aja/backend` and `kuwrir-aja/admin` packages
public in GitHub → Packages settings, and skip this step.)

### 2.4 Configure backend secrets

```bash
cp deploy/.env.production.example deploy/.env.production
nano deploy/.env.production   # set JWT_SECRET, R2_* credentials, etc.
```

### 2.5 Start the stack

```bash
docker compose -f deploy/docker-compose.yml up -d
```

Once everything is healthy:
- Backend API: `http://<VPS_IP>:8090/api/v1`
- Admin panel: `http://<VPS_IP>:8091` (proxies `/api/*` to the backend container)

### 2.6 Point the apps at the VPS

Update `shared/kuwrir_shared/lib/src/api/api_config.dart` `baseUrl` to
`http://<VPS_IP>:8090/api/v1` so the 3 Flutter apps talk to the VPS instead of
a local LAN IP.

## 3. Firebase App Distribution setup (one-time, no project exists yet)

1. Go to the [Firebase console](https://console.firebase.google.com/) and
   create a new project (e.g. "KUWRIR").
2. Add 3 Android apps to the project with these exact package names:
   - `com.enak.enak_customer`
   - `com.enak.enak_driver`
   - `com.enak.enak_restaurant`
   You don't need to download `google-services.json` or add the Firebase SDK
   to the apps — App Distribution only needs the App ID.
3. For each app, go to **Project settings → General**, scroll to "Your apps",
   and copy the **App ID** (format `1:1234567890:android:abcdef1234567890`).
   Set these as `FIREBASE_APP_ID_CUSTOMER`, `FIREBASE_APP_ID_DRIVER`,
   `FIREBASE_APP_ID_RESTAURANT`.
4. Create a service account for CI: **Project settings → Service accounts →
   Generate new private key**, then grant it the **Firebase App Distribution
   Admin** role under [IAM](https://console.cloud.google.com/iam-admin/iam)
   for the project. Paste the full JSON content into the
   `FIREBASE_SERVICE_ACCOUNT` secret.
5. In **App Distribution → Testers & Groups**, create a group named `testers`
   and add the email addresses of people who should receive new builds. (The
   workflows upload to the `testers` group by default — change the `groups:`
   input in `.github/workflows/firebase-distribution.yml` if you want a
   different name.)

## Notes

- Release APKs are currently signed with the Flutter **debug** keystore
  (`signingConfig = signingConfigs.getByName("debug")` in each app's
  `android/app/build.gradle.kts`). This is fine for Firebase App Distribution
  to internal testers. A real release keystore is a separate task needed
  before publishing to the Play Store.
- No domain/HTTPS is configured yet — everything is exposed via the VPS's IP
  and ports 80/8080. Add an Nginx reverse proxy + Let's Encrypt (Certbot) in
  front of `deploy/docker-compose.yml` once a domain is available.
