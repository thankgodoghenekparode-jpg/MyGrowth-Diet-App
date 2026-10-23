import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';
import '../../core/models/programme_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';

/// Fasting Tracker: the month's fasting guidance plus Wednesday & Saturday
/// fasting days with self-reported records.
class FastingScreen extends ConsumerWidget {
  const FastingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _FastingView();
  }
}

class _FastingView extends ConsumerStatefulWidget {
  const _FastingView();

  @override
  ConsumerState<_FastingView> createState() => _FastingViewState();
}

class _FastingViewState extends ConsumerState<_FastingView> {
  DateTime _month = _monthOf(DateTime.now());

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

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
    final fastingDays = _fastingDaysIn(_month);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthlyPlanProvider(
            (year: _month.year, month: _month.month)));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
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

          // --------------------------------------- month's guidance
          plan.when(
            loading: () => const SkeletonBox(height: 100, radius: 14),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(monthlyPlanProvider(
                  (year: _month.year, month: _month.month))),
            ),
            data: (plan) {
              final guidance = plan?.fastingGuidance?.trim();
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined,
                            size: 18, color: AppColors.gold600),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'This month’s fasting guidance',
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
                          ? 'Published guidance will appear here. In the '
                              'meantime, the general rhythm shown on each '
                              'fasting day below still applies.'
                          : guidance,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: AppColors.inkSecondary,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // --------------------------------------------- fasting days
          SectionHeader(
            title: 'Fasting days',
            subtitle: 'Wednesdays & Saturdays in ${DateFormat('MMMM').format(_month)}',
            icon: Icons.calendar_month_outlined,
          ),
          if (fastingDays.isEmpty)
            AppCard(
              child: Text(
                'No Wednesdays or Saturdays fall in this month.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (final day in fastingDays) ...[
              _FastingDayCard(
                date: day,
                guidanceText: _dayGuidance(plan.value),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: AppColors.navy50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline,
                    size: 18, color: AppColors.navy600),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Fasting records are self-reported and personal — a gift '
                    'between you and God. Days without a record are completely '
                    'okay.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSecondary,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  String _dayGuidance(MonthlyPlan? plan) {
    final guidance = plan?.fastingGuidance?.trim();
    if (guidance != null && guidance.isNotEmpty) return guidance;
    return '6:00 a.m.–2:00 p.m. minimum';
  }
}

/// Every Wednesday (3) and Saturday (6) of the given month, computed with
/// plain DateTime arithmetic (a month can hold 4 or 5 of each).
List<DateTime> _fastingDaysIn(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final next = DateTime(month.year, month.month + 1, 1);
  final days = <DateTime>[];
  for (var d = first; d.isBefore(next); d = d.add(const Duration(days: 1))) {
    if (d.weekday == DateTime.wednesday || d.weekday == DateTime.saturday) {
      days.add(d);
    }
  }
  return days;
}

/// A single fasting day with self-reported "I fasted" / challenge actions.
class _FastingDayCard extends ConsumerStatefulWidget {
  const _FastingDayCard({required this.date, required this.guidanceText});

  final DateTime date;
  final String guidanceText;

  @override
  ConsumerState<_FastingDayCard> createState() => _FastingDayCardState();
}

class _FastingDayCardState extends ConsumerState<_FastingDayCard> {
  bool _busy = false;

  DateTime get _date => widget.date;

  Future<void> _recordFasted() async {
    final activity = _fastingActivity(ref);
    if (activity == null) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(_date);
    try {
      final existing = activity.record;
      if (existing == null) {
        await client.post('/me/activity-records', body: {
          'activityId': activity.id,
          'date': dateKey,
          'status': 'COMPLETED',
        });
      } else {
        await client.patch('/me/activity-records/${existing.id}', body: {
          'status': 'COMPLETED',
        });
      }
      if (!mounted) return;
      ref.invalidate(dailyChecklistProvider(_date));
      Toast.success(context, 'Recorded. Thank you for your faithfulness!');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordChallenge() async {
    final activity = _fastingActivity(ref);
    if (activity == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom:
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
        ),
        child: _ChallengeNoteSheet(
          activity: activity,
          date: _date,
          onSaved: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(dailyChecklistProvider(_date));
    }
  }

  PlannedActivity? _fastingActivity(WidgetRef ref) {
    final items = ref
        .read(dailyChecklistProvider(_date))
        .value;
    if (items == null) return null;
    for (final item in items) {
      if (item.categoryKey == 'fasting_and_prayer') return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklist = ref.watch(dailyChecklistProvider(_date));
    final today = DateTime.now();
    final isFuture = DateTime(_date.year, _date.month, _date.day)
        .isAfter(DateTime(today.year, today.month, today.day));
    final isToday = _date.year == today.year &&
        _date.month == today.month &&
        _date.day == today.day;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMMM').format(_date) +
                      (isToday ? ' (today)' : ''),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isFuture)
                const StatusBadge(label: 'Upcoming', tone: AppBadgeTone.info),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            widget.guidanceText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.gold600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          checklist.when(
            loading: () => const SkeletonBox(height: 28, radius: 8),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(dailyChecklistProvider(_date)),
            ),
            data: (items) {
              PlannedActivity? activity;
              for (final item in items) {
                if (item.categoryKey == 'fasting_and_prayer') {
                  activity = item;
                  break;
                }
              }
              if (activity == null) {
                return Text(
                  'No fasting activity is published for this day, so there '
                  'is nothing to record.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                );
              }
              final recorded = activity.record?.status == 'COMPLETED';
              if (isFuture) {
                return Text(
                  'This day hasn’t arrived yet — you can record it when the '
                  'time comes.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                );
              }
              return Row(
                children: [
                  StatusBadge(
                    label: recorded ? 'Recorded' : 'Not recorded',
                    tone: recorded
                        ? AppBadgeTone.success
                        : AppBadgeTone.neutral,
                    icon: recorded
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline,
                  ),
                  const Spacer(),
                  if (!recorded)
                    TextButton(
                      onPressed: _busy ? null : _recordChallenge,
                      child: const Text('Record a challenge'),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  AppButton(
                    label: recorded ? 'Update' : 'I fasted',
                    icon: Icons.favorite_outline,
                    variant: recorded
                        ? AppButtonVariant.outlined
                        : AppButtonVariant.filled,
                    busy: _busy,
                    onPressed: () => _recordFasted(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small sheet to note a challenge faced while fasting.
class _ChallengeNoteSheet extends ConsumerStatefulWidget {
  const _ChallengeNoteSheet({
    required this.activity,
    required this.date,
    required this.onSaved,
  });

  final PlannedActivity activity;
  final DateTime date;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ChallengeNoteSheet> createState() =>
      _ChallengeNoteSheetState();
}

class _ChallengeNoteSheetState extends ConsumerState<_ChallengeNoteSheet> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _note.text = widget.activity.record?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _note.text.trim();
    if (note.isEmpty) {
      Toast.info(context, 'A short note helps you look back with grace.');
      return;
    }
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    try {
      final existing = widget.activity.record;
      if (existing == null) {
        await client.post('/me/activity-records', body: {
          'activityId': widget.activity.id,
          'date': dateKey,
          'status': 'IN_PROGRESS',
          'note': note,
        });
      } else {
        await client.patch('/me/activity-records/${existing.id}', body: {
          'note': note,
        });
      }
      if (!mounted) return;
      ref.invalidate(dailyChecklistProvider(widget.date));
      widget.onSaved();
      Toast.success(context, 'Challenge note saved.');
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
        Text('Record a challenge',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Fasting isn’t always easy. A short note helps you look back with '
          'grace — no judgement, ever.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'What made fasting difficult?',
          controller: _note,
          maxLines: 3,
          hint: 'e.g. A busy schedule made the afternoon hard',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Save note',
          busy: _busy,
          expand: true,
          onPressed: _save,
        ),
      ],
    );
  }
}
