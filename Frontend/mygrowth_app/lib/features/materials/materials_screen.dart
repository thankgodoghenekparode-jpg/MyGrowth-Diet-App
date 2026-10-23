import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/material_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/pagination.dart';
import 'materials_providers.dart';

/// Study Materials Library: server-side search, category/month filters,
/// sort and pagination, plus a personal reading-list tab.
class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MaterialsView();
  }
}

class _MaterialsView extends ConsumerStatefulWidget {
  const _MaterialsView();

  @override
  ConsumerState<_MaterialsView> createState() => _MaterialsViewState();
}

class _MaterialsViewState extends ConsumerState<_MaterialsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Library'),
            Tab(text: 'My Reading List'),
          ],
        ),
      ),
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _MaterialsList(saved: false),
                _MaterialsList(saved: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Search field (debounced) + category chips + month & sort dropdowns.
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar();

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(materialsFiltersProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(materialsFiltersProvider);
    final pageItems =
        ref.watch(materialsListProvider(false)).value?.items ?? const [];

    // Sensible defaults plus anything extra the API returned this page.
    final categories = <String>{...defaultMaterialCategories};
    for (final item in pageItems) {
      if (item.category.isNotEmpty) categories.add(item.category);
    }
    final categoryList = categories.toList()..sort();

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Breakpoints.isCompact(context) ? AppSpacing.md : AppSpacing.xl,
        AppSpacing.sm,
        Breakpoints.isCompact(context) ? AppSpacing.md : AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Search materials',
            controller: _searchController,
            hint: 'Title, author or topic…',
            prefixIcon: Icons.search_rounded,
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: DropdownButton<String>(
                    value: filters.month == null ? 'all' : '${filters.month}',
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All months')),
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: '$m',
                          child: Text(monthNames[m - 1]),
                        ),
                    ],
                    onChanged: (value) => ref
                        .read(materialsFiltersProvider.notifier)
                        .setMonth(value == null || value == 'all'
                            ? null
                            : int.tryParse(value)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: DropdownButton<String>(
                    value: filters.sort,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: 'newest', child: Text('Newest first')),
                      DropdownMenuItem(
                          value: 'title', child: Text('Title A–Z')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(materialsFiltersProvider.notifier)
                            .setSort(value);
                      }
                    },
                  ),
                ),
                for (final category in categoryList)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(humanizeStatus(category)),
                      selected: filters.category == category,
                      onSelected: (selected) =>
                          ref.read(materialsFiltersProvider.notifier).setCategory(
                                selected ? category : null,
                              ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialsList extends ConsumerWidget {
  const _MaterialsList({required this.saved});

  final bool saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(materialsFiltersProvider);
    final async = ref.watch(materialsListProvider(saved));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(materialsListProvider(saved));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 5),
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            ErrorState(error: e, onRetry: () => ref.invalidate(materialsListProvider(saved))),
          ],
        ),
        data: (result) {
          if (result.items.isEmpty) {
            return ListView(
              padding: AppSpacing.pagePaddingMobile,
              children: [
                EmptyState(
                  icon: saved
                      ? Icons.bookmark_border_rounded
                      : Icons.local_library_outlined,
                  title: saved
                      ? 'Your reading list is empty'
                      : 'No materials found',
                  message: saved
                      ? 'Save materials from the library and they will show up here for quick access.'
                      : (filters.search.isNotEmpty || filters.category != null || filters.month != null)
                          ? 'Nothing matches the current filters. Try clearing them.'
                          : 'Study materials published by your ministry will appear here soon.',
                ),
              ],
            );
          }
          final wide = !Breakpoints.isCompact(context);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              wide ? AppSpacing.xl : AppSpacing.md,
              AppSpacing.md,
              wide ? AppSpacing.xl : AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              if (wide)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in result.items)
                      SizedBox(
                        width: 360,
                        child: _MaterialCard(item: item, savedTab: saved),
                      ),
                  ],
                )
              else
                for (final item in result.items) ...[
                  _MaterialCard(item: item, savedTab: saved),
                  const SizedBox(height: AppSpacing.xs),
                ],
              PaginationFooter(
                page: result.page,
                totalPages: result.totalPages,
                totalItems: result.total,
                onPrevious: () => ref
                    .read(materialsFiltersProvider.notifier)
                    .goToPage(result.page - 1),
                onNext: () => ref
                    .read(materialsFiltersProvider.notifier)
                    .goToPage(result.page + 1),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData materialCategoryIcon(String category) {
  switch (category.toUpperCase()) {
    case 'PDF':
    case 'DOCUMENT':
      return Icons.picture_as_pdf_outlined;
    case 'AUDIO':
      return Icons.headphones_outlined;
    case 'VIDEO':
      return Icons.play_circle_outline;
    case 'STUDY_NOTES':
      return Icons.edit_note_outlined;
    case 'LITERATURE':
      return Icons.auto_stories_outlined;
    case 'PRAYER_GUIDE':
      return Icons.self_improvement_outlined;
    case 'SCRIPTURE_LINK':
      return Icons.menu_book_outlined;
    case 'CONFESSION':
      return Icons.record_voice_over_outlined;
    case 'ANNOUNCEMENT':
      return Icons.campaign_outlined;
    default:
      return Icons.folder_outlined;
  }
}

String materialPeriodLabel(MaterialItem item) {
  final parts = <String>[];
  if (item.month != null && item.month! >= 1 && item.month! <= 12) {
    parts.add(DateFormat('MMMM').format(DateTime(item.year ?? 2000, item.month!)));
  }
  if (item.year != null) parts.add('${item.year}');
  if (parts.isNotEmpty) return parts.join(' ');
  if (item.publishedAt != null) {
    return DateFormat('d MMM yyyy').format(item.publishedAt!.toLocal());
  }
  return '';
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.item, required this.savedTab});

  final MaterialItem item;
  final bool savedTab;

  @override
  Widget build(BuildContext context) {
    final period = materialPeriodLabel(item);
    return AppCard(
      onTap: () => context.go('/materials/${item.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.navy100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              materialCategoryIcon(item.category),
              color: AppColors.navy700,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (item.author != null && item.author!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.author!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    StatusBadge(
                      label: humanizeStatus(item.category),
                      tone: AppBadgeTone.navy,
                      small: true,
                    ),
                    if (period.isNotEmpty)
                      StatusBadge(label: period, tone: AppBadgeTone.gold, small: true),
                    if (item.isCompleted)
                      const StatusBadge(
                        label: 'Completed',
                        tone: AppBadgeTone.success,
                        small: true,
                        icon: Icons.check_rounded,
                      ),
                    if (savedTab && item.savedToReadingList)
                      const StatusBadge(
                        label: 'Saved',
                        tone: AppBadgeTone.info,
                        small: true,
                        icon: Icons.bookmark_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}


