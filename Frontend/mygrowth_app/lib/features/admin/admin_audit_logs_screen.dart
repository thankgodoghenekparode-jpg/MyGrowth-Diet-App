import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/pagination.dart';
import '../../core/widgets/section_header.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Audit Logs: a read-only, filterable trail of administrative actions.
class AdminAuditLogsScreen extends ConsumerWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AuditBody();
  }
}

class _AuditBody extends ConsumerStatefulWidget {
  const _AuditBody();

  @override
  ConsumerState<_AuditBody> createState() => _AuditBodyState();
}

class _AuditBodyState extends ConsumerState<_AuditBody> {
  int _page = 1;
  String _action = '';
  String _search = '';
  DateTime? _from;
  DateTime? _to;

  void _setFilter(void Function() apply) {
    setState(() {
      apply();
      _page = 1;
    });
  }

  String _date(DateTime? value) =>
      value == null ? '' : DateTime(value.year, value.month, value.day)
          .toUtc()
          .toIso8601String();

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _page,
      action: _action,
      search: _search,
      from: _date(_from),
      to: _date(_to),
    );
    final result = ref.watch(adminAuditLogsProvider(query));
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAuditLogsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Audit Logs',
            subtitle: 'Every administrative action, newest first',
            icon: Icons.policy_outlined,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  label: 'Search action',
                  hint: 'e.g. member_approved, material_published…',
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
                        label: 'Outcome type',
                        value: _action,
                        items: const [
                          DropdownMenuItem(
                              value: '', child: Text('All actions')),
                          DropdownMenuItem(
                              value: 'admin_', child: Text('Admin access')),
                          DropdownMenuItem(
                              value: 'member_', child: Text('Member changes')),
                          DropdownMenuItem(
                              value: 'report_', child: Text('Report reviews')),
                          DropdownMenuItem(
                              value: 'safety_report_',
                              child: Text('Safety reports')),
                          DropdownMenuItem(
                              value: 'privilege_escalation_attempt',
                              child: Text('Blocked escalations')),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _action = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: AppDateField(
                        label: 'From',
                        value: _from,
                        onChanged: (value) => _setFilter(() => _from = value),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: AppDateField(
                        label: 'To',
                        value: _to,
                        onChanged: (value) => _setFilter(() => _to = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          result.when(
            loading: () => const CardListSkeleton(count: 6),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminAuditLogsProvider),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.policy_outlined,
                    title: 'No log entries match',
                    message:
                        'Administrative actions are recorded here as they '
                        'happen. Try widening the filters.',
                    actionLabel: 'Clear filters',
                    onAction: () => setState(() {
                      _action = '';
                      _search = '';
                      _from = null;
                      _to = null;
                      _page = 1;
                    }),
                  ),
                );
              }
              return Column(
                children: [
                  for (final entry in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _AuditTile(entry: entry),
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

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AdminAuditEntry entry;

  bool get _denied => entry.outcome == 'DENIED' || entry.outcome == 'FAILURE';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _denied
                    ? Icons.gpp_bad_outlined
                    : entry.isAdminAccessAction
                        ? Icons.admin_panel_settings_outlined
                        : Icons.history_rounded,
                size: 19,
                color: _denied ? AppColors.danger : AppColors.navy700,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  humanizeStatus(entry.action),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (entry.outcome != null)
                StatusBadge(
                  label: humanizeStatus(entry.outcome!),
                  tone: _denied ? AppBadgeTone.danger : AppBadgeTone.success,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(
                entry.actorName ?? 'Unknown actor',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (entry.targetDescription != null)
                Text(
                  '· ${entry.targetDescription}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              Text(
                '· ${fmtDateTime(entry.createdAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (entry.details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _Details(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.entry});

  final AdminAuditEntry entry;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final body = formatJsonCopyable(widget.entry.details).trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Icon(
                _open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Text(
                _open ? 'Hide details' : 'Show details',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.xxs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppSpacing.controlRadius,
            ),
            child: SelectableText(
              body.isEmpty ? '(no details)' : body,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
