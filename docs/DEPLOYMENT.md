# MyGrowth Diet App — Deployment Guide

How to run the backend in production: configuration, database setup, the
scheduler, and operations. Commands assume you are in `Backend/backend`.

---

## Contents

- [Prerequisites](#prerequisites)
- [Deployment overview](#deployment-overview)
- [1. Get the code and install](#1-get-the-code-and-install)
- [2. Configure the environment](#2-configure-the-environment)
- [3. Provision the database](#3-provision-the-database)
- [4. Migrate and seed](#4-migrate-and-seed)
- [5. Create the Main Admin](#5-create-the-main-admin)
- [6. Run the API](#6-run-the-api)
- [7. Run the scheduler](#7-run-the-scheduler)
- [Reverse proxy and TLS](#reverse-proxy-and-tls)
- [Email configuration](#email-configuration)
- [Storage configuration](#storage-configuration)
- [Hosting: Neon + Render + Vercel](#hosting-neon--render--vercel)
- [Health checks and monitoring](#health-checks-and-monitoring)
- [Backups and recovery](#backups-and-recovery)
- [Upgrades and migrations](#upgrades-and-migrations)
- [Scaling](#scaling)
- [Production checklist](#production-checklist)

---

## Prerequisites

- **Node.js 20+** (developed on Node 25).
- **PostgreSQL 16** (a managed instance is fine).
- A reverse proxy / TLS terminator (nginx, Caddy, or a platform load balancer).
- A process manager (PM2, systemd) or a container platform.
- Optional: an email provider (Resend) and object storage (S3-compatible).

---

## Deployment overview

Two processes run in production:

1. **API** — `node src/server.js` (long-lived HTTP server).
2. **Scheduler** — either the bundled worker `node src/jobs/worker.js`
   **or** an external cron that `POST`s to `/api/v1/cron/tick`.

Both share the same database. Reminders are idempotent (deduplicated per
user/event/key), so the worker and the external cron may coexist safely.

---

## 1. Get the code and install

```bash
cd Backend/backend
npm ci            # reproducible install from package-lock.json
npm run generate  # prisma generate
```

---

## 2. Configure the environment

Create a `.env` (or inject environment variables from your platform). Start from
`.env.example`. Production essentials:

```dotenv
NODE_ENV=production
PORT=4000

# Use a dedicated least-privilege role, not the superuser.
DATABASE_URL=postgresql://mygrowth_app:STRONG_PASSWORD@db-host:5432/mygrowth_diet_plan?schema=public

# Only the real frontend origin(s).
CORS_ORIGINS=https://app.mygrowth.example
FRONTEND_URL=https://app.mygrowth.example
APP_BASE_URL=https://api.mygrowth.example

# Generate with: openssl rand -hex 32
JWT_ACCESS_SECRET=<64-hex-chars>
JWT_REFRESH_SECRET=<64-hex-chars>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL_DAYS=30
BCRYPT_ROUNDS=12

# Required to enable POST /api/v1/cron/tick
CRON_SECRET=<strong-random-value>

EMAIL_PROVIDER=resend
RESEND_API_KEY=<resend-api-key>
EMAIL_FROM="MyGrowth Diet App <no-reply@mygrowth.example>"

STORAGE_ADAPTER=local
UPLOAD_DIR=/var/lib/mygrowth/uploads
FILE_MAX_BYTES=52428800

LOG_LEVEL=info
```

> **Never** set `NODE_ENV` to anything other than `production` on a real
> deployment — the seed only skips development sample accounts when
> `NODE_ENV=production`.

---

## 3. Provision the database

```sql
CREATE ROLE mygrowth_app LOGIN PASSWORD 'STRONG_PASSWORD';
CREATE DATABASE mygrowth_diet_plan OWNER mygrowth_app;
```

Keep superuser credentials for migrations/backups only. Restrict network access
to the application host. (See `docs/SECURITY.md` → least-privilege access.)

---

## 4. Migrate and seed

```bash
npm run migrate   # applies committed migrations (prisma migrate deploy)
npm run seed      # idempotent: 2027 programme content + definitions
```

- `migrate deploy` is the production-safe migration command; it never generates
  new migrations or resets data.
- `seed` is **idempotent** — safe to run on every deploy. In production it
  creates the 2027 programme, the 12 activity categories, the notification-event
  definitions and the settings, and **skips** the development accounts.
- The seed creates no weekly or day-by-day assignments; those remain
  admin-editable.

---

## 5. Create the Main Admin

Run **once**, with a strong password (or let it generate one and store it
securely):

```bash
npm run bootstrap:admin -- --email admin@mygrowth.example \
  --first-name Ada --last-name Obi
```

Re-running is a no-op if a Main Admin already exists. The Main Admin is the only
account that can create administrators and grant administrative access.

---

## 6. Run the API

Foreground (for a first smoke test):

```bash
NODE_ENV=production npm start
```

With PM2:

```bash
pm2 start src/server.js --name mygrowth-api --time
pm2 save
```

With systemd (`/etc/systemd/system/mygrowth-api.service`):

```ini
[Unit]
Description=MyGrowth Diet App API
After=network.target postgresql.service

[Service]
Type=simple
WorkingDirectory=/srv/mygrowth/Backend/backend
ExecStart=/usr/bin/node src/server.js
EnvironmentFile=/srv/mygrowth/Backend/backend/.env
Restart=always
RestartSec=5
User=mygrowth

[Install]
WantedBy=multi-user.target
```

---

## 7. Run the scheduler

**Option A — bundled worker:**

```bash
pm2 start src/jobs/worker.js --name mygrowth-worker --time
```

The worker runs the reminder suite every minute (Africa/Lagos) and performs
hourly housekeeping (expired refresh-token cleanup).

**Option B — platform/external cron:**

Schedule a request every minute (or every 5 minutes) to:

```
POST https://api.mygrowth.example/api/v1/cron/tick
Header: x-cron-secret: <CRON_SECRET>
```

The route is disabled unless `CRON_SECRET` is set. Example crontab:

```cron
* * * * * curl -fsS -X POST https://api.mygrowth.example/api/v1/cron/tick \
  -H "x-cron-secret: $CRON_SECRET" >/dev/null 2>&1
```

Reminder tasks are idempotent, so overlapping or retried ticks will not create
duplicate notifications.

---

## Reverse proxy and TLS

Terminate TLS at the proxy and forward to the API. Example nginx:

```nginx
server {
  listen 443 ssl;
  server_name api.mygrowth.example;

  ssl_certificate     /etc/letsencrypt/live/api.mygrowth.example/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/api.mygrowth.example/privkey.pem;

  client_max_body_size 60m;   # must exceed FILE_MAX_BYTES

  location / {
    proxy_pass         http://127.0.0.1:4000;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
  }
}
```

The app sets `trust proxy` so `X-Forwarded-*` headers are honoured for correct
client IPs and rate limiting. Ensure `CORS_ORIGINS` lists the real frontend
origin (with scheme, no trailing slash).

---

## Email configuration

- **Development/CI:** `EMAIL_PROVIDER=console` logs verification/reset links to
  stdout — no external service needed.
- **Production:** set `EMAIL_PROVIDER=resend`, `RESEND_API_KEY`, and a verified
  `EMAIL_FROM`. Links use `APP_BASE_URL`.

No email credentials are required for the app to boot; without them (console
mode) users simply won't receive mail.

---

## Storage configuration

Files are always served through the authenticated `GET /api/v1/files/:id` route,
never from a public static path, so a private bucket needs no bucket policy and
no signed URLs. Pick one adapter with `STORAGE_ADAPTER`:

### `local` (default)

Files are written under `UPLOAD_DIR` and streamed from there. The directory is
created automatically at startup, so a fresh host or an empty disk cannot break
the first upload. It still has to be a **durable** path: anything under the app's
own directory is wiped by a container redeploy. Ensure it is writable by the app
user and included in backups.

```dotenv
STORAGE_ADAPTER=local
UPLOAD_DIR=/var/data/uploads
```

### `s3` (any S3-compatible object store)

Amazon S3, Cloudflare R2, Backblaze B2, Supabase Storage and MinIO all work.
Multer still receives the upload on a temporary local path; the adapter uploads
it and deletes the temporary copy. Objects are private.

```dotenv
STORAGE_ADAPTER=s3
S3_BUCKET=mygrowth-files
S3_ACCESS_KEY_ID=…
S3_SECRET_ACCESS_KEY=…
S3_REGION=auto                     # "auto" for R2; the real region for S3
S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com   # empty for Amazon S3
S3_FORCE_PATH_STYLE=true           # required by R2/B2/MinIO, accepted by S3
S3_PREFIX=mygrowth/prod            # optional; keeps environments in one bucket
# UPLOAD_TEMP_DIR=/tmp/mygrowth-uploads   # where multipart uploads land first
```

Cloudflare R2 setup:

1. R2 → **Create bucket** (e.g. `mygrowth-files`), keep it private.
2. **Manage R2 API Tokens** → create a token with *Object Read & Write* on that
   bucket. Note the Access Key ID and Secret Access Key.
3. `S3_ENDPOINT` is `https://<account-id>.r2.cloudflarestorage.com` (the account
   ID is in the R2 overview page, not the bucket name).
4. Set the variables above and restart the API. `GET /api/v1/files/:id` will now
   stream from R2.

If the adapter is selected without credentials the first upload fails with
`STORAGE_NOT_CONFIGURED` naming the missing variables — it does not fail silently.

> Changing `STORAGE_ADAPTER` does not move existing files. Rows remember the
> adapter they were written with (`File.storageAdapter`), but downloads use the
> *current* adapter. Migrate existing objects (e.g. `rclone copy`) before
> switching a live deployment.

---

## Health checks and monitoring

```bash
curl -fsS https://api.mygrowth.example/api/v1/health
```

Returns HTTP 200 with `{ "status": "ok", "db": "up", ... }`, or **503** with
`db: "down"` if the database is unreachable. Point your platform health check
(load balancer, PM2, Kubernetes) at this endpoint.

Monitor:

- API 5xx rate and latency,
- database connections and disk,
- scheduler runs (`POST /cron/tick` responses or worker logs),
- audit log for denied elevation/IDOR attempts.

---

## Backups and recovery

- Schedule regular encrypted `pg_dump` backups off the primary host, and back up
  `UPLOAD_DIR` (or the object store).
- Test restores periodically. Recovery steps:

  ```bash
  # on a fresh host with a fresh database
  npm ci && npm run generate
  npm run migrate
  psql "$DATABASE_URL" < backup.sql
  # restore uploads, then:
  npm run bootstrap:admin -- --email admin@mygrowth.example   # no-op if present
  ```

- See `docs/SECURITY.md` for retention guidance.

---

## Upgrades and migrations

1. Back up the database.
2. `git pull` (or deploy the new artifact) and `npm ci`.
3. `npm run generate`.
4. `npm run migrate` (applies only new migrations).
5. `npm run seed` (idempotent).
6. Restart the API and worker.

Migrations are committed under `prisma/migrations/`; never edit an applied
migration. Use `prisma migrate dev` locally to create new ones and commit them.

---

## Scaling

- The API is **stateless** apart from the database and file storage; run multiple
  instances behind a load balancer.
- Run **one** scheduler (worker) unless you rely solely on idempotent external
  cron ticks.
- Database connection pooling is handled by Prisma; size the pool to the
  database's limits and the number of API instances.
- For multi-instance deployments, move uploads to shared/object storage so every
  instance can serve files.

---

## Hosting: Neon + Render + Vercel

This split works for this app. The only real decision is **where the uploaded
files live**, because that is the one thing none of these three platforms gives
you by default.

| Piece | Platform | What it holds |
| --- | --- | --- |
| Database | Neon (Postgres 16) | users, programmes, Daily Diet content, tick-offs, reports *metadata*, audit log |
| API | Render web service | the Node process — no durable state of its own |
| Web app | Vercel (static files) | the `flutter build web` output |

### The short answer on "many files and storage"

Neon never stores your files. It is a database: it stores **one row per upload**
(original name, MIME type, size, storage key) at a few hundred bytes each. 10,000
uploads is still only a few megabytes of database. The file *bytes* live in
object storage or on a disk. So the number of files does not affect your Neon
plan at all — pick Neon on database size, not on upload volume.

Sizing rule of thumb for the file store:

- 200 weekly audio messages at 8 MB ≈ 1.6 GB
- 365 literature PDFs at 2 MB ≈ 0.7 GB
- 1 year of members' report attachments ≈ 0.5–2 GB

Budget **5–10 GB for the first year**. Neon's free 0.5 GB is plenty for the
database itself.

### 1. Neon — the database

1. Create a project (Postgres 16). Neon gives you two connection strings: a
   **pooled** host (contains `-pooler`) and a **direct** host.
2. `DATABASE_URL` on Render = the **pooled** string (`?sslmode=require`). Prisma
   opens one pool per process; the pooler keeps you inside Neon's connection
   limit when Render restarts or you run more than one instance.
3. Run migrations against the **direct** host:

   ```bash
   cd Backend/backend
   DATABASE_URL="postgresql://…direct…" npm run migrate
   DATABASE_URL="postgresql://…direct…" npm run seed
   ```

   (Prisma migrations are happier without a transaction pooler. Adding
   `directUrl = env("DIRECT_URL")` to the `datasource` block is the tidier
   long-term option and lets `npm run migrate` use `DIRECT_URL` automatically.)
4. Free-plan behaviour: compute suspends after a few idle minutes, so the first
   query afterwards takes a second. Combined with Render's own sleep, the first
   visitor of the morning can wait ~30–60 s. A paid instance (either side) fixes
   it. Neon's free plan also keeps only a short restore window — keep your own
   `pg_dump` backups (see [Backups and recovery](#backups-and-recovery)).

### 2. Render — the API

New → **Web Service** → this repo:

| Setting | Value |
| --- | --- |
| Root directory | `Backend/backend` |
| Runtime | Node |
| Build command | `npm ci && npm run generate` |
| Start command | `npm run migrate && npm start` |
| Health check path | `/api/v1/health` |

Environment:

```dotenv
NODE_ENV=production
DATABASE_URL=postgresql://…-pooler…/mygrowth?sslmode=require
JWT_ACCESS_SECRET=<64+ random chars>
JWT_REFRESH_SECRET=<64+ random chars>
CRON_SECRET=<64+ random chars>
CORS_ORIGINS=https://your-app.vercel.app
APP_BASE_URL=https://your-service.onrender.com
FRONTEND_URL=https://your-app.vercel.app
EMAIL_PROVIDER=console            # or resend + RESEND_API_KEY + EMAIL_FROM
STORAGE_ADAPTER=s3
S3_BUCKET=mygrowth-files
S3_ACCESS_KEY_ID=…
S3_SECRET_ACCESS_KEY=…
S3_REGION=auto
S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
S3_FORCE_PATH_STYLE=true
```

Things that bite on Render:

- **Free instances have an ephemeral disk.** Every deploy, restart or crash
  wipes anything written under the app's own directory. Object storage (above)
  is the fix; a local `UPLOAD_DIR` is only safe on a paid persistent disk.
- **A persistent disk is a paid feature** (mount at `/var/data`,
  `UPLOAD_DIR=/var/data/uploads`). It also pins the service to **one instance** —
  a disk cannot be shared, so you cannot scale horizontally while files are on
  it.
- **Free services sleep after ~15 minutes idle** (30–60 s cold start). The
  in-process `node-cron` does not fire while asleep — if Daily Diet reminders
  matter, schedule the tick externally instead of running `npm run worker`
  (a background worker is also a paid service):

  ```
  POST https://your-service.onrender.com/api/v1/cron/tick
  x-cron-secret: $CRON_SECRET
  ```

  A GitHub Actions `schedule` or cron-job.org can do this free. The tick is
  idempotent, so overlapping calls are safe.
- Migrations in the start command are fine for a single instance. If you ever
  run two, move `npm run migrate` to a release step so they cannot race.

### 3. Vercel — the Flutter web app

Vercel has no Flutter runtime, so the build script downloads the SDK and caches
it under `/vercel/.cache`. Both files already exist in the repo:

- `Frontend/mygrowth_app/vercel.json` — install/build/output + SPA rewrite
- `Frontend/mygrowth_app/vercel-build.sh` — installs Flutter, runs
  `flutter build web --release --dart-define=API_BASE_URL=…`

Project settings:

| Setting | Value |
| --- | --- |
| Root directory | `Frontend/mygrowth_app` |
| Framework preset | Other |
| Build command | `bash vercel-build.sh` (from `vercel.json`) |
| Output directory | `build/web` |

Environment variables:

```dotenv
API_BASE_URL=https://your-service.onrender.com/api/v1
FLUTTER_VERSION=3.47.2     # optional pin; defaults in the script
```

Notes:

- `API_BASE_URL` is compiled into the bundle. Changing it requires a redeploy —
  and it must be the public HTTPS API URL, **including** `/api/v1`.
- Add the Vercel production domain to `CORS_ORIGINS` on Render. Preview
  deployments get a fresh `*.vercel.app` host each time; use a custom domain for
  the real app, or add previews deliberately.
- Sessions survive the cross-site split: the access token is a bearer header and
  the refresh token is also stored client-side and sent in the request body, so
  the `SameSite=Lax` refresh cookie is not required. Nothing to change.
- Deep links: add the `vercel.json` rewrite if you ever switch Flutter to the
  path URL strategy; with the default hash strategy `/#/diet` already works.
- First load is heavy (≈4 MB `main.dart.js` plus the CanvasKit bundle). Vercel
  serves it fine; it is a one-time cost per visitor, cached afterwards.

### Where files live — pick one

| Option | Cost | Works on Render free? | Durable | Setup |
| --- | --- | --- | --- | --- |
| **Cloudflare R2** | 10 GB free, no egress fees | ✓ | ✓ | `STORAGE_ADAPTER=s3` + 5 env vars |
| Backblaze B2 | 10 GB free | ✓ | ✓ | same adapter |
| Supabase Storage | 1 GB free | ✓ | ✓ | same adapter |
| Render persistent disk | paid service + ~$0.25/GB | ✗ | ✓ (single instance) | `UPLOAD_DIR=/var/data/uploads` |

**Recommended:** R2. It keeps every service on a free tier, survives redeploys,
allows more than one instance, and keeps monthly bandwidth off Render — files
still stream through `GET /api/v1/files/:id`, so access rules are unchanged.
The `s3` adapter is implemented and unit-tested (`tests/storage.test.js`), so
this is configuration only. The persistent disk remains the no-code fallback if
you would rather not create an R2 token.

### Order of operations

1. Neon project → copy pooled + direct strings.
2. R2 bucket + API token → keep the keys for step 3.
3. Render service → env vars (including `S3_*`) → `npm run migrate && npm run seed`.
4. `npm run bootstrap:admin` against the Neon URL from your machine.
5. `curl https://your-service.onrender.com/api/v1/health` → `{ "status": "ok" }`.
6. Vercel project with `API_BASE_URL` → deploy → load the site → sign in.
7. Add the Vercel domain to `CORS_ORIGINS`, redeploy Render.
8. Upload one test file as an admin and open it as a member — that single check
   proves the bucket, the credentials and the access rules together.

---

## Production checklist

- [ ] `NODE_ENV=production`, `npm ci`, `prisma generate`.
- [ ] Strong `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `CRON_SECRET` set.
- [ ] `DATABASE_URL` uses a dedicated least-privilege role.
- [ ] `npm run migrate` and `npm run seed` completed.
- [ ] Main Admin created via `bootstrap:admin`.
- [ ] API running with restart-on-crash; HTTPS via the proxy.
- [ ] Scheduler running (worker or cron tick).
- [ ] `CORS_ORIGINS` limited to the real frontend origin(s).
- [ ] `STORAGE_ADAPTER=s3` with `S3_*` set (or `UPLOAD_DIR` on a persistent disk) — never the ephemeral container disk.
- [ ] Email provider configured (or intentionally left in console mode).
- [ ] Backups scheduled and a restore tested.
- [ ] Health check wired to the platform.
