import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/activity_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../programme/programme_providers.dart';
import 'record_activity_sheet.dart';

/// Daily Diet: the member's checklist for a given day with self-reported
/// activity records.
class DailyDietScreen extends ConsumerWidget {
  const DailyDietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _DailyDietView();
  }
}

class _DailyDietView extends ConsumerStatefulWidget {
  const _DailyDietView();

  @override
  ConsumerState<_DailyDietView> createState() => _DailyDietViewState();
}

class _DailyDietViewState extends ConsumerState<_DailyDietView> {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _selected = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final programme = ref.watch(currentProgrammeProvider);
    final today = _dateOnly(DateTime.now());
    final programmeStart = programme.maybeWhen(
      data: (p) => p?.startDate == null ? null : _dateOnly(p!.startDate!),
      orElse: () => null,
    );
    final minDate = programmeStart == null || programmeStart.isAfter(today)
        ? today.subtract(const Duration(days: 45))
        : programmeStart;
    if (_selected.isBefore(minDate)) _selected = minDate;
    if (_selected.isAfter(today)) _selected = today;

    final checklist = ref.watch(dailyChecklistProvider(_selected));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyChecklistProvider(_selected));
        ref.invalidate(currentProgrammeProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          // ------------------------------------------------- date strip
          _DateStrip(
            selected: _selected,
            minDate: minDate,
            today: today,
            onSelect: (d) => setState(() => _selected = d),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---------------------------------------------- day checklist
          checklist.when(
            loading: () => const CardListSkeleton(count: 4),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(dailyChecklistProvider(_selected)),
            ),
            data: (items) {
              final completed = items.where((a) => a.isCompleted).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(
                              label: '$completed of ${items.length} recorded',
                              tone: completed == items.length && items.isNotEmpty
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
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (items.isEmpty)
                    AppCard(
                      child: EmptyState(
                        icon: Icons.checklist_rounded,
                        title: 'Nothing scheduled for this day',
                        message:
                            'Plans are published by your ministry. Check My '
                            'Growth Plan for monthly guidance in the meantime.',
                      ),
                    )
                  else ...[
                    _ChecklistGroup(
                      title: 'Remaining',
                      icon: Icons.radio_button_unchecked,
                      items: items.where((a) => !a.isCompleted).toList(),
                    ),
                    _ChecklistGroup(
                      title: 'Completed',
                      icon: Icons.check_circle_outline,
                      items: items.where((a) => a.isCompleted).toList(),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Note: activities come from the published programme and your own '
            'records.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// A horizontal 7-day strip with today towards the right (today is centred
/// while browsing) and future dates disabled.
class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.minDate,
    required this.today,
    required this.onSelect,
  });

  final DateTime selected;
  final DateTime minDate;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    var start = selected.subtract(const Duration(days: 3));
    if (start.isBefore(minDate)) start = minDate;
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DayChip(
                day: day,
                selected: day == selected,
                enabled: !day.isAfter(today) && !day.isBefore(minDate),
                onTap: () => onSelect(day),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? Colors.white
        : enabled
            ? AppColors.ink
            : AppColors.inkMuted;
    return Semantics(
      selected: selected,
      button: enabled,
      label: DateFormat('EEEE, d MMMM yyyy').format(day),
      child: InkWell(
        borderRadius: AppSpacing.controlRadius,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryAction : Colors.transparent,
            borderRadius: AppSpacing.controlRadius,
            border: Border.all(
              color: selected ? AppColors.primaryAction : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.E().format(day),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white70 : AppColors.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistGroup extends StatelessWidget {
  const _ChecklistGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<PlannedActivity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, icon: icon, subtitle: '${items.length}'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _ChecklistTile(activity: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends ConsumerWidget {
  const _ChecklistTile({required this.activity});

  final PlannedActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = activity.status;
    final tint = AppColors
        .categoryTints[activity.categoryKey.hashCode.abs() %
            AppColors.categoryTints.length];
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showRecordActivitySheet(context, activity: activity),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _categoryIcon(activity.categoryKey),
                size: 19,
                color: AppColors.navy700,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: activity.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: activity.isCompleted
                          ? AppColors.inkSecondary
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        activity.categoryLabel ??
                            humanizeStatus(activity.categoryKey),
                        style: theme.textTheme.labelSmall,
                      ),
                      if (activity.targetDuration != null)
                        Text(
                          '• ${activity.targetDuration!}',
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            StatusBadge(
              label: humanizeStatus(status),
              tone: badgeToneFor(status),
              small: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps an activity category key to a Material icon.
IconData _categoryIcon(String categoryKey) {
  switch (categoryKey) {
    case 'prayer':
      return Icons.self_improvement;
    case 'scripture_reading':
      return Icons.menu_book;
    case 'bible_study':
      return Icons.history_edu;
    case 'literature_reading':
      return Icons.auto_stories;
    case 'proverbs_reading':
      return Icons.menu_book;
    case 'fasting_and_prayer':
      return Icons.wb_sunny;
    case 'prayer_and_affirmations':
      return Icons.wb_twilight;
    case 'confessions_declarations':
      return Icons.record_voice_over;
    case 'audio_message':
      return Icons.headphones;
    case 'prayer_partner_session':
      return Icons.handshake;
    case 'personal_reflection':
      return Icons.edit_note;
    default:
      return Icons.star;
  }
}
