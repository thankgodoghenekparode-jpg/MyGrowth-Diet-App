# MyGrowth App (Flutter frontend)

Feature-based Flutter client for the MyGrowth Diet App. Targets Android, iOS
and Web. See the repository root `README.md` for the full architecture and the
`docs/FRONTEND_CONVENTIONS.md` for the coding conventions used here.

## Offline access

The installed web app precaches its Flutter shell and bundled Bible translations.
After signing in while online, the app also keeps the profile and each opened
Daily Diet day on that device so an existing member can read them offline.
Sign-in on a new device, server-backed pages, AI, Shape Space, reminders, and
saving progress still need an internet connection. Offline progress is not
queued for later sync.

## Run

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

The backend must be running (see `Backend/backend/README.md`).

## Build

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build ios --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

`API_BASE_URL` is the only build-time configuration; it is public by design.
No secrets are ever embedded in the bundle.

## Structure

```text
lib/
  app/           # MaterialApp, router, responsive area shells
  core/
    config/      # build-time configuration
    models/      # plain data models parsed from the API
    network/     # ApiClient (auth header, refresh-retry, error envelope)
    auth/        # session controller + providers
    theme/       # design tokens (colours, spacing) + Material theme
    widgets/     # shared reusable widgets & feedback states
  features/      # one folder per screens-group (auth, dashboard, programme,
                 # activities, goals, materials, prayer_partners, reports,
                 # reflections, progress, notifications, announcements,
                 # profile, more, admin)
test/            # widget + unit tests
```

## Test

```powershell
flutter test
flutter analyze
```
