import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/image_carousel.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';

/// Day-precision "now" used as a provider family key.
///
/// Passing `DateTime.now()` directly would mint a new key on every rebuild,
/// re-fetching the daily checklist in an endless loop.
DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

const memberHomeSlides = <CarouselSlide>[
  CarouselSlide(
    image: 'assets/images/bible.jpg',
    title: 'Feed on the Word',
    caption: 'Follow the reading plan and let Scripture shape your week.',
    icon: Icons.auto_stories_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/diet.jpg',
    title: 'Today’s Growth Diet',
    caption: 'Your daily activities, ready to record honestly.',
    icon: Icons.today_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/prayer.jpg',
    title: 'A Life of Prayer',
    caption: 'Meet God in the quiet place, then pray with a partner.',
    icon: Icons.self_improvement_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/plan.jpg',
    title: 'Grow with the Plan',
    caption: 'Monthly and weekly guidance for your journey.',
    icon: Icons.menu_book_outlined,
  ),
  CarouselSlide(
    image: 'assets/images/materials.jpg',
    title: 'Study Materials',
    caption: 'Resources to equip and strengthen your faith.',
    icon: Icons.local_library_outlined,
  ),
];

/// Member dashboard: today at a glance, plan highlights, progress and news.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final programme = ref.watch(currentProgrammeProvider);
    final checklist = ref.watch(dailyChecklistProvider(_today()));
    final announcements = ref.watch(announcementsProvider);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentProgrammeProvider);
        ref.invalidate(dailyChecklistProvider(_today()));
        ref.invalidate(announcementsProvider);
        ref.invalidate(notificationsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          // ------------------------------------------------ welcome + date
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${firstName.isEmpty ? 'friend' : firstName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM').format(now),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _NotificationBell(unread: ref.watch(unreadNotificationCountProvider)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------------- hero carousel
          //
          // Placeholder picture strip — see [memberHomeSlides] to swap images.
          ImageCarousel(
            slides: memberHomeSlides,
            height: Breakpoints.isCompact(context) ? 190 : 240,
            onTapSlide: (_) => context.go('/plan'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------------------ prayer focus
          programme.when(
            loading: () => const SkeletonBox(height: 150, radius: 14),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(currentProgrammeProvider),
            ),
            data: (programme) {
              if (programme == null) {
                return const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No published programme yet',
                  message:
                      'Your ministry administrators haven’t published a '
                      'programme year. It will appear here as soon as it is '
                      'ready.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VerseCard(
                    tone: VerseTone.navy,
                    label: '${programme.year} Prayer Focus',
                    text: programme.prayerFocus ?? '',
                    caption: programme.title,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  VerseCard(
                    tone: VerseTone.gold,
                    label: 'Daily Affirmation',
                    text: programme.dailyAffirmation ?? '',
                    icon: Icons.wb_sunny_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ------------------------------------------- today's activities
          SectionHeader(
            title: 'Today’s Activities',
            subtitle: DateFormat('EEEE, d MMMM yyyy').format(now),
            icon: Icons.today_rounded,
            actionLabel: 'Open',
            onAction: () => context.go('/diet'),
          ),
          checklist.when(
            loading: () => const CardListSkeleton(count: 3),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(dailyChecklistProvider(_today())),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'Nothing scheduled today',
                    message:
                        'Plans are published by your ministry. Check My '
                        'Growth Plan for monthly guidance in the meantime.',
                    actionLabel: 'View plan',
                    onAction: () => context.go('/plan'),
                  ),
                );
              }
              final completed =
                  items.where((a) => a.isCompleted).length;
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          label: '$completed of ${items.length} recorded',
                          tone: completed == items.length
                              ? AppBadgeTone.success
                              : AppBadgeTone.navy,
                        ),
                        const Spacer(),
                        Text(
                          'Self-reported',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ProgressBar(
                      value: items.isEmpty ? 0 : completed / items.length,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final activity in items.take(4))
                      _ActivityTile(activity: activity),
                    if (items.length > 4)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go('/diet'),
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(
                              'See ${items.length - 4} more activities'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ------------------------------------------------- tools bar (Materials only)
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: Breakpoints.isCompact(context)
                    ? 0
                    : 0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.cardRadius,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.go('/materials'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Icon(Icons.local_library_outlined,
                                color: AppColors.iconAccent),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Materials',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ------------------------------------------- monthly confession
          //
          // Use the resolved programme's year, not the calendar year: the
          // published programme may be for a different year (e.g. 2027 while
          // the clock still reads 2026), and requesting a non-existent year
          // returns 404.
          _MonthlyConfession(
            month: now.month,
            year: programme.asData?.value?.year ?? now.year,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ---------------------------------------------- announcements
          SectionHeader(
            title: 'Announcements',
            icon: Icons.campaign_outlined,
            actionLabel: 'All',
            onAction: () => context.go('/announcements'),
          ),
          announcements.when(
            loading: () => const SkeletonBox(height: 72, radius: 14),
            error: (e, _) => ErrorState(error: e, compact: true),
            data: (items) {
              if (items.isEmpty) {
                return AppCard(
                  child: Text(
                    'No announcements right now. Check back soon.',
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
                        onTap: () => context.go('/announcements'),
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
                                  Text(a.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
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
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      backgroundColor: AppColors.danger,
      child: AppIconButton(
        icon: Icons.notifications_outlined,
        filled: true,
        tooltip: 'Notifications',
        onPressed: () => context.go('/notifications'),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.activity});

  final PlannedActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showRecordSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              activity.isCompleted
                  ? Icons.check_circle_rounded
                  : activity.isInProgress
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 22,
              color: activity.isCompleted
                  ? AppColors.success
                  : activity.isInProgress
                      ? AppColors.gold500
                      : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          decoration: activity.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: activity.isCompleted
                              ? AppColors.inkSecondary
                              : AppColors.ink,
                        ),
                  ),
                  if (activity.categoryLabel != null)
                    Text(
                      activity.categoryLabel!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            if (activity.targetDuration != null)
              Text(
                activity.targetDuration!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }

  void _showRecordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: _RecordActivitySheet(activity: activity),
      ),
    );
  }
}

/// Bottom sheet to record completion / progress / a missed activity.
class _RecordActivitySheet extends ConsumerStatefulWidget {
  const _RecordActivitySheet({required this.activity});

  final PlannedActivity activity;

  @override
  ConsumerState<_RecordActivitySheet> createState() =>
      _RecordActivitySheetState();
}

class _RecordActivitySheetState extends ConsumerState<_RecordActivitySheet> {
  late String _status = widget.activity.record?.status ?? 'COMPLETED';
  final _note = TextEditingController();
  final _duration = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _note.text = widget.activity.record?.note ?? '';
    _duration.text = widget.activity.record?.actualDuration ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final date = DateFormat('yyyy-MM-dd')
        .format(widget.activity.date ?? DateTime.now());
    final body = {
      'activityId': widget.activity.id,
      'date': date,
      'status': _status,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      if (_duration.text.trim().isNotEmpty)
        'actualDuration': _duration.text.trim(),
    };
    try {
      final existing = widget.activity.record;
      if (existing == null) {
        await client.post('/me/activity-records', body: body);
      } else {
        await client.patch('/me/activity-records/${existing.id}', body: {
          'status': _status,
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
          if (_duration.text.trim().isNotEmpty)
            'actualDuration': _duration.text.trim(),
        });
      }
      if (!mounted) return;
      ref.invalidate(dailyChecklistProvider(_today()));
      Navigator.of(context).pop();
      final message = switch (_status) {
        'COMPLETED' => 'Recorded. Well done on keeping your diet plan!',
        'SKIPPED' =>
          'Saved. It’s okay — consistency grows one day at a time.',
        'IN_PROGRESS' => 'Saved. You can update this later today.',
        _ => 'Saved.',
      };
      Toast.success(context, message);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.activity.title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        if (widget.activity.description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.activity.description!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('How did it go?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in const [
              ('COMPLETED', 'Completed', Icons.check_circle_outline),
              ('IN_PROGRESS', 'In progress', Icons.timelapse),
              ('SKIPPED', 'Missed today', Icons.pause_circle_outline),
            ])
              ChoiceChip(
                label: Text(option.$2),
                avatar: Icon(option.$3, size: 16),
                selected: _status == option.$1,
                onSelected: (_) => setState(() => _status = option.$1),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Minutes spent (optional)',
          controller: _duration,
          keyboardType: TextInputType.number,
          hint: 'e.g. 20',
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Private note (optional)',
          controller: _note,
          maxLines: 3,
          hint: 'Anything you’d like to remember about this activity',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Save',
          busy: _busy,
          expand: true,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Activity records are self-reported. Be honest and gracious with '
          'yourself.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

// _QuickAccessGrid removed - the home screen now owns the quick actions.

class _MonthlyConfession extends ConsumerWidget {
  const _MonthlyConfession({required this.month, required this.year});

  final int month;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(monthlyPlanProvider((year: year, month: month)));
    return plan.when(
      loading: () => const SkeletonBox(height: 120, radius: 14),
      error: (e, _) => ErrorState(error: e, compact: true),
      data: (plan) {
        if (plan == null || (plan.confession?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '${DateFormat('MMMM').format(DateTime(year, month))} Focus',
              subtitle: plan.theme,
              icon: Icons.auto_awesome_outlined,
              actionLabel: 'Details',
              onAction: () => context.go('/plan'),
            ),
            VerseCard(
              tone: VerseTone.light,
              label: 'Monthly Confession',
              text: plan.confession!,
            ),
          ],
        );
      },
    );
  }
}
