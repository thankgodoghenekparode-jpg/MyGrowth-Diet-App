import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/models/daily_diet_models.dart';
import '../core/theme/app_colors.dart';
import '../features/activities/fasting_screen.dart';
import '../features/admin/admin_access_screen.dart';
import '../features/admin/admin_activities_screen.dart';
import '../features/admin/admin_announcements_screen.dart';
import '../features/admin/admin_analytics_screen.dart';
import '../features/admin/admin_audit_logs_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_daily_diet_screen.dart';
import '../features/admin/admin_materials_screen.dart';
import '../features/admin/admin_members_screen.dart';
import '../features/admin/admin_member_detail_screen.dart';
import '../features/admin/admin_more_screen.dart';
import '../features/admin/admin_monthly_plans_screen.dart';
import '../features/admin/admin_prayer_partners_screen.dart';
import '../features/admin/admin_programmes_screen.dart';
import '../features/admin/admin_reports_screen.dart';
import '../features/admin/admin_report_detail_screen.dart';
import '../features/admin/admin_settings_screen.dart';
import '../features/admin/admin_weekly_plans_screen.dart';
import '../features/admin/programme_edit_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/profile_completion_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/daily_diet/daily_diet_screen.dart';
import '../features/daily_diet/daily_diet_section_screen.dart';
import '../features/materials/material_detail_screen.dart';
import '../features/materials/materials_screen.dart';
import '../features/more/more_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/prayer_partners/prayer_partners_screen.dart';
import '../features/prayer_partners/prayer_room_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/programme/bible_reading_screen.dart';
import '../features/programme/growth_plan_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/reflections/reflections_screen.dart';
import '../features/reports/report_detail_screen.dart';
import '../features/reports/report_form_screen.dart';
import '../features/reports/reports_screen.dart';
import '../app/area_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listens to auth state changes so GoRouter can re-evaluate redirects.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _sub = _ref.listen<AuthState>(authControllerProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthStateNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;
      final onAuthPage = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password' ||
          path.startsWith('/reset-password');

      // Session still restoring on cold start.
      if (auth.status == AuthStatus.initial ||
          auth.status == AuthStatus.loading) {
        return path == '/splash' ? null : '/splash';
      }

      if (!auth.isAuthenticated) {
        return onAuthPage ? null : '/login';
      }

      final user = auth.user;
      if (user == null) return null;

      // Once the session has restored, leave the splash for the home screen.
      if (path == '/splash') {
        return user.canUseAdminArea ? '/admin' : '/home';
      }

      if (onAuthPage) {
        return user.canUseAdminArea ? '/admin' : '/home';
      }
      if (path == '/login' || path == '/register' || path == '/') {
        return user.canUseAdminArea ? '/admin' : '/home';
      }

      // Guard the admin area: backend enforces this too; this is UX only.
      if (path.startsWith('/admin')) {
        if (!user.isAdmin) return '/home';
        if (path.startsWith('/admin/access') && !user.isMainAdmin) {
          return '/admin';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: SplashScreen())),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: LoginScreen())),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: RegisterScreen())),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ForgotPasswordScreen())),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) => _fade(MaterialPage(
          child: ResetPasswordScreen(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        )),
      ),
      GoRoute(
        path: '/setup-profile',
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ProfileCompletionScreen())),
      ),

      // -------------------------------------------------- member shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AreaShell(
          title: _memberShellTitle(shell.currentIndex),
          destinations: memberBottomDestinations,
          area: AppArea.member,
          child: shell,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: MoreScreen(area: AppArea.member)),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/diet',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: DailyDietScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/plan',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: GrowthPlanScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/prayer',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: PrayerRoomScreen()),
            ),
          ]),
        ],
      ),

      // ------------------------------------------ member full-screen routes
      GoRoute(
        path: '/dashboard',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(MaterialPage(
          child: _MemberPage(
            title: 'Dashboard',
            child: DashboardScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/bible-reading',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: BibleReadingScreen())),
      ),
      GoRoute(
        path: '/materials',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: MaterialsScreen())),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (_, state) => _fade(MaterialPage(
              child: MaterialDetailScreen(materialId: state.pathParameters['id']!),
            )),
          ),
        ],
      ),
      GoRoute(
        path: '/goals',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: GoalsScreen())),
      ),
      GoRoute(
        path: '/fasting',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: FastingScreen())),
      ),
      GoRoute(
        path: '/daily-diet/section/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _fade(MaterialPage(
          child: DailyDietSectionScreen(
            sectionId: state.pathParameters['id']!,
            dateISO: state.uri.queryParameters['date'] ??
                dailyDietDateISO(DateTime.now()),
          ),
        )),
      ),
      GoRoute(
        path: '/prayer/partners',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: PrayerPartnersScreen())),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ReportsScreen())),
        routes: [
          GoRoute(
            path: 'new/:type',
            pageBuilder: (_, state) => _fade(MaterialPage(
              child:
                  ReportFormScreen(type: state.pathParameters['type']!),
            )),
          ),
          GoRoute(
            path: 'edit/:id',
            pageBuilder: (_, state) => _fade(MaterialPage(
              child: ReportFormScreen(reportId: state.pathParameters['id']!),
            )),
          ),
          GoRoute(
            path: ':id',
            pageBuilder: (_, state) => _fade(MaterialPage(
              child: ReportDetailScreen(reportId: state.pathParameters['id']!),
            )),
          ),
        ],
      ),
      GoRoute(
        path: '/reflections',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ReflectionsScreen())),
      ),
      GoRoute(
        path: '/progress',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ProgressScreen())),
      ),
      GoRoute(
        path: '/announcements',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: AnnouncementsScreen())),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: NotificationsScreen())),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) =>
            _fade(const MaterialPage(child: ProfileScreen())),
      ),

      // ---------------------------------------------------- admin shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AreaShell(
          title: _adminShellTitle(shell.currentIndex),
          destinations: adminBottomDestinations,
          area: AppArea.admin,
          child: shell,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: AdminMoreScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/members',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: AdminMembersScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (_, state) => _fade(MaterialPage(
                    child: _AdminPage(
                      title: 'Member profile',
                      child: AdminMemberDetailScreen(
                          memberId: state.pathParameters['id']!),
                    ),
                  )),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/reports',
              pageBuilder: (_, _) =>
                  const NoTransitionPage(child: AdminReportsScreen()),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (_, state) => _fade(MaterialPage(
                    child: _AdminPage(
                      title: 'Report',
                      child: AdminReportDetailScreen(
                          reportId: state.pathParameters['id']!),
                    ),
                  )),
                ),
              ],
            ),
          ]),
        ],
      ),

      GoRoute(
        path: '/admin/dashboard',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(MaterialPage(
          child: _AdminPage(
            title: 'Dashboard',
            child: AdminDashboardScreen(),
          ),
        )),
      ),

      // ----------------------------------------- admin full-screen routes
      GoRoute(
        path: '/admin/access',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Admin access',
            child: AdminAccessScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/programmes',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Programmes',
            child: AdminProgrammesScreen(),
          ),
        )),
        routes: [
          GoRoute(
            path: 'edit/:id',
            pageBuilder: (_, state) => _fade(MaterialPage(
              child: _AdminPage(
                title: 'Edit programme',
                child: ProgrammeEditScreen(
                    programmeId: state.pathParameters['id']),
              ),
            )),
          ),
          GoRoute(
            path: 'new',
            pageBuilder: (_, _) => _fade(const MaterialPage(
              child: _AdminPage(
                title: 'New programme',
                child: ProgrammeEditScreen(),
              ),
            )),
          ),
        ],
      ),
      GoRoute(
        path: '/admin/monthly-plans',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Monthly plans',
            child: AdminMonthlyPlansScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/weekly-plans',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Weekly plans',
            child: AdminWeeklyPlansScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/materials',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Materials',
            child: AdminMaterialsScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/daily-diet',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Daily Diet',
            child: AdminDailyDietScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/activities',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Activities',
            child: AdminActivitiesScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/prayer-partners',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Prayer partners',
            child: AdminPrayerPartnersScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/announcements',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Announcements',
            child: AdminAnnouncementsScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/analytics',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Analytics',
            child: AdminAnalyticsScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Audit log',
            child: AdminAuditLogsScreen(),
          ),
        )),
      ),
      GoRoute(
        path: '/admin/settings',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => _fade(const MaterialPage(
          child: _AdminPage(
            title: 'Settings',
            child: AdminSettingsScreen(),
          ),
        )),
      ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(location: state.uri.path),
  );
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _fade(MaterialPage page) {
  return CustomTransitionPage<void>(
    key: page.key,
    child: page.child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

/// Scaffold + app bar for the member full-screen routes.
///
/// The member dashboard sits on the root navigator (outside the member
/// shell), so it needs its own frame. The leading control pops when there is
/// something to return to, otherwise it falls back to the Home tab.
class _MemberPage extends StatelessWidget {
  const _MemberPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: child,
    );
  }
}

/// Scaffold + app bar for the admin full-screen routes.
///
/// Those routes sit on the root navigator (outside the admin shell), so they
/// need their own frame. The leading control pops when there is something to
/// return to, otherwise it falls back to the admin "More" tab.
class _AdminPage extends StatelessWidget {
  const _AdminPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
      ),
      body: child,
    );
  }
}

String _memberShellTitle(int index) => switch (index) {
      0 => 'Home',
      1 => 'Daily Diet',
      2 => 'My Growth Plan',
      3 => 'Prayer Room',
      _ => 'Home',
    };

String _adminShellTitle(int index) => switch (index) {
      0 => 'Home',
      1 => 'Members',
      2 => 'Reports & Reviews',
      _ => 'Home',
    };

/// Cold-start splash: restores the session then lets the router redirect.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Restore once on mount; the router's redirect moves us to the landing
    // area as soon as the auth state settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrapSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SplashLogo(),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.forestGreen, AppColors.darkEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(Icons.spa_outlined,
          color: AppColors.champagneGold, size: 40),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, size: 48, color: Color(0xFF7A8494)),
              const SizedBox(height: 16),
              Text('We couldn’t find “$location”.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

