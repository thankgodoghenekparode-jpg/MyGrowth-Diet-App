import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/daily_diet_models.dart';
import '../../core/models/programme_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';
import 'daily_diet_providers.dart';
import 'daily_diet_shared.dart';

/// Daily Diet — the member's hub for a day of the devotional structure.
///
/// The administrator decides which sections exist and how each one behaves;
/// the member picks a date, reads what was published for that day and ticks
/// each section off.
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
  DateTime _selected = dailyDietDateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final today = dailyDietDateOnly(DateTime.now());
    final dateISO = dailyDietDateISO(_selected);
    final bundleAsync = ref.watch(dailyDietProvider(dateISO));
    final programmeAsync = ref.watch(currentProgrammeProvider);

    final bounds = _DateBounds.resolve(programmeAsync, today);
    if (_selected.isBefore(bounds.min)) _selected = bounds.min;
    if (_selected.isAfter(bounds.max)) _selected = bounds.max;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyDietProvider(dateISO));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          _DayHeader(date: _selected, today: today),
          const SizedBox(height: AppSpacing.md),
          _DateStrip(
            selected: _selected,
            today: today,
            minDate: bounds.min,
            maxDate: bounds.max,
            onSelect: (d) => setState(() => _selected = d),
            onPickDate: () => _pickDate(context, bounds),
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncValueView<DailyDietBundle>(
            value: bundleAsync,
            onRetry: () => ref.invalidate(dailyDietProvider(dateISO)),
            data: (bundle) => _DayContent(bundle: bundle, dateISO: dateISO),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, _DateBounds bounds) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: bounds.min,
      lastDate: bounds.max,
      helpText: 'Choose a day',
    );
    if (picked != null && mounted) {
      setState(() => _selected = dailyDietDateOnly(picked));
    }
  }
}

/// The window of dates the member may browse.
class _DateBounds {
  const _DateBounds({required this.min, required this.max});

  final DateTime min;
  final DateTime max;

  /// The programme window when it is known, widened so the member can still
  /// look back at recent days before the programme started.
  factory _DateBounds.resolve(AsyncValue<AnnualProgramme?> programme, DateTime today) {
    DateTime min = today.subtract(const Duration(days: 45));
    DateTime max = today.add(const Duration(days: 365));

    final value = programme.value;
    final start = value?.startDate;
    final end = value?.endDate;
    if (start != null && start.isBefore(min)) min = dailyDietDateOnly(start);
    if (end != null && end.isAfter(max)) max = dailyDietDateOnly(end);
    if (max.isBefore(today)) max = today;

    return _DateBounds(min: min, max: max);
  }
}

/// The selected day, spelled out.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.today});

  final DateTime date;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = date == today;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(date),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMMM yyyy').format(date),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (isToday)
          const StatusBadge(
            label: 'Today',
            tone: AppBadgeTone.success,
            icon: Icons.today_rounded,
          )
        else
          StatusBadge(
            label: DateFormat('EEE').format(date),
            tone: AppBadgeTone.neutral,
          ),
      ],
    );
  }
}

/// A horizontal 7-day strip plus a full calendar picker.
class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.selected,
    required this.today,
    required this.minDate,
    required this.maxDate,
    required this.onSelect,
    required this.onPickDate,
  });

  final DateTime selected;
  final DateTime today;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    var start = selected.subtract(const Duration(days: 3));
    if (start.isBefore(minDate)) start = minDate;
    if (start.add(const Duration(days: 6)).isAfter(maxDate)) {
      start = maxDate.subtract(const Duration(days: 6));
      if (start.isBefore(minDate)) start = minDate;
    }
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayChip(
                      day: day,
                      selected: day == selected,
                      enabled: !day.isBefore(minDate) && !day.isAfter(maxDate),
                      onTap: () => onSelect(day),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Tooltip(
          message: 'Pick a date',
          child: InkWell(
            borderRadius: AppSpacing.controlRadius,
            onTap: onPickDate,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppSpacing.controlRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: AppColors.iconAccent,
              ),
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
        ? AppColors.onPrimary
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
                  color: selected ? AppColors.onPrimary : AppColors.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: theme.textTheme.titleSmall?.copyWith(
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

/// Everything published for the selected day.
class _DayContent extends StatelessWidget {
  const _DayContent({required this.bundle, required this.dateISO});

  final DailyDietBundle bundle;
  final String dateISO;

  @override
  Widget build(BuildContext context) {
    if (!bundle.dateInProgramme || bundle.sections.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No Daily Diet for this day',
          message:
              'Your ministry publishes the daily devotional structure. Check '
              'another date, or come back once this day is prepared.',
        ),
      );
    }

    final sections = bundle.sections;
    final completed = bundle.progress.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressCard(bundle: bundle),
        if (bundle.monthlyPlan?.theme != null ||
            bundle.monthlyPlan?.prayerFocus != null) ...[
          const SizedBox(height: AppSpacing.md),
          _MonthlyCard(plan: bundle.monthlyPlan!),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Your daily diet',
          subtitle: completed == sections.length
              ? 'All sections completed'
              : '$completed of ${sections.length} completed',
          icon: Icons.checklist_rounded,
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _SectionTile(section: sections[i], dateISO: dateISO),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Open a section to read what was published for this day and mark it '
          'done.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// How much of the day is done.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.bundle});

  final DailyDietBundle bundle;

  @override
  Widget build(BuildContext context) {
    final progress = bundle.progress;
    final done = progress.total > 0 && progress.completed == progress.total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: '${progress.completed} of ${progress.total} done',
                tone: done ? AppBadgeTone.success : AppBadgeTone.navy,
                icon: done ? Icons.check_circle_rounded : Icons.timelapse_rounded,
              ),
              const Spacer(),
              if (bundle.programme != null)
                Flexible(
                  child: Text(
                    bundle.programme!.title,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ProgressBar(value: progress.ratio),
        ],
      ),
    );
  }
}

/// The month's theme and prayer focus.
class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.plan});

  final DailyDietMonthlyPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month focus',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0.6,
            ),
          ),
          if (plan.theme != null) ...[
            const SizedBox(height: 4),
            Text(
              plan.theme!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brandText,
              ),
            ),
          ],
          if (plan.prayerFocus != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(plan.prayerFocus!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// One section row: icon, label, what was published and the tick-off.
class _SectionTile extends ConsumerStatefulWidget {
  const _SectionTile({required this.section, required this.dateISO});

  final DailyDietSection section;
  final String dateISO;

  @override
  ConsumerState<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends ConsumerState<_SectionTile> {
  bool _busy = false;

  DailyDietSection get section => widget.section;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final writer = ref.read(dailyDietCompletionWriterProvider);
    try {
      final completion = section.completion;
      if (section.isCompleted) {
        if (completion != null) {
          await writer.clear(completionId: completion.id, date: widget.dateISO);
        } else {
          await writer.save(
            sectionId: section.id,
            date: widget.dateISO,
            status: DailyDietStatus.notStarted,
          );
        }
        if (mounted) {
          Toast.show(context, message: 'Marked as not done', tone: ToastTone.info);
        }
      } else {
        await writer.save(
          sectionId: section.id,
          date: widget.dateISO,
          status: DailyDietStatus.completed,
        );
        if (mounted) {
          Toast.show(context, message: 'Done. Well done!', tone: ToastTone.success);
        }
      }
    } catch (error) {
      if (mounted) {
        Toast.show(
          context,
          message: _messageFor(error),
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() {
    context.push(
      '/daily-diet/section/${section.id}?date=${widget.dateISO}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = section.isCompleted;
    final tint = dailyDietTint(section.key);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _open,
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
                dailyDietSectionIcon(section),
                size: 19,
                color: AppColors.iconAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.inkSecondary : AppColors.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(
                        label: section.behaviour.label,
                        tone: AppBadgeTone.neutral,
                        small: true,
                      ),
                      if (section.content != null)
                        StatusBadge(
                          label: section.content!.scope.label,
                          tone: AppBadgeTone.info,
                          small: true,
                        ),
                      if (section.completion?.actualDurationMinutes != null)
                        StatusBadge(
                          label:
                              '${section.completion!.actualDurationMinutes} min',
                          tone: AppBadgeTone.navy,
                          small: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _TickButton(busy: _busy, done: done, onTap: _toggle),
          ],
        ),
      ),
    );
  }
}

/// The circular tick-off control.
class _TickButton extends StatelessWidget {
  const _TickButton({
    required this.busy,
    required this.done,
    required this.onTap,
  });

  final bool busy;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Completed — tap to undo' : 'Mark as completed',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.success : Colors.transparent,
            border: Border.all(
              color: done ? AppColors.success : AppColors.borderStrong,
              width: 1.6,
            ),
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  done ? Icons.check_rounded : Icons.circle_outlined,
                  size: 19,
                  color: done ? Colors.white : AppColors.inkMuted,
                ),
        ),
      ),
    );
  }
}

/// Turns an API failure into a short, human message.
String _messageFor(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
