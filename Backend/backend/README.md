# MyGrowth Diet App — Backend API

REST API for the **MyGrowth Diet App** (Healings Erhuvwuigho Azuike Ministry) —
a year-long programme of prayer, Bible reading, study, literature, fasting and
accountability. Built with Node.js (ESM), Express, Prisma and PostgreSQL.

This package is the whole backend: database schema + migrations, seed content,
auth, member features, admin features, scheduler and the test suite.

---

## Contents

- [Stack](#stack)
- [Quick start](#quick-start)
- [Environment variables](#environment-variables)
- [Scripts](#scripts)
- [Development accounts](#development-accounts)
- [Architecture](#architecture)
- [Roles and access](#roles-and-access)
- [Programme content model](#programme-content-model)
- [Scheduler](#scheduler)
- [Testing](#testing)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)

---

## Stack

| Concern | Choice |
| --- | --- |
| Runtime | Node.js 20+ (developed on Node 25) |
| Language | JavaScript, ESM (`"type": "module"`), no TypeScript |
| Server | Express 4 |
| Database | PostgreSQL 16 via Prisma 6 |
| Auth | JWT access token (15m) + rotating refresh token (30d, hashed at rest) |
| Validation | Zod, applied through a shared `validate()` middleware |
| Email | Pluggable — `console` (default) or `resend` |
| Storage | Pluggable — `local` disk (default, served via `/api/v1/files/:id`) or `s3` stub |
| Scheduler | `node-cron` worker **or** `POST /api/v1/cron/tick` |
| Tests | `node:test` + `supertest` |

All API routes live under `/api/v1`. Responses are JSON. Errors use a single
shape: `{ "error": { "code", "message", "details?" } }`.

---

## Quick start

Requires a local PostgreSQL 16 server (the default `.env.example` uses local
trust auth for the `postgres` superuser).

```bash
cd Backend/backend
npm install

cp .env.example .env          # Windows: copy .env.example .env
# edit .env if your Postgres credentials differ

npm run generate              # prisma generate
npm run migrate               # apply migrations (prisma migrate deploy)
npm run seed                  # 2027 programme + dev sample accounts

npm run dev                   # http://localhost:4000 (nodemon)
# or: npm start
```

Health check:

```bash
curl http://localhost:4000/api/v1/health
# {"status":"ok","service":"mygrowth-diet-plan-backend",...,"db":"up",...}
```

Log in as the seeded Main Admin (development only):

```bash
curl -X POST http://localhost:4000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"mainadmin@mygrowth.dev","password":"MyGrowth!Dev2027"}'
```

The production entrypoint is `src/server.js`; `src/app.js` exports
`createApp()` for tests.

---

## Environment variables

Copy `.env.example` to `.env`. **Never commit `.env`.** Full reference:

| Variable | Default | Purpose |
| --- | --- | --- |
| `NODE_ENV` | `development` | `development` \| `production` \| `test` |
| `PORT` | `4000` | HTTP port |
| `DATABASE_URL` | `postgresql://postgres@localhost:5432/mygrowth_diet_plan?schema=public` | Primary database |
| `TEST_DATABASE_URL` | `…/mygrowth_diet_plan_test` | Database used by `npm test` (migrated + truncated) |
| `FRONTEND_URL` | `http://localhost:3000` | Primary client origin |
| `CORS_ORIGINS` | `http://localhost:3000,http://localhost:5173,http://localhost:8080` | Comma-separated allowlist |
| `APP_BASE_URL` | `http://localhost:4000` | Base URL for links in emails |
| `JWT_ACCESS_SECRET` | dev placeholder | **Must** be a strong random value in production |
| `JWT_REFRESH_SECRET` | dev placeholder | **Must** be a strong random value in production |
| `JWT_ACCESS_TTL` | `15m` | Access-token lifetime |
| `JWT_REFRESH_TTL_DAYS` | `30` | Refresh-token lifetime |
| `BCRYPT_ROUNDS` | `10` | Password hashing cost |
| `REFRESH_COOKIE_NAME` | `mgdp_refresh` | httpOnly refresh cookie name |
| `CRON_SECRET` | *(empty)* | Required by `POST /api/v1/cron/tick`; empty disables the route |
| `EMAIL_PROVIDER` | `console` | `console` or `resend` |
| `RESEND_API_KEY` | *(empty)* | Required only when `EMAIL_PROVIDER=resend` |
| `EMAIL_FROM` | `MyGrowth Diet App <no-reply@mygrowth.local>` | From header |
| `OPENAI_API_KEY` | *(empty)* | Optional; enables the authenticated AI Assistant. Store only on the backend host. |
| `OPENAI_MODEL` | `gpt-4.1-mini` | Optional model used by the AI Assistant. |
| `STORAGE_ADAPTER` | `local` | `local` or `s3` (stub) |
| `UPLOAD_DIR` | `./uploads` | Local storage root |
| `FILE_MAX_BYTES` | `52428800` | Upload size limit (50 MB) |
| `LOG_LEVEL` | `info` | `debug` \| `info` \| `warn` \| `error` |

> The default email provider (`console`) **logs** verification/reset links to
> stdout and never sends mail, so nothing external is needed for local dev or
> CI. See `docs/DEPLOYMENT.md` for production email/storage configuration.

---

## Scripts

| Script | What it does |
| --- | --- |
| `npm run dev` | Start the API with nodemon (auto-reload) |
| `npm start` | Start the API (production mode as configured) |
| `npm run worker` | Start the standalone reminder scheduler (node-cron) |
| `npm run migrate` | Apply pending migrations (`prisma migrate deploy`) |
| `npm run migrate:dev` | Create/apply a dev migration |
| `npm run generate` | Regenerate the Prisma client |
| `npm run seed` | Idempotent seed (2027 content, definitions, dev accounts) |
| `npm run bootstrap:admin` | Create the single Main Admin (once) |
| `npm test` | Prepare the test DB and run the whole suite |
| `npm run lint` | ESLint |

### `npm run bootstrap:admin`

Creates the **only** Main Admin account. Safe to re-run — if a Main Admin
already exists it is a no-op.

```bash
npm run bootstrap:admin -- --email admin@example.org
# generates a strong password and prints it once

npm run bootstrap:admin -- --email admin@example.org --password "YourStrongPass" \
  --first-name Ada --last-name Obi
```

Environment fallbacks: `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_FIRST_NAME`,
`ADMIN_LAST_NAME`. The script refuses to create a second Main Admin (and a
database trigger enforces this even outside the script).

---

## Development accounts

`npm run seed` creates these **only when `NODE_ENV !== 'production'`**.
All share the password **`MyGrowth!Dev2027`**.

| Email | Role | Status | Admin access |
| --- | --- | --- | --- |
| `mainadmin@mygrowth.dev` | `MAIN_ADMIN` | ACTIVE | ACTIVE |
| `admin@mygrowth.dev` | `ADMIN` | ACTIVE | ACTIVE |
| `suspended.admin@mygrowth.dev` | `ADMIN` | ACTIVE | SUSPENDED |
| `grace.member@mygrowth.dev` | `MEMBER` | ACTIVE | — |
| `daniel.member@mygrowth.dev` | `MEMBER` | ACTIVE | — |
| `pending.member@mygrowth.dev` | `MEMBER` | PENDING | — |
| `suspended.member@mygrowth.dev` | `MEMBER` | SUSPENDED | — |

> These are development fixtures. They are never created in production, and the
> password is not a secret to reuse anywhere real.

---

## Architecture

```
src/
  app.js                    Express app factory (middleware + route mounting)
  server.js                 HTTP entrypoint (listens, graceful shutdown)
  config/index.js           Reads + normalises environment variables
  db/index.js               Single PrismaClient instance
  middleware/
    auth.js                 requireAuth / requireApprovedMember / requireAdmin / requireMainAdmin
    error.js                notFound + central error handler
    rateLimiters.js         global / auth / sensitive limiters (skipped in tests)
  lib/                      Cross-cutting helpers
    errors.js               AppError + asyncHandler + typed error factories
    validate.js             Zod validate() middleware + shared schemas
    jwt.js                  Access/refresh token signing + verification
    password.js             bcrypt hash/compare
    pagination.js           Standard { data, meta } envelopes
    dates.js                Period keys (week/month/quarter/year) + ISO helpers
    programme.js            Programme/plan resolution for a date
    reportFields.js         Structured report field definitions
    settings.js             Cached runtime settings
    audit.js                Audit-log writer
    contentShapes.js        Canonical + display-alias JSON shapes for content
    logger.js               Level-based JSON-ish logger (no secrets)
  modules/                  Feature routers (see docs/API.md for the full map)
    auth/ me/ reports/ reflections/ notifications/ prayerPartners/
    programmes/ materials/ announcements/ files/ admin/ cron/
  services/
    email/                  Email provider (console | resend)
    storage/                Storage adapter (local | s3 stub)
    notifications.js        Notification creation + fan-out
  jobs/
    worker.js               node-cron scheduler entrypoint
    tasks.js                Idempotent reminder tasks
prisma/
  schema.prisma             Data model (PascalCase table names)
  migrations/               Committed SQL migrations
  seed.js                   Idempotent content + dev seed
scripts/
  bootstrap-admin.js        One-time Main Admin creation
  test-setup.js             Prepares the test database before `npm test`
tests/                      node:test + supertest suite
```

### Error + pagination conventions

Every error response:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "…", "details": { } } }
```

Every paginated list:

```json
{ "data": [ … ], "meta": { "page": 1, "pageSize": 20, "total": 42, "totalPages": 3 } }
```

---

## Roles and access

Three roles: `MAIN_ADMIN`, `ADMIN`, `MEMBER`.

- Exactly **one** `MAIN_ADMIN` may exist — enforced by a DB trigger
  (`User_single_main_admin`). The role is never accepted from client input.
- `ADMIN` accounts are created **only by the Main Admin** and start with
  `adminAccess = PENDING` (no admin access until granted).
- `MAIN_ADMIN` and `ADMIN` pass `requireAdmin` **only when**
  `adminAccess = ACTIVE`; the Main Admin is otherwise always allowed.
- Member endpoints require `status = ACTIVE` (`requireApprovedMember`).
- The Main Admin account cannot be modified through access-management routes.

Admin account lifecycle: `PENDING` → `ACTIVE` → `SUSPENDED` → `REVOKED`
(grant / suspend / reactivate / revoke under `/api/v1/admin/admins`).

---

## Programme content model

`Programme` (annual) → `MonthlyPlan` (12) → `WeeklyPlan` → `DailyActivity`.

- The seed creates the **2027 programme** with its annual content and all 12
  monthly plans exactly as specified. **No weekly or day-by-day assignments are
  fabricated** — those tables stay empty and are edited by administrators.
- Members only see `PUBLISHED` content; administrators with granted access also
  see `DRAFT`/`ARCHIVED` content so the same routes back the editors.
- `GET /api/v1/programmes/:idOrYear/monthly-plans` accepts a programme UUID
  **or** a 4-digit year.

### Response shapes

Storage column names are the source of truth and are always present. A small
set of **display aliases** is added for the Flutter client (see
`src/lib/contentShapes.js`), e.g. `ministryName` (alias of `ministry`),
`prayerFocus` (alias of `annualPrayerFocus`), `confession`, `goalsGuidance`,
`audioMessageList`, `prayerDurationTarget`, and string forms of the JSON list
columns. The raw JSON is preserved under `literatureItems` /
`extraActivitiesItems` when a free-text string is emitted.

---

## Scheduler

Reminder logic lives in `src/jobs/tasks.js` and is **idempotent**: notifications
are deduplicated by the unique `(userId, eventType, eventKey)` constraint, so
overlapping runs are safe. Tasks:

- daily activity reminder,
- weekly / monthly report reminders,
- quarterly review reminder,
- annual reflection reminder,
- upcoming prayer-session reminder,
- expired refresh-token cleanup.

Run it either way:

```bash
npm run worker                                   # node-cron, every minute (Africa/Lagos)
curl -X POST http://localhost:4000/api/v1/cron/tick \
  -H "x-cron-secret: $CRON_SECRET"               # platform/external scheduler
```

`POST /api/v1/cron/tick` is disabled unless `CRON_SECRET` is set.

---

## Testing

```bash
npm test
```

`npm test` first runs `scripts/test-setup.js`, which migrates and truncates
`TEST_DATABASE_URL`, then executes every `tests/**/*.test.js` file with
`--test-concurrency=1` (each file is its own process, so the database is not
shared mid-run). Tests never touch the development database.

Current status: **81 tests, all passing.** The suite covers auth/authorization
guards, IDOR protection, mass-assignment attempts, the single-Main-Admin guard,
programme content fidelity, reports, activities/goals, prayer partners and the
cron/sec-retry paths.

Test fixtures use the password `TestPass!2027` and a `seedBaseline()` helper
(2027 programme + definitions) rather than the dev accounts.

---

## Documentation

- [`docs/API.md`](../../docs/API.md) — every endpoint, auth, params, examples.
- [`docs/SECURITY.md`](../../docs/SECURITY.md) — threat model, controls, privacy,
  data retention, recovery.
- [`docs/DEPLOYMENT.md`](../../docs/DEPLOYMENT.md) — production configuration,
  migrations, scheduler, backups.

---

## Troubleshooting

- **`Can't reach database server`** — Postgres isn't running, or `DATABASE_URL`
  is wrong. On Windows, confirm the PostgreSQL 16 service is started.
- **`npm test` fails immediately** — make sure `TEST_DATABASE_URL` points to a
  database the current user can create/drop tables in.
- **`EADDRINUSE :4000`** — another process holds the port:
  `Get-NetTCPConnection -LocalPort 4000` then `Stop-Process -Id <pid>`.
- **Admin gets `403 ADMIN_ACCESS_REQUIRED`** — the account exists but its
  `adminAccess` is not `ACTIVE`; grant it from the Main Admin.
- **Uploads fail** — check `UPLOAD_DIR` exists/writable and the file is within
  `FILE_MAX_BYTES`.
