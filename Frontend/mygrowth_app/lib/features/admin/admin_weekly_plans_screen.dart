import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
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
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Weekly & daily plan authoring for a programme month.
class AdminWeeklyPlansScreen extends ConsumerWidget {
  const AdminWeeklyPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _WeeklyPlansBody();
  }
}

const List<String> _weekCategories = [
  'prayer',
  'scripture_reading',
  'bible_study',
  'literature_reading',
  'proverbs_reading',
  'fasting_and_prayer',
  'prayer_and_affirmations',
  'confessions_declarations',
  'audio_message',
  'prayer_partner_session',
  'personal_reflection',
  'custom',
];

class _WeeklyPlansBody extends ConsumerStatefulWidget {
  const _WeeklyPlansBody();

  @override
  ConsumerState<_WeeklyPlansBody> createState() => _WeeklyPlansBodyState();
}

class _WeeklyPlansBodyState extends ConsumerState<_WeeklyPlansBody> {
  final DateTime _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month;

  @override
  Widget build(BuildContext context) {
    final key = (year: _year, month: _month);
    final weekly = ref.watch(adminWeeklyPlansProvider(key));
    final daily = ref.watch(adminDailyActivitiesProvider(key));
    final programmes = ref.watch(adminProgrammesProvider);
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminWeeklyPlansProvider);
        ref.invalidate(adminDailyActivitiesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Weekly & Daily Plans',
            subtitle: 'Assign each week and add dated daily activities',
            icon: Icons.view_week_outlined,
          ),

          // ------------------------------------------------- selectors
          AppCard(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(
                  width: compact ? double.infinity : 200,
                  child: AppDropdown<int>(
                    label: 'Programme year',
                    value: _year,
                    items: [
                      for (final year in _yearOptions())
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _year = value);
                    },
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : 200,
                  child: AppDropdown<int>(
                    label: 'Month',
                    value: _month,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            DateFormat('MMMM').format(DateTime(_year, m)),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _month = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          programmes.when(
            loading: () => const CardListSkeleton(count: 2),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminProgrammesProvider),
            ),
            data: (list) {
              final programme = _programmeFor(list);
              if (programme == null) {
                return AdminBanner(
                  text:
                      'No annual programme exists for $_year yet. Create the '
                      'programme before adding weekly and daily plans.',
                  tone: AdminBannerTone.warning,
                  icon: Icons.warning_amber_rounded,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeading(
                    title: 'Weekly assignments',
                    subtitle:
                        'Week $monthLabel($_month) assigned for ${programme.title.isEmpty ? programme.year : programme.title}',
                    actionLabel: 'Add week',
                    onAction: () => _openWeeklySheet(programme.id, null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  weekly.when(
                    loading: () => const CardListSkeleton(count: 2),
                    error: (error, _) => ErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(adminWeeklyPlansProvider),
                    ),
                    data: (plans) {
                      if (plans.isEmpty) {
                        return AppCard(
                          child: EmptyState(
                            icon: Icons.view_week_outlined,
                            title: 'No weekly assignments yet',
                            message:
                                'No weekly assignments yet. Add them as the '
                                'ministry finalises the schedule — members will '
                                'see monthly guidance until then.',
                            actionLabel: 'Add week',
                            onAction: () => _openWeeklySheet(programme.id, null),
                          ),
                        );
                      }
                      final sorted = [...plans]
                        ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
                      return Column(
                        children: [
                          for (final plan in sorted)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _WeeklyPlanCard(
                                plan: plan,
                                onEdit: () =>
                                    _openWeeklySheet(programme.id, plan),
                                onChanged: () {
                                  ref.invalidate(adminWeeklyPlansProvider);
                                  ref.invalidate(adminDailyActivitiesProvider);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // -------------------------------------- daily activities
                  _SectionHeading(
                    title: 'Daily activities',
                    subtitle:
                        'Dated activities for ${monthName(_month)} $_year',
                    actionLabel: 'Add activity',
                    onAction: () => _openDailySheet(programme.id, null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  daily.when(
                    loading: () => const CardListSkeleton(count: 3),
                    error: (error, _) => ErrorState(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(adminDailyActivitiesProvider),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return AppCard(
                          child: EmptyState(
                            icon: Icons.checklist_outlined,
                            title: 'No daily activities for this month',
                            message:
                                'Add dated activities (prayer, reading, '
                                'fasting…) so members see a clear daily '
                                'checklist for ${monthName(_month)}.',
                            actionLabel: 'Add activity',
                            onAction: () => _openDailySheet(programme.id, null),
                          ),
                        );
                      }
                      final sorted = [...items]..sort((a, b) {
                          final da = a.date;
                          final db = b.date;
                          if (da == null && db == null) return 0;
                          if (da == null) return 1;
                          if (db == null) return -1;
                          return da.compareTo(db);
                        });
                      return Column(
                        children: [
                          for (final activity in sorted)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _DailyActivityCard(
                                activity: activity,
                                onEdit: () =>
                                    _openDailySheet(programme.id, activity),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  List<int> _yearOptions() {
    final years = <int>{_now.year - 1, _now.year, _now.year + 1, _year};
    final list = years.toList()..sort();
    return list;
  }

  AnnualProgramme? _programmeFor(List<AnnualProgramme> list) {
    for (final programme in list) {
      if (programme.year == _year) return programme;
    }
    return null;
  }

  Future<void> _openWeeklySheet(String programmeId, WeeklyPlan? plan) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _WeeklyPlanSheet(
        programmeId: programmeId,
        year: _year,
        month: _month,
        plan: plan,
      ),
    );
    if (mounted) {
      ref.invalidate(adminWeeklyPlansProvider);
      ref.invalidate(currentProgrammeProvider);
    }
  }

  Future<void> _openDailySheet(
    String programmeId,
    AdminDailyActivity? activity,
  ) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _DailyActivitySheet(
        programmeId: programmeId,
        month: _month,
        activity: activity,
      ),
    );
    if (mounted) ref.invalidate(adminDailyActivitiesProvider);
  }
}

String monthLabel(int month) => monthName(month);

String monthName(int month) =>
    DateFormat('MMMM').format(DateTime(2000, month));

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        AppButton(
          label: actionLabel,
          icon: Icons.add_rounded,
          variant: AppButtonVariant.outlined,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _WeeklyPlanCard extends ConsumerStatefulWidget {
  const _WeeklyPlanCard({
    required this.plan,
    required this.onEdit,
    required this.onChanged,
  });

  final WeeklyPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<_WeeklyPlanCard> createState() => _WeeklyPlanCardState();
}

class _WeeklyPlanCardState extends ConsumerState<_WeeklyPlanCard> {
  bool _busy = false;

  Future<void> _publish() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Publish week ${widget.plan.weekNumber}?',
      message: 'Members will see this week’s guidance immediately.',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/admin/weekly-plans/${widget.plan.id}/publish');
      if (!mounted) return;
      widget.onChanged();
      Toast.success(context, 'Week ${widget.plan.weekNumber} published.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t publish this week just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this week?',
      message:
          'The weekly assignment is removed. Members keep their own activity '
          'records.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/admin/weekly-plans/${widget.plan.id}');
      if (!mounted) return;
      widget.onChanged();
      Toast.success(context, 'Week removed.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t delete this week just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${plan.weekNumber}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(plan.status),
                tone: badgeToneFor(plan.status),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.startDate == null && plan.endDate == null
                ? 'Dates not set'
                : '${fmtDate(plan.startDate)} – ${fmtDate(plan.endDate)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          _kv('Bible reading', plan.bibleReading),
          _kv('Memory verse', plan.memoryVerse),
          _kv('Prayer target', plan.prayerDurationTarget),
          _kv('Book reading', plan.bookReading),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: 'Edit week',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: widget.onEdit,
              ),
              if (plan.status != 'PUBLISHED')
                AppButton(
                  label: 'Publish',
                  icon: Icons.publish_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _publish,
                ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.text,
                busy: _busy,
                onPressed: _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DailyActivityCard extends ConsumerStatefulWidget {
  const _DailyActivityCard({required this.activity, required this.onEdit});

  final AdminDailyActivity activity;
  final VoidCallback onEdit;

  @override
  ConsumerState<_DailyActivityCard> createState() => _DailyActivityCardState();
}

class _DailyActivityCardState extends ConsumerState<_DailyActivityCard> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this activity?',
      message: 'Members will no longer see it on their daily checklist.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/admin/daily-activities/${widget.activity.id}');
      if (!mounted) return;
      ref.invalidate(adminDailyActivitiesProvider);
      Toast.success(context, 'Activity removed.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t delete this activity just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.navy50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 22,
              color: AppColors.navy700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title.isEmpty ? 'Untitled activity' : activity.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activityCategoryLabel(activity.categoryKey)} · '
                  '${activity.scheduleLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (activity.description != null &&
                    activity.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.outlined,
                      onPressed: widget.onEdit,
                    ),
                    AppButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      variant: AppButtonVariant.text,
                      busy: _busy,
                      onPressed: _delete,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (activity.status != null)
            StatusBadge(
              label: humanizeStatus(activity.status!),
              tone: badgeToneFor(activity.status!),
              small: true,
            ),
        ],
      ),
    );
  }
}

class _WeeklyPlanSheet extends ConsumerStatefulWidget {
  const _WeeklyPlanSheet({
    required this.programmeId,
    required this.year,
    required this.month,
    required this.plan,
  });

  final String programmeId;
  final int year;
  final int month;
  final WeeklyPlan? plan;

  @override
  ConsumerState<_WeeklyPlanSheet> createState() => _WeeklyPlanSheetState();
}

class _WeeklyPlanSheetState extends ConsumerState<_WeeklyPlanSheet> {
  late int _weekNumber = widget.plan?.weekNumber ?? 1;
  late final TextEditingController _bible =
      TextEditingController(text: widget.plan?.bibleReading ?? '');
  late final TextEditingController _prayer = TextEditingController(
    text: widget.plan?.prayerDurationTarget ?? '',
  );
  late final TextEditingController _book =
      TextEditingController(text: widget.plan?.bookReading ?? '');
  late final TextEditingController _fasting =
      TextEditingController(text: widget.plan?.fastingSchedule ?? '');
  late final TextEditingController _lesson =
      TextEditingController(text: widget.plan?.keyLessonPrompt ?? '');
  late final TextEditingController _verse =
      TextEditingController(text: widget.plan?.memoryVerse ?? '');
  late final TextEditingController _extra =
      TextEditingController(text: widget.plan?.extraActivities ?? '');
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _start = widget.plan?.startDate;
    _end = widget.plan?.endDate;
  }

  @override
  void dispose() {
    _bible.dispose();
    _prayer.dispose();
    _book.dispose();
    _fasting.dispose();
    _lesson.dispose();
    _verse.dispose();
    _extra.dispose();
    super.dispose();
  }

  String? _iso(DateTime? value) =>
      value == null ? null : DateFormat('yyyy-MM-dd').format(value);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final plan = widget.plan;
    final body = <String, dynamic>{
      'weekNumber': _weekNumber,
      'month': widget.month,
      'bibleReading': _nullIfEmpty(_bible.text),
      'prayerDurationTargetMinutes': int.tryParse(_prayer.text.trim()),
      'bookReading': _nullIfEmpty(_book.text),
      'fastingSchedule': _nullIfEmpty(_fasting.text),
      'keyLessonPrompt': _nullIfEmpty(_lesson.text),
      'memoryVerse': _nullIfEmpty(_verse.text),
      'extraActivities': _extraList(),
      if (_start != null) 'startDate': _iso(_start),
      if (_end != null) 'endDate': _iso(_end),
    };
    try {
      final client = ref.read(apiClientProvider);
      if (plan == null) {
        await client.post(
          '/admin/programmes/${widget.programmeId}/weekly-plans',
          body: body,
        );
      } else {
        await client.patch('/admin/weekly-plans/${plan.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(context, 'Week $_weekNumber saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this week just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String>? _extraList() {
    final items = _extra.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return items.isEmpty ? null : items;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.plan != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editing ? 'Edit week ${widget.plan!.weekNumber}' : 'Add a week',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${monthName(widget.month)} ${widget.year}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!editing)
          AppDropdown<int>(
            label: 'Week number',
            value: _weekNumber,
            items: [
              for (var w = 1; w <= 6; w++)
                DropdownMenuItem(value: w, child: Text('Week $w')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _weekNumber = value);
            },
          ),
        if (!editing) const SizedBox(height: fieldGap),
        Row(
          children: [
            Expanded(
              child: AppDateField(
                label: 'Start date',
                value: _start,
                onChanged: (value) => setState(() => _start = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDateField(
                label: 'End date',
                value: _end,
                onChanged: (value) => setState(() => _end = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Bible reading',
          controller: _bible,
          hint: 'e.g. John 15',
          maxLines: 2,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Prayer duration target (minutes)',
          controller: _prayer,
          keyboardType: TextInputType.number,
          hint: 'e.g. 30',
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Book reading',
          controller: _book,
          maxLines: 2,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Fasting schedule',
          controller: _fasting,
          maxLines: 2,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Key lesson prompt',
          controller: _lesson,
          maxLines: 3,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Memory verse',
          controller: _verse,
          maxLines: 2,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Extra activities (one per line)',
          controller: _extra,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: editing ? 'Save week' : 'Add week',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _DailyActivitySheet extends ConsumerStatefulWidget {
  const _DailyActivitySheet({
    required this.programmeId,
    required this.month,
    required this.activity,
  });

  final String programmeId;
  final int month;
  final AdminDailyActivity? activity;

  @override
  ConsumerState<_DailyActivitySheet> createState() =>
      _DailyActivitySheetState();
}

class _DailyActivitySheetState extends ConsumerState<_DailyActivitySheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.activity?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.activity?.description ?? '');
  late final TextEditingController _startTime =
      TextEditingController(text: widget.activity?.startTime ?? '');
  late final TextEditingController _duration = TextEditingController(
    text: widget.activity?.targetDuration ?? '',
  );
  late String _category = widget.activity?.categoryKey ?? 'prayer';
  late DateTime? _date = widget.activity?.date;
  late bool _trackCompletion = widget.activity?.trackingEnabled ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _startTime.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      Toast.error(context, 'Give the activity a title.');
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'description': _nullIfEmpty(_description.text),
      'month': widget.month,
      if (_date != null) 'date': DateFormat('yyyy-MM-dd').format(_date!),
      if (_startTime.text.trim().isNotEmpty)
        'startTime': _startTime.text.trim(),
      if (int.tryParse(_duration.text.trim()) != null)
        'durationMinutes': int.parse(_duration.text.trim()),
      'trackCompletion': _trackCompletion,
    };
    try {
      final client = ref.read(apiClientProvider);
      final activity = widget.activity;
      if (activity == null) {
        await client.post(
          '/admin/programmes/${widget.programmeId}/daily-activities',
          body: body,
        );
      } else {
        await client.patch('/admin/daily-activities/${activity.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(context, 'Daily activity saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this activity just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.activity != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editing ? 'Edit daily activity' : 'Add daily activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${monthName(widget.month)} · members see this on their daily checklist',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Title',
          controller: _title,
          required: true,
          hint: 'e.g. Morning prayer',
        ),
        const SizedBox(height: fieldGap),
        AppDropdown<String>(
          label: 'Category',
          value: _category,
          items: [
            for (final key in _weekCategories)
              DropdownMenuItem(
                value: key,
                child: Text(activityCategoryLabel(key)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: fieldGap),
        AppDateField(
          label: 'Date (optional — leave blank for any day)',
          value: _date,
          onChanged: (value) => setState(() => _date = value),
        ),
        const SizedBox(height: fieldGap),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Start time',
                controller: _startTime,
                hint: 'HH:mm',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: 'Duration (minutes)',
                controller: _duration,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: fieldGap),
        AppSwitchRow(
          label: 'Track completion',
          subtitle: 'Members can mark this activity done.',
          value: _trackCompletion,
          onChanged: (value) => setState(() => _trackCompletion = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: editing ? 'Save activity' : 'Add activity',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
