import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/models/app_user.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/brand_logo.dart';

/// Destinations available in the member bottom navigation (compact devices).
const memberBottomDestinations = [
  NavDestination('Home', Icons.home_outlined, Icons.home_rounded, '/home'),
  NavDestination(
      'Daily Diet', Icons.today_outlined, Icons.today_rounded, '/diet'),
  NavDestination('Bible', Icons.menu_book_outlined, Icons.menu_book_rounded,
      '/bible'),
  NavDestination('Plan', Icons.event_note_outlined, Icons.event_note_rounded,
      '/plan'),
  NavDestination(
      'Prayer', Icons.self_improvement_outlined, Icons.self_improvement_rounded,
      '/prayer'),
];

/// Destinations available in the admin bottom navigation (compact devices).
const adminBottomDestinations = [
  NavDestination('Home', Icons.home_outlined, Icons.home_rounded, '/admin'),
  NavDestination(
      'Members', Icons.people_outlined, Icons.people_rounded, '/admin/members'),
  NavDestination('Reports', Icons.fact_check_outlined, Icons.fact_check_rounded,
      '/admin/reports'),
];

class NavDestination {
  const NavDestination(this.label, this.icon, this.activeIcon, this.shellPath);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String shellPath;
}

/// A single entry in the full-area menu (drawer + "More" grid).
///
/// [image] is a bundled illustration shown on the "More" landing tiles.
class MenuItem {
  const MenuItem(this.icon, this.label, this.path, {this.image});

  final IconData icon;
  final String label;
  final String path;
  final String? image;
}

/// Responsive scaffold for area navigation.
///
/// - Compact widths: [BottomNavigationBar] plus a drawer for the full menu.
/// - Expanded widths: a permanent navigation rail/sidebar with labels.
class AreaShell extends ConsumerWidget {
  const AreaShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.area,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  final Widget child;
  final List<NavDestination> destinations;
  final AppArea area;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final offlineMode = ref.watch(authControllerProvider).offlineMode &&
        area == AppArea.member;
    final location = GoRouterState.of(context).uri.path;
    final expanded = Breakpoints.isExpanded(context);
    final medium = Breakpoints.isMedium(context);
    final selectedIndex = _indexOf(location);

    final navigation = expanded || medium
        ? _SidebarNavigation(
            destinations: destinations,
            selectedIndex: selectedIndex,
            area: area,
            user: user,
          )
        : null;

    final body = expanded || medium
        ? Row(
            children: [
              navigation!,
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: child),
            ],
          )
        : Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: actions,
              leadingWidth: 56,
            ),
            drawer: _AreaDrawer(area: area, user: user),
            body: Column(
              children: [
                if (offlineMode) const _OfflineAccessBanner(),
                Expanded(child: child),
              ],
            ),
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: _BottomNav(
              destinations: destinations,
              selectedIndex: selectedIndex,
            ),
          );

    if (expanded || medium) {
      return Scaffold(
        body: Row(
          children: [
            navigation!,
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Column(
                children: [
                  _DesktopAppBar(title: title, actions: actions, user: user),
                  if (offlineMode) const _OfflineAccessBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }
    return body;
  }

  int _indexOf(String location) {
    var best = 0;
    for (var i = 0; i < destinations.length; i++) {
      final path = destinations[i].shellPath;
      if (location == path || location.startsWith('$path/')) {
        best = i;
      }
    }
    return best;
  }
}

class _OfflineAccessBanner extends StatelessWidget {
  const _OfflineAccessBanner();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: AppColors.navy100,
        child: const Text(
          'Offline mode · saved Bible and daily readings are available. Saving progress needs internet.',
          textAlign: TextAlign.center,
        ),
      );
}

enum AppArea { member, admin }

class _DesktopAppBar extends StatelessWidget {
  const _DesktopAppBar({
    required this.title,
    required this.actions,
    required this.user,
  });

  final String title;
  final List<Widget>? actions;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          ...?actions,
          const SizedBox(width: AppSpacing.sm),
          if (user != null) _AvatarBadge(user: user!),
        ],
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.avatarBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        user.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.area,
    required this.user,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final AppArea area;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _SidebarItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () =>
                        context.go(destinations[i].shellPath),
                  ),
              ],
            ),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _SidebarUserTile(user: user!),
            ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg,
          AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          const BrandLogo(size: 38),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MyGrowth',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                ),
                Text(
                  'Diet App',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? AppColors.navy100 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 21,
                  color:
                      selected ? AppColors.navy800 : AppColors.inkSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    destination.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: selected
                              ? AppColors.navy800
                              : AppColors.inkSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.gold500,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarUserTile extends StatelessWidget {
  const _SidebarUserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: _AvatarBadge(user: user),
      title: Text(
        user.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        switch (user.role) {
          'MAIN_ADMIN' => 'Main Admin',
          'ADMIN' => 'Admin',
          _ => 'Member',
        },
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.settings_outlined, size: 20),
        tooltip: 'Profile & settings',
        onPressed: () => context.go('/profile'),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.destinations, required this.selectedIndex});

  final List<NavDestination> destinations;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () =>
                        context.go(destinations[i].shellPath),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 23,
              color: selected ? AppColors.navy800 : AppColors.inkMuted,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? AppColors.navy800
                        : AppColors.inkMuted,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "More" menu shared by members and admins: a grid of gradient tiles
/// inspired by the reference design, adapted to the navy/gold identity.
class _AreaDrawer extends StatelessWidget {
  const _AreaDrawer({required this.area, required this.user});

  final AppArea area;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandHeader(),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _SidebarUserTile(user: user!),
                    ),
                  ..._menuItems(context)
                      .map(
                        (item) => ListTile(
                          leading: Icon(item.icon, size: 21),
                          title: Text(item.label),
                          trailing: const Icon(Icons.chevron_right_rounded,
                              size: 18),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(item.path);
                          },
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MenuItem> _menuItems(BuildContext context) {
    if (area == AppArea.admin) return adminMenuItems;
    return memberMenuItems;
  }
}

/// Full member navigation list (used by drawer and the "More" screen).
const memberMenuItems = <MenuItem>[
  MenuItem(Icons.auto_stories_outlined, 'Daily Devotion', '/devotion'),
  MenuItem(Icons.forum_outlined, 'Shape Space', '/shape-space'),
  MenuItem(Icons.auto_awesome_outlined, 'AI Assistant', '/assistant'),
  MenuItem(Icons.alarm_outlined, 'Daily Reminders', '/reminders'),
  MenuItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard',
      image: 'assets/images/dashboard.jpg'),
  MenuItem(Icons.today_outlined, 'Daily Diet', '/diet',
      image: 'assets/images/diet.jpg'),
  MenuItem(Icons.menu_book_outlined, 'Bible', '/bible',
      image: 'assets/images/bible.jpg'),
  MenuItem(Icons.menu_book_outlined, 'My Growth Plan', '/plan',
      image: 'assets/images/plan.jpg'),
  MenuItem(Icons.auto_stories_outlined, 'Bible Reading', '/bible-reading',
      image: 'assets/images/bible.jpg'),
  MenuItem(Icons.local_library_outlined, 'Study Materials', '/materials',
      image: 'assets/images/materials.jpg'),
  MenuItem(Icons.flag_outlined, 'My Goals', '/goals',
      image: 'assets/images/goals.jpg'),
  MenuItem(Icons.wb_sunny_outlined, 'Fasting Tracker', '/fasting',
      image: 'assets/images/fasting.jpg'),
  MenuItem(Icons.self_improvement_outlined, 'Prayer Room', '/prayer',
      image: 'assets/images/prayer.jpg'),
  MenuItem(Icons.handshake_outlined, 'Prayer Partners', '/prayer/partners',
      image: 'assets/images/partners.jpg'),
  MenuItem(Icons.fact_check_outlined, 'Accountability Reports', '/reports',
      image: 'assets/images/reports.jpg'),
  MenuItem(Icons.edit_note_outlined, 'Reflections & Testimonies',
      '/reflections',
      image: 'assets/images/reflections.jpg'),
  MenuItem(Icons.insights_outlined, 'My Progress', '/progress',
      image: 'assets/images/progress.jpg'),
  MenuItem(Icons.campaign_outlined, 'Announcements', '/announcements',
      image: 'assets/images/announcements.jpg'),
  MenuItem(Icons.notifications_outlined, 'Notifications', '/notifications',
      image: 'assets/images/notifications.jpg'),
  MenuItem(Icons.person_outline_rounded, 'Profile & Settings', '/profile',
      image: 'assets/images/profile.jpg'),
];

/// Full admin navigation list (used by drawer and the "More" screen).
const adminMenuItems = <MenuItem>[
  MenuItem(Icons.dashboard_outlined, 'Admin Dashboard', '/admin/dashboard',
      image: 'assets/images/admin_dashboard.jpg'),
  MenuItem(Icons.admin_panel_settings_outlined, 'Admin Access Management',
      '/admin/access',
      image: 'assets/images/admin_access.jpg'),
  MenuItem(Icons.people_outlined, 'Members', '/admin/members',
      image: 'assets/images/members.jpg'),
  MenuItem(Icons.event_note_outlined, 'Annual Programmes', '/admin/programmes',
      image: 'assets/images/programmes.jpg'),
  MenuItem(Icons.calendar_month_outlined, 'Monthly Plans', '/admin/monthly-plans',
      image: 'assets/images/monthly_plans.jpg'),
  MenuItem(Icons.view_week_outlined, 'Weekly & Daily Plans',
      '/admin/weekly-plans',
      image: 'assets/images/weekly_plans.jpg'),
  MenuItem(Icons.today_outlined, 'Daily Diet', '/admin/daily-diet',
      image: 'assets/images/diet.jpg'),
  MenuItem(Icons.forum_outlined, 'Shape Space (Pastoral Care)', '/admin/shape-space',
      image: 'assets/images/partners.jpg'),
  MenuItem(Icons.library_books_outlined, 'Materials Library',
      '/admin/materials',
      image: 'assets/images/admin_materials.jpg'),
  MenuItem(Icons.checklist_outlined, 'Activity Management', '/admin/activities',
      image: 'assets/images/activities.jpg'),
  MenuItem(Icons.fact_check_outlined, 'Reports & Reviews', '/admin/reports',
      image: 'assets/images/admin_reports.jpg'),
  MenuItem(Icons.handshake_outlined, 'Prayer Partnerships',
      '/admin/prayer-partners',
      image: 'assets/images/admin_partners.jpg'),
  MenuItem(Icons.campaign_outlined, 'Announcements', '/admin/announcements',
      image: 'assets/images/admin_announcements.jpg'),
  MenuItem(Icons.query_stats_outlined, 'Analytics', '/admin/analytics',
      image: 'assets/images/analytics.jpg'),
  MenuItem(Icons.policy_outlined, 'Audit Logs', '/admin/audit-logs',
      image: 'assets/images/audit.jpg'),
  MenuItem(Icons.settings_outlined, 'Settings', '/admin/settings',
      image: 'assets/images/settings.jpg'),
];

/// Human label for a status that might come from the backend.
String statusLabel(String status) => humanizeStatus(status);
