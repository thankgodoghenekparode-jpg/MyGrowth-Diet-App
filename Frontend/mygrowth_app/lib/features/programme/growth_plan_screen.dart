import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/programme_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bible_reference_text.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../programme/programme_providers.dart';

/// My Growth Plan: the published monthly guidance for the programme year,
/// with a year switcher, month selector and weekly plans.
class GrowthPlanScreen extends ConsumerWidget {
  const GrowthPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _GrowthPlanView();
  }
}

class _GrowthPlanView extends ConsumerStatefulWidget {
  const _GrowthPlanView();

  @override
  ConsumerState<_GrowthPlanView> createState() => _GrowthPlanViewState();
}

class _GrowthPlanViewState extends ConsumerState<_GrowthPlanView> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final years = ref.watch(programmeYearsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(programmeYearsProvider);
        ref.invalidate(monthlyPlanProvider((year: _year, month: _month)));
        ref.invalidate(weeklyPlansProvider((year: _year, month: _month)));
        ref.invalidate(currentProgrammeProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          // ---------------------------------------- programme overview
          const _ProgrammeOverviewCard(),
          const SizedBox(height: AppSpacing.md),

          // --------------------------------------------- year switcher
          years.when(
            loading: () => const SkeletonBox(height: 40, radius: 10),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(programmeYearsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const SizedBox.shrink();
              }
              final yearValues = list.map((p) => p.year).toSet().toList()
                ..sort();
              if (!yearValues.contains(_year)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _year = yearValues.last);
                });
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note_outlined,
                          size: 18, color: AppColors.navy700),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Programme year',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final year in yearValues)
                        ChoiceChip(
                          label: Text('$year'),
                          selected: year == _year,
                          onSelected: (_) => setState(() => _year = year),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------- month selector
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final month = i + 1;
                return ChoiceChip(
                  label: Text(DateFormat.MMM().format(DateTime(2000, month))),
                  selected: month == _month,
                  onSelected: (_) => setState(() => _month = month),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const _ProgramReviewSection(),
          const SizedBox(height: AppSpacing.lg),

          // ----------------------------------------- month's content
          _MonthlyPlanContent(year: _year, month: _month),
        ],
      ),
    );
  }
}

const _programReviewItems = <_ProgramReviewItem>[
  _ProgramReviewItem(
    title: 'Prayers',
    subtitle: 'Prayer room and prayer focus',
    icon: Icons.self_improvement_outlined,
    route: '/prayer',
  ),
  _ProgramReviewItem(
    title: 'Bible Reading',
    subtitle: 'Monthly reading guidance',
    icon: Icons.auto_stories_outlined,
    route: '/bible-reading',
  ),
  _ProgramReviewItem(
    title: 'Bible Study Topics',
    subtitle: 'Study notes and Bible resources',
    icon: Icons.menu_book_outlined,
    route: '/diet?section=bible_study',
  ),
  _ProgramReviewItem(
    title: 'Literature Daily Read',
    subtitle: 'Today’s reading assignment',
    icon: Icons.local_library_outlined,
    route: '/diet?section=literature_reading',
  ),
  _ProgramReviewItem(
    title: 'Weekly Audio Messages',
    subtitle: 'Audio messages and teaching resources',
    icon: Icons.headphones_outlined,
    route: '/diet?section=audio_message',
  ),
  _ProgramReviewItem(
    title: 'Daily Affirmation',
    subtitle: 'Read this year’s affirmation',
    icon: Icons.format_quote_outlined,
    affirmation: true,
  ),
  _ProgramReviewItem(
    title: 'Daily Proverbs Read',
    subtitle: 'Open Proverbs chapter 1',
    icon: Icons.menu_book_outlined,
    route: '/bible?book=Proverbs&chapter=1',
  ),
  _ProgramReviewItem(
    title: 'Daily Devotional Read',
    subtitle: 'Open today’s devotional',
    icon: Icons.wb_sunny_outlined,
    route: '/devotion',
  ),
  _ProgramReviewItem(
    title: 'Declarations',
    subtitle: 'Today’s declarations and growth activities',
    icon: Icons.record_voice_over_outlined,
    route: '/diet?section=declarations',
  ),
  _ProgramReviewItem(
    title: 'Fasting and Prayer Days',
    subtitle: 'View and manage fasting days',
    icon: Icons.event_available_outlined,
    route: '/fasting',
  ),
  _ProgramReviewItem(
    title: 'Prayer Accountability Partner',
    subtitle: 'Connect with your prayer partner',
    icon: Icons.handshake_outlined,
    route: '/prayer/partners',
  ),
  _ProgramReviewItem(
    title: 'Weekly, Monthly & Annual Reports',
    subtitle: 'Write and review your reports',
    icon: Icons.fact_check_outlined,
    route: '/reports',
  ),
];

class _ProgramReviewItem {
  const _ProgramReviewItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
    this.affirmation = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final bool affirmation;
}

class _ProgramReviewSection extends ConsumerWidget {
  const _ProgramReviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(currentProgrammeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Program Review',
          subtitle: 'Tap a card to open its page or reading.',
          icon: Icons.dashboard_customize_outlined,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                    ? 3
                    : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _programReviewItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
                childAspectRatio: columns == 2 ? 1.45 : 1.7,
              ),
              itemBuilder: (context, index) {
                final item = _programReviewItems[index];
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  onTap: () {
                    if (item.affirmation) {
                      programme.when(
                        data: (value) => _showPlanContent(
                          context,
                          title: item.title,
                          text: value?.dailyAffirmation?.trim().isNotEmpty ==
                                  true
                              ? value!.dailyAffirmation!
                              : 'The daily affirmation has not been published yet.',
                          icon: item.icon,
                        ),
                        loading: () => _showPlanContent(
                          context,
                          title: item.title,
                          text: 'Loading the daily affirmation…',
                          icon: item.icon,
                        ),
                        error: (_, _) => _showPlanContent(
                          context,
                          title: item.title,
                          text:
                              'The daily affirmation is unavailable right now.',
                          icon: item.icon,
                        ),
                      );
                    } else if (item.route != null) {
                      context.push(item.route!);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, size: 19, color: AppColors.navy700),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              size: 20, color: AppColors.inkMuted),
                        ],
                      ),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Expandable card with the annual prayer focus + daily affirmation.
class _ProgrammeOverviewCard extends ConsumerWidget {
  const _ProgrammeOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(currentProgrammeProvider);
    return programme.when(
      loading: () => const SkeletonBox(height: 120, radius: 14),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(currentProgrammeProvider),
      ),
      data: (programme) {
        if (programme == null) return const SizedBox.shrink();
        return AppCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading:
                  Icon(Icons.auto_awesome_outlined, color: AppColors.gold600),
              title: Text(
                'Programme overview',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                programme.title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (programme.prayerFocus != null &&
                          programme.prayerFocus!.isNotEmpty) ...[
                        VerseCard(
                          tone: VerseTone.navy,
                          label: '${programme.year} Prayer Focus',
                          text: programme.prayerFocus!,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (programme.dailyAffirmation != null &&
                          programme.dailyAffirmation!.isNotEmpty)
                        VerseCard(
                          tone: VerseTone.gold,
                          label: 'Daily Affirmation',
                          text: programme.dailyAffirmation!,
                          icon: Icons.wb_sunny_outlined,
                        ),
                      if ((programme.prayerFocus == null ||
                              programme.prayerFocus!.isEmpty) &&
                          (programme.dailyAffirmation == null ||
                              programme.dailyAffirmation!.isEmpty))
                        Text(
                          'The ${programme.year} prayer focus and daily '
                          'affirmation will appear here once published.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The selected month's published content plus its weekly plans.
class _MonthlyPlanContent extends ConsumerWidget {
  const _MonthlyPlanContent({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(monthlyPlanProvider((year: year, month: month)));
    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));

    return plan.when(
      loading: () => const CardListSkeleton(count: 3),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () =>
            ref.invalidate(monthlyPlanProvider((year: year, month: month))),
      ),
      data: (plan) {
        if (plan == null) {
          return AppCard(
            child: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No published plan for $monthName',
              message:
                  'Your ministry hasn’t published guidance for this month '
                  'yet. Follow the current month’s plan in the meantime — it '
                  'will appear here as soon as it is ready.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------- theme
            TitledCard(
              icon: Icons.menu_book_outlined,
              title: 'Theme & Study Topic',
              onTap: () => _showPlanContent(
                context,
                title: 'Theme & Study Topic',
                text: (plan.theme == null || plan.theme!.trim().isEmpty)
                    ? 'The theme for this month is being prepared.'
                    : plan.theme!,
                icon: Icons.menu_book_outlined,
              ),
              child: Text(
                (plan.theme == null || plan.theme!.trim().isEmpty)
                    ? 'The theme for this month is being prepared.'
                    : plan.theme!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(height: 1.45),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // -------------------------------------------- prayer focus
            if (_hasText(plan.prayerFocus)) ...[
              VerseCard(
                tone: VerseTone.navy,
                label: 'Prayer Focus',
                text: plan.prayerFocus!,
                onTap: () => _showPlanContent(
                  context,
                  title: 'Prayer Focus',
                  text: plan.prayerFocus!,
                  icon: Icons.favorite_outline,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // --------------------------------------- bible reading
            if (_hasText(plan.bibleReadingGuidance)) ...[
              TitledCard(
                icon: Icons.auto_stories_outlined,
                title: 'Bible Reading Guidance',
                onTap: () => _showPlanContent(
                  context,
                  title: 'Bible Reading Guidance',
                  text: plan.bibleReadingGuidance!,
                  icon: Icons.auto_stories_outlined,
                  bibleReferences: true,
                ),
                child: BibleReferenceText(
                  text: plan.bibleReadingGuidance!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.55, color: AppColors.inkSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // -------------------------------------------- confession
            if (_hasText(plan.confession)) ...[
              VerseCard(
                tone: VerseTone.gold,
                label: 'Monthly Confession',
                text: plan.confession!,
                onTap: () => _showPlanContent(
                  context,
                  title: 'Monthly Confession',
                  text: plan.confession!,
                  icon: Icons.format_quote_rounded,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // -------------------------------------------- literature
            if (_hasText(plan.literatureList)) ...[
              TitledCard(
                icon: Icons.local_library_outlined,
                title: 'Literature List',
                onTap: () => _showPlanContent(
                  context,
                  title: 'Literature List',
                  text: plan.literatureList!,
                  icon: Icons.local_library_outlined,
                ),
                child: _GuidanceText(plan.literatureList!),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ----------------------------------------- audio messages
            if (_hasText(plan.audioMessageList)) ...[
              TitledCard(
                icon: Icons.headphones_outlined,
                title: 'Audio Messages',
                onTap: () => _showPlanContent(
                  context,
                  title: 'Audio Messages',
                  text: plan.audioMessageList!,
                  icon: Icons.headphones_outlined,
                ),
                child: _GuidanceText(plan.audioMessageList!),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // --------------------------------------------- fasting
            if (_hasText(plan.fastingGuidance)) ...[
              TitledCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Fasting Guidance',
                onTap: () => _showPlanContent(
                  context,
                  title: 'Fasting Guidance',
                  text: plan.fastingGuidance!,
                  icon: Icons.wb_sunny_outlined,
                ),
                child: _GuidanceText(plan.fastingGuidance!),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // -------------------------------------------- goals
            if (_hasText(plan.goalsGuidance)) ...[
              TitledCard(
                icon: Icons.flag_outlined,
                title: 'Monthly Goals',
                onTap: () => _showPlanContent(
                  context,
                  title: 'Monthly Goals',
                  text: plan.goalsGuidance!,
                  icon: Icons.flag_outlined,
                ),
                child: _GuidanceText(plan.goalsGuidance!),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // ------------------------------- reflection questions
            TitledCard(
              icon: Icons.edit_note_outlined,
              title: 'Reflection Questions',
              onTap: () => _showPlanContent(
                context,
                title: 'Reflection Questions',
                text: plan.reflectionQuestions.isEmpty
                    ? 'Reflection questions for this month haven’t been published yet.'
                    : plan.reflectionQuestions
                        .asMap()
                        .entries
                        .map((entry) => '${entry.key + 1}. ${entry.value}')
                        .join('\n\n'),
                icon: Icons.edit_note_outlined,
              ),
              child: plan.reflectionQuestions.isEmpty
                  ? Text(
                      'Reflection questions for this month haven’t been '
                      'published yet.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0;
                            i < plan.reflectionQuestions.length;
                            i++)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.navy800,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    plan.reflectionQuestions[i],
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----------------------------------------- weekly plans
            _WeeklyPlansSection(year: year, month: month),
          ],
        );
      },
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

void _showPlanContent(
  BuildContext context, {
  required String title,
  required String text,
  required IconData icon,
  bool bibleReferences = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(icon, color: AppColors.navy700),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: bibleReferences
                    ? BibleReferenceText(
                        text: text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      )
                    : Text(
                        text,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Multi-line guidance text that respects existing line breaks.
class _GuidanceText extends StatelessWidget {
  const _GuidanceText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(height: 1.55, color: AppColors.inkSecondary),
    );
  }
}

/// Weekly plans for the month; may legitimately be empty until ministry
/// administrators publish them.
class _WeeklyPlansSection extends ConsumerWidget {
  const _WeeklyPlansSection({required this.year, required this.month});

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(weeklyPlansProvider((year: year, month: month)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Weekly Plans',
          subtitle: DateFormat('MMMM yyyy').format(DateTime(year, month)),
          icon: Icons.view_week_outlined,
        ),
        weeks.when(
          loading: () => const CardListSkeleton(count: 2),
          error: (e, _) => ErrorState(
            error: e,
            compact: true,
            onRetry: () =>
                ref.invalidate(weeklyPlansProvider((year: year, month: month))),
          ),
          data: (list) {
            if (list.isEmpty) {
              return AppCard(
                child: EmptyState(
                  icon: Icons.pending_actions_outlined,
                  title: 'Weekly assignments coming soon',
                  message:
                      'Weekly assignments are added by your ministry '
                      'administrators. Until they are published, please '
                      'follow the monthly guidance above.',
                ),
              );
            }
            final sorted = [...list]
              ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
            return Column(
              children: [
                for (final week in sorted) ...[
                  _WeekCard(week: week),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final WeeklyPlan week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateRange = _formatRange(week.startDate, week.endDate);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_week_outlined,
                  size: 18, color: AppColors.navy700),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Week ${week.weekNumber}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (dateRange != null)
                StatusBadge(label: dateRange, tone: AppBadgeTone.navy, small: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (week.bibleReading != null) ...[
            _WeekRow(
              icon: Icons.auto_stories_outlined,
              label: 'Bible reading',
              value: week.bibleReading!,
              bibleReference: true,
            ),
          ],
          if (week.prayerDurationTarget != null)
            _WeekRow(
              icon: Icons.self_improvement_outlined,
              label: 'Prayer target',
              value: week.prayerDurationTarget!,
            ),
          if (week.bookReading != null)
            _WeekRow(
              icon: Icons.menu_book_outlined,
              label: 'Book reading',
              value: week.bookReading!,
            ),
          if (week.fastingSchedule != null)
            _WeekRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Fasting',
              value: week.fastingSchedule!,
            ),
          if (week.keyLessonPrompt != null)
            _WeekRow(
              icon: Icons.lightbulb_outline,
              label: 'Key lesson prompt',
              value: week.keyLessonPrompt!,
            ),
          if (week.memoryVerse != null && week.memoryVerse!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: VerseCard(
                tone: VerseTone.light,
                label: 'Memory Verse',
                text: week.memoryVerse!,
                icon: Icons.format_quote_rounded,
              ),
            ),
        ],
      ),
    );
  }

  String? _formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return null;
    final fmt = DateFormat('d MMM');
    final yearFmt = DateFormat('d MMM yyyy');
    if (start != null && end != null) {
      if (start.year == end.year) {
        return '${fmt.format(start)} – ${yearFmt.format(end)}';
      }
      return '${yearFmt.format(start)} – ${yearFmt.format(end)}';
    }
    return start != null
        ? 'From ${yearFmt.format(start)}'
        : 'Until ${yearFmt.format(end!)}';
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bibleReference = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool bibleReference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                if (bibleReference)
                  BibleReferenceText(
                    text: value,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  )
                else
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
