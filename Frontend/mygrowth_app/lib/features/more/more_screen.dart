import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/area_shell.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/appearance_section.dart';
import '../../core/widgets/image_carousel.dart';
import '../../core/widgets/section_header.dart';

/// Home tab: the landing screen after sign-in.
///
/// The layout follows the reference service-app structure (brand header,
/// greeting, promo carousel, two rows of quick actions, a full-width call
/// to action) but keeps this project's navy / grey-brown identity.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key, required this.area});

  final AppArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final wide = !Breakpoints.isCompact(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final dashboardPath =
        area == AppArea.admin ? '/admin/dashboard' : '/dashboard';

    final actions = area == AppArea.admin ? _adminQuickActions : _memberQuickActions;
    final slides = area == AppArea.admin ? _adminSlides : _memberSlides;
    final tools = area == AppArea.admin ? _adminTools : _memberTools;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ref.read(authControllerProvider.notifier).refreshUser();
        } catch (_) {
          // Keep whatever cached profile we already have.
        }
      },
      child: ListView(
        padding: wide
            ? const EdgeInsets.all(AppSpacing.xl)
            : const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
        children: [
          // ------------------------------------------------------- greeting
          _GreetingHeader(
            onNotifications: () => context.go('/notifications'),
            onSignOut: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _GreetingStrip(
            greeting:
                '$greeting, ${firstName.isEmpty ? 'friend' : firstName}',
            subtitle: user?.email ?? '',
            initials: user?.initials ?? '?',
          ),
          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------- promo carousel
          ImageCarousel(
            slides: slides,
            height: wide ? 230 : 185,
            onTapSlide: (i) => context.go(slides[i].path),
            onAction: (i) => context.go(slides[i].path),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------------- quick actions
          const SectionHeader(
            title: 'Quick actions',
            subtitle: 'Your everyday tools, one tap away',
          ),
          _QuickActionRow(actions: actions.take(4).toList()),
          const SizedBox(height: AppSpacing.md),
          _QuickActionRow(actions: actions.skip(4).take(4).toList()),
          const SizedBox(height: AppSpacing.lg),

          // --------------------------------------------------- all the tools
          SectionHeader(
            title: area == AppArea.admin ? 'Admin services' : 'All services',
            subtitle: 'Everything else in the app',
            icon: Icons.grid_view_rounded,
          ),
          _ToolGrid(tools: tools),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------------- full-width call to action
          _PromoBanner(
            title: area == AppArea.admin
                ? 'Steward the flock with wisdom'
                : 'Grow in faith, discipline and health',
            subtitle: area == AppArea.admin
                ? 'Every admin tool in one place'
                : 'Your whole Growth Diet in one place',
            actionLabel: 'Dashboard',
            onAction: () => context.go(dashboardPath),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- slides

class _HomeSlide extends CarouselSlide {
  const _HomeSlide({
    required super.image,
    required super.title,
    required super.caption,
    required this.path,
    super.icon,
    super.actionLabel,
  });

  final String path;
}

const _memberSlides = <_HomeSlide>[
  _HomeSlide(
    image: 'assets/images/bible.jpg',
    title: 'Feed on the Word',
    caption: 'Follow the reading plan and let Scripture shape your week.',
    actionLabel: 'Start reading',
    path: '/bible-reading',
    icon: Icons.auto_stories_outlined,
  ),
  _HomeSlide(
    image: 'assets/images/diet.jpg',
    title: 'Today\u2019s Growth Diet',
    caption: 'Your daily activities, ready to record honestly.',
    actionLabel: 'Open my diet',
    path: '/diet',
    icon: Icons.today_outlined,
  ),
  _HomeSlide(
    image: 'assets/images/prayer.jpg',
    title: 'A life of prayer',
    caption: 'Meet God in the quiet place, then pray with a partner.',
    actionLabel: 'Enter prayer room',
    path: '/prayer',
    icon: Icons.self_improvement_outlined,
  ),
  _HomeSlide(
    image: 'assets/images/plan.jpg',
    title: 'Grow with the plan',
    caption: 'Monthly and weekly guidance for your journey.',
    actionLabel: 'See my plan',
    path: '/plan',
    icon: Icons.menu_book_outlined,
  ),
];

const _adminSlides = <_HomeSlide>[
  _HomeSlide(
    image: 'assets/images/members.jpg',
    title: 'Know your members',
    caption: 'Approve, encourage and follow up on every account.',
    actionLabel: 'View members',
    path: '/admin/members',
    icon: Icons.people_outline_rounded,
  ),
  _HomeSlide(
    image: 'assets/images/programmes.jpg',
    title: 'Publish the plan',
    caption: 'Keep annual, monthly and weekly content current.',
    actionLabel: 'Open programmes',
    path: '/admin/programmes',
    icon: Icons.event_note_outlined,
  ),
  _HomeSlide(
    image: 'assets/images/admin_reports.jpg',
    title: 'Review with grace',
    caption: 'Read accountability reports and respond with wisdom.',
    actionLabel: 'Open reports',
    path: '/admin/reports',
    icon: Icons.fact_check_outlined,
  ),
  _HomeSlide(
    image: 'assets/images/analytics.jpg',
    title: 'Watch the trends',
    caption: 'Aggregate insight, never individual surveillance.',
    actionLabel: 'View analytics',
    path: '/admin/analytics',
    icon: Icons.query_stats_outlined,
  ),
];

// --------------------------------------------------------- quick actions

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String caption;
  final String path;
}

const _memberQuickActions = <_QuickAction>[
  _QuickAction(
    icon: Icons.today_outlined,
    label: 'Daily Diet',
    caption: 'Record today',
    path: '/diet',
  ),
  _QuickAction(
    icon: Icons.auto_stories_outlined,
    label: 'Bible Reading',
    caption: 'Feed on the Word',
    path: '/bible-reading',
  ),
  _QuickAction(
    icon: Icons.self_improvement_outlined,
    label: 'Prayer Room',
    caption: 'Meet with God',
    path: '/prayer',
  ),
  _QuickAction(
    icon: Icons.menu_book_outlined,
    label: 'Growth Plan',
    caption: 'Monthly guide',
    path: '/plan',
  ),
  _QuickAction(
    icon: Icons.flag_outlined,
    label: 'My Goals',
    caption: 'Stay accountable',
    path: '/goals',
  ),
  _QuickAction(
    icon: Icons.wb_sunny_outlined,
    label: 'Fasting',
    caption: 'Track your fast',
    path: '/fasting',
  ),
  _QuickAction(
    icon: Icons.local_library_outlined,
    label: 'Materials',
    caption: 'Study resources',
    path: '/materials',
  ),
  _QuickAction(
    icon: Icons.fact_check_outlined,
    label: 'Reports',
    caption: 'Share progress',
    path: '/reports',
  ),
];

const _adminQuickActions = <_QuickAction>[
  _QuickAction(
    icon: Icons.space_dashboard_outlined,
    label: 'Dashboard',
    caption: 'See it all',
    path: '/admin/dashboard',
  ),
  _QuickAction(
    icon: Icons.people_outlined,
    label: 'Members',
    caption: 'Care for the flock',
    path: '/admin/members',
  ),
  _QuickAction(
    icon: Icons.fact_check_outlined,
    label: 'Reports',
    caption: 'Review progress',
    path: '/admin/reports',
  ),
  _QuickAction(
    icon: Icons.event_note_outlined,
    label: 'Programmes',
    caption: 'Publish content',
    path: '/admin/programmes',
  ),
  _QuickAction(
    icon: Icons.calendar_month_outlined,
    label: 'Monthly Plans',
    caption: 'Set the month',
    path: '/admin/monthly-plans',
  ),
  _QuickAction(
    icon: Icons.view_week_outlined,
    label: 'Weekly Plans',
    caption: 'Set the week',
    path: '/admin/weekly-plans',
  ),
  _QuickAction(
    icon: Icons.today_outlined,
    label: 'Daily Diet',
    caption: 'Shape the day',
    path: '/admin/daily-diet',
  ),
  _QuickAction(
    icon: Icons.library_books_outlined,
    label: 'Materials',
    caption: 'Equip the ministry',
    path: '/admin/materials',
  ),
  _QuickAction(
    icon: Icons.query_stats_outlined,
    label: 'Analytics',
    caption: 'Watch trends',
    path: '/admin/analytics',
  ),
];

// ----------------------------------------------------------------- tools

class _Tool {
  const _Tool({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;
}

const _memberTools = <_Tool>[
  _Tool(
    icon: Icons.handshake_outlined,
    label: 'Prayer Partners',
    path: '/prayer/partners',
  ),
  _Tool(
    icon: Icons.edit_note_outlined,
    label: 'Reflections',
    path: '/reflections',
  ),
  _Tool(
    icon: Icons.insights_outlined,
    label: 'My Progress',
    path: '/progress',
  ),
  _Tool(
    icon: Icons.campaign_outlined,
    label: 'Announcements',
    path: '/announcements',
  ),
  _Tool(
    icon: Icons.person_outline_rounded,
    label: 'Profile & Settings',
    path: '/profile',
  ),
];

const _adminTools = <_Tool>[
  _Tool(
    icon: Icons.admin_panel_settings_outlined,
    label: 'Admin Access',
    path: '/admin/access',
  ),
  _Tool(
    icon: Icons.checklist_outlined,
    label: 'Activities',
    path: '/admin/activities',
  ),
  _Tool(
    icon: Icons.handshake_outlined,
    label: 'Prayer Partners',
    path: '/admin/prayer-partners',
  ),
  _Tool(
    icon: Icons.campaign_outlined,
    label: 'Announcements',
    path: '/admin/announcements',
  ),
  _Tool(
    icon: Icons.policy_outlined,
    label: 'Audit Logs',
    path: '/admin/audit-logs',
  ),
  _Tool(
    icon: Icons.settings_outlined,
    label: 'Settings',
    path: '/admin/settings',
  ),
];

// --------------------------------------------------------------- widgets

/// Brand row, mirroring the reference header band.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.onNotifications,
    required this.onSignOut,
  });

  final VoidCallback onNotifications;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.forestGreen, AppColors.darkEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppSpacing.cardRadius,
      ),
      child: Row(
        children: [
          // --------------------------------------------- brand mark
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.spa_outlined,
              color: AppColors.softGold,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MyGrowth',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                Text(
                  'Diet App',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const AppearanceToggleButton(onDarkBackground: true),
          const SizedBox(width: AppSpacing.xs),
          _CircleAction(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            onPressed: onNotifications,
          ),
          const SizedBox(width: AppSpacing.xs),
          _CircleAction(
            icon: Icons.logout_rounded,
            tooltip: 'Sign out',
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}

/// Greeting strip that sits just under the brand band.
class _GreetingStrip extends StatelessWidget {
  const _GreetingStrip({
    required this.greeting,
    required this.subtitle,
    required this.initials,
  });

  final String greeting;
  final String subtitle;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.avatarBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// One row of four quick actions (icon, label, one-line caption).
class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final wide = !Breakpoints.isCompact(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: wide ? AppSpacing.md : AppSpacing.sm),
          Expanded(
            child: _QuickActionTile(
              action: actions[i],
              onTap: () => context.go(actions[i].path),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(action.icon, color: AppColors.iconAccent, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                action.caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                  fontSize: 10.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of the remaining destinations.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools});

  final List<_Tool> tools;

  @override
  Widget build(BuildContext context) {
    final wide = !Breakpoints.isCompact(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tool in tools)
          SizedBox(
            width: wide
                ? (MediaQuery.sizeOf(context).width -
                        AppSpacing.xl * 2 -
                        AppSpacing.sm * 2) /
                    3
                : (MediaQuery.sizeOf(context).width -
                        AppSpacing.md * 2 -
                        AppSpacing.sm * 2) /
                    3,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(tool.path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.paleChampagne.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          tool.icon,
                          color: AppColors.goldText,
                          size: 21,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tool.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-width banner with a single call to action.
class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      borderRadius: AppSpacing.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.forestGreen, AppColors.darkEmerald],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: AppSpacing.cardRadius,
        ),
        child: InkWell(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: AppColors.darkEmerald,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: AppColors.darkEmerald,
                      ),
                    ],
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
