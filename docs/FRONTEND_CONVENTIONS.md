# MyGrowth Frontend Conventions (Flutter)

All feature code lives under `Frontend/mygrowth_app/lib/`. Read this before writing any screen.

## Stack
- Flutter 3.47 / Dart 3.13, Material 3.
- State: flutter_riverpod 3 (use `ConsumerWidget` / `ConsumerStatefulWidget`, `FutureProvider.autoDispose`, `Notifier`).
- Routing: go_router 18. Use `context.go('/path')` for navigation (never `pushNamed`).
- Networking: `lib/core/network/api_client.dart` → `apiClientProvider`.
- Charts: `fl_chart`. Dates: `intl`. Storage: `shared_preferences`.

## Import prefix
From a file at `lib/features/<area>/<x>_screen.dart`, core code is imported as:
```dart
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';      // AppCard, TitledCard, VerseCard
import '../../core/widgets/app_buttons.dart';   // AppButton, AppIconButton, AppButtonVariant
import '../../core/widgets/app_badge.dart';     // StatusBadge, AppBadgeTone, badgeToneFor(status), humanizeStatus(status)
import '../../core/widgets/app_text_field.dart';// AppTextField, AppDropdown, AppSwitchRow, AppDateField, fieldGap
import '../../core/widgets/feedback_states.dart';// EmptyState, ErrorState, AsyncValueView, SkeletonBox, CardListSkeleton
import '../../core/widgets/toast.dart';         // Toast.success/error/info, confirmDialog()
import '../../core/widgets/section_header.dart';// SectionHeader, StatTile, ProgressBar, StatTileTone
import '../../core/widgets/pagination.dart';    // PaginationFooter, PagedResult<T>
import '../../core/network/api_client.dart';    // apiClientProvider, ApiException
import '../../core/auth/auth_controller.dart'; // currentUserProvider, authControllerProvider
import '../../app/area_shell.dart';             // memberMenuItems, adminMenuItems, AppArea
```
Model files are in `lib/core/models/`: `app_user.dart`, `programme_models.dart`,
`activity_models.dart`, `goal_models.dart`, `material_models.dart` (class `MaterialItem`),
`prayer_models.dart`, `report_models.dart`, `journal_models.dart`,
`notification_models.dart`.
Shared feature providers: `lib/features/programme/programme_providers.dart`
(`currentProgrammeProvider`, `programmeYearsProvider`, `monthlyPlansProvider(year)`,
`monthlyPlanProvider((year:, month:))`, `weeklyPlansProvider((year:, month:))`,
`dailyChecklistProvider(DateTime)`, `announcementsProvider`, `notificationsProvider`,
`unreadNotificationCountProvider`, helper `asJsonList(dynamic)`).

## API conventions
- `final client = ref.read(apiClientProvider);`
- `await client.get('/path', query: {...})`, `client.post('/path', body: {...})`,
  `client.patch`, `client.put`, `client.delete`.
- Responses are unwrapped: lists come back as `List<dynamic>` (or `{data:[...],meta:{...}}`
  for paginated endpoints → use `PagedResult.fromJson(json, Item.fromJson)`), single
  resources come back as the object map directly.
- Errors throw `ApiException` with `.message`, `.fieldError`, `.statusCode`.
  Wrap every call in try/catch and surface via `Toast.error(context, e.fieldError ?? e.message)`.
- Paginated list query params: `page`, `pageSize`, `search`, plus filters.
- All list loading must show: loading skeleton, empty state, error state with retry.
- Use `RefreshIndicator` on scrollable top-level lists.

## Design rules (from the design system; do not invent new colours)
- Colours: only from `AppColors` (navy/gold/white/soft-grey + semantic success/warning/danger/info).
- Cards: `AppCard` / `TitledCard`. Buttons: `AppButton` (supports `busy` to prevent double submit).
- Forms: `AppTextField` (has built-in label + `required` asterisk + validator support).
- Status strings from the backend → `StatusBadge(label: humanizeStatus(s), tone: badgeToneFor(s))`.
- Ample spacing (AppSpacing.xs 8 … xl 24). Never hardcode a raw colour hex.
- Tone: encouraging, grace-filled. Never shame a user for missed activities.
  Label metrics "self-reported" where relevant.
- Desktop/web: screens already sit in a responsive shell with a sidebar ≥600px wide, so
  content can use horizontal space; use simple `Wrap`/`LayoutBuilder` grids where a screen
  has cards. Don't build a second sidebar.

## Interaction rules
- Every button must do something real (call API) or be visibly disabled with a reason.
- Destructive actions (end partnership, delete entry) → `confirmDialog(...)`.
- Show success toasts after mutations, and `ref.invalidate(...)` the relevant providers.
- Prevent duplicate submissions with the `busy` flag.

## Quality gate
After writing your files run (from `Frontend/mygrowth_app`):
`flutter analyze lib/features/<your folders>` and fix every error/warning in YOUR files.
Do not modify files outside your assigned feature folders (no changes to core/, app/,
or other features). If you need a shared change, implement it inside your own folder.
