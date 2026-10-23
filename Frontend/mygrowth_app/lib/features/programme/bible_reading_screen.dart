import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/activity_models.dart';
import '../../core/models/programme_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../activities/record_activity_sheet.dart';
import '../programme/programme_providers.dart';

/// Bible Reading: the month's reading guidance plus weekly reading
/// assignments and a quick way to record today's reading.
class BibleReadingScreen extends ConsumerWidget {
  const BibleReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _BibleReadingView();
  }
}

class _BibleReadingView extends ConsumerStatefulWidget {
  const _BibleReadingView();

  @override
  ConsumerState<_BibleReadingView> createState() => _BibleReadingViewState();
}

class _BibleReadingViewState extends ConsumerState<_BibleReadingView> {
  DateTime _month = _monthOf(DateTime.now());

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(
      monthlyPlanProvider((year: _month.year, month: _month.month)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
            monthlyPlanProvider((year: _month.year, month: _month.month)));
        ref.invalidate(
            weeklyPlansProvider((year: _month.year, month: _month.month)));
        ref.invalidate(dailyChecklistProvider(_today));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Bible Reading', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            'Read along with the monthly guidance and keep your place with '
            'the weekly assignments.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------------- month switcher
          Row(
            children: [
              AppIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AppIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next month',
                onPressed: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------- month's reading guidance
          plan.when(
            loading: () => const SkeletonBox(height: 100, radius: 14),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(monthlyPlanProvider(
                  (year: _month.year, month: _month.month))),
            ),
            data: (plan) {
              final guidance = plan?.bibleReadingGuidance?.trim();
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_stories_outlined,
                            size: 18, color: AppColors.gold600),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Reading guidance — ${DateFormat('MMMM').format(_month)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      (guidance == null || guidance.isEmpty)
                          ? 'Reading guidance for this month hasn’t been '
                              'published yet. It will appear here as soon as '
                              'your ministry adds it.'
                          : guidance,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.55, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------- weekly reading assignments
          _WeeklyReadings(year: _month.year, month: _month.month),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------- today's reading
          const _RecordTodayReading(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Weekly reading assignments for the month (published by admins).
class _WeeklyReadings extends ConsumerWidget {
  const _WeeklyReadings({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(weeklyPlansProvider((year: year, month: month)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Weekly Reading Assignments',
          subtitle: DateFormat('MMMM yyyy').format(DateTime(year, month)),
          icon: Icons.view_week_outlined,
        ),
        weeks.when(
          loading: () => const CardListSkeleton(count: 2),
          error: (e, _) => ErrorState(
            error: e,
            compact: true,
            onRetry: () =>
                ref.invalidate(weeklyPlansProvider((year: year, month: month))),
          ),
          data: (list) {
            final withReading = [...list]
              ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
            if (withReading.isEmpty) {
              return AppCard(
                child: EmptyState(
                  icon: Icons.pending_actions_outlined,
                  title: 'Weekly assignments coming soon',
                  message:
                      'Weekly reading assignments are added by your ministry '
                      'administrators. Until they are published, please '
                      'follow the monthly reading guidance above.',
                ),
              );
            }
            return Column(
              children: [
                for (final week in withReading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _WeeklyReadingCard(week: week),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WeeklyReadingCard extends StatelessWidget {
  const _WeeklyReadingCard({required this.week});

  final WeeklyPlan week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = _formatDates(week.startDate, week.endDate);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.navy100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 19, color: AppColors.navy700),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Week ${week.weekNumber}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (dates != null)
                      StatusBadge(
                          label: dates, tone: AppBadgeTone.navy, small: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  (week.bibleReading == null ||
                          week.bibleReading!.trim().isEmpty)
                      ? 'Reading for this week hasn’t been published yet.'
                      : week.bibleReading!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDates(DateTime? start, DateTime? end) {
    if (start == null && end == null) return null;
    final fmt = DateFormat('d MMM');
    if (start != null && end != null && start.year == end.year) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    final full = DateFormat('d MMM yyyy');
    if (start != null && end != null) {
      return '${full.format(start)} – ${full.format(end)}';
    }
    return start != null
        ? 'From ${full.format(start)}'
        : 'Until ${full.format(end!)}';
  }
}

/// "Record today's reading" action, backed by today's checklist entry for
/// scripture reading / Proverbs.
class _RecordTodayReading extends ConsumerWidget {
  const _RecordTodayReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    final checklist = ref.watch(dailyChecklistProvider(date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Record Today’s Reading',
          subtitle: 'Self-reported',
          icon: Icons.fact_check_outlined,
        ),
        checklist.when(
          loading: () => const SkeletonBox(height: 96, radius: 14),
          error: (e, _) => ErrorState(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(dailyChecklistProvider(date)),
          ),
          data: (items) {
            PlannedActivity? reading;
            for (final item in items) {
              if (item.categoryKey == 'scripture_reading' ||
                  item.categoryKey == 'proverbs_reading') {
                reading = item;
                break;
              }
            }
            if (reading == null) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Nothing to record here today',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Today’s checklist doesn’t include a scripture or '
                      'Proverbs reading activity. Reading activities are '
                      'published with your daily plan — you can record them '
                      'from the Daily Diet checklist.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => context.go('/diet'),
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('Open Daily Diet'),
                    ),
                  ],
                ),
              );
            }
            final alreadyRecorded = reading.record != null;
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.gold100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book,
                        size: 19, color: AppColors.gold600),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reading.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (reading.isCompleted)
                          const StatusBadge(
                            label: 'Recorded',
                            tone: AppBadgeTone.success,
                            small: true,
                            icon: Icons.check_circle_rounded,
                          )
                        else if (alreadyRecorded)
                          StatusBadge(
                            label: humanizeStatus(reading.status),
                            tone: badgeToneFor(reading.status),
                            small: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: alreadyRecorded ? 'Update' : 'Record today’s reading',
                    icon: Icons.fact_check_outlined,
                    onPressed: () =>
                        showRecordActivitySheet(context, activity: reading!),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
