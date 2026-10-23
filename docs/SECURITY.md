# MyGrowth Diet App — Security Documentation

This document describes the security model, controls, privacy rules, and
operational practices of the MyGrowth Diet App backend. It is written for
maintainers and operators; it does not replace a professional security audit
before handling real member data at scale.

---

## Contents

- [Scope and threat model](#scope-and-threat-model)
- [Authentication](#authentication)
- [Authorization (RBAC)](#authorization-rbac)
- [The single Main Admin rule](#the-single-main-admin-rule)
- [Mass assignment and privilege escalation](#mass-assignment-and-privilege-escalation)
- [IDOR / object-level authorization](#idor--object-level-authorization)
- [Input validation](#input-validation)
- [Transport and headers](#transport-and-headers)
- [Rate limiting](#rate-limiting)
- [Uploads and stored files](#uploads-and-stored-files)
- [Secrets management](#secrets-management)
- [Logging and audit trail](#logging-and-audit-trail)
- [Privacy and data classification](#privacy-and-data-classification)
- [Data retention](#data-retention)
- [Backups and recovery](#backups-and-recovery)
- [Least-privilege database access](#least-privilege-database-access)
- [Production checklist](#production-checklist)
- [Reporting a vulnerability](#reporting-a-vulnerability)

---

## Scope and threat model

In scope: the REST API, its database, authentication/session handling, uploaded
files, the reminder scheduler, and administrative workflows.

Primary threats considered:

- **Account takeover** — credential stuffing, brute force, token theft/replay.
- **Privilege escalation** — a member obtaining admin capabilities, or an admin
  obtaining Main Admin capabilities.
- **Horizontal data access (IDOR)** — one member reading another member's
  private reports, reflections, prayer content or profile.
- **Unsafe data exposure** — stack traces, secrets, password hashes, or private
  journal/reflection text leaking to clients or logs.
- **Abuse / spam** — automated registration, upload flooding, prayer-partner
  request spam.
- **Malicious uploads** — oversized or malformed files, path traversal.

---

## Authentication

- **Passwords** are hashed with bcrypt (`BCRYPT_ROUNDS`, default 10). Plaintext
  passwords are never stored or logged.
- **Access tokens** are short-lived JWTs (default 15 minutes) signed with
  `JWT_ACCESS_SECRET`. They carry the subject and a `typ: "access"` claim;
  tokens with the wrong type are rejected.
- **Refresh tokens** are long-lived (default 30 days) and stored **SHA‑256
  hashed** — a database leak does not yield usable refresh tokens. They are
  delivered in an httpOnly cookie (`REFRESH_COOKIE_NAME`).
- **Rotation and reuse detection:** every refresh rotates the token. If an
  already-used token is presented again, the entire token *family* is revoked,
  which detects token theft.
- **Immediate revocation:** suspending a member or suspending/revoking an
  admin's access revokes that user's refresh tokens, ending active sessions.
- **On every request**, `requireAuth` re-reads the user row from the database.
  Role or status changes therefore take effect immediately — a stale JWT cannot
  outlive a suspension.
- **Brute-force protection:** auth endpoints are rate-limited (see
  [Rate limiting](#rate-limiting)); password reset and verification requests use
  an even stricter limiter.

### Password policy

- Passwords are validated on the server (`passwordSchema`); the bootstrap script
  requires at least 12 characters in production (8 in development).
- Development sample accounts share a well-known password and must never be
  created in production (the seed skips them when `NODE_ENV=production`).

---

## Authorization (RBAC)

Three roles: `MAIN_ADMIN`, `ADMIN`, `MEMBER`.

| Gate | Rule |
| --- | --- |
| `requireAuth` | Valid access token; account not `SUSPENDED`/`DEACTIVATED`. |
| `requireApprovedMember` | When `registration.approvalRequired` is on, `PENDING` members cannot reach content routes. |
| `requireAdmin` | Role `ADMIN` or `MAIN_ADMIN` **and** `adminAccess = ACTIVE`. |
| `requireMainAdmin` | Role `MAIN_ADMIN` **and** `adminAccess = ACTIVE`. |

- The **role is never taken from client input**. It is set only by seeding, the
  bootstrap script, or the Main-Admin-only admin-creation route (which always
  creates `ADMIN`, never `MAIN_ADMIN`).
- Administrator accounts are created **only by the Main Admin** and begin with
  `adminAccess = PENDING`, granting no administrative access until explicitly
  granted.
- Every failed elevation attempt (member → admin route, admin → Main Admin route,
  member → administrator account) is written to the audit log with
  `outcome = DENIED`.

---

## The single Main Admin rule

Exactly one `MAIN_ADMIN` may exist. This is enforced at several layers:

1. **Bootstrap script** serialises creation with a Postgres advisory lock inside
   a `SERIALIZABLE` transaction and is a no-op if a Main Admin already exists.
2. **API** exposes no route that can create a Main Admin, and the access-
   management route refuses to modify the Main Admin's own account.
3. **Database trigger** (`User_single_main_admin`, migration
   `20261019135100_single_main_admin_guard`) rejects any insert/update that would
   create a second `MAIN_ADMIN`, even if application code is bypassed.

---

## Mass assignment and privilege escalation

- Request bodies pass through **Zod schemas with explicit fields**; unknown keys
  are stripped rather than assigned.
- `PATCH /me` and `PATCH /admin/users/:id` accept only profile fields. Attempts
  to change `role`, `status`, `adminAccess`, `email` or `id` are rejected with
  `FIELD_NOT_EDITABLE`, audited as `privilege_escalation_attempt`.
- Administrators cannot be edited through the member-management routes
  (`ROLE_PROTECTED`); administrator changes go only through Main-Admin-only
  access management.
- Admin access actions are limited to the enum
  `grant | suspend | reactivate | revoke`.

---

## IDOR / object-level authorization

- Member resources (reports, reflections, testimonies, goals, activity records,
  notifications, prayer sessions, annual letters) are always queried **scoped to
  `req.user.id`**. Fetching another member's row returns `NOT_FOUND`, so the API
  does not confirm the existence of another member's data.
- `assertOwner()` provides a shared ownership guard for loaded resources; denied
  attempts are audited as `idor_attempt`.
- Admins accessing member data do so through dedicated, audited admin routes
  (e.g. report review) — never by an id in a member route.

---

## Input validation

- Every mutating route declares a Zod schema via the shared `validate()`
  middleware for `body`, `query` and `params` (UUIDs, enums, dates, lengths).
- Database access goes through Prisma (parameterised queries); raw SQL, where
  used (analytics aggregates), is parameter-free and quotes identifiers.
- Enum-like columns are constrained in the schema; invalid values are rejected.
- Request bodies are size-limited to 1 MB (`express.json({ limit: '1mb' })`).
- Rich text is not rendered as HTML by the API; the API returns JSON only.

---

## Transport and headers

- **Helmet** sets standard security headers. `contentSecurityPolicy` is disabled
  because the API serves JSON only, and `crossOriginResourcePolicy` is set to
  `cross-origin` so the client can load files.
- **CORS** uses an explicit allowlist (`CORS_ORIGINS`). Requests from unknown
  origins are rejected. Credentials are enabled for the refresh cookie.
- `x-powered-by` is disabled.
- **Production must terminate TLS** (HTTPS) in front of the app; see
  `docs/DEPLOYMENT.md`. Secure cookies require HTTPS.

---

## Rate limiting

Implemented with `express-rate-limit` (standard `RateLimit-*` headers). Limiters
are disabled under `NODE_ENV=test` so tests exercise logic, not throttling.

| Limiter | Window | Max | Applies to |
| --- | --- | --- | --- |
| Global | 15 min | 500 | All `/api/v1` traffic |
| Auth | 15 min | 20 | `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/change-password` |
| Sensitive auth | 60 min | 10 | Password reset + email verification requests |
| Upload | 60 min | 40 | File uploads |
| Partner requests | 60 min | 30 | Prayer-partner requests |

Responses use code `RATE_LIMITED`.

---

## Uploads and stored files

- Uploads are size-limited (`FILE_MAX_BYTES`, default 50 MB) and type-checked.
- Files are stored via a storage adapter as **storage keys**, not
  client-supplied filesystem paths; the local adapter writes under `UPLOAD_DIR`.
- Downloads go through `GET /api/v1/files/:id`, which requires authentication
  and resolves the stored key server-side (no direct path traversal).
- The S3 adapter is a drop-in stub; when enabled, use private buckets and signed
  URLs, and never expose service-role/secret keys to the client.

---

## Secrets management

- All secrets come from environment variables. **Nothing secret is committed**;
  `.env` is git-ignored and only `.env.example` is tracked.
- Production must set strong, unique values for `JWT_ACCESS_SECRET` and
  `JWT_REFRESH_SECRET` (`openssl rand -hex 32`), plus a strong `CRON_SECRET`.
- The cron endpoint compares `CRON_SECRET` in constant time and is disabled if
  the variable is unset.
- Third-party keys (`RESEND_API_KEY`) are read from the environment only.

---

## Logging and audit trail

- The request logger records **method, path and status only** — never bodies,
  tokens or query secrets.
- Sensitive fields (passwords, tokens, private reflections, report answers) are
  never written to logs.
- **Audit log** (`AuditLog` table) records actor (id/role/email), action, target,
  outcome, structured `details`, IP and user-agent for significant events:
  admin role/access changes, account suspension/approval, programme and material
  publication, report review, announcements, content edits, and every denied
  elevation/IDOR attempt.
- Audit writes are best-effort (failures are logged, never break the request).
- Audit entries are queryable by admins at `GET /api/v1/admin/audit-logs`.

---

## Privacy and data classification

| Data | Sensitivity | Who can access |
| --- | --- | --- |
| Credentials (password hash), refresh tokens | Secret | Nobody (server-internal only) |
| Reflections (journal) | **Private** | The owning member only |
| Testimonies | Member-controlled | Owner; community **only if shared with consent** |
| Accountability reports | Private (accountability) | Owner; authorised admins (review workflow). Admins may comment but **never rewrite** answers |
| Prayer sessions / partner messages | Private to participants | The two participants; safety reports escalate to admins |
| Annual letter | **Private** | Owning member only |
| Profile fields | Personal | Owner; admins (name/email/phone for operations) |
| Notification preferences, availability | Personal | Owner; aggregate use by scheduler |
| Programme content, materials | Public within the ministry | Authenticated, approved members |
| Analytics | Aggregate | Admins (counts only — no private text) |

Guiding rule: **admin views never include private reflection or journal text**,
and report review is strictly additive. The admin member-detail endpoint
deliberately excludes reflection counts.

---

## Data retention

- **Reports** are historical records; the schema avoids cascading deletion of
  submitted reports. Members may delete only their own **drafts**.
- **Refresh tokens** are cleaned up by the scheduler: expired tokens and tokens
  revoked more than 7 days ago are deleted.
- **Notifications** are member-deletable.
- Operators should define a formal retention schedule for audit logs (retain
  long enough for accountability, then archive/purge) and for account deletion
  requests before handling real data at scale.

---

## Backups and recovery

- Back up PostgreSQL regularly (`pg_dump`) and store backups encrypted, off the
  primary host. Test restores on a schedule.
- Uploaded files live under `UPLOAD_DIR` (or object storage) and must be backed
  up alongside the database; the database stores only file metadata/keys.
- Recovery procedure:
  1. Provision a fresh database and run `npm run migrate`.
  2. Restore the most recent `pg_dump`.
  3. Restore the upload directory / object storage.
  4. Re-run `npm run bootstrap:admin` if the Main Admin row is missing
     (it is a no-op when one already exists).
  5. Verify with `GET /api/v1/health` and a login smoke test.
- Document and test an RPO/RTO target appropriate to the ministry's needs.

---

## Least-privilege database access

- The application should connect with a **dedicated role** that owns only the
  application schema — not the `postgres` superuser.
- Grant that role only the DML/DDL it needs on the app schema; keep superuser
  credentials for migrations/backups only.
- Network access to the database should be restricted to the application host.

> The development `.env.example` uses local trust auth for convenience. This is
> **not** suitable for production.

---

## Production checklist

- [ ] `NODE_ENV=production` (this disables development seed accounts).
- [ ] Strong `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `CRON_SECRET`.
- [ ] `CORS_ORIGINS` restricted to the real frontend origin(s) only.
- [ ] HTTPS/TLS termination; secure cookies.
- [ ] Dedicated least-privilege database role; automated, tested backups.
- [ ] `EMAIL_PROVIDER` configured with verified sender and API key.
- [ ] Private object storage (if not local) with signed access.
- [ ] `LOG_LEVEL=info` (never log secrets); centralised log retention.
- [ ] Scheduler running (worker or external cron hitting `/cron/tick`).
- [ ] Main Admin created via `bootstrap:admin` with a strong password.
- [ ] Audit log reviewed periodically; retention defined.

---

## Reporting a vulnerability

If you discover a security issue, report it privately to the ministry's
technical maintainer rather than opening a public issue. Include a description,
reproduction steps, and impact. Please do not access or modify data that is not
yours while investigating.
