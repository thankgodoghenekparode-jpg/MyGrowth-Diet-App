import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Analytics: aggregate participation only.
///
/// Private reflections, journal entries and prayer-session text are never
/// included — every figure here is a count or an aggregate.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AnalyticsBody();
  }
}

class _AnalyticsBody extends ConsumerStatefulWidget {
  const _AnalyticsBody();

  @override
  ConsumerState<_AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends ConsumerState<_AnalyticsBody> {
  int _year = DateTime.now().year;
  int _month = 0; // 0 = whole year

  @override
  Widget build(BuildContext context) {
    final query = (year: _year, month: _month, period: '');
    final overview = ref.watch(adminAnalyticsOverviewProvider(query));
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAnalyticsOverviewProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Analytics',
            subtitle: 'Aggregate participation across the ministry',
            icon: Icons.query_stats_outlined,
          ),
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
                      for (var y = DateTime.now().year + 1;
                          y >= DateTime.now().year - 4;
                          y--)
                        DropdownMenuItem(value: y, child: Text('$y')),
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
                      const DropdownMenuItem(value: 0, child: Text('Whole year')),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(monthNameOf(m)),
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
          const SizedBox(height: AppSpacing.md),
          overview.when(
            loading: () => metricGrid(
              context,
              const [
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
                SkeletonBox(height: 96, radius: 14),
              ],
            ),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminAnalyticsOverviewProvider),
            ),
            data: (data) => data.isEmpty
                ? AppCard(
                    child: EmptyState(
                      icon: Icons.query_stats_outlined,
                      title: 'No analytics for this period',
                      message:
                          'Try another year or month, or check back once '
                          'members have recorded activity.',
                      actionLabel: 'Clear filters',
                      onAction: () => setState(() {
                        _year = DateTime.now().year;
                        _month = 0;
                      }),
                    ),
                  )
                : _AnalyticsContent(
                    data: data,
                    year: _year,
                    month: _month,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AdminBanner(
            tone: AdminBannerTone.navy,
            icon: Icons.lock_outline_rounded,
            text:
                'Aggregates only — private reflections and journal content are '
                'never included in analytics.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _AnalyticsContent extends ConsumerStatefulWidget {
  const _AnalyticsContent({
    required this.data,
    required this.year,
    required this.month,
  });

  final Map<String, dynamic> data;
  final int year;
  final int month;

  @override
  ConsumerState<_AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends ConsumerState<_AnalyticsContent> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final d = widget.data;
      final members = asJsonMap(d['members']);
      final reports = asJsonMap(d['reports']);
      final completion = asJsonMap(d['activityCompletion']);
      final prayer = asJsonMap(d['prayerSessions']);
      final buffer = StringBuffer()
        ..writeln('MyGrowth Diet App — analytics summary')
        ..writeln('Generated: ${fmtDateTime(DateTime.now())}')
        ..writeln(
          'Period: ${widget.month == 0 ? 'the whole of ${widget.year}' : '${monthNameOf(widget.month)} ${widget.year}'}',
        )
        ..writeln('—')
        ..writeln('Members')
        ..writeln('  Total: ${statOrDash(members['total'])}')
        ..writeln('  Active in period: ${statOrDash(members['activeDuringPeriod'])}')
        ..writeln('  Pending approval: ${statOrDash(members['pending'])}')
        ..writeln('Reports')
        ..writeln('  Submitted (non-draft): ${statOrDash(reports['totalNonDraft'])}')
        ..writeln('  Awaiting review: ${statOrDash(reports['awaitingReview'])}')
        ..writeln('Activity')
        ..writeln('  Total records: ${statOrDash(completion['totalRecords'])}')
        ..writeln('Prayer sessions')
        ..writeln('  Completed: ${statOrDash(prayer['COMPLETED'])}')
        ..writeln('—')
        ..writeln(
          'Aggregates only — private reflections and journal content are never '
          'included in analytics.',
        );
      if (!mounted) return;
      await showCopyableSheet(
        context,
        title: 'Copy analytics summary',
        body: buffer.toString(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t build the summary just now.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final members = asJsonMap(d['members']);
    final reports = asJsonMap(d['reports']);
    final completion = asJsonMap(d['activityCompletion']);
    final prayer = asJsonMap(d['prayerSessions']);
    final byStatus = asJsonMap(completion['byStatus']);
    final totalRecords = pickNum(completion, const ['totalRecords']) ?? 0;
    final completed = pickNum(byStatus, const ['COMPLETED']) ?? 0;
    final rate = totalRecords == 0 ? null : completed / totalRecords;

    final byCategory = pickMaps(
      completion,
      const ['completedByCategory'],
    )
        .map((row) => (
              key: strOf(row['category'], 'custom'),
              value: pickNum(row, const ['completed']) ?? 0,
            ))
        .where((row) => row.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final participation = pickMaps(d, const ['participationOverTime']);
    final reportsOverTime = pickMaps(d, const ['reportsOverTime']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        metricGrid(context, [
          StatTile(
            label: 'Members',
            value: statOrDash(members['total']),
            icon: Icons.people_outline_rounded,
          ),
          StatTile(
            label: 'Active in period',
            value: statOrDash(members['activeDuringPeriod']),
            icon: Icons.verified_user_outlined,
            tone: StatTileTone.gold,
          ),
          StatTile(
            label: 'Reports submitted',
            value: statOrDash(reports['totalNonDraft']),
            icon: Icons.task_alt_rounded,
            tone: StatTileTone.success,
          ),
          StatTile(
            label: 'Awaiting review',
            value: statOrDash(reports['awaitingReview']),
            icon: Icons.rate_review_outlined,
            tone: StatTileTone.info,
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        metricGrid(context, [
          StatTile(
            label: 'Activity completion',
            caption: 'aggregate, self-reported',
            value: percentText(rate),
            icon: Icons.check_circle_outline_rounded,
            tone: StatTileTone.success,
          ),
          StatTile(
            label: 'Prayer sessions',
            caption: 'completed',
            value: statOrDash(prayer['COMPLETED']),
            icon: Icons.self_improvement_outlined,
            tone: StatTileTone.gold,
          ),
          StatTile(
            label: 'Announcements',
            caption: 'published',
            value: statOrDash(d['announcementsPublished']),
            icon: Icons.campaign_outlined,
          ),
          StatTile(
            label: 'Open safety reports',
            value: statOrDash(d['openSafetyReports']),
            icon: Icons.health_and_safety_outlined,
            tone: StatTileTone.danger,
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Every figure is an aggregate count.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            AppButton(
              label: 'Copy summary',
              icon: Icons.ios_share_rounded,
              variant: AppButtonVariant.outlined,
              busy: _exporting,
              onPressed: _export,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CategoryChart(rows: byCategory),
        const SizedBox(height: AppSpacing.sm),
        _ParticipationChart(rows: participation),
        const SizedBox(height: AppSpacing.sm),
        _ReportsChart(rows: reportsOverTime),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.rows});

  final List<({String key, num value})> rows;

  @override
  Widget build(BuildContext context) {
    return TitledCard(
      icon: Icons.donut_small_outlined,
      title: 'Completed by category',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.donut_small_outlined,
              title: 'No completed activities',
              message:
                  'Once members complete recorded activities, the category '
                  'breakdown appears here.',
            )
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: rows.first.value.toDouble() + 1,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < rows.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: rows[i].value.toDouble(),
                            width: 16,
                            color: AppColors.navy700,
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
                        reservedSize: 32,
                        interval: 1,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= rows.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6, right: 4),
                            child: SizedBox(
                              width: 60,
                              child: Text(
                                activityCategoryLabel(rows[index].key),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
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
}

class _ParticipationChart extends StatelessWidget {
  const _ParticipationChart({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final data = rows
        .map((row) => (
              month: strOf(row['month']),
              value: pickNum(row, const ['activityRecords', 'records']) ?? 0,
            ))
        .toList();
    var maxY = 0.0;
    for (final row in data) {
      if (row.value.toDouble() > maxY) maxY = row.value.toDouble();
    }

    return TitledCard(
      icon: Icons.show_chart_rounded,
      title: 'Activity records over time',
      child: data.isEmpty
          ? const EmptyState(
              icon: Icons.show_chart_rounded,
              title: 'No activity records yet',
              message: 'Monthly activity volume will appear here.',
            )
          : SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY + 1,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[i].value.toDouble(),
                            width: 14,
                            color: AppColors.gold500,
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
                        reservedSize: 32,
                        interval: 1,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              data[index].month,
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
}

class _ReportsChart extends StatelessWidget {
  const _ReportsChart({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final data = rows
        .map((row) => (
              month: strOf(row['month']),
              submitted: pickNum(row, const ['submitted']) ?? 0,
              reviewed: pickNum(row, const ['reviewed']) ?? 0,
            ))
        .toList();
    var maxY = 0.0;
    for (final row in data) {
      final peak = row.submitted > row.reviewed ? row.submitted : row.reviewed;
      if (peak.toDouble() > maxY) maxY = peak.toDouble();
    }

    return TitledCard(
      icon: Icons.fact_check_outlined,
      title: 'Reports submitted vs reviewed',
      trailing: Text(
        'submitted / reviewed',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: data.isEmpty
          ? const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No reports in this period',
              message: 'Submitted and reviewed report counts will appear here.',
            )
          : SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY + 1,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: data[i].submitted.toDouble(),
                            width: 10,
                            color: AppColors.navy700,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: data[i].reviewed.toDouble(),
                            width: 10,
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(3),
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
                        reservedSize: 32,
                        interval: 1,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              data[index].month,
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
}
