import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'admin_member_model.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Member profile: read-only summary, status actions for MEMBER accounts,
/// submitted reports and a completion summary.
class AdminMemberDetailScreen extends ConsumerWidget {
  const AdminMemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MemberDetailBody(memberId: memberId);
  }
}

class _MemberDetailBody extends ConsumerStatefulWidget {
  const _MemberDetailBody({required this.memberId});

  final String memberId;

  @override
  ConsumerState<_MemberDetailBody> createState() =>
      _MemberDetailBodyState();
}

class _MemberDetailBodyState extends ConsumerState<_MemberDetailBody> {
  String? _busy;

  Future<void> _run(
    String action,
    Future<void> Function() call,
    String successMessage,
  ) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await call();
      if (!mounted) return;
      ref.invalidate(adminMemberProvider(widget.memberId));
      ref.invalidate(adminMembersProvider);
      ref.invalidate(adminMemberSummaryProvider);
      Toast.success(context, successMessage);
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'That action didn’t complete. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _approve() {
    final client = ref.read(apiClientProvider);
    return _run(
      'approve',
      () => client.post('/admin/users/${widget.memberId}/approve'),
      'Member approved. Their account is now active.',
    );
  }

  Future<void> _reactivate() {
    final client = ref.read(apiClientProvider);
    return _run(
      'reactivate',
      () => client.post('/admin/users/${widget.memberId}/reactivate'),
      'Member reactivated. They can sign in again.',
    );
  }

  Future<void> _suspend() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Suspend this member?',
      message:
          'They will lose access to MyGrowth until reactivated. Their '
          'records, reports and progress are kept.',
      confirmLabel: 'Suspend',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final client = ref.read(apiClientProvider);
    await _run(
      'suspend',
      () => client.post('/admin/users/${widget.memberId}/suspend'),
      'Member suspended. You can reactivate them at any time.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(adminMemberProvider(widget.memberId));

    return memberAsync.when(
      loading: () => ListView(
        padding: adminPadding(context),
        children: const [
          SkeletonBox(height: 140, radius: 14),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 180, radius: 14),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 120, radius: 14),
        ],
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () =>
            ref.invalidate(adminMemberProvider(widget.memberId)),
      ),
      data: (member) {
        if (member == null) {
          return EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Member not found',
            message:
                'This account may have been removed, or the link is out of '
                'date.',
            actionLabel: 'Back to members',
            onAction: () => context.go('/admin/members'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminMemberProvider(widget.memberId));
            ref.invalidate(adminMemberReportsProvider);
            ref.invalidate(adminMemberSummaryProvider);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: adminPadding(context),
            children: [
              _profile(context, member),
              const SizedBox(height: AppSpacing.lg),
              _statusSection(context, member),
              const SizedBox(height: AppSpacing.lg),
              _reportsSection(context),
              const SizedBox(height: AppSpacing.lg),
              _completionSection(context),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------- profile

  Widget _profile(BuildContext context, AdminMember member) {
    final roleTone = switch (member.role) {
      'MAIN_ADMIN' => AppBadgeTone.navy,
      'ADMIN' => AppBadgeTone.gold,
      _ => AppBadgeTone.neutral,
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: member.name, size: 56),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name.isEmpty ? 'Unnamed member' : member.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(member.email,
                    style: Theme.of(context).textTheme.bodySmall),
                if (member.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(member.phone!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: member.roleLabel,
                      tone: roleTone,
                      small: true,
                    ),
                    StatusBadge(
                      label: humanizeStatus(member.status),
                      tone: badgeToneFor(member.status),
                      small: true,
                    ),
                    Text(
                      'Joined ${fmtDate(member.createdAt)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------- status actions

  Widget _statusSection(BuildContext context, AdminMember member) {
    final bool canApprove = member.isMember && member.isPending;
    final bool canSuspend =
        member.isMember && (member.isActive || member.isPending);
    final bool canReactivate = member.isMember && member.isSuspended;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Account Status',
          icon: Icons.manage_accounts_outlined,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Current status',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  StatusBadge(
                    label: humanizeStatus(member.status),
                    tone: badgeToneFor(member.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                member.isMember
                    ? 'Member account — standard membership actions apply.'
                    : '${member.roleLabel} account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!member.isMember) ...[
                const AdminBanner(
                  text:
                      'Administrator accounts are managed by the Main Admin. '
                      'Status changes, access grants and revocations are made '
                      'in Admin Access Management.',
                  tone: AdminBannerTone.warning,
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: const [
                    _DisabledAction(label: 'Approve'),
                    _DisabledAction(label: 'Suspend'),
                    _DisabledAction(label: 'Reactivate'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Administrator status is shown read-only on this screen.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ] else ...[
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppButton(
                      label: 'Approve',
                      icon: Icons.how_to_reg_outlined,
                      busy: _busy == 'approve',
                      tooltip: canApprove
                          ? null
                          : 'Only accounts pending approval can be approved',
                      onPressed: canApprove ? _approve : null,
                    ),
                    AppButton(
                      label: 'Suspend',
                      icon: Icons.block_outlined,
                      variant: AppButtonVariant.outlined,
                      busy: _busy == 'suspend',
                      tooltip: canSuspend
                          ? null
                          : 'Only active or pending accounts can be suspended',
                      onPressed: canSuspend ? _suspend : null,
                    ),
                    AppButton(
                      label: 'Reactivate',
                      icon: Icons.restart_alt_rounded,
                      variant: AppButtonVariant.outlined,
                      busy: _busy == 'reactivate',
                      tooltip: canReactivate
                          ? null
                          : 'Only suspended accounts can be reactivated',
                      onPressed: canReactivate ? _reactivate : null,
                    ),
                  ],
                ),
                if (!canApprove && !canSuspend && !canReactivate) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This account is ${humanizeStatus(member.status).toLowerCase()} '
                    '— no status actions apply right now.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- reports

  Widget _reportsSection(BuildContext context) {
    final reports = ref.watch(adminMemberReportsProvider(widget.memberId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Submitted Reports',
          subtitle: 'Tap a report to read and review it',
          icon: Icons.fact_check_outlined,
          actionLabel: 'All reports',
          onAction: () => context.go('/admin/reports'),
        ),
        reports.when(
          loading: () => const CardListSkeleton(count: 2),
          error: (error, _) => ErrorState(
            error: error,
            compact: true,
            onRetry: () =>
                ref.invalidate(adminMemberReportsProvider(widget.memberId)),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return AppCard(
                child: Text(
                  'No reports submitted yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return Column(
              children: [
                for (final report in page.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AppCard(
                      onTap: () => context.go('/admin/reports/${report.id}'),
                      child: Row(
                        children: [
                          Icon(Icons.fact_check_outlined,
                              size: 20, color: AppColors.navy700),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${humanizeStatus(report.type)} report',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusBadge(
                                      label:
                                          humanizeStatus(report.status),
                                      tone: badgeToneFor(report.status),
                                      small: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${report.periodKey.isEmpty ? 'Period not set' : report.periodKey}'
                                  ' · ${fmtDate(report.submittedAt ?? report.createdAt)}',
                                  style:
                                      Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.inkMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------- completion

  Widget _completionSection(BuildContext context) {
    final summary = ref.watch(adminMemberSummaryProvider(widget.memberId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Activity Completion Summary',
          icon: Icons.insights_outlined,
        ),
        summary.when(
          loading: () => const SkeletonBox(height: 150, radius: 14),
          error: (error, _) => ErrorState(
            error: error,
            compact: true,
            onRetry: () =>
                ref.invalidate(adminMemberSummaryProvider(widget.memberId)),
          ),
          data: (data) {
            if (data.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No summary available yet',
                  message:
                      'The server doesn’t have a completion summary for this '
                      'member. It appears once activity records exist.',
                ),
              );
            }
            final total = pickNum(
              data,
              const ['totalActivities', 'plannedActivities'],
            );
            final completed = pickNum(
              data,
              const ['completedActivities', 'completed'],
            );
            final reportsSubmitted = pickNum(
              data,
              const ['reportsSubmitted', 'reports'],
            );
            final sessions = pickNum(
              data,
              const ['sessionsCompleted', 'prayerSessionsCompleted'],
            );
            final rate = pickNum(
                  data,
                  const [
                    'completionRate',
                    'completionPct',
                    'activityCompletionRate',
                  ],
                ) ??
                (total != null && completed != null && total > 0
                    ? completed / total
                    : null);

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Self-reported activity records',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (rate != null)
                    ProgressBar(
                      value: percentValue(rate),
                      showLabel: true,
                    )
                  else
                    Text(
                      'No completion rate available yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (total != null && completed != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${completed.toInt()} of ${total.toInt()} planned '
                      'activities recorded',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                  if (reportsSubmitted != null || sessions != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    metricGrid(context, [
                      if (reportsSubmitted != null)
                        StatTile(
                          label: 'Reports submitted',
                          value: '${reportsSubmitted.toInt()}',
                          icon: Icons.task_alt_rounded,
                        ),
                      if (sessions != null)
                        StatTile(
                          label: 'Prayer sessions completed',
                          value: '${sessions.toInt()}',
                          icon: Icons.self_improvement_outlined,
                          tone: StatTileTone.gold,
                        ),
                    ]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DisabledAction extends StatelessWidget {
  const _DisabledAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      variant: AppButtonVariant.outlined,
      tooltip: 'Administrator accounts are managed by the Main Admin',
      onPressed: null,
    );
  }
}
