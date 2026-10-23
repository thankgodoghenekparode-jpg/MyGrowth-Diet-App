import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'reports_providers.dart';

/// Read-only view of a submitted report with admin reviews and a
/// follow-up reply affordance.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportDetailProvider(reportId));
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 6),
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(reportDetailProvider(reportId)),
        ),
        data: (report) {
          if (report == null) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Report not found',
              message:
                  'This report may have been removed. Head back to the list '
                  'to see your other reports.',
            );
          }
          return _ReportDetailView(report: report);
        },
      ),
    );
  }
}

class _ReportDetailView extends ConsumerStatefulWidget {
  const _ReportDetailView({required this.report});

  final Report report;

  @override
  ConsumerState<_ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends ConsumerState<_ReportDetailView> {
  bool _busy = false;

  Report get report => widget.report;

  Future<void> _sendReply(String message) async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final answers = Map<String, dynamic>.from(report.answers)
      ..['followUpReply'] = message.trim();
    try {
      await client.patch('/me/reports/${report.id}', body: {'answers': answers});
      ref.invalidate(reportDetailProvider(report.id));
      ref.invalidate(reportsListProvider(report.type));
      if (mounted) {
        Toast.success(
          context,
          'Reply sent. Your updated answers are back with the reviewers.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to send the reply just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReplySheet() async {
    final controller = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply / update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Administrators asked for a follow-up on this report. Share an '
              'update or answer their question below.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Your reply',
              required: true,
              controller: controller,
              maxLines: 5,
              hint: 'Type your update…',
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim().isNotEmpty),
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    if (sent == true && mounted) {
      await _sendReply(controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = report.submittedAt?.toLocal();
    final wide = !Breakpoints.isCompact(context);
    final specs = reportFieldsFor(report.type);

    // Answers the form knows about, rendered via specs; anything else is
    // appended with a humanized label.
    final knownKeys = <String>{};
    for (final spec in specs) {
      knownKeys
        ..add(spec.key)
        ..add('${spec.key}Comment')
        ..add('${spec.key}Rating')
        ..add('${spec.key}Title')
        ..add('${spec.key}Status');
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportDetailProvider(report.id));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: ListView(
        padding: wide
            ? const EdgeInsets.all(AppSpacing.xl)
            : AppSpacing.pagePaddingMobile,
        children: [
          // ------------------------------------------------- header card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${humanizeStatus(report.type)} report — '
                        '${humanizePeriodKey(report.periodKey)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(
                      label: humanizeStatus(report.status),
                      tone: badgeToneFor(report.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  submittedAt == null
                      ? 'Not yet submitted'
                      : 'Submitted ${DateFormat('d MMM yyyy, HH:mm').format(submittedAt)}'
                          '${report.reviewedAt != null ? ' · reviewed ${DateFormat('d MMM yyyy').format(report.reviewedAt!.toLocal())}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (report.revisionCount > 0)
                  Text(
                    'Revision ${report.revisionCount}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------- follow-up notice
          if (report.needsAttention) ...[
            AppCard(
              color: AppColors.infoSurface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Follow-up requested',
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
                    'Your ministry administrators reviewed this report and '
                    'asked for a follow-up. Check the reviews below, then '
                    'send an update — grace upon grace, you’re doing well.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Reply / update',
                    icon: Icons.reply_rounded,
                    busy: _busy,
                    onPressed: _openReplySheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ------------------------------------------------- answers
          const SectionHeader(
            title: 'Your answers',
            subtitle: 'Exactly what you shared',
            icon: Icons.edit_note_outlined,
          ),
          for (final spec in specs)
            _AnswerCard(
              title: spec.label,
              body: _answerText(report, spec),
              rating: spec.kind == ReportFieldKind.rating
                  ? report.answerFor('${spec.key}Rating')
                  : '',
            ),
          for (final entry in report.answers.entries)
            if (!knownKeys.contains(entry.key) &&
                entry.key != 'followUpReply')
              _AnswerCard(
                title: reportAnswerLabel(entry.key),
                body: report.answerFor(entry.key),
              ),

          // ------------------------------------------- follow-up reply
          if (report.answerFor('followUpReply').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _AnswerCard(
              title: 'Your follow-up reply',
              body: report.answerFor('followUpReply'),
              isReply: true,
            ),
          ],

          // ------------------------------------------- admin reviews
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Administrator reviews',
            subtitle:
                'Notes from your ministry leaders — never shared publicly',
            icon: Icons.supervisor_account_outlined,
          ),
          if (report.reviews.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No reviews yet',
                message:
                    'When an administrator reviews this report, their notes '
                    'will appear here.',
              ),
            )
          else
            for (final review in report.reviews) ...[
              _ReviewCard(review: review),
              const SizedBox(height: AppSpacing.xs),
            ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _answerText(Report report, ReportFieldSpec spec) {
    final direct = report.answerFor(spec.key);
    final comment = report.answerFor('${spec.key}Comment');
    final title = report.answerFor('${spec.key}Title');
    final status = report.answerFor('${spec.key}Status');
    final parts = <String>[
      if (title.isNotEmpty) title,
      if (status.isNotEmpty) 'Status: ${humanizeStatus(status)}',
      if (direct.isNotEmpty) direct,
      if (comment.isNotEmpty) comment,
    ];
    return parts.join('\n');
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.title,
    required this.body,
    this.rating = '',
    this.isReply = false,
  });

  final String title;
  final String body;
  final String rating;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty && rating.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        color: isReply ? AppColors.gold100 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (rating.isNotEmpty)
                  StatusBadge(
                    label: humanizeStatus(rating),
                    tone: badgeToneFor(rating),
                    small: true,
                  ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6, color: AppColors.inkSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReportReview review;

  @override
  Widget build(BuildContext context) {
    final createdAt = review.createdAt?.toLocal();
    return AppCard(
      color: AppColors.navy50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 16, color: AppColors.navy700),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  review.reviewerName ?? 'Ministry administrator',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(review.kind),
                tone: review.kind == 'FOLLOW_UP'
                    ? AppBadgeTone.info
                    : AppBadgeTone.navy,
                small: true,
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.comment!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.55),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              DateFormat('d MMM yyyy, HH:mm').format(createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
