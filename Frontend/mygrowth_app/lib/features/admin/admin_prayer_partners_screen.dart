import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Prayer partnerships: partnerships, open requests and safety reports.
///
/// This view is deliberately safety-focused — only pairing status and
/// safety-report handling are surfaced, never private session content.
class AdminPrayerPartnersScreen extends ConsumerWidget {
  const AdminPrayerPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PrayerPartnersBody();
  }
}

enum _PartnerTab { partnerships, requests, safety }

class _PrayerPartnersBody extends ConsumerStatefulWidget {
  const _PrayerPartnersBody();

  @override
  ConsumerState<_PrayerPartnersBody> createState() =>
      _PrayerPartnersBodyState();
}

class _PrayerPartnersBodyState extends ConsumerState<_PrayerPartnersBody> {
  _PartnerTab _tab = _PartnerTab.partnerships;
  int _page = 1;
  String _status = '';

  static const _tabs = <(_PartnerTab, String, IconData)>[
    (_PartnerTab.partnerships, 'Partnerships', Icons.handshake_outlined),
    (_PartnerTab.requests, 'Requests', Icons.mail_outline_rounded),
    (_PartnerTab.safety, 'Safety reports', Icons.health_and_safety_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminPrayerPartnershipsProvider);
        ref.invalidate(adminPrayerRequestsProvider);
        ref.invalidate(adminPrayerReportsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Prayer Partnerships',
            subtitle: 'Pairings, open requests and safety reports',
            icon: Icons.handshake_outlined,
          ),
          const AdminBanner(
            tone: AdminBannerTone.warning,
            icon: Icons.shield_outlined,
            text:
                'This view exists for safety and support. Do not contact '
                'members about private session content.',
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                return ChoiceChip(
                  avatar: Icon(tab.$3, size: 16),
                  label: Text(tab.$2),
                  selected: _tab == tab.$1,
                  onSelected: (_) => setState(() {
                    _tab = tab.$1;
                    _page = 1;
                    _status = '';
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          switch (_tab) {
            _PartnerTab.partnerships => _partnerships(context),
            _PartnerTab.requests => _requests(context),
            _PartnerTab.safety => _safety(context),
          },
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // --------------------------------------------------------- partnerships
  Widget _partnerships(BuildContext context) {
    final query = (page: _page, status: _status);
    final result = ref.watch(adminPrayerPartnershipsProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: AppDropdown<String>(
            label: 'Status',
            value: _status,
            items: const [
              DropdownMenuItem(value: '', child: Text('All statuses')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
              DropdownMenuItem(value: 'PAUSED', child: Text('Paused')),
              DropdownMenuItem(value: 'ENDED', child: Text('Ended')),
            ],
            onChanged: (value) => setState(() {
              _status = value ?? '';
              _page = 1;
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        result.when(
          loading: () => const CardListSkeleton(count: 4),
          error: (error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(adminPrayerPartnershipsProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No partnerships to show',
                  message:
                      'Active and past prayer partnerships will appear here '
                      'for oversight.',
                ),
              );
            }
            return Column(
              children: [
                for (final p in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PartnershipCard(partnership: p),
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
      ],
    );
  }

  // ------------------------------------------------------------- requests
  Widget _requests(BuildContext context) {
    final requests = ref.watch(adminPrayerRequestsProvider);
    return requests.when(
      loading: () => const CardListSkeleton(count: 4),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminPrayerRequestsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppCard(
            child: EmptyState(
              icon: Icons.mail_outline_rounded,
              title: 'No partner requests',
              message:
                  'Requests members send to one another appear here for '
                  'awareness.',
            ),
          );
        }
        return Column(
          children: [
            for (final request in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RequestCard(request: request),
              ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------- safety
  Widget _safety(BuildContext context) {
    final reports = ref.watch(adminPrayerReportsProvider);
    return reports.when(
      loading: () => const CardListSkeleton(count: 4),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminPrayerReportsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppCard(
            child: EmptyState(
              icon: Icons.health_and_safety_outlined,
              title: 'No safety reports',
              message:
                  'Reports raised by members about prayer-partner conduct will '
                  'appear here.',
            ),
          );
        }
        return Column(
          children: [
            for (final report in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SafetyReportCard(
                  report: report,
                  onChanged: () => ref.invalidate(adminPrayerReportsProvider),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PartnershipCard extends StatelessWidget {
  const _PartnershipCard({required this.partnership});

  final AdminPartnership partnership;

  @override
  Widget build(BuildContext context) {
    final p = partnership;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.handshake_outlined,
              size: 22, color: AppColors.navy700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.memberAName} & ${p.memberBName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(
                      label: humanizeStatus(p.status),
                      tone: badgeToneFor(p.status),
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.endedAt != null
                      ? 'Started ${fmtDate(p.startedAt)} · ended ${fmtDate(p.endedAt)}'
                      : 'Started ${fmtDate(p.startedAt)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final AdminPartnerRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline_rounded,
              size: 22, color: AppColors.navy700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.senderName} → ${r.recipientName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(
                      label: humanizeStatus(r.status),
                      tone: badgeToneFor(r.status),
                      small: true,
                    ),
                  ],
                ),
                if (r.message != null && r.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.message!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Sent ${fmtDate(r.createdAt)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyReportCard extends ConsumerStatefulWidget {
  const _SafetyReportCard({required this.report, required this.onChanged});

  final AdminPartnerReport report;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SafetyReportCard> createState() => _SafetyReportCardState();
}

class _SafetyReportCardState extends ConsumerState<_SafetyReportCard> {
  bool _busy = false;

  bool get _isOpen => widget.report.status == 'OPEN';

  Future<void> _review() async {
    await _patch('review', null, 'Report marked as reviewed.');
  }

  Future<void> _resolve() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _ResolutionSheet(),
        ),
      ),
    );
    if (note == null || !mounted) return;
    await _patch('resolve', note, 'Report resolved.');
  }

  Future<void> _patch(String action, String? note, String success) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).patch(
        '/admin/safety-reports/${widget.report.id}',
        body: {
          'action': action,
          if (note != null && note.trim().isNotEmpty)
            'resolutionNote': note.trim(),
        },
      );
      if (!mounted) return;
      widget.onChanged();
      Toast.success(context, success);
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t update this report just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return AppCard(
      highlight: _isOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 22, color: AppColors.navy700),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reported by ${r.anonymisedReporter}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(r.status),
                tone: badgeToneFor(r.status),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            r.reason,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            r.resolvedAt != null
                ? 'Raised ${fmtDate(r.createdAt)} · resolved ${fmtDate(r.resolvedAt)}'
                : 'Raised ${fmtDate(r.createdAt)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (_isOpen)
                AppButton(
                  label: 'Mark reviewed',
                  icon: Icons.visibility_outlined,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _review,
                ),
              if (r.status != 'RESOLVED')
                AppButton(
                  label: 'Resolve',
                  icon: Icons.task_alt_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _resolve,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionSheet extends StatefulWidget {
  const _ResolutionSheet();

  @override
  State<_ResolutionSheet> createState() => _ResolutionSheetState();
}

class _ResolutionSheetState extends State<_ResolutionSheet> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Resolve safety report',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Record how this was handled. The note is stored for safeguarding '
          'records and is never shown to members.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Resolution note',
          controller: _note,
          maxLines: 4,
          hint: 'What action was taken?',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Resolve report',
          icon: Icons.task_alt_rounded,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
