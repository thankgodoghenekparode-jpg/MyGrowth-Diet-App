# Implementation Status

Live checklist. ✅ done · 🚧 in progress · ⬜ not started

## Backend (Node/Express/Prisma) — `Backend/backend`
- ✅ Project scaffold, Express app, central error handling, Zod validation, security middleware
- ✅ PostgreSQL schema (all Section 20 entities) + migrations (incl. `single_main_admin_guard` DB trigger)
- ✅ JWT auth (register / login / logout / refresh-with-rotation / forgot / reset / verify),
  SHA-256-hashed refresh tokens with reuse detection, single-Main-Admin invariant
- ✅ RBAC: MAIN_ADMIN / ADMIN / MEMBER with server-side enforcement + audit logs
- ✅ 2027 programme seed (12 monthly plans faithful to spec, quarterly + annual templates,
  dev accounts; weekly/daily assignments intentionally left for admins)
- ✅ **Daily Diet** — the admin-configured devotional structure:
  - `DailyDietSection` (the structure: label, behaviour, order, publish/archive)
  - `DailyDietContent` (what a section carries on a day, week or month)
  - `DailyDietCompletion` (a member's tick-off, note and prayer duration)
  - Content is filed against a **scope anchor** — the day itself, the Sunday that
    starts its week, or the first of its month — and the closest scope wins, so a
    day can override its week and a week its month. Admins may pick any day of a
    period; the row is always filed against the anchor.
  - 11 default sections: Prayers · Scriptures reading · Bible study topics ·
    Literature daily read · Daily proverbs · Fasting days · Weekly/monthly report ·
    Declarations · Daily/weekly audio messages · Prayer accountability partner ·
    Music (admin may add, rename, reorder or archive any of them)
- ✅ 2027 daily-diet seed: the full 365-day Scripture reading plan (Acts & Romans)
  plus the month- and week-scoped content for every section — **873 content rows**
- ✅ REST API `/api/v1` (programmes, materials & files, activities, goals, prayer partners,
  reports & reviews, reflections, testimonies, notifications, announcements, admin,
  analytics, audit logs, settings, cron)
- ✅ Scheduler worker + protected cron tick endpoint with idempotent notification dedup
- ✅ File storage adapters — `local` (`UPLOAD_DIR`, created at startup) and `s3`
  (any S3-compatible store: Cloudflare R2, Backblaze B2, Supabase Storage,
  Amazon S3, MinIO). Objects stay private and stream through the authenticated
  `GET /api/v1/files/:id`; no bucket policy or signed URL is exposed.
- ✅ Backend tests — **126 passing** (`npm test`)
- ✅ `bootstrap:admin` script, `README.md`

## Flutter frontend — `Frontend/mygrowth_app`
- ✅ Design system: colours, typography, spacing, theme (navy/gold/white per spec,
  gradient category tiles adapted from the reference image)
- ✅ Core widgets: cards, buttons, badges, text fields, empty/error/skeleton states,
  toasts, confirm dialogs, stat tiles, progress bars, pagination
- ✅ Network layer: typed API client, 401 refresh-retry, error-envelope mapping
- ✅ Auth: session controller, login, registration, forgot/reset password, profile completion
- ✅ Navigation: responsive member shell (bottom nav + sidebar/rail), admin shell,
  role-guarded routes, splash/session restore
- ✅ Member dashboard (welcome, prayer focus, affirmation, today's checklist, quick-access
  grid, monthly confession, announcements)
- ✅ Member features: growth plan, Bible reading, daily diet, fasting, goals,
  materials, prayer room/partners, reports, reflections, progress, notifications,
  announcements, more, profile
- ✅ **Daily Diet (member)** — `/diet` hub: date strip + calendar picker, progress card,
  monthly theme card and the 11 section tiles. Tapping a tile opens
  `/daily-diet/section/:id?date=YYYY-MM-DD`, which dispatches on the section's
  behaviour: `TEXT` (read + tick), `MATERIAL` (open/download the uploaded file),
  `TIMER` (prayer stopwatch that records the minutes actually prayed),
  `TICK` (fasting tick-off), `REPORT` (type or upload the weekly/monthly report) and
  `PARTNER` (jump to the prayer room).
- ✅ Admin features: dashboard, members, member detail, reports & reviews, programmes,
  programme editor, monthly plans, weekly plans, materials, activities, prayer
  partnerships & safety, announcements, analytics, audit logs, settings,
  Admin Access Management, admin-more
- ✅ **Daily Diet (admin)** — `/admin/daily-diet`: a *Structure* tab to add, rename,
  reorder, publish and archive sections, and a *Day content* tab to pick a date and
  write what each section carries on that day, the week or the month (with a live
  note of which anchor the row will be filed against), attach materials and publish
  the whole day in one action.

## Verification tooling
- ✅ `scripts/e2e-smoke.mjs` — full acceptance-flow smoke test (**40/40 passing**)
- ✅ `scripts/contract-probe.mjs` — wire-contract shape probe (backend ↔ Flutter models)
- ✅ `scripts/contract-probe2.mjs` — authoring-flow probe (uses exact Flutter request bodies)
- ✅ `scripts/contract-probe3.mjs` — remaining member/admin endpoint shape probe
- ✅ `scripts/serve-web.mjs` — static server for the built web app (SPA route fallback)
- ✅ `scripts/daily-diet-probe.mjs` — live end-to-end probe of the Daily Diet
  (**41/41 passing**): member day bundle and behaviours, tick-offs, prayer minutes,
  notes, report upload + attachment + delete, IDOR, progress isolation, admin section
  CRUD / publish / archive, day/week/month scope anchoring, closest-scope-wins
  and publish-day. Writes its own fixtures and removes them again.

## Documentation
- ✅ README.md, docs/API.md, docs/SECURITY.md, docs/DEPLOYMENT.md, docs/FRONTEND_CONVENTIONS.md

## Verification results
- ✅ `flutter analyze` — No issues found (whole app)
- ✅ `flutter test` — 35/35 passing (22 existing + 13 new Daily Diet model tests)
- ✅ `flutter build web --release` — built `build/web` (main.dart.js 4.13 MB)
- ✅ Backend `npm test` — 126/126 passing (22 of them cover the Daily Diet:
  structure and behaviours, tick-offs, prayer minutes, notes, IDOR, progress
  isolation, admin section CRUD / publish / archive / reorder, content write,
  week- and month-scope anchoring, closest-scope-wins, publish-day, content delete;
  7 more cover member file upload, download, ownership and delete-when-unused)
- ✅ Live re-check: `GET /api/v1/daily-diet?date=2027-03-17` returns the 11 sections
  with their behaviours and the seeded reading, study topic, declarations and prayer
  focus; a week-scoped row written on a Wednesday lands on the Sunday anchor and
  reaches members on every day of that week.
- ✅ Daily Diet probe (`scripts/daily-diet-probe.mjs`) — **41/41 passing** against the
  running dev server.
- ✅ Storage adapter tests (`tests/storage.test.js`) — **9/9 passing**: upload,
  prefix, temp-file cleanup (success and failure), stat, exists, streaming,
  idempotent delete, key validation, and a precise error when `s3` is selected
  without credentials.
- ✅ Backend migrations applied + seed run against local PostgreSQL 16.
- ✅ End-to-end smoke (`scripts/e2e-smoke.mjs`) — **40/40 passing**: register → dashboard →
  record activity → goal → report → admin review → prayer-partner propose/accept flow.
- ✅ Backend ↔ Flutter **wire-contract alignment** complete. The backend is now the server of
  record while the Flutter client defines the field names/envelopes; the backend emits the
  aliases the client reads (e.g. `name`/`timeZone` on the user, flat `/me` responses,
  `ProgressSummary` keys on `/me/progress`, `actualDuration` on activity records,
  `body`/`MINISTRY_ADMINS` on testimonies, `status` on prayer-session PATCH, and the
  `/me/annual-letter` editor endpoints).
