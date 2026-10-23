import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Monthly plan authoring: pick a programme year, then edit each of the
/// 12 months with a full-height editor sheet.
class AdminMonthlyPlansScreen extends ConsumerWidget {
  const AdminMonthlyPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MonthlyPlansBody();
  }
}

class _MonthlyPlansBody extends ConsumerStatefulWidget {
  const _MonthlyPlansBody();

  @override
  ConsumerState<_MonthlyPlansBody> createState() => _MonthlyPlansBodyState();
}

class _MonthlyPlansBodyState extends ConsumerState<_MonthlyPlansBody> {
  int? _selectedYear;

  DropdownMenuItem<String> _yearItem(int year) => DropdownMenuItem<String>(
        value: '$year',
        child: Text('$year'),
      );

  @override
  Widget build(BuildContext context) {
    final programmesAsync = ref.watch(adminProgrammesProvider);

    return programmesAsync.when(
      loading: () => ListView(
        padding: adminPadding(context),
        children: const [
          SkeletonBox(height: 56, radius: 14),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 120, radius: 14),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 120, radius: 14),
        ],
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminProgrammesProvider),
      ),
      data: (programmes) {
        if (programmes.isEmpty) {
          return SingleChildScrollView(
            padding: adminPadding(context),
            child: EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Create a programme year first',
              message:
                  'Monthly plans hang off an annual programme. Start one, '
                  'then come back to fill in each month.',
              actionLabel: 'Create programme',
              onAction: () => context.go('/admin/programmes/new'),
            ),
          );
        }
        final years = programmes.map((p) => p.year).toSet().toList()..sort();
        if (_selectedYear == null || !years.contains(_selectedYear)) {
          _selectedYear = years.last;
        }
        final year = _selectedYear!;
        final plansAsync = ref.watch(adminMonthlyPlansProvider(year));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminMonthlyPlansProvider);
            ref.invalidate(adminProgrammesProvider);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: adminPadding(context),
            children: [
              SectionHeader(
                title: 'Monthly Plans',
                subtitle: 'Themes, prayer focus and guidance for each month',
                icon: Icons.calendar_month_outlined,
              ),
              SizedBox(
                width: Breakpoints.isCompact(context) ? 200 : 260,
                child: AppDropdown<String>(
                  label: 'Programme year',
                  value: '$year',
                  items: [for (final y in years) _yearItem(y)],
                  onChanged: (value) => setState(() {
                    _selectedYear = int.tryParse(value ?? '');
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              plansAsync.when(
                loading: () => const CardListSkeleton(count: 6),
                error: (error, _) => ErrorState(
                  error: error,
                  compact: true,
                  onRetry: () =>
                      ref.invalidate(adminMonthlyPlansProvider(year)),
                ),
                data: (plans) => Column(
                  children: [
                    for (var month = 1; month <= 12; month++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _MonthCard(
                          key: ValueKey('$year-$month'),
                          year: year,
                          month: month,
                          plan: plans
                              .where((p) => p.month == month)
                              .cast<MonthlyPlan?>()
                              .firstOrNull,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

const _monthFieldLabels = <(String, String Function(MonthlyPlan))>[
  ('Theme / study topic', _themeOf),
  ('Prayer focus', _prayerOf),
  ('Bible reading guidance', _bibleOf),
  ('Literature list', _literatureOf),
  ('Audio message list', _audioOf),
  ('Fasting guidance', _fastingOf),
  ('Confession', _confessionOf),
  ('Goals guidance', _goalsOf),
];

String _themeOf(MonthlyPlan p) => p.theme ?? '';
String _prayerOf(MonthlyPlan p) => p.prayerFocus ?? '';
String _bibleOf(MonthlyPlan p) => p.bibleReadingGuidance ?? '';
String _literatureOf(MonthlyPlan p) => p.literatureList ?? '';
String _audioOf(MonthlyPlan p) => p.audioMessageList ?? '';
String _fastingOf(MonthlyPlan p) => p.fastingGuidance ?? '';
String _confessionOf(MonthlyPlan p) => p.confession ?? '';
String _goalsOf(MonthlyPlan p) => p.goalsGuidance ?? '';

int _filledCount(MonthlyPlan? plan) {
  if (plan == null) return 0;
  var filled = 0;
  for (final field in _monthFieldLabels) {
    if (field.$2(plan).trim().isNotEmpty) filled++;
  }
  if (plan.reflectionQuestions.any((q) => q.trim().isNotEmpty)) filled++;
  return filled;
}

const int _monthFieldTotal = 9;

class _MonthCard extends ConsumerStatefulWidget {
  const _MonthCard({
    super.key,
    required this.year,
    required this.month,
    required this.plan,
  });

  final int year;
  final int month;
  final MonthlyPlan? plan;

  @override
  ConsumerState<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends ConsumerState<_MonthCard> {
  bool _busy = false;

  String get _monthName =>
      DateFormat('MMMM').format(DateTime(widget.year, widget.month));

  Future<void> _publish() async {
    final plan = widget.plan;
    if (plan == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Publish $_monthName?',
      message: 'Members will see this month’s guidance once it is published.',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    await _statusAction('/admin/monthly-plans/${plan.id}/publish',
        '$_monthName published.');
  }

  Future<void> _archive() async {
    final plan = widget.plan;
    if (plan == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Archive $_monthName?',
      message:
          'It moves out of the active plan. Content is kept and can be '
          'published again later.',
      confirmLabel: 'Archive',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _statusAction('/admin/monthly-plans/${plan.id}/archive',
        '$_monthName archived.');
  }

  Future<void> _statusAction(String path, String successMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(path);
      if (!mounted) return;
      ref.invalidate(adminMonthlyPlansProvider(widget.year));
      ref.invalidate(monthlyPlansProvider(widget.year));
      Toast.success(context, successMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'That didn’t complete. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    await showAdminSheet(
      context: context,
      builder: (_) => _MonthlyPlanSheet(
        year: widget.year,
        month: widget.month,
        plan: widget.plan,
      ),
    );
    if (mounted) {
      ref.invalidate(adminMonthlyPlansProvider(widget.year));
      ref.invalidate(monthlyPlansProvider(widget.year));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final filled = _filledCount(plan);
    final complete = filled == _monthFieldTotal;

    return AppCard(
      onTap: _edit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.month}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.gold600,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _monthName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      plan == null
                          ? 'Not created yet'
                          : (plan.theme == null || plan.theme!.trim().isEmpty
                              ? 'No theme set'
                              : plan.theme!),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusBadge(
                label: plan == null ? 'Draft' : humanizeStatus(plan.status),
                tone: plan == null
                    ? AppBadgeTone.neutral
                    : badgeToneFor(plan.status),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusBadge(
                label: '$filled/$_monthFieldTotal fields',
                tone: plan == null
                    ? AppBadgeTone.neutral
                    : complete
                        ? AppBadgeTone.success
                        : AppBadgeTone.warning,
                small: true,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  plan == null
                      ? 'Tap to create this month’s plan'
                      : 'Completeness indicator — not a score',
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: plan == null ? 'Create plan' : 'Edit plan',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.outlined,
                busy: _busy,
                onPressed: _edit,
              ),
              if (plan != null && plan.status != 'PUBLISHED')
                AppButton(
                  label: 'Publish',
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _publish,
                ),
              if (plan != null && plan.status != 'ARCHIVED')
                AppButton(
                  label: 'Archive',
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _archive,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full editor for one month's plan content.
class _MonthlyPlanSheet extends ConsumerStatefulWidget {
  const _MonthlyPlanSheet({
    required this.year,
    required this.month,
    required this.plan,
  });

  final int year;
  final int month;
  final MonthlyPlan? plan;

  @override
  ConsumerState<_MonthlyPlanSheet> createState() => _MonthlyPlanSheetState();
}

class _MonthlyPlanSheetState extends ConsumerState<_MonthlyPlanSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final List<TextEditingController> _questions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    for (final field in _monthFieldLabels) {
      final controller = TextEditingController(text: field.$2(plan ?? _empty));
      _controllers[field.$1] = controller;
    }
    for (final question in plan?.reflectionQuestions ?? const <String>[]) {
      _questions.add(TextEditingController(text: question));
    }
  }

  static final MonthlyPlan _empty = MonthlyPlan(
    id: '',
    month: 1,
    year: 2026,
    status: 'DRAFT',
  );

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _questions) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _monthName =>
      DateFormat('MMMM').format(DateTime(widget.year, widget.month));

  void _addQuestion() {
    setState(() => _questions.add(TextEditingController()));
  }

  void _removeQuestion(int index) {
    final controller = _questions.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  void _moveQuestion(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _questions.length) return;
    final item = _questions.removeAt(index);
    _questions.insert(target, item);
    setState(() {});
  }

  /// Resolves the annual programme id for [widget.year] from the cached list.
  String? _programmeIdForYear() {
    final programmes = ref
        .read(adminProgrammesProvider)
        .maybeWhen(data: (list) => list, orElse: () => null);
    if (programmes == null) return null;
    for (final programme in programmes) {
      if (programme.year == widget.year) return programme.id;
    }
    return null;
  }

  String _text(String label) => _controllers[label]?.text.trim() ?? '';

  /// Turns a free-text field into the `[{title}]` array the API expects.
  List<Map<String, String>> _itemsFrom(String text) => [
        for (final line in text.split(RegExp(r'[\n,;]+')))
          if (line.trim().isNotEmpty) {'title': line.trim()},
      ];

  Future<void> _save() async {
    if (_saving) return;
    final plan = widget.plan;
    final programmeId = plan?.programmeId ?? _programmeIdForYear();
    if (plan == null && (programmeId == null || programmeId.isEmpty)) {
      Toast.error(
        context,
        'Create an annual programme for ${widget.year} before adding months.',
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'year': widget.year,
      'month': widget.month,
      'theme': _text('Theme / study topic'),
      'prayerFocus': _text('Prayer focus'),
      'bibleReadingGuidance': _text('Bible reading guidance'),
      'literatureList': _itemsFrom(_text('Literature list')),
      'audioMessages': _itemsFrom(_text('Audio message list')),
      'fastingGuidance': _text('Fasting guidance'),
      'monthlyConfession': _text('Confession'),
      'monthlyGoalsGuidance': _text('Goals guidance'),
      'reflectionQuestions': [
        for (final controller in _questions)
          if (controller.text.trim().isNotEmpty) controller.text.trim(),
      ],
    };
    try {
      final client = ref.read(apiClientProvider);
      if (plan == null || plan.id.isEmpty) {
        await client.post(
          '/admin/programmes/$programmeId/monthly-plans',
          body: body,
        );
      } else {
        await client.patch('/admin/monthly-plans/${plan.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(context, '$_monthName saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this month just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
              child: Text(
                '$_monthName ${widget.year}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            StatusBadge(
              label: widget.plan == null ? 'New plan' : 'Editing',
              tone: AppBadgeTone.navy,
              small: true,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final field in _monthFieldLabels) ...[
          AppTextField(
            label: field.$1,
            controller: _controllers[field.$1],
            maxLines: 3,
          ),
          const SizedBox(height: fieldGap),
        ],
        Text(
          'Reflection questions',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        if (_questions.isEmpty)
          Text(
            'No questions yet — add as many as the month needs.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (var i = 0; i < _questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Question ${i + 1}',
                    controller: _questions[i],
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                      tooltip: 'Move up',
                      onPressed: i == 0 ? null : () => _moveQuestion(i, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                      tooltip: 'Move down',
                      onPressed: i == _questions.length - 1
                          ? null
                          : () => _moveQuestion(i, 1),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Remove question',
                  onPressed: () => _removeQuestion(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _addQuestion,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add question'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: widget.plan == null ? 'Create plan' : 'Save plan',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Members see published months only.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
