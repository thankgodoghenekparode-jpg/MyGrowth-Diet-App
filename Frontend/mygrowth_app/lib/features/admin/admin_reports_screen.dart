import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../core/widgets/pagination.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Reports & Reviews: type tabs, server-side filters, pagination and an
/// honest copy-to-clipboard export.
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ReportsBody();
  }
}

class _ReportsBody extends ConsumerStatefulWidget {
  const _ReportsBody();

  @override
  ConsumerState<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends ConsumerState<_ReportsBody> {
  int _page = 1;
  String _type = '';
  String _status = '';
  String _search = '';
  String _year = '';
  bool _exporting = false;

  static const _types = <(String, String)>[
    ('', 'All'),
    ('WEEKLY', 'Weekly'),
    ('MONTHLY', 'Monthly'),
    ('QUARTERLY', 'Quarterly'),
    ('ANNUAL', 'Annual'),
  ];

  Map<String, String> get _filterQuery => {
        'page': '$_page',
        'pageSize': '$adminPageSize',
        if (_type.isNotEmpty) 'type': _type,
        if (_status.isNotEmpty) 'status': _status,
        if (_search.isNotEmpty) 'search': _search,
        if (_year.isNotEmpty) 'programmeYear': _year,
      };

  void _setFilter(void Function() apply) {
    setState(() {
      apply();
      _page = 1;
    });
  }

  DropdownMenuItem<String> _item(String value, String label) =>
      DropdownMenuItem<String>(value: value, child: Text(label));

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.get(
        '/admin/reports',
        query: {..._filterQuery, 'page': '1', 'pageSize': '100'},
      );
      final page = pagedFrom(data, Report.fromJson);
      final buffer = StringBuffer()
        ..writeln('MyGrowth Diet App — report summary')
        ..writeln('Generated: ${fmtDateTime(DateTime.now())}')
        ..writeln(
          'Filters: type=${_type.isEmpty ? 'all' : humanizeStatus(_type)}, '
          'status=${_status.isEmpty ? 'all' : humanizeStatus(_status)}, '
          'year=${_year.isEmpty ? 'all' : _year}, '
          'search=${_search.isEmpty ? 'none' : _search}',
        )
        ..writeln('Reports matching this view: ${page.total}')
        ..writeln('—')
        ..writeln();
      if (page.items.isEmpty) {
        buffer.writeln('No reports match the current filters.');
      }
      for (final report in page.items) {
        buffer.writeln(
          '${report.memberName ?? 'Member'} · ${humanizeStatus(report.type)} · '
          '${report.periodKey.isEmpty ? 'period not set' : report.periodKey} · '
          '${humanizeStatus(report.status)} · submitted '
          '${fmtDate(report.submittedAt ?? report.createdAt)}',
        );
      }
      if (!mounted) return;
      await showCopyableSheet(
        context,
        title: 'Copy report summary',
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
    final query = (
      page: _page,
      type: _type,
      status: _status,
      search: _search,
      year: _year,
    );
    final result = ref.watch(adminReportsProvider(query));
    final programmes = ref.watch(adminProgrammesProvider);
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminReportsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Reports & Reviews',
            subtitle: 'Read submitted reports and add review feedback',
            icon: Icons.fact_check_outlined,
          ),

          // ------------------------------------------------ type "tabs"
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final option = _types[index];
                return ChoiceChip(
                  label: Text(option.$2),
                  selected: _type == option.$1,
                  onSelected: (_) =>
                      _setFilter(() => _type = option.$1),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // --------------------------------------------------- filters
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  hint: 'Member name…',
                  onChanged: (value) => _setFilter(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: AppDropdown<String>(
                        label: 'Status',
                        value: _status,
                        items: [
                          _item('', 'All statuses'),
                          _item('SUBMITTED', 'Submitted'),
                          _item('REVIEWED', 'Reviewed'),
                          _item('REQUIRES_FOLLOW_UP', 'Requires follow-up'),
                          _item('DRAFT', 'Draft'),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _status = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: programmes.when(
                        loading: () => AppDropdown<String>(
                          label: 'Programme year',
                          value: null,
                          items: const [],
                          onChanged: (_) {},
                        ),
                        error: (_, _) => AppDropdown<String>(
                          label: 'Programme year',
                          value: _year,
                          items: [_item('', 'All years')],
                          onChanged: (value) =>
                              _setFilter(() => _year = value ?? ''),
                        ),
                        data: (years) => AppDropdown<String>(
                          label: 'Programme year',
                          value: _year,
                          items: [
                            _item('', 'All years'),
                            for (final programme in years)
                              _item('${programme.year}', '${programme.year}'),
                          ],
                          onChanged: (value) =>
                              _setFilter(() => _year = value ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Export uses the current filters.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    AppButton(
                      label: 'Copy report summary',
                      icon: Icons.ios_share_rounded,
                      variant: AppButtonVariant.outlined,
                      busy: _exporting,
                      onPressed: _export,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ----------------------------------------------------- list
          result.when(
            loading: () => const CardListSkeleton(count: 5),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminReportsProvider(query)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No reports here yet',
                    message:
                        'Submitted accountability reports will appear here '
                        'for review.',
                    actionLabel: 'Clear filters',
                    onAction: () {
                      setState(() {
                        _type = '';
                        _status = '';
                        _search = '';
                        _year = '';
                        _page = 1;
                      });
                      ref.invalidate(adminReportsProvider(query));
                    },
                  ),
                );
              }
              return Column(
                children: [
                  for (final report in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () =>
                            context.go('/admin/reports/${report.id}'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              report.type == 'WEEKLY'
                                  ? Icons.view_week_outlined
                                  : report.type == 'ANNUAL'
                                      ? Icons.event_note_outlined
                                      : Icons.assignment_outlined,
                              size: 22,
                              color: AppColors.navy700,
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
                                          report.memberName ?? 'Member',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      StatusBadge(
                                        label: humanizeStatus(report.status),
                                        tone: badgeToneFor(report.status),
                                        small: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xxs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusBadge(
                                        label: humanizeStatus(report.type),
                                        tone: AppBadgeTone.navy,
                                        small: true,
                                      ),
                                      Text(
                                        report.periodKey.isEmpty
                                            ? 'Period not set'
                                            : report.periodKey,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      Text(
                                        '· Submitted ${fmtDate(report.submittedAt ?? report.createdAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: AppColors.inkMuted),
                          ],
                        ),
                      ),
                    ),
                  PaginationFooter(
                    page: page.page,
                    totalPages: page.totalPages,
                    totalItems: page.total,
                    onPrevious: () => setState(() => _page -= 1),
                    onNext: () => setState(() => _page += 1),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
