# MyGrowth Diet App

**Ministry:** Healings Erhuvwuigho Azuike Ministry
**Programme:** Growth Diet Plan 2027
**Tagline:** *Growing in the Word. Consistent in Prayer. Accountable in Purpose.*

A production-minded spiritual-growth application that helps members build
consistent habits (prayer, Bible reading, study, fasting), access
ministry-approved resources, set goals, connect with prayer partners, record
activities, and submit accountability reports — with a full administration
area for programme management.

## Architecture

| Layer     | Technology |
|-----------|------------|
| Frontend  | Flutter / Dart (Material 3), Riverpod, GoRouter — Android, iOS, Web |
| Backend   | Node.js + Express (JavaScript, ESM), REST API under `/api/v1` |
| Database  | PostgreSQL 16 + Prisma ORM |
| Auth      | Backend-owned JWT (short-lived access + rotating refresh), bcrypt |
| Storage   | Pluggable storage abstraction (local-disk adapter by default; S3/Supabase-ready interface) |
| Scheduler | `node-cron` worker + protected `POST /api/v1/cron/tick` endpoint |
| Email     | Provider abstraction (`console` adapter by default; Resend adapter included) |

```text
mygrowth-diet-plan/
  Frontend/mygrowth_app/   # Flutter app (feature-based lib/ structure)
  Backend/backend/         # Node/Express API, Prisma schema, seeds, jobs
  docs/                    # API.md, SECURITY.md, DEPLOYMENT.md, FRONTEND_CONVENTIONS.md
  README.md
```

## Quick start (local)

### 1. Database

PostgreSQL must be running. Create a database and put its URL in
`Backend/backend/.env`:

```sql
CREATE DATABASE mygrowth_diet_plan;
```

### 2. Backend

```powershell
cd Backend/backend
copy .env.example .env        # then edit DATABASE_URL etc.
npm install
npx prisma migrate dev        # creates schema
npm run seed                  # seeds Growth Diet Plan 2027 + dev accounts
npm run dev                   # starts API on http://localhost:4000
```

One-time production admin bootstrap (creates the single Main Admin; refuses to
run twice, no hardcoded password):

```powershell
npm run bootstrap:admin
```

Run the backend test suite:

```powershell
npm test
```

Development seed accounts (password **`MyGrowth!Dev2027`**, created only when
`NODE_ENV !== production`) — see `Backend/backend/README.md` for the full list:

| Email | Role / state |
|-------|--------------|
| `mainadmin@mygrowth.dev` | MAIN_ADMIN |
| `admin@mygrowth.dev` | ADMIN (access ACTIVE) |
| `suspended.admin@mygrowth.dev` | ADMIN (access SUSPENDED) |
| `grace.member@mygrowth.dev`, `daniel.member@mygrowth.dev` | ACTIVE members |
| `pending.member@mygrowth.dev` | PENDING member |
| `suspended.member@mygrowth.dev` | SUSPENDED member |

### 3. Frontend

```powershell
cd Frontend/mygrowth_app
flutter pub get
flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

Build for release:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

No secret ever ships in the Flutter bundle — only the public API base URL is
configured at build time via `--dart-define`.

To preview a release build locally (with SPA route fallback, so `/diet` and
`/admin/daily-diet` survive a refresh):

```powershell
cd Frontend/mygrowth_app
flutter build web --release --dart-define=API_BASE_URL=http://localhost:4000/api/v1
cd ..\..
node scripts/serve-web.mjs 8080
# http://localhost:8080
```

## Roles

- **Main Admin** (exactly one, created via `npm run bootstrap:admin` or the
  seed in development) — everything, including *Admin Access Management*.
- **Admin** — day-to-day programme and member management. Cannot manage other
  admins or touch the Main Admin.
- **Member** — everything personal: plan, activities, goals, materials,
  prayer partners, reports, reflections.

All authorization is enforced server-side; the Flutter UI merely hides
unavailable controls.

## Seeded programme content

`npm run seed` creates the **Growth Diet Plan 2027** with all twelve monthly
plans (theme, prayer focus, Bible-reading guidance, literature, audio
messages, fasting guidance, confession, reflection questions), quarterly
review content, the annual reflection template, activity categories, and — in
development only — sample accounts and data.

It also seeds the **Daily Diet**: the eleven default sections and, from the
supplied 2027 plan, the full 365-day Scripture reading schedule (Acts and
Romans) with its heading, focus and note, plus the month- and week-scoped
content for every other section. Administrators can change any of it from
*Admin → Daily Diet*; nothing is hard-coded in the app.

## Documentation

- `docs/API.md` — REST endpoints with request/response examples
- `docs/SECURITY.md` — roles, privacy model, storage access, audit logging
- `docs/DEPLOYMENT.md` — Neon + Render + Vercel hosting, S3/R2 file storage and cron setup
- `docs/FRONTEND_CONVENTIONS.md` — Flutter conventions used in this repo
- `Backend/backend/README.md` — backend scripts and configuration
- `IMPLEMENTATION_STATUS.md` — live checklist of what is done

## Environment variables

Backend: see `Backend/backend/.env.example` (every variable documented).
Frontend: `API_BASE_URL` (public, build-time `--dart-define`).

Never commit real credentials.
