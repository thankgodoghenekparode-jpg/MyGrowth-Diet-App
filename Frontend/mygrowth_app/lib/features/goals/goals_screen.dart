import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/goal_models.dart';
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
import 'goals_providers.dart';

/// My Goals: weekly and monthly personal goals with progress tracking.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _GoalsView();
  }
}

class _GoalsView extends ConsumerStatefulWidget {
  const _GoalsView();

  @override
  ConsumerState<_GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends ConsumerState<_GoalsView> {
  String _period = 'MONTHLY';

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider(_period));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(goalsProvider(_period));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('My Goals', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            'Small, personal steps that help you grow at your own pace.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),

          // ---------------------------------------- gentle guidance
          AppCard(
            color: AppColors.navy50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    size: 18, color: AppColors.navy600),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Members may set up to three monthly goals at a time. '
                    'Need inspiration? Example: complete the monthly Bible '
                    'reading plan — examples are simply ideas, never ministry '
                    'requirements.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSecondary,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---------------------------------------- period switcher
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'WEEKLY', label: Text('Weekly')),
              ButtonSegment(value: 'MONTHLY', label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) =>
                setState(() => _period = selection.first),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ----------------------------------------------- goal list
          goals.when(
            loading: () => const CardListSkeleton(count: 3),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(goalsProvider(_period)),
            ),
            data: (list) {
              final openGoals =
                  list.where((g) => g.status != 'ABANDONED').toList();
              if (list.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.flag_outlined,
                    title: _period == 'MONTHLY'
                        ? 'No monthly goals yet'
                        : 'No weekly goals yet',
                    message:
                        'Goals are personal and entirely optional. When '
                        'you’re ready, set one small step for this '
                        '${_period == 'MONTHLY' ? 'month' : 'week'}.',
                    actionLabel: 'New goal',
                    onAction: () => _showCreateSheet(context, 0),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${list.length} ${_period.toLowerCase()} goal${list.length == 1 ? '' : 's'}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      AppButton(
                        label: 'New goal',
                        icon: Icons.add_rounded,
                        variant: AppButtonVariant.outlined,
                        onPressed: () => _showCreateSheet(context,
                            _period == 'MONTHLY' ? openGoals.length : 0),
                      ),
                    ],
                  ),
                  if (_period == 'MONTHLY' && openGoals.length >= 3) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_outline,
                            size: 16, color: AppColors.gold600),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'You have three monthly goals open. That’s '
                            'wonderful — you’re welcome to add more, but '
                            'finishing one first keeps things peaceful.',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  for (final goal in list) ...[
                    _GoalCard(goal: goal, period: _period),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Goals and progress are self-reported and private to you.',
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

  Future<void> _showCreateSheet(BuildContext context, int currentMonthlyCount) async {
    final created = await showModalBottomSheet<bool>(
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
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
        ),
        child: _CreateGoalSheet(
          periodType: _period,
          currentMonthlyCount: currentMonthlyCount,
        ),
      ),
    );
    if (created == true) {
      ref.invalidate(goalsProvider(_period));
    }
  }
}

class _GoalCard extends ConsumerStatefulWidget {
  const _GoalCard({required this.goal, required this.period});

  final Goal goal;
  final String period;

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _busy = false;

  Goal get _goal => widget.goal;

  Future<void> _patchStatus(String status, String successMessage) async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.patch('/me/goals/${_goal.id}', body: {'status': status});
      if (!mounted) return;
      ref.invalidate(goalsProvider(widget.period));
      Toast.success(context, successMessage);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this goal?',
      message:
          'This will permanently remove “${_goal.title}” and its recorded '
          'progress. This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.delete('/me/goals/${_goal.id}');
      if (!mounted) return;
      ref.invalidate(goalsProvider(widget.period));
      Toast.success(context, 'Goal deleted.');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to delete just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logProgress() async {
    final logged = await showModalBottomSheet<bool>(
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
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
        ),
        child: _LogProgressSheet(goal: _goal),
      ),
    );
    if (logged == true && mounted) {
      ref.invalidate(goalsProvider(widget.period));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMM yyyy');
    final periodText = _goal.startDate == null && _goal.targetDate == null
        ? 'Flexible dates'
        : [
            if (_goal.startDate != null) dateFmt.format(_goal.startDate!),
            if (_goal.targetDate != null) '→ ${dateFmt.format(_goal.targetDate!)}',
          ].join('  ');
    final canLog = _goal.status == 'ACTIVE' && !_busy;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _goal.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(_goal.status),
                tone: badgeToneFor(_goal.status),
                small: true,
              ),
              PopupMenuButton<String>(
                tooltip: 'Goal actions',
                enabled: !_busy,
                onSelected: (action) {
                  switch (action) {
                    case 'pause':
                      _patchStatus('PAUSED', 'Goal paused. Resume anytime.');
                    case 'resume':
                      _patchStatus('ACTIVE', 'Goal resumed. You’ve got this!');
                    case 'complete':
                      _patchStatus(
                          'COMPLETED', 'Wonderful — goal marked complete!');
                    case 'delete':
                      _delete();
                  }
                },
                itemBuilder: (context) => [
                  if (_goal.status == 'ACTIVE')
                    const PopupMenuItem(
                      value: 'pause',
                      child: ListTile(
                        leading: Icon(Icons.pause_circle_outline),
                        title: Text('Pause'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (_goal.status == 'PAUSED')
                    const PopupMenuItem(
                      value: 'resume',
                      child: ListTile(
                        leading: Icon(Icons.play_circle_outline),
                        title: Text('Resume'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (_goal.status != 'COMPLETED')
                    const PopupMenuItem(
                      value: 'complete',
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Mark completed'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: AppColors.danger),
                      title: Text('Delete', style: TextStyle(color: AppColors.danger)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_goal.description != null &&
              _goal.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _goal.description!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  periodText,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ProgressBar(value: _goal.progressFraction),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_fmtQuantity(_goal.currentProgress)}'
                  '${_goal.targetQuantity != null ? ' / ${_fmtQuantity(_goal.targetQuantity!)}' : ''}'
                  '${_goal.targetUnit != null ? ' ${_goal.targetUnit}' : ''}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_goal.targetQuantity != null && _goal.targetQuantity! > 0)
                Text(
                  '${(_goal.progressFraction * 100).round()}%',
                  style: theme.textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppButton(
                label: 'Log progress',
                icon: Icons.add_chart_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: canLog ? _logProgress : null,
                tooltip: canLog
                    ? null
                    : _goal.status == 'COMPLETED'
                        ? 'This goal is already complete — well done!'
                        : 'Only active goals can log progress. Resume it '
                            'from the actions menu.',
              ),
              if (_busy) ...[
                const SizedBox(width: AppSpacing.sm),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmtQuantity(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// Sheet to log progress against a goal.
class _LogProgressSheet extends ConsumerStatefulWidget {
  const _LogProgressSheet({required this.goal});

  final Goal goal;

  @override
  ConsumerState<_LogProgressSheet> createState() => _LogProgressSheetState();
}

class _LogProgressSheetState extends ConsumerState<_LogProgressSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount you completed (e.g. 1).');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final client = ref.read(apiClientProvider);
    try {
      await client.post('/me/goals/${widget.goal.id}/progress', body: {
        'amount': amount,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      Toast.success(context, 'Progress logged. Keep going — line upon line!');
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
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Log progress', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          widget.goal.title,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: widget.goal.targetUnit == null
              ? 'Amount completed'
              : 'Amount completed (${widget.goal.targetUnit})',
          controller: _amount,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: 'e.g. 1',
          errorText: _error,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Private note (optional)',
          controller: _note,
          maxLines: 2,
          hint: 'Anything you’d like to remember',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: 'Save progress', busy: _busy, expand: true, onPressed: _save),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Progress is self-reported — small steps still count.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Sheet to create a new weekly/monthly goal.
class _CreateGoalSheet extends ConsumerStatefulWidget {
  const _CreateGoalSheet({
    required this.periodType,
    required this.currentMonthlyCount,
  });

  final String periodType;
  final int currentMonthlyCount;

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  DateTime? _startDate;
  DateTime? _targetDate;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_targetDate != null &&
        _startDate != null &&
        _targetDate!.isBefore(_startDate!)) {
      Toast.error(context, 'The target date can’t be before the start date.');
      return;
    }
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final quantity = double.tryParse(_quantity.text.trim());
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'periodType': widget.periodType,
    };
    final description = _description.text.trim();
    if (description.isNotEmpty) body['description'] = description;
    if (_startDate != null) body['startDate'] = dateFmt.format(_startDate!);
    if (_targetDate != null) body['targetDate'] = dateFmt.format(_targetDate!);
    if (quantity != null) body['targetQuantity'] = quantity;
    final unit = _unit.text.trim();
    if (unit.isNotEmpty) body['targetUnit'] = unit;
    try {
      await client.post('/me/goals', body: body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      Toast.success(context, 'Goal created. One step at a time!');
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
    final theme = Theme.of(context);
    final periodLabel =
        widget.periodType == 'MONTHLY' ? 'monthly' : 'weekly';
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New $periodLabel goal', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Goals are personal. Choose something realistic and kind to '
              'yourself.',
              style: theme.textTheme.bodySmall,
            ),
            if (widget.periodType == 'MONTHLY' &&
                widget.currentMonthlyCount >= 3) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'You already have three monthly goals open. Members '
                      'may keep up to three at a time — consider finishing '
                      'one first, though you’re free to add another.',
                      style: theme.textTheme.labelSmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Title',
              controller: _title,
              required: true,
              textCapitalization: TextCapitalization.sentences,
              hint: 'e.g. Example: complete the monthly Bible reading plan',
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Description (optional)',
              controller: _description,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              hint: 'Why this goal matters to you',
            ),
            const SizedBox(height: fieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Target quantity (optional)',
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    hint: 'e.g. 30',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Unit (optional)',
                    controller: _unit,
                    hint: 'e.g. days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: fieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppDateField(
                    label: 'Start date',
                    value: _startDate,
                    onChanged: (d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppDateField(
                    label: 'Target date',
                    value: _targetDate,
                    firstDate: _startDate ?? DateTime.now(),
                    onChanged: (d) => setState(() => _targetDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Create goal',
              busy: _busy,
              expand: true,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This goal is for you alone — it isn’t a ministry requirement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
