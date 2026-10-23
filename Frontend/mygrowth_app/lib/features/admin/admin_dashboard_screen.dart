import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/image_carousel.dart';
import '../../core/widgets/section_header.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

const adminHomeSlides = <CarouselSlide>[
  CarouselSlide(
    image: 'assets/images/members.jpg',
    title: 'Shepherd the Flock',
    caption: 'Care for and guide members with wisdom and grace.',
    icon: Icons.people_outline_rounded,
  ),
  CarouselSlide(
    image: 'assets/images/admin_reports.jpg',
    title: 'Review with Grace',
    caption: 'Read accountability reports and respond with wisdom.',
    icon: Icons.fact_check_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/programmes.jpg',
    title: 'Publish the Plan',
    caption: 'Keep annual, monthly and weekly content current.',
    icon: Icons.event_note_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/materials.jpg',
    title: 'Equip the Ministry',
    caption: 'Share materials to nourish faith and growth.',
    icon: Icons.local_library_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/analytics.jpg',
    title: 'Watch the Trends',
    caption: 'Aggregate insight, never individual surveillance.',
    icon: Icons.query_stats_outlined,
  ),
];


/// Admin home: live metrics from `/admin/analytics/summary`, attention
/// items, recent activity and quick actions.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AdminDashboardBody();
  }
}

class _AdminDashboardBody extends ConsumerStatefulWidget {
  const _AdminDashboardBody();

  @override
  ConsumerState<_AdminDashboardBody> createState() =>
      _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends ConsumerState<_AdminDashboardBody> {
  String _period = 'month';

  static const _periods = <(String, String)>[
    ('week', 'This week'),
    ('month', 'This month'),
    ('year', 'This year'),
  ];

  String get _periodLabel => _periods
      .firstWhere((p) => p.$1 == _period, orElse: () => _periods[1])
      .$2;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(adminSummaryProvider(_period));
    final announcements = ref.watch(adminAnnouncementsProvider);
    final isMainAdmin = ref.watch(currentUserProvider)?.isMainAdmin == true;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminSummaryProvider);
        ref.invalidate(adminAnnouncementsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          // ------------------------------------------------------ header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ministry at a glance',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(now),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: 'Aggregates only',
                tone: AppBadgeTone.navy,
                icon: Icons.shield_outlined,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------------- hero carousel
          //
          // Placeholder picture strip — see [adminHomeSlides] to swap images.
          ImageCarousel(
            slides: adminHomeSlides,
            height: Breakpoints.isCompact(context) ? 190 : 240,
            onTapSlide: (_) => context.go('/admin/analytics'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------------------ period chips
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Active members:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final option in _periods)
                ChoiceChip(
                  label: Text(option.$2),
                  selected: _period == option.$1,
                  onSelected: (_) => setState(() => _period = option.$1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ---------------------------------------------------- metrics
          summary.when(
            loading: () => metricGrid(
              context,
              const [
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
              ],
            ),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminSummaryProvider(_period)),
            ),
            data: (data) => _summary(context, data, isMainAdmin),
          ),
          const SizedBox(height: AppSpacing.xl),

          // --------------------------------------------- quick actions
          SectionHeader(
            title: 'Quick Actions',
            icon: Icons.bolt_rounded,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Post announcement',
                icon: Icons.campaign_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go('/admin/announcements'),
              ),
              AppButton(
                label: 'Add material',
                icon: Icons.upload_file_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.go('/admin/materials'),
              ),
              if (isMainAdmin)
                AppButton(
                  label: 'Manage access',
                  icon: Icons.admin_panel_settings_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go('/admin/access'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // --------------------------------------------- announcements
          SectionHeader(
            title: 'Recent Announcements',
            icon: Icons.campaign_outlined,
            actionLabel: 'Manage',
            onAction: () => context.go('/admin/announcements'),
          ),
          announcements.when(
            loading: () => const SkeletonBox(height: 72, radius: 14),
            error: (error, _) => ErrorState(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(adminAnnouncementsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AppCard(
                  child: Text(
                    'No announcements yet. Post one to keep members informed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final a in items.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppCard(
                        onTap: () => context.go('/admin/announcements'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 20, color: AppColors.gold600),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                      ),
                                      StatusBadge(
                                        label: humanizeStatus(a.status),
                                        tone: badgeToneFor(a.status),
                                        small: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // ------------------------------------------------------- summary body

  Widget _summary(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMainAdmin,
  ) {
    if (data.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.query_stats_outlined,
          title: 'Analytics summary isn’t available',
          message:
              'The server returned no metrics just now. Try again, or open '
              'the Analytics page for the full picture.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(adminSummaryProvider(_period)),
        ),
      );
    }

    final totalMembers = pickNum(
      data,
      const ['totalMembers', 'membersTotal', 'totalUsers', 'members'],
    );
    final activeMembers = pickNum(
      data,
      const ['activeMembers', 'activeMemberCount', 'activeUsers'],
    );
    final reportsSubmitted = pickNum(
      data,
      const ['reportsSubmitted', 'submittedReports', 'totalReportsSubmitted'],
    );
    final reportsOutstanding = pickNum(
      data,
      const ['reportsOutstanding', 'outstandingReports', 'pendingReports'],
    );
    final awaitingReview = pickNum(
      data,
      const [
        'reportsAwaitingReview',
        'awaitingReview',
        'unreviewedReports',
        'reportsNeedingReview',
      ],
    );
    final completion = pickNum(
      data,
      const [
        'activityCompletionRate',
        'completionRate',
        'aggregateCompletion',
        'completionPct',
        'completionPercentage',
      ],
    );

    final prayerNested =
        data['prayerSessions'] is Map<String, dynamic>
            ? data['prayerSessions'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final prayerScheduled = pickNum(
          data,
          const ['prayerSessionsScheduled', 'sessionsScheduled'],
        ) ??
        pickNum(prayerNested, const ['scheduled', 'total']);
    final prayerCompleted = pickNum(
          data,
          const ['prayerSessionsCompleted', 'sessionsCompleted'],
        ) ??
        pickNum(prayerNested, const ['completed', 'done']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        metricGrid(context, [
          StatTile(
            label: 'Total members',
            value: statOrDash(totalMembers),
            icon: Icons.people_outline_rounded,
          ),
          StatTile(
            label: 'Active members',
            caption: _periodLabel.toLowerCase(),
            value: statOrDash(activeMembers),
            icon: Icons.verified_user_outlined,
            tone: StatTileTone.gold,
          ),
          StatTile(
            label: 'Reports submitted',
            value: statOrDash(reportsSubmitted),
            icon: Icons.task_alt_rounded,
            tone: StatTileTone.success,
          ),
          Semantics(
            button: true,
            label: 'Reports awaiting review. Opens Reports & Reviews.',
            child: InkWell(
              borderRadius: AppSpacing.cardRadius,
              onTap: () => context.go('/admin/reports'),
              child: StatTile(
                label: 'Awaiting review',
                caption: 'Tap to open reports',
                value: statOrDash(awaitingReview),
                icon: Icons.rate_review_outlined,
                tone: StatTileTone.info,
              ),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        metricGrid(context, [
          StatTile(
            label: 'Reports outstanding',
            caption: 'submitted vs outstanding below',
            value: statOrDash(reportsOutstanding),
            icon: Icons.pending_actions_outlined,
            tone: StatTileTone.danger,
          ),
          StatTile(
            label: 'Activity completion',
            caption: 'aggregate, self-reported',
            value: percentText(completion),
            icon: Icons.check_circle_outline_rounded,
            tone: StatTileTone.success,
          ),
          StatTile(
            label: 'Prayer sessions scheduled',
            value: statOrDash(prayerScheduled),
            icon: Icons.event_available_outlined,
          ),
          StatTile(
            label: 'Prayer sessions completed',
            value: statOrDash(prayerCompleted),
            icon: Icons.self_improvement_outlined,
            tone: StatTileTone.gold,
          ),
        ]),
        if (completion != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aggregate activity completion',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                ProgressBar(
                  value: percentValue(completion),
                  showLabel: true,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Self-reported activity records across all members.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],

        // ------------------------------------------- needs attention
        ..._attention(context, data),

        // ---------------------------------------------- recent sign-ups
        ..._recentSignUps(context, data),
      ],
    );
  }

  List<Widget> _attention(BuildContext context, Map<String, dynamic> data) {
    final pendingApprovals = pickNum(
      data,
      const [
        'pendingMemberApprovals',
        'pendingApprovals',
        'membersPendingApproval',
        'pendingMembers',
      ],
    );
    final suspendedAdmins = pickNum(
      data,
      const ['suspendedAdmins', 'adminsSuspended', 'suspendedAdministrators'],
    );
    final unresolvedReports = pickNum(
      data,
      const [
        'unresolvedPartnershipReports',
        'partnershipReportsUnresolved',
        'unresolvedPrayerReports',
        'unresolvedSafetyReports',
      ],
    );

    final rows = <(String, num, IconData, String)>[
      if (pendingApprovals != null)
        ('Pending member approvals', pendingApprovals,
            Icons.how_to_reg_outlined, '/admin/members'),
      if (suspendedAdmins != null)
        ('Suspended administrators', suspendedAdmins,
            Icons.admin_panel_settings_outlined, '/admin/access'),
      if (unresolvedReports != null)
        ('Unresolved partnership reports', unresolvedReports,
            Icons.health_and_safety_outlined, '/admin/prayer-partners'),
    ];
    if (rows.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.sm),
      TitledCard(
        title: 'Needs your attention',
        icon: Icons.priority_high_rounded,
        child: Column(
          children: [
            for (final row in rows)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.go(row.$4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(row.$3, size: 20, color: AppColors.navy700),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          row.$1,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      StatusBadge(
                        label: '${row.$2}',
                        tone: row.$2 > 0
                            ? AppBadgeTone.warning
                            : AppBadgeTone.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _recentSignUps(BuildContext context, Map<String, dynamic> data) {
    final signUps = pickMaps(
      data,
      const ['recentSignUps', 'recentSignups', 'recentMembers', 'newestMembers'],
    );
    if (signUps.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.sm),
      TitledCard(
        title: 'Recent sign-ups',
        icon: Icons.person_add_alt_outlined,
        child: Column(
          children: [
            for (final row in signUps.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: strOf(row['name'] ?? row['fullName']),
                      size: 34,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strOf(
                              row['name'] ??
                                  row['fullName'] ??
                                  row['user']?['name'],
                              'New member',
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Joined ${fmtDate(dateOf(row['createdAt'] ?? row['joinedAt'] ?? row['date']))}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: humanizeStatus(strOf(row['status'], 'PENDING')),
                      tone: badgeToneFor(strOf(row['status'], 'PENDING')),
                      small: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
