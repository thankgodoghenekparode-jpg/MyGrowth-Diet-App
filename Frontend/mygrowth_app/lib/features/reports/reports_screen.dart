import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/report_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import 'reports_providers.dart';

/// Accountability reports: browse drafts and submitted reports per type.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accountability Reports'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
              Tab(text: 'Quarterly'),
              Tab(text: 'Annual'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReportsTab(type: 'WEEKLY'),
            _ReportsTab(type: 'MONTHLY'),
            _ReportsTab(type: 'QUARTERLY'),
            _ReportsTab(type: 'ANNUAL'),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reportsListProvider(type));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reportsListProvider(type));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 4),
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(reportsListProvider(type)),
            ),
          ],
        ),
        data: (reports) {
          final wide = !Breakpoints.isCompact(context);
          final padding =
              wide ? const EdgeInsets.all(AppSpacing.xl) : AppSpacing.pagePaddingMobile;
          return ListView(
            padding: padding,
            children: [
              AppCard(
                color: AppColors.navy50,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'These reports are shared with ministry '
                        'administrators for accountability review. Your '
                        'private reflections and journal entries are never '
                        'included.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: 'Start new report',
                      icon: Icons.add_rounded,
                      onPressed: () =>
                          context.go('/reports/new/${type.toLowerCase()}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (reports.isEmpty)
                EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No ${humanizeStatus(type).toLowerCase()} reports yet',
                  message:
                      'Start your first ${humanizeStatus(type).toLowerCase()} '
                      'report whenever you’re ready — drafts save as you go.',
                  actionLabel: 'Start new report',
                  onAction: () =>
                      context.go('/reports/new/${type.toLowerCase()}'),
                )
              else
                for (final report in reports) ...[
                  _ReportCard(report: report),
                  const SizedBox(height: AppSpacing.xs),
                ],
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final submitted = report.submittedAt?.toLocal();
    return AppCard(
      onTap: () => context.go(report.isDraft
          ? '/reports/edit/${report.id}'
          : '/reports/${report.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.navy100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: AppColors.navy700,
              size: 21,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  humanizePeriodKey(report.periodKey),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  submitted == null
                      ? 'Draft — not yet submitted'
                      : 'Submitted ${DateFormat('d MMM yyyy').format(submitted)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge(
                      label: humanizeStatus(report.status),
                      tone: badgeToneFor(report.status),
                      small: true,
                    ),
                    if (report.revisionCount > 0)
                      StatusBadge(
                        label:
                            '${report.revisionCount} revision${report.revisionCount == 1 ? '' : 's'}',
                        tone: AppBadgeTone.neutral,
                        small: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (report.isDraft)
                AppButton(
                  label: 'Continue editing',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => context.go('/reports/edit/${report.id}'),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.inkMuted),
            ],
          ),
        ],
      ),
    );
  }
}
