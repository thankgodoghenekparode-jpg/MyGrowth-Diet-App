# MyGrowth Diet App — API Reference

Base URL (development): `http://localhost:4000/api/v1`

All requests and responses are JSON. Every protected endpoint expects an
`Authorization: Bearer <accessToken>` header.

---

## Contents

- [Conventions](#conventions)
- [Authentication](#authentication)
- [Profile and preferences](#profile-and-preferences)
- [Programme content](#programme-content)
- [Activities and goals](#activities-and-goals)
- [Reports](#reports)
- [Reflections and testimonies](#reflections-and-testimonies)
- [Notifications](#notifications)
- [Prayer partners](#prayer-partners)
- [Materials and files](#materials-and-files)
- [Daily Diet](#daily-diet)
- [Announcements](#announcements)
- [Scheduler and health](#scheduler-and-health)
- [Admin — users](#admin--users)
- [Admin — administrator accounts (Main Admin only)](#admin--administrator-accounts-main-admin-only)
- [Admin — programmes and plans](#admin--programmes-and-plans)
- [Admin — materials](#admin--materials)
- [Admin — Daily Diet](#admin--daily-diet)
- [Admin — reports and safety](#admin--reports-and-safety)
- [Admin — prayer partners](#admin--prayer-partners)
- [Admin — announcements and definitions](#admin--announcements-and-definitions)
- [Admin — analytics, audit and settings](#admin--analytics-audit-and-settings)

---

## Conventions

### Authentication levels

| Level | Meaning |
| --- | --- |
| **Public** | No token required |
| **Member** | Valid access token; account `status = ACTIVE` |
| **Admin** | Valid access token; `ADMIN`/`MAIN_ADMIN` with `adminAccess = ACTIVE` (Main Admin always passes) |
| **Main Admin** | Role `MAIN_ADMIN` only |

### Error shape

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "…", "details": { "fieldErrors": {} } } }
```

Common codes: `VALIDATION_ERROR`, `UNAUTHENTICATED`, `FORBIDDEN`,
`ADMIN_ACCESS_REQUIRED`, `MAIN_ADMIN_ACCESS_REQUIRED`, `ROLE_PROTECTED`,
`NOT_FOUND`, `CONFLICT`, `RATE_LIMITED`, `GOAL_LIMIT_REACHED`, `EMAIL_TAKEN`.

### Pagination

List endpoints accept `page` (default `1`) and `pageSize` (default `20`, max
`100`) and return:

```json
{ "data": [ … ], "meta": { "page": 1, "pageSize": 20, "total": 42, "totalPages": 3 } }
```

Some member content lists (e.g. programme monthly plans) return `{ "data": [ … ] }`
without a `meta` block because the full set is bounded.

### Dates and times

Date fields in request bodies use `YYYY-MM-DD`; timestamps in responses are ISO
8601 UTC. Users have a `timezone` (default `Africa/Lagos`) used for period keys
and reminders.

---

## Authentication

Rate-limited (`authLimiter`, plus `sensitiveAuthLimiter` on password/verification
routes).

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | `/auth/register` | Public | Create a member account. May start `PENDING` if approval is required. |
| POST | `/auth/login` | Public | Returns `{ accessToken, user }`; sets the httpOnly refresh cookie. |
| POST | `/auth/refresh` | Public (cookie) | Rotates the refresh token; reuse of an old token revokes the family. |
| POST | `/auth/logout` | Public (cookie) | Revokes the presented refresh token and clears the cookie. |
| POST | `/auth/forgot-password` | Public | Sends a reset link (console logs it in dev). |
| POST | `/auth/reset-password` | Public | Consumes a reset token, sets a new password, revokes sessions. Body accepts `newPassword` or the Flutter alias `password`. |
| POST | `/auth/verify-email` | Public | Confirms an email-verification token. |
| POST | `/auth/resend-verification` | Public | Re-sends the verification link. |
| POST | `/auth/change-password` | Member | Requires the current password; revokes other sessions. Body accepts `newPassword` or the Flutter alias `password`. |
| GET | `/auth/session` | Member | Returns the current `{ user }`. |

Access tokens live 15 minutes (`JWT_ACCESS_TTL`); refresh tokens live 30 days
(`JWT_REFRESH_TTL_DAYS`) and are stored **SHA‑256 hashed** with rotation and
reuse detection.

---

## Profile and preferences

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/me` | Member | `{ user, notificationPreference, prayerAvailability }` |
| PATCH | `/me` | Member | Editable: `name` (or `firstName`/`lastName`), `phone`, `timeZone` (or `timezone`), `locale`, `avatarFileId`. Returns a flat user object. Privileged fields (`role`, `status`, `adminAccess`, `email`, `id`) are rejected and audited. |
| GET | `/me/notification-preferences` | Member | Creates defaults on first read. |
| PATCH | `/me/notification-preferences` | Member | Channel toggles, reminder times, quiet hours, `summaryPreference`. |
| GET | `/me/dashboard` | Member | Aggregated home payload. |
| GET | `/me/progress` | Member | Progress summary; `period` = `week`\|`month`\|`year`\|`all` (+ optional `from`/`to`). Returns both a detailed `activities` block and the flat keys the Flutter `ProgressSummary` consumes (`totalActivities`, `completedActivities`, `inProgressActivities`, `skippedActivities`, `totalMinutesRecorded`, `reportsSubmitted`, `sessionsCompleted`, `currentStreakDays`, `byCategory` as a `{category: count}` map, and `byMonth` as a `[{year, month, completed, total}]` list). |
| GET | `/me/activities` | Member | Today's / requested day's activity checklist. |

---

## Programme content

Mounted at `/api/v1/programmes` (Member auth). Administrators with granted
access also see `DRAFT`/`ARCHIVED` content, so these routes back the editors too.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/programmes` | List programmes. Query: `year`, `includeArchived=true` (admin only). Response items include `monthlyPlanCount`. |
| GET | `/programmes/:id` | Programme detail (UUID). Includes top-level fields **and** a `programme` wrapper, plus `quarterlyConfession`, `quarterlyReviewTopics`, `annualReflectionTemplate`, and published `monthlyPlans`. |
| GET | `/programmes/:idOrYear/monthly-plans` | Monthly plans for a programme **UUID or 4-digit year**. |
| GET | `/programmes/:idOrYear/monthly-plans/:month` | One month + its weekly plans (month `1`–`12`). |
| GET | `/programmes/today` | Resolves the programme + month for a date. Query: `date=YYYY-MM-DD` (defaults to today in the user's timezone). Returns `{ date, dateInProgramme, programme, monthlyPlan }`. |
| GET | `/programmes/weekly-plans` | Weekly plans. Query: `year`, `month`, `programmeId`. |
| GET | `/programmes/weekly-plans/:id` | One weekly plan. |

### Response shapes

Storage column names are canonical and always present. Display aliases are added
for the Flutter client (`src/lib/contentShapes.js`):

- Programme: `ministryName`, `prayerFocus`.
- Monthly plan: `literatureList` (string), `audioMessages` (array),
  `audioMessageList` (string), `confession`, `goalsGuidance`; raw values kept
  under `literatureItems`.
- Weekly plan: `prayerDurationTarget` (string), `extraActivities` (string); raw
  value kept under `extraActivitiesItems`.

---

## Activities and goals

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/me/activities` | Member | Activity checklist for a date. |
| POST | `/me/activity-records` | Member | Record completion of an activity. Deduplicated per user/activity/date. Duration accepts `actualDurationMinutes` or the Flutter alias `actualDuration`. |
| GET | `/me/activity-records` | Member | List the member's own records. |
| PATCH | `/me/activity-records/:id` | Member | Update own record (IDOR-protected). Accepts either duration spelling. |
| DELETE | `/me/activity-records/:id` | Member | Delete own record. |
| GET | `/me/goals` | Member | List goals. |
| POST | `/me/goals` | Member | Create a goal. Enforces `goals.maxMonthlySuggested` unless `goals.allowExtra`. |
| GET | `/me/goals/:id` | Member | One goal (own). |
| PATCH | `/me/goals/:id` | Member | Update (status, title, etc.). |
| DELETE | `/me/goals/:id` | Member | Delete own goal. |
| POST | `/me/goals/:id/progress` | Member | Append a progress entry. |
| GET | `/me/reviews` | Member | Period reviews. |
| POST | `/me/reviews` | Member | Create a review. |
| GET | `/me/period-keys` | Member | Current week/month/quarter/year keys in the user's timezone. |

Over-limit goal creation returns `GOAL_LIMIT_REACHED`.

---

## Reports

Structured accountability reports. Answers are stored per `fieldKey`; admins may
**never** rewrite a member's answers (reviews are additive only).

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/me/report-fields` | Member | Field definitions for each report type + `quarterlyConfession` + `visibilityNotice`. |
| GET | `/me/reports` | Member | List own reports. Query: `type`, `status`, `periodKey`. |
| POST | `/me/reports` | Member | Create a `DRAFT` for a period (unique per user/period/type). |
| GET | `/me/reports/:id` | Member | Own report. |
| PATCH | `/me/reports/:id` | Member | Edit a draft / create a revision for submitted reports. |
| POST | `/me/reports/:id/submit` | Member | Submit (requires all required answers + explicit confirmation). |
| DELETE | `/me/reports/:id` | Member | Delete a draft only (IDOR-protected). |
| GET | `/me/reports-status/current` | Member | Status of the four current periods. |

Report types: `WEEKLY`, `MONTHLY`, `QUARTERLY`, `ANNUAL`. Statuses: `DRAFT`,
`SUBMITTED`, `REQUIRES_FOLLOW_UP`, `REVIEWED`.

---

## Reflections and testimonies

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/me/reflections` | Member | Private journal entries (own only). |
| POST | `/me/reflections` | Member | Create. |
| GET | `/me/reflections/:id` | Member | Own entry. |
| PATCH | `/me/reflections/:id` | Member | Update own entry. |
| DELETE | `/me/reflections/:id` | Member | Delete own entry. |
| GET | `/me/testimonies` | Member | Own testimonies. Each item exposes the text as both `story` (storage name) and `body` (Flutter). |
| POST | `/me/testimonies` | Member | Create. Accepts the text as `body` (Flutter) or `story`; `entryDate` is optional (defaults to today); `visibility` accepts `MINISTRY_ADMINS` as an alias for `ADMINS`. `COMMUNITY` requires `consentToShare: true`. |
| GET | `/me/testimonies/:id` | Member | Own testimony. |
| PATCH | `/me/testimonies/:id` | Member | Update / change consent. Accepts `body`/`story` and the `MINISTRY_ADMINS` alias. |
| DELETE | `/me/testimonies/:id` | Member | Delete own. |
| GET | `/me/testimonies-shared/community` | Member | Testimonies shared with the community. |
| GET | `/me/annual-letter` | Member | Own annual letter for the current programme. Returns an empty letter (`content: ''`) when none exists yet — never a 404. |
| PUT | `/me/annual-letter` | Member | Upsert the current programme's letter. Body accepts `content` (Flutter) or `body` (storage name). |
| GET | `/me/annual-letters/:programmeId` | Member | Own annual letter for an explicit programme. |
| PUT | `/me/annual-letters/:programmeId` | Member | Upsert own annual letter for an explicit programme. |

Reflections are private and are never exposed to administrators.

---

## Notifications

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/me/notifications` | Member | Own notifications (paginated). |
| POST | `/me/notifications/:id/read` | Member | Mark one read. |
| POST | `/me/notifications/read-all` | Member | Mark all read. |
| DELETE | `/me/notifications/:id` | Member | Delete own notification. |

---

## Prayer partners

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/prayer-partners/availability` | Member | Own availability + preferences. |
| PUT | `/prayer-partners/availability` | Member | Set availability. |
| GET | `/prayer-partners/discover` | Member | Suggested partners (never exposes contact details). |
| GET | `/prayer-partners/requests` | Member | Incoming/outgoing requests. |
| POST | `/prayer-partners/requests` | Member | Send a request (duplicates blocked). |
| PATCH | `/prayer-partners/requests/:id` | Member | Accept / decline / cancel. |
| GET | `/prayer-partners/partnerships` | Member | Own partnerships. |
| PATCH | `/prayer-partners/partnerships/:id` | Member | Pause / end / report-safety. |
| GET | `/prayer-partners/sessions` | Member | Own sessions. |
| POST | `/prayer-partners/sessions` | Member | Propose a session (time conflicts rejected). |
| GET | `/prayer-partners/sessions/:id` | Member | One session (participants only). |
| PATCH | `/prayer-partners/sessions/:id` | Member | Accept / decline / complete / cancel. Accepts `action` (`accept`\|`cancel`\|`complete`…) or, as the Flutter client sends, a target `status` (`ACCEPTED`\|`CANCELLED`\|`COMPLETED`\|`MISSED`) plus optional `myAttendance: true`. |

Safety reports raised here surface to admins at `/admin/safety-reports`.

---

## Materials and files

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/materials` | Member | Published materials. Query: `search`, `category`, pagination. |
| GET | `/materials/:id` | Member | One material + its file metadata. |
| GET | `/files/:id` | Member | Streams a stored file (local adapter) or redirects to signed storage. |
| POST | `/files` | Member | Upload a file (multipart `file`, optional `category`). Used by the Daily Diet report upload. Returns the created `file` metadata. |
| DELETE | `/files/:id` | Member | Remove a file you uploaded. `403` for anyone else; `409 FILE_IN_USE` while it is attached to a material, report or profile photo. |

---

## Daily Diet

The Daily Diet is the admin-configured devotional structure for a day. The
administrator sets the sections and what each carries; the member follows them
by picking a date and ticking each section off.

**Scopes.** A content row reaches a `DAY`, a `WEEK` or a `MONTH`. Rows are filed
against an *anchor*: the day itself, the Sunday that starts its week, or the
first of its month. When several rows cover a day, the closest scope wins
(`DAY` → `WEEK` → `MONTH`). An administrator may pick any day inside a period;
the backend files the row against the anchor automatically.

**Behaviours.** Each section carries one of `TEXT` (read and tick), `MATERIAL`
(open/download the files), `TIMER` (prayer stopwatch), `TICK` (fasting tick-off),
`REPORT` (write or upload the report) or `PARTNER` (open the prayer room).

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/daily-diet?date=YYYY-MM-DD` | Member | The whole day: the published sections in order, each with its resolved `content` (day/week/month), `materials`, the member's `completion` and `status`, plus `programme`, `monthlyPlan`, `weeklyPlan`, `dateInProgramme` and `progress`. |
| POST | `/daily-diet/completions` | Member | Tick a section. Body: `sectionId` or `sectionKey`, `date`, `status` (`COMPLETED` \| `IN_PROGRESS` \| `SKIPPED` \| `NOT_APPLICABLE`), optional `note`, `actualDurationMinutes`, `attachmentFileId`. Upserts, so re-posting updates the same row. |
| DELETE | `/daily-diet/completions/:id` | Member | Clear a tick-off. Only the owner may delete it (`403` otherwise). |
| GET | `/daily-diet/progress?from=&to=` | Member | The member's own completion counts per day in the range, plus `meta.totalSections`. |

`GET /daily-diet` response (trimmed):

```json
{
  "date": "2027-03-17",
  "dateInProgramme": true,
  "programme": { "id": "…", "title": "Growth Diet Plan 2027", "year": 2027 },
  "monthlyPlan": { "id": "…", "month": 3, "year": 2027, "theme": "…" },
  "weeklyPlan": { "id": "…", "weekNumber": 3, "prayerDurationTargetMinutes": 45 },
  "progress": { "completed": 0, "total": 11, "ratio": 0 },
  "sections": [
    {
      "id": "…",
      "key": "scripture_reading",
      "label": "Scriptures reading",
      "behaviour": "TEXT",
      "sortOrder": 2,
      "required": true,
      "allowNote": true,
      "trackCompletion": true,
      "status": "NOT_STARTED",
      "content": {
        "id": "…",
        "date": "2027-03-17",
        "scope": "DAY",
        "title": "Acts 4–6",
        "body": "…",
        "details": { "reading": "Acts 4–6", "heading": "…", "focus": "…" },
        "materialIds": [],
        "durationTargetMinutes": null,
        "status": "PUBLISHED"
      },
      "materials": [],
      "completion": null
    }
  ]
}
```

The eleven canonical section keys are `prayer`, `scripture_reading`,
`bible_study`, `literature_reading`, `proverbs_reading`, `fasting_and_prayer`,
`report`, `declarations`, `audio_message`, `prayer_partner_session` and `music`.
Administrators may add, rename, reorder or archive sections; the keys above are
the ones the client knows how to render specially, and any other key falls back
to the `TEXT` behaviour.

---

## Announcements

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/announcements` | Member | Published announcements (audience-aware). |
| GET | `/announcements/:id` | Member | One announcement. |

---

## Scheduler and health

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/health` | Public | Liveness/readiness with DB check. Also at `/health` (no prefix). |
| POST | `/cron/tick` | Secret | Runs all reminder tasks. Requires header `x-cron-secret: $CRON_SECRET` (or body `{ secret }`). Disabled when `CRON_SECRET` is unset. |

---

## Admin — users

All routes below require **Admin** unless stated otherwise.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/users` | Paginated members. Query: `search`, `status`, `role`, `sort` (`newest`\|`oldest`\|`name`\|`email`). Defaults to `role=MEMBER`. |
| GET | `/admin/users/:id` | Member detail + `stats` (`reports` by status, `completedActivities`, `completedPrayerSessions`, `goals`). Reflections are never counted. Administrator accounts are visible to the Main Admin only. |
| PATCH | `/admin/users/:id` | Editable profile fields only; `role`/`status`/`adminAccess`/`email` are rejected and audited. Administrators are `ROLE_PROTECTED`. |
| POST | `/admin/users/:id/approve` | Set member `ACTIVE` (+ notification). |
| POST | `/admin/users/:id/suspend` | Set member `SUSPENDED`. |
| POST | `/admin/users/:id/reactivate` | Set member `ACTIVE`. |

## Admin — administrator accounts (Main Admin only)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/admins` | List `ADMIN` + `MAIN_ADMIN` with `adminAccess` state. |
| POST | `/admin/admins` | Create an `ADMIN` (starts `adminAccess = PENDING`). Never creates a second Main Admin. |
| PATCH | `/admin/admins/:id/access` | Body `{ action: "grant"\|"suspend"\|"reactivate"\|"revoke" }`. Suspending/revoking revokes the target's refresh tokens immediately. The Main Admin's own access cannot be changed. |

## Admin — programmes and plans

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/programmes` | Paginated programmes. Query: `year`, `status`. |
| POST | `/admin/programmes` | Create. Body accepts `ministry`/`ministryName`, `annualPrayerFocus`/`prayerFocus`, `status`. |
| GET | `/admin/programmes/:id` | Programme detail. |
| PATCH | `/admin/programmes/:id` | Update. |
| POST | `/admin/programmes/:id/publish` | Publish + notify members. |
| POST | `/admin/programmes/:id/archive` | Archive. |
| GET | `/admin/monthly-plans` | List. Query: `year`, `programmeId`, `status`. |
| POST | `/admin/monthly-plans` | Create (by `programmeId` or `year`/`programmeYear`). |
| POST | `/admin/programmes/:id/monthly-plans` | Create under a programme. |
| GET | `/admin/monthly-plans/:id` | Detail + `weeklyPlans`. |
| PATCH | `/admin/monthly-plans/:id` | Update. Body accepts `audioMessages`/`audioMessageList`, `monthlyConfession`/`confession`, `monthlyGoalsGuidance`/`goalsGuidance`, `literatureList` (array or string). |
| POST | `/admin/monthly-plans/:id/publish` | Publish. |
| POST | `/admin/monthly-plans/:id/archive` | Archive. |
| DELETE | `/admin/monthly-plans/:id` | Delete. |
| GET | `/admin/weekly-plans` | List. Query: `year`, `month`, `status`. |
| POST | `/admin/programmes/:id/weekly-plans` | Create (body includes `month`, `weekNumber`, …). |
| PATCH | `/admin/weekly-plans/:id` | Update. |
| POST | `/admin/weekly-plans/:id/publish` | Publish. |
| DELETE | `/admin/weekly-plans/:id` | Delete. |
| GET | `/admin/daily-activities` | List. Query: `year`, `month`, `weeklyPlanId`, `monthlyPlanId`, `status`. |
| GET | `/admin/activity-definitions` | Alias of `/admin/daily-activities` (the Flutter admin client asks for this first). |
| POST | `/admin/programmes/:id/daily-activities` | Create under a programme. |
| POST | `/admin/monthly-plans/:id/daily-activities` | Create under a month. |
| POST | `/admin/weekly-plans/:id/daily-activities` | Create under a week. |
| PATCH | `/admin/daily-activities/:id` | Update. |
| POST | `/admin/daily-activities/:id/publish` | Publish. |
| DELETE | `/admin/daily-activities/:id` | Delete. |

All create/update/publish/archive actions are audit-logged.

## Admin — materials

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/materials` | Paginated. Query: `search`, `status`, `category`. |
| POST | `/admin/materials` | Create. |
| GET | `/admin/materials/:id` | Detail. |
| PATCH | `/admin/materials/:id` | Update. |
| POST | `/admin/materials/:id/publish` | Publish (+ notify). |
| POST | `/admin/materials/:id/archive` | Archive. |
| DELETE | `/admin/materials/:id` | Delete. |
| POST | `/admin/files` | Multipart upload; validates size/type, stores via the adapter, returns file metadata. |
| GET | `/admin/files` | List uploaded files. |

## Admin — Daily Diet

The administrator owns the structure (which sections exist and how they behave)
and the content each section carries per day, week or month.

**Sections** — the structure:

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/daily-diet/sections?year=` | The sections in display order (published, draft and archived). |
| POST | `/admin/daily-diet/sections` | Create. Body: `year` or `programmeId`, `key` (lowercase, `[a-z0-9_]`), `label`, `description?`, `behaviour` (`TEXT`\|`MATERIAL`\|`TIMER`\|`TICK`\|`REPORT`\|`PARTNER`), `sortOrder?`, `enabled?`, `required?`, `allowNote?`, `trackCompletion?`, `status?`. |
| PATCH | `/admin/daily-diet/sections/:id` | Update any of the fields above. |
| POST | `/admin/daily-diet/sections/:id/publish` | Publish so members can see it. |
| POST | `/admin/daily-diet/sections/:id/archive` | Hide from members. |
| POST | `/admin/daily-diet/sections/reorder` | Body `{ programmeId, order: [sectionId, …] }`. |
| DELETE | `/admin/daily-diet/sections/:id` | Delete the section and its content. |

**Content** — what each section carries:

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/daily-diet/content?date=` | Every row that covers the day: the day row, the week row and the month row for each section (`scope` on each row says which). Also accepts `year`, `month` (a whole month at once), `sectionId`, `programmeId`, `status`. |
| PUT | `/admin/daily-diet/content` | Upsert one row. Body: `sectionId` or `sectionKey`, `date`, `scope` (`DAY`\|`WEEK`\|`MONTH`), `title?`, `body?`, `details?` (free-form object), `materialIds?`, `externalUrl?`, `durationTargetMinutes?`, `sortOrder?`, `status?`. **The date is filed against the scope's anchor** (the Sunday for `WEEK`, the 1st for `MONTH`), so the response `date` may differ from the one sent. |
| PATCH | `/admin/daily-diet/content/:id` | Update fields. Changing `scope` moves the row to the new period's anchor; `409 DUPLICATE_CONTENT` if another row already covers that period. |
| POST | `/admin/daily-diet/content/:id/publish` | Publish one row. |
| POST | `/admin/daily-diet/content/publish-day` | Body `{ date, sectionId? }`. Publishes every unpublished row that covers the day (day + week + month). Returns `{ published, date }`. |
| DELETE | `/admin/daily-diet/content/:id` | Delete a row; members fall back to the wider scope. |

All create/update/publish/archive/delete actions are audit-logged.

## Admin — reports and safety

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/reports` | Submitted-or-later reports only (never drafts). Query: `status`, `periodType`, `periodKey`, `reportType`/`type`, `userId`, `programmeId`, `programmeYear`, `search`, `from`, `to`. |
| GET | `/admin/reports/:id` | Detail: `answers` keyed by `fieldKey`, `reviews`, `revisions`. Drafts are `NOT_FOUND`. |
| POST | `/admin/reports/:id/reviews` | Body `{ action: "COMMENT"\|"REQUEST_FOLLOW_UP"\|"MARK_REVIEWED", comment? }`. Additive only; injects a notification. |
| GET | `/admin/safety-reports` | Prayer-partner safety reports. Query: `status`. |
| PATCH | `/admin/safety-reports/:id` | Body `{ action: "review"\|"resolve", resolutionNote? }`. |

## Admin — prayer partners

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/prayer-partnerships` | Paginated partnerships. Query: `status`. Safety-view only. |
| GET | `/admin/prayer-partner-requests` | Recent partner requests. |

## Admin — announcements and definitions

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/announcements` | List. Query: `status`. |
| POST | `/admin/announcements` | Create. Body: `title`, `body`, `link?`, `materialId?`, `audience` (`ALL_MEMBERS`\|`ADMINS_ONLY`), `startsAt?`, `endsAt?`. |
| PATCH | `/admin/announcements/:id` | Update. |
| POST | `/admin/announcements/:id/publish` | Publish; notifies members when configured. |
| POST | `/admin/announcements/:id/archive` | Archive. |
| DELETE | `/admin/announcements/:id` | Delete. |
| GET | `/admin/activity-categories` | The 12 configurable activity categories. |
| PATCH | `/admin/activity-categories/:key` | Update `label`/`description`/`sortOrder`/`enabled`. |
| GET | `/admin/notification-events` | Notification event definitions. |
| PATCH | `/admin/notification-events/:key` | Update `label`/`description`/`defaultEnabled`. |

## Admin — analytics, audit and settings

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/analytics/overview` | Aggregate metrics. Query: `year`, `month`, `period` (`week`\|`month`\|`year`). Never includes private reflection text. |
| GET | `/admin/analytics/export` | CSV export (`text/csv` attachment). |
| GET | `/admin/audit-logs` | Query: `action`, `search`, `from`, `to`, pagination. |
| GET | `/admin/settings` | All runtime settings. |
| PATCH | `/admin/settings` | Update known settings keys only (unknown keys are stripped). |

---

## Frontend contract notes

The Flutter client (which must not be modified) reads the following directly:

- Programme lists/detail: `ministryName`, `prayerFocus`, `status`.
- Monthly plans: `audioMessages` (array), `monthlyConfession`, `monthlyGoalsGuidance`,
  `literatureList`, `reflectionQuestions`.
- Weekly plans: `prayerDurationTarget` (string), `extraActivities` (string).
- `GET /programmes/weekly-plans?year=&month=` and
  `GET /programmes/{year}/monthly-plans` (year, not UUID).
- Admin lists accept the `{data:[…]}` envelope.
- Daily Diet: section `behaviour` (`TEXT`/`MATERIAL`/`TIMER`/`TICK`/`REPORT`/`PARTNER`),
  content `scope` (`DAY`/`WEEK`/`MONTH`), the free-form `details` object, and the
  completion `attachment` (`{ id, url, originalName, mimeType }`). `GET /daily-diet`
  is a plain object (not an envelope); admin listings use the `{data:[…]}` envelope.

See `src/lib/contentShapes.js` for the exact serializer.
