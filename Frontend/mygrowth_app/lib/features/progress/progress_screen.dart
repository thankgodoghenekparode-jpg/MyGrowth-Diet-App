import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/activity_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import 'progress_providers.dart';

/// My Progress: self-reported participation metrics, a monthly bar chart
/// and a per-category breakdown.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(progressSummaryProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('My Progress', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            'A record of your self-reported participation — encouraging, '
            'never a measure of spiritual worth.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          summary.when(
            loading: () => const CardListSkeleton(count: 4),
            error: (error, _) {
              if (error is ApiException &&
                  (error.statusCode == 404 || error.statusCode == 501)) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Progress insights are being set up',
                    message:
                        'Your progress dashboard is getting ready behind the '
                        'scenes. In the meantime, your Daily Diet records '
                        'and reports are safely saved.',
                  ),
                );
              }
              return ErrorState(
                error: error,
                onRetry: () => ref.invalidate(progressSummaryProvider),
              );
            },
            data: (data) => _ProgressBody(summary: data),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'At a glance',
          subtitle: 'Self-reported & recorded participation',
          icon: Icons.query_stats_outlined,
        ),
        _StatTileGrid(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _MonthlyChart(summary: summary),
        const SizedBox(height: AppSpacing.lg),
        _CategoryBreakdown(summary: summary),
        const SizedBox(height: AppSpacing.lg),
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
                  'These metrics reflect participation in your diet plan — '
                  'they are self-reported records, not a measure of your '
                  'spiritual worth. Grace covers every gap.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSecondary,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Responsive grid of stat tiles.
class _StatTileGrid extends StatelessWidget {
  const _StatTileGrid({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 440
                ? 2
                : 1;
        const spacing = AppSpacing.sm;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final tiles = <Widget>[
          StatTile(
            label: 'Activities recorded',
            value: '${summary.completedActivities}',
            caption: 'of ${summary.totalActivities} planned',
            icon: Icons.checklist_rounded,
          ),
          StatTile(
            label: 'Completion',
            value: '${(summary.completionRate * 100).round()}%',
            caption: 'self-reported',
            icon: Icons.percent_outlined,
            tone: StatTileTone.success,
          ),
          StatTile(
            label: 'Minutes recorded',
            value: '${summary.totalMinutesRecorded}',
            icon: Icons.timer_outlined,
            tone: StatTileTone.info,
          ),
          StatTile(
            label: 'Reports submitted',
            value: '${summary.reportsSubmitted}',
            icon: Icons.fact_check_outlined,
          ),
          StatTile(
            label: 'Prayer sessions',
            value: '${summary.sessionsCompleted}',
            icon: Icons.self_improvement_outlined,
            tone: StatTileTone.gold,
          ),
          StatTile(
            label: 'Current streak',
            value: '${summary.currentStreakDays} day${summary.currentStreakDays == 1 ? '' : 's'}',
            caption: 'of recorded days',
            icon: Icons.local_fire_department_outlined,
            tone: StatTileTone.gold,
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// Monthly activity bar chart (navy bars, gold for the current month).
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final months = [...summary.byMonth]
      ..sort((a, b) => (a.year * 12 + a.month) - (b.year * 12 + b.month));
    final now = DateTime.now();

    return TitledCard(
      icon: Icons.bar_chart_rounded,
      title: 'Activities completed by month',
      trailing: Text(
        'Self-reported',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: months.isEmpty
          ? EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No records yet',
              message:
                  'As soon as you record activities in your Daily Diet, '
                  'your monthly picture will appear here.',
            )
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: _maxCompleted(months) + 1,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: months[i].completed.toDouble(),
                            width: 16,
                            color: months[i].month == now.month &&
                                    months[i].year == now.year
                                ? AppColors.gold500
                                : AppColors.navy700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= months.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat.MMM()
                                  .format(DateTime(2000, months[index].month)),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  double _maxCompleted(List<MonthTally> months) {
    var max = 0;
    for (final m in months) {
      if (m.completed > max) max = m.completed;
    }
    return max.toDouble();
  }
}

/// Per-category breakdown of recorded activities.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        entries.isEmpty ? 0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return TitledCard(
      icon: Icons.donut_small_outlined,
      title: 'By category',
      trailing: Text(
        'Recorded',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: entries.isEmpty
          ? Text(
              'No recorded activities yet. Your categories will appear here '
              'as you check things off in the Daily Diet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkMuted),
            )
          : Column(
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(entry.key),
                          size: 18,
                          color: AppColors.navy600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      humanizeStatus(entry.key),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.gold600,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ProgressBar(
                                value: maxCount == 0
                                    ? 0
                                    : entry.value / maxCount,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  IconData _categoryIcon(String categoryKey) {
    switch (categoryKey) {
      case 'prayer':
        return Icons.self_improvement;
      case 'scripture_reading':
      case 'proverbs_reading':
        return Icons.menu_book;
      case 'bible_study':
        return Icons.history_edu;
      case 'literature_reading':
        return Icons.auto_stories;
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
}
