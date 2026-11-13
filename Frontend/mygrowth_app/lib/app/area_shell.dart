import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/models/app_user.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/app_badge.dart';
import '../core/widgets/brand_logo.dart';
import '../core/widgets/app_back_button.dart';

/// Destinations available in the member bottom navigation (compact devices).
const memberBottomDestinations = [
  NavDestination('Home', Icons.home_outlined, Icons.home_rounded, '/home'),
  NavDestination(
      'Today\'s Diet', Icons.today_outlined, Icons.today_rounded, '/diet'),
  NavDestination('Bible', Icons.menu_book_outlined,
      Icons.menu_book_rounded, '/bible'),
  NavDestination('Diet Plan', Icons.event_note_outlined,
      Icons.event_note_rounded, '/plan'),
  NavDestination('AI Assistance', Icons.auto_awesome_outlined,
      Icons.auto_awesome_rounded, '/assistant'),
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
  const MenuItem(
    this.icon,
    this.label,
    this.path, {
    this.image,
    this.category = 'More',
  });

  final IconData icon;
  final String label;
  final String path;
  final String? image;
  final String category;
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
    final isHomeLocation = location == '/home' || location == '/admin';
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
            appBar: isHomeLocation && area == AppArea.member
                ? null
                : AppBar(
                    title: Text(title),
                    leading: isHomeLocation
                        ? Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Open navigation menu',
                              icon: const Icon(Icons.menu_rounded),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          )
                        : const AppBackButton(),
                    leadingWidth: 56,
                    actions: [
                      ...?actions,
                      if (!isHomeLocation)
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: 'Open navigation menu',
                            icon: const Icon(Icons.menu_rounded),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                    ],
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
                  _DesktopAppBar(
                    title: title,
                    actions: actions,
                    user: user,
                    showBackButton: !isHomeLocation,
                  ),
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
    required this.showBackButton,
  });

  final String title;
  final List<Widget>? actions;
  final AppUser? user;
  final bool showBackButton;

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
          if (showBackButton) const AppBackButton(),
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
      decoration: BoxDecoration(
        color: AppColors.background,
        image: Theme.of(context).brightness == Brightness.light
            ? const DecorationImage(
                image: AssetImage('assets/images/app_background.jpg'),
                fit: BoxFit.cover,
              )
            : null,
      ),
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
          height: 72,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 48,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.brandSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 20,
                color: selected ? AppColors.inkOnDark : AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 2),
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
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          image: Theme.of(context).brightness == Brightness.light
              ? const DecorationImage(
                  image: AssetImage('assets/images/app_background.jpg'),
                  fit: BoxFit.cover,
                )
              : null,
        ),
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
                  for (final group in _menuGroups(context).entries)
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          _menuCategoryIcon(group.key),
                          color: AppColors.iconAccent,
                          size: 21,
                        ),
                        title: Text(
                          group.key,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding: const EdgeInsets.only(left: 8),
                        children: [
                          for (final item in group.value)
                            ListTile(
                              dense: true,
                              leading: Icon(item.icon, size: 20),
                              title: Text(item.label),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                if (item.path == '/shape-space') {
                                  context.push(item.path);
                                } else {
                                  context.go(item.path);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  List<MenuItem> _menuItems(BuildContext context) {
    if (area == AppArea.admin) return adminMenuItems;
    return memberMenuItems;
  }

  Map<String, List<MenuItem>> _menuGroups(BuildContext context) {
    final groups = <String, List<MenuItem>>{};
    for (final item in _menuItems(context)) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    final order = area == AppArea.admin
        ? const [
            'Overview',
            'Programmes & Content',
            'People & Partnerships',
            'Admin Tools',
          ]
        : const [
            'Growth',
            'Bible & Study',
            'Prayer & Community',
            'Updates',
            'Account',
          ];
    return {
      for (final category in order)
        if (groups.containsKey(category)) category: groups[category]!,
    };
  }
}

IconData _menuCategoryIcon(String category) => switch (category) {
      'Growth' => Icons.trending_up_rounded,
      'Bible & Study' => Icons.menu_book_rounded,
      'Prayer & Community' || 'People & Partnerships' => Icons.groups_rounded,
      'Updates' => Icons.notifications_active_outlined,
      'Account' => Icons.manage_accounts_outlined,
      'Overview' => Icons.dashboard_outlined,
      'Programmes & Content' => Icons.calendar_month_outlined,
      'Admin Tools' => Icons.admin_panel_settings_outlined,
      _ => Icons.apps_rounded,
    };

/// Full member navigation list (used by drawer and the "More" screen).
const memberMenuItems = <MenuItem>[
  MenuItem(Icons.auto_stories_outlined, 'Daily Devotion', '/devotion',
      category: 'Growth'),
  MenuItem(Icons.forum_outlined, 'Shape Space', '/shape-space',
      category: 'Prayer & Community'),
  MenuItem(Icons.auto_awesome_outlined, 'AI Assistant', '/assistant',
      category: 'Updates'),
  MenuItem(Icons.alarm_outlined, 'Daily Reminders', '/reminders',
      category: 'Updates'),
  MenuItem(Icons.dashboard_outlined, 'Dashboard', '/dashboard',
      image: 'assets/images/dashboard.jpg', category: 'Growth'),
  MenuItem(Icons.workspace_premium_outlined, 'Subscription & Access',
      '/subscription', image: 'assets/images/profile.jpg', category: 'Account'),
  MenuItem(Icons.today_outlined, 'Daily Diet', '/diet',
      image: 'assets/images/diet.jpg', category: 'Growth'),
  MenuItem(Icons.menu_book_outlined, 'Bible', '/bible',
      image: 'assets/images/bible.jpg', category: 'Bible & Study'),
  MenuItem(Icons.menu_book_outlined, 'My Growth Plan', '/plan',
      image: 'assets/images/plan.jpg', category: 'Growth'),
  MenuItem(Icons.auto_stories_outlined, 'Bible Reading', '/bible-reading',
      image: 'assets/images/bible.jpg', category: 'Bible & Study'),
  MenuItem(Icons.local_library_outlined, 'Study Materials', '/materials',
      image: 'assets/images/materials.jpg', category: 'Bible & Study'),
  MenuItem(Icons.flag_outlined, 'My Goals', '/goals',
      image: 'assets/images/goals.jpg', category: 'Growth'),
  MenuItem(Icons.wb_sunny_outlined, 'Fasting Tracker', '/fasting',
      image: 'assets/images/fasting.jpg', category: 'Growth'),
  MenuItem(Icons.self_improvement_outlined, 'Prayer Room', '/prayer',
      image: 'assets/images/prayer.jpg', category: 'Prayer & Community'),
  MenuItem(Icons.handshake_outlined, 'Prayer Partners', '/prayer/partners',
      image: 'assets/images/partners.jpg', category: 'Prayer & Community'),
  MenuItem(Icons.fact_check_outlined, 'Accountability Reports', '/reports',
      image: 'assets/images/reports.jpg', category: 'Growth'),
  MenuItem(Icons.edit_note_outlined, 'Reflections & Testimonies',
      '/reflections',
      image: 'assets/images/reflections.jpg', category: 'Growth'),
  MenuItem(Icons.insights_outlined, 'My Progress', '/progress',
      image: 'assets/images/progress.jpg', category: 'Growth'),
  MenuItem(Icons.campaign_outlined, 'Announcements', '/announcements',
      image: 'assets/images/announcements.jpg', category: 'Updates'),
  MenuItem(Icons.link_outlined, 'Connect with me', '/connect',
      image: 'assets/images/profile.jpg', category: 'Prayer & Community'),
  MenuItem(Icons.notifications_outlined, 'Notifications', '/notifications',
      image: 'assets/images/notifications.jpg', category: 'Updates'),
  MenuItem(Icons.person_outline_rounded, 'Profile & Settings', '/profile',
      image: 'assets/images/profile.jpg', category: 'Account'),
];

/// Full admin navigation list (used by drawer and the "More" screen).
const adminMenuItems = <MenuItem>[
  MenuItem(Icons.dashboard_outlined, 'Admin Dashboard', '/admin/dashboard',
      image: 'assets/images/admin_dashboard.jpg', category: 'Overview'),
  MenuItem(Icons.admin_panel_settings_outlined, 'Admin Access Management',
      '/admin/access',
      image: 'assets/images/admin_access.jpg',
      category: 'People & Partnerships'),
  MenuItem(Icons.people_outlined, 'Members', '/admin/members',
      image: 'assets/images/members.jpg', category: 'People & Partnerships'),
  MenuItem(Icons.event_note_outlined, 'Annual Programmes', '/admin/programmes',
      image: 'assets/images/programmes.jpg', category: 'Programmes & Content'),
  MenuItem(Icons.calendar_month_outlined, 'Monthly Plans', '/admin/monthly-plans',
      image: 'assets/images/monthly_plans.jpg',
      category: 'Programmes & Content'),
  MenuItem(Icons.view_week_outlined, 'Weekly & Daily Plans',
      '/admin/weekly-plans',
      image: 'assets/images/weekly_plans.jpg',
      category: 'Programmes & Content'),
  MenuItem(Icons.today_outlined, 'Daily Diet', '/admin/daily-diet',
      image: 'assets/images/diet.jpg', category: 'Programmes & Content'),
  MenuItem(Icons.forum_outlined, 'Shape Space Q&A', '/admin/shape-space',
      image: 'assets/images/partners.jpg', category: 'People & Partnerships'),
  MenuItem(Icons.library_books_outlined, 'Materials Library',
      '/admin/materials',
      image: 'assets/images/admin_materials.jpg',
      category: 'Programmes & Content'),
  MenuItem(Icons.checklist_outlined, 'Activity Management', '/admin/activities',
      image: 'assets/images/activities.jpg',
      category: 'Programmes & Content'),
  MenuItem(Icons.fact_check_outlined, 'Reports & Reviews', '/admin/reports',
      image: 'assets/images/admin_reports.jpg', category: 'Overview'),
  MenuItem(Icons.handshake_outlined, 'Prayer Partnerships',
      '/admin/prayer-partners',
      image: 'assets/images/admin_partners.jpg',
      category: 'People & Partnerships'),
  MenuItem(Icons.campaign_outlined, 'Announcements', '/admin/announcements',
      image: 'assets/images/admin_announcements.jpg',
      category: 'Programmes & Content'),
  MenuItem(Icons.link_outlined, 'Connect with me links', '/admin/connect-links',
      image: 'assets/images/admin_announcements.jpg',
      category: 'People & Partnerships'),
  MenuItem(Icons.query_stats_outlined, 'Analytics', '/admin/analytics',
      image: 'assets/images/analytics.jpg', category: 'Overview'),
  MenuItem(Icons.policy_outlined, 'Audit Logs', '/admin/audit-logs',
      image: 'assets/images/audit.jpg', category: 'Admin Tools'),
  MenuItem(Icons.settings_outlined, 'Settings', '/admin/settings',
      image: 'assets/images/settings.jpg', category: 'Admin Tools'),
];

/// Human label for a status that might come from the backend.
String statusLabel(String status) => humanizeStatus(status);
