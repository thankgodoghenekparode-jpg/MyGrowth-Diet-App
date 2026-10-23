import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/report_models.dart';
import '../../core/auth/auth_controller.dart';
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
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Read-only view of a member's submitted report plus the admin review
/// panel (comment / follow-up / mark reviewed).
class AdminReportDetailScreen extends ConsumerWidget {
  const AdminReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ReportDetailBody(reportId: reportId);
  }
}

class _ReportDetailBody extends ConsumerStatefulWidget {
  const _ReportDetailBody({required this.reportId});

  final String reportId;

  @override
  ConsumerState<_ReportDetailBody> createState() =>
      _ReportDetailBodyState();
}

class _ReportDetailBodyState extends ConsumerState<_ReportDetailBody> {
  final TextEditingController _comment = TextEditingController();
  String? _busy;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addReview(String kind, {bool confirmFirst = false}) async {
    final comment = _comment.text.trim();
    if (kind != 'REVIEWED' && comment.isEmpty) {
      Toast.error(context, 'Please write your comment first.');
      return;
    }
    if (confirmFirst) {
      final titles = switch (kind) {
        'FOLLOW_UP' => (
            'Request a follow-up?',
            'The report status will change to “Requires follow-up” and your '
                'comment will be sent alongside it.',
            'Request follow-up',
          ),
        _ => (
            'Mark as reviewed?',
            'This records your review on the report. The member will see '
                'that it has been reviewed.',
            'Mark as reviewed',
          ),
      };
      final confirmed = await confirmDialog(
        context,
        title: titles.$1,
        message: titles.$2,
        confirmLabel: titles.$3,
      );
      if (!confirmed || !mounted) return;
    }
    if (_busy != null) return;
    setState(() => _busy = kind);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/admin/reports/${widget.reportId}/reviews', body: {
        'action': switch (kind) {
          'FOLLOW_UP' => 'REQUEST_FOLLOW_UP',
          'REVIEWED' => 'MARK_REVIEWED',
          _ => 'COMMENT',
        },
        if (comment.isNotEmpty) 'comment': comment,
      });
      _comment.clear();
      if (!mounted) return;
      ref.invalidate(adminReportDetailProvider);
      ref.invalidate(adminReportsProvider);
      ref.invalidate(adminMemberReportsProvider);
      ref.invalidate(adminSummaryProvider);
      Toast.success(
        context,
        switch (kind) {
          'COMMENT' => 'Comment added alongside the member’s answers.',
          'FOLLOW_UP' => 'Follow-up requested. The report now needs attention.',
          _ => 'Report marked as reviewed. Well done shepherding well!',
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save your review just now.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(adminReportDetailProvider(widget.reportId));

    return reportAsync.when(
      loading: () => ListView(
        padding: adminPadding(context),
        children: const [
          SkeletonBox(height: 120, radius: 14),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 260, radius: 14),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 180, radius: 14),
        ],
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminReportDetailProvider(widget.reportId)),
      ),
      data: (report) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminReportDetailProvider(widget.reportId));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: adminPadding(context),
          children: [
            _header(context, report),
            const SizedBox(height: AppSpacing.md),
            const AdminBanner(
              text:
                  'You cannot edit the member’s answers. Comments are added '
                  'alongside them.',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            _answers(context, report),
            const SizedBox(height: AppSpacing.lg),
            _reviewPanel(context, report),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- header

  Widget _header(BuildContext context, Report report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: report.memberName ?? 'Member'),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.memberName ?? 'Member',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${humanizeStatus(report.type)} report'
                      '${report.periodKey.isEmpty ? '' : ' · ${report.periodKey}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: humanizeStatus(report.status),
                tone: badgeToneFor(report.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              StatusBadge(
                label: humanizeStatus(report.type),
                tone: AppBadgeTone.navy,
                small: true,
              ),
              if (report.programmeYear != null)
                StatusBadge(
                  label: 'Year ${report.programmeYear}',
                  tone: AppBadgeTone.gold,
                  small: true,
                ),
              Text(
                'Submitted ${fmtDate(report.submittedAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (report.reviewedAt != null)
                Text(
                  'Reviewed ${fmtDate(report.reviewedAt)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- answers

  Widget _answers(BuildContext context, Report report) {
    final entries = report.answers.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Member’s Answers',
          subtitle: 'Read-only — recorded exactly as submitted',
          icon: Icons.subject_rounded,
        ),
        AppCard(
          child: entries.isEmpty
              ? Text(
                  'This report has no answers recorded.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries) ...[
                      _answer(context, entry.key, entry.value),
                      if (entry != entries.last) const Divider(height: 20),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _answer(BuildContext context, String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            humanizeKey(key),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy700,
                ),
          ),
          const SizedBox(height: 2),
          if (value == null)
            Text(
              '—',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (value is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(height: 1.5)),
                        Expanded(
                          child: Text(
                            strOf(item),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Text(
              strOf(value),
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------- review panel

  Widget _reviewPanel(BuildContext context, Report report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Review',
          subtitle: '${report.reviews.length} note(s) on this report',
          icon: Icons.rate_review_outlined,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (report.reviews.isEmpty)
                Text(
                  'No comments yet. A kind, specific note helps members grow.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Column(
                  children: [
                    for (final review in report.reviews)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: AppSpacing.controlRadius,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      review.reviewerName ?? 'Administrator',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: switch (review.kind) {
                                      'FOLLOW_UP' => 'Follow-up',
                                      'REVIEWED' => 'Reviewed',
                                      _ => 'Comment',
                                    },
                                    tone: switch (review.kind) {
                                      'FOLLOW_UP' => AppBadgeTone.info,
                                      'REVIEWED' => AppBadgeTone.success,
                                      _ => AppBadgeTone.neutral,
                                    },
                                    small: true,
                                  ),
                                ],
                              ),
                              if (review.comment != null &&
                                  review.comment!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  review.comment!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                fmtDateTime(review.createdAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const Divider(height: AppSpacing.xl),
              AppTextField(
                label: 'Add comment',
                controller: _comment,
                maxLines: 3,
                hint:
                    'Encouraging, specific feedback alongside the member’s '
                    'answers…',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppButton(
                    label: 'Add comment',
                    icon: Icons.chat_bubble_outline_rounded,
                    busy: _busy == 'COMMENT',
                    onPressed: () => _addReview('COMMENT'),
                  ),
                  AppButton(
                    label: 'Request follow-up',
                    icon: Icons.forward_outlined,
                    variant: AppButtonVariant.outlined,
                    busy: _busy == 'FOLLOW_UP',
                    onPressed: () =>
                        _addReview('FOLLOW_UP', confirmFirst: true),
                  ),
                  AppButton(
                    label: 'Mark as reviewed',
                    icon: Icons.check_circle_outline_rounded,
                    variant: AppButtonVariant.outlined,
                    busy: _busy == 'REVIEWED',
                    onPressed: () =>
                        _addReview('REVIEWED', confirmFirst: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
