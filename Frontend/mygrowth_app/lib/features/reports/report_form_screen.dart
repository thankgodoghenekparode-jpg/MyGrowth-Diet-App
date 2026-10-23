import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/report_models.dart';
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
import 'reports_providers.dart';

/// Create or continue editing an accountability report. Either [type]
/// (for new reports) or [reportId] (for drafts) must be provided.
class ReportFormScreen extends ConsumerWidget {
  const ReportFormScreen({super.key, this.type, this.reportId})
      : assert(
          type != null || reportId != null,
          'Provide either a report type or an existing report id.',
        );

  /// Lowercase in the URL, e.g. 'weekly'.
  final String? type;
  final String? reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReportFormBody(type: type, reportId: reportId);
  }
}

class _ReportFormBody extends ConsumerStatefulWidget {
  const _ReportFormBody({this.type, this.reportId});

  final String? type;
  final String? reportId;

  @override
  ConsumerState<_ReportFormBody> createState() => _ReportFormBodyState();
}

class _ReportFormBodyState extends ConsumerState<_ReportFormBody> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _dropdowns = {};
  Map<String, dynamic> _seedAnswers = {};
  Report? _report;
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _resolvedType {
    final fromReport = _report?.type;
    if (fromReport != null) return fromReport.toUpperCase();
    if (widget.type != null) return widget.type!.toUpperCase();
    return null;
  }

  bool get _readOnly => _report != null && !_report!.canEdit;

  TextEditingController _controllerFor(String key) => _controllers.putIfAbsent(
        key,
        () => TextEditingController(text: _report?.answerFor(key) ?? ''),
      );

  void _seedFromReport(Report report) {
    if (_initialized) return;
    _report = report;
    _seedAnswers = Map<String, dynamic>.from(report.answers);
    // Restore dropdown values from the saved answers (only values the
    // dropdowns actually offer — the API may store something else).
    final specs = reportFieldsFor(report.type);
    for (final spec in specs) {
      if (spec.kind == ReportFieldKind.rating) {
        final key = '${spec.key}Rating';
        final raw = report.answers[key];
        final value = raw is String ? raw : null;
        _dropdowns[key] =
            ratingOptions.any((o) => o.$1 == value) ? value : null;
      } else if (spec.kind == ReportFieldKind.goal) {
        final key = '${spec.key}Status';
        final raw = report.answers[key];
        final value = raw is String ? raw : null;
        _dropdowns[key] =
            goalStatusOptions.any((o) => o.$1 == value) ? value : null;
      }
    }
    _initialized = true;
  }

  Map<String, dynamic> _collectAnswers() {
    final result = Map<String, dynamic>.from(_seedAnswers);
    _dropdowns.forEach((key, value) {
      if (value == null) {
        result.remove(key);
      } else {
        result[key] = value;
      }
    });
    _controllers.forEach((key, controller) {
      final text = controller.text.trim();
      if (text.isEmpty) {
        result.remove(key);
      } else {
        result[key] = text;
      }
    });
    return result;
  }

  int get _programmeYear =>
      ref.read(currentProgrammeProvider).value?.year ?? DateTime.now().year;

  Future<String?> _saveDraft({bool silent = false}) async {
    final type = _resolvedType;
    if (type == null) return null;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final answers = _collectAnswers();
    try {
      String? id = widget.reportId;
      if (id == null) {
        final res = await client.post('/me/reports', body: {
          'type': type,
          'periodKey': periodKeyFor(type, DateTime.now()),
          'answers': answers,
          'programmeYear': _programmeYear,
        });
        if (res is Map<String, dynamic> && res['id'] != null) {
          id = res['id'].toString();
        }
        if (id == null) {
          if (mounted) {
            Toast.error(
              context,
              'The report was created but the server response was '
              'unexpected. Your answers stay in this form — try again shortly.',
            );
          }
          return null;
        }
      } else {
        await client.patch('/me/reports/$id', body: {'answers': answers});
      }
      ref.invalidate(reportsListProvider(type));
      ref.invalidate(reportDetailProvider(id));
      if (mounted && !silent) Toast.success(context, 'Draft saved.');
      return id;
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
      return null;
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final id = await _saveDraft(silent: true);
    if (id == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Submit report?',
      message:
          'Your report will be shared with ministry administrators for '
          'accountability review. Your private reflections/journal entries '
          'are NOT included.',
      confirmLabel: 'Submit report',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final type = _resolvedType ?? 'WEEKLY';
    try {
      await client.post('/me/reports/$id/submit');
      ref.invalidate(reportsListProvider(type));
      ref.invalidate(reportDetailProvider(id));
      if (mounted) {
        Toast.success(
          context,
          'Report submitted. Thank you for your faithfulness!',
        );
        context.go('/reports');
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to submit just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = widget.reportId == null
        ? null
        : ref.watch(reportDetailProvider(widget.reportId!));

    if (detailAsync != null && detailAsync.isLoading && _report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 6),
        ),
      );
    }
    if (detailAsync != null &&
        detailAsync.error != null &&
        _report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: ErrorState(
          error: detailAsync.error!,
          onRetry: () =>
              ref.invalidate(reportDetailProvider(widget.reportId!)),
        ),
      );
    }
    final detail = detailAsync?.value;
    if (detail != null && !_initialized) _seedFromReport(detail);

    final type = _resolvedType ?? 'WEEKLY';
    final specs = reportFieldsFor(type);
    final periodDate = _report != null
        ? periodStartDateFor(_report!.type, _report!.periodKey)
        : DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _report == null
              ? 'New ${humanizeStatus(type).toLowerCase()} report'
              : '${humanizeStatus(type).toLowerCase()} report — '
                  '${humanizePeriodKey(_report!.periodKey)}',
        ),
      ),
      body: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (_readOnly) ...[
            AppCard(
              color: AppColors.infoSurface,
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This report has been submitted and is read-only. '
                      'Ministry administrators are reviewing it — if they '
                      'request changes, you can reply from the report detail '
                      'page.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_report != null) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                StatusBadge(
                  label: humanizePeriodKey(_report!.periodKey),
                  tone: AppBadgeTone.gold,
                ),
                StatusBadge(
                  label: humanizeStatus(_report!.status),
                  tone: badgeToneFor(_report!.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ---------------------------------------------------- fields
          for (final spec in specs) ...[
            _buildField(context, spec),
            const SizedBox(height: AppSpacing.md),
          ],

          // ----------------------------------- monthly reflection questions
          if (type == 'MONTHLY')
            _MonthlyReflectionSection(
              periodDate: periodDate,
              readOnly: _readOnly,
              controllerFor: _controllerFor,
            ),

          // ------------------------------- quarterly confession block
          if (type == 'QUARTERLY')
            _QuarterlyConfessionSection(periodDate: periodDate),

          if (type == 'ANNUAL') ...[
            AppCard(
              color: AppColors.gold100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 20, color: AppColors.gold600),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This letter is private by default. It is stored for '
                      'your eyes only and is never shared with administrators '
                      'or other members.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // --------------------------------------------------- actions
          if (!_readOnly)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Save as draft',
                    icon: Icons.save_outlined,
                    variant: AppButtonVariant.outlined,
                    busy: _busy,
                    onPressed: () => _saveDraft(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Submit',
                    icon: Icons.send_rounded,
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, ReportFieldSpec spec) {
    switch (spec.kind) {
      case ReportFieldKind.text:
        return AppTextField(
          label: spec.label,
          controller: _controllerFor(spec.key),
          maxLines: spec.maxLines ?? 4,
          enabled: !_readOnly,
        );
      case ReportFieldKind.rating:
        final ratingKey = '${spec.key}Rating';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDropdown<String>(
              label: spec.label,
              required: true,
              value: _dropdowns[ratingKey],
              hint: 'Select a rating',
              items: [
                for (final option in ratingOptions)
                  DropdownMenuItem(
                    value: option.$1,
                    child: Text(option.$2),
                  ),
              ],
              onChanged: _readOnly
                  ? (_) {}
                  : (v) => setState(() => _dropdowns[ratingKey] = v),
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Comment',
              controller: _controllerFor('${spec.key}Comment'),
              maxLines: 3,
              enabled: !_readOnly,
              hint: 'A short reflection on this area…',
            ),
          ],
        );
      case ReportFieldKind.goal:
        final statusKey = '${spec.key}Status';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: '${spec.label} title',
              controller: _controllerFor('${spec.key}Title'),
              enabled: !_readOnly,
              hint: 'What was the goal?',
            ),
            const SizedBox(height: fieldGap),
            AppDropdown<String>(
              label: 'Status (self-reported)',
              value: _dropdowns[statusKey],
              hint: 'Select a status',
              items: [
                for (final option in goalStatusOptions)
                  DropdownMenuItem(
                    value: option.$1,
                    child: Text(option.$2),
                  ),
              ],
              onChanged: _readOnly
                  ? (_) {}
                  : (v) => setState(() => _dropdowns[statusKey] = v),
            ),
          ],
        );
    }
  }
}

/// Renders the month's reflection questions as text areas.
class _MonthlyReflectionSection extends ConsumerWidget {
  const _MonthlyReflectionSection({
    required this.periodDate,
    required this.readOnly,
    required this.controllerFor,
  });

  final DateTime periodDate;
  final bool readOnly;
  final TextEditingController Function(String key) controllerFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(monthlyPlanProvider(
        (year: periodDate.year, month: periodDate.month)));
    return plan.when(
      loading: () => const SkeletonBox(height: 120, radius: 14),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(monthlyPlanProvider(
            (year: periodDate.year, month: periodDate.month))),
      ),
      data: (plan) {
        if (plan == null || plan.reflectionQuestions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Monthly reflection questions',
              subtitle: plan.theme == null
                  ? null
                  : 'From the ${DateFormat('MMMM yyyy').format(periodDate)} plan: ${plan.theme}',
              icon: Icons.lightbulb_outline_rounded,
            ),
            for (var i = 0; i < plan.reflectionQuestions.length; i++) ...[
              AppTextField(
                label: plan.reflectionQuestions[i],
                controller: controllerFor('reflection_$i'),
                maxLines: 4,
                enabled: !readOnly,
              ),
              const SizedBox(height: fieldGap),
            ],
          ],
        );
      },
    );
  }
}

/// Displays the quarterly confession from the programme, with a clearly
/// labelled fallback when the API doesn't expose one.
class _QuarterlyConfessionSection extends ConsumerWidget {
  const _QuarterlyConfessionSection({required this.periodDate});

  final DateTime periodDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(monthlyPlanProvider(
        (year: periodDate.year, month: periodDate.month)));
    final confession = plan.value?.confession;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: VerseCard(
        tone: VerseTone.gold,
        icon: Icons.record_voice_over_outlined,
        label: confession == null
            ? 'Quarterly confession (fallback)'
            : 'Quarterly confession',
        text: confession ?? quarterlyConfessionFallback,
        caption: confession == null
            ? 'The API doesn’t expose a quarterly confession yet — this '
                'fallback from the MyGrowth team is shown instead.'
            : null,
      ),
    );
  }
}
