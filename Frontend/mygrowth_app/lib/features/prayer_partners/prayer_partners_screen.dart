import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/prayer_models.dart';
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
import 'prayer_partners_providers.dart';

/// Find, manage and communicate with prayer partners.
class PrayerPartnersScreen extends ConsumerWidget {
  const PrayerPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PartnersView();
  }
}

class _PartnersView extends ConsumerStatefulWidget {
  const _PartnersView();

  @override
  ConsumerState<_PartnersView> createState() => _PartnersViewState();
}

class _PartnersViewState extends ConsumerState<_PartnersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Partners'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Find a Partner'),
            Tab(text: 'My Partnership'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _DiscoverTab(),
          _PartnershipTab(onFindPartner: () => _tabController.animateTo(0)),
          const _RequestsTab(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- helpers

/// "First name + initial": the directory never exposes full names, and we
/// keep it that way in the UI even if the API sends more.
String _privacyName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'Member';
  if (parts.length == 1) return parts.first;
  final last = parts.last;
  return '${parts.first} ${last.substring(0, 1)}.';
}

const _dayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _daysSummary(List<int> days) {
  final sorted = [...days]..sort();
  if (sorted.isEmpty) return 'Days flexible';
  return sorted
      .where((d) => d >= 1 && d <= 7)
      .map((d) => _dayAbbrev[d - 1])
      .join(', ');
}

// ------------------------------------------------------------- discover

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerPartnerSuggestionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(prayerPartnerSuggestionsProvider);
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
              onRetry: () => ref.invalidate(prayerPartnerSuggestionsProvider),
            ),
          ],
        ),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return ListView(
              padding: AppSpacing.pagePaddingMobile,
              children: const [
                EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No partners to suggest right now',
                  message:
                      'The directory only shows members who opted in to the '
                      'prayer-partner programme. More suggestions will appear '
                      'as members join — you can also update your own '
                      'availability in the Prayer Room.',
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
                    for (final s in suggestions)
                      SizedBox(
                        width: 340,
                        child: _SuggestionCard(suggestion: s),
                      ),
                  ],
                )
              else
                for (final s in suggestions) ...[
                  _SuggestionCard(suggestion: s),
                  const SizedBox(height: AppSpacing.xs),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({required this.suggestion});

  final PartnerSuggestion suggestion;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _busy = false;

  PartnerSuggestion get suggestion => widget.suggestion;

  Future<void> _sendRequest() async {
    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send prayer request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Introduce yourself to ${_privacyName(suggestion.name)}. '
              'A short, kind message goes a long way.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Message (optional)',
              controller: messageController,
              maxLines: 3,
              hint: 'Hi, I’d love to partner with you in prayer…',
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(messageController.text),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (message == null || !mounted) return;

    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.post(
        '/prayer-partners/requests',
        body: {
          'recipientId': suggestion.userId,
          if (message.trim().isNotEmpty) 'message': message.trim(),
        },
      );
      ref.invalidate(prayerPartnerSuggestionsProvider);
      ref.invalidate(prayerRequestsProvider('outgoing'));
      if (mounted) {
        Toast.success(
          context,
          'Request sent. ${_privacyName(suggestion.name)} will be notified.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to send the request just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeRange = (suggestion.timeStart != null &&
            suggestion.timeEnd != null)
        ? '${suggestion.timeStart}–${suggestion.timeEnd}'
        : 'Times flexible';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.navy100,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _privacyName(suggestion.name).substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.navy800,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _privacyName(suggestion.name),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (suggestion.hasPendingRequest)
                const StatusBadge(
                  label: 'Request pending',
                  tone: AppBadgeTone.warning,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            text: _daysSummary(suggestion.availableDays),
          ),
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: '$timeRange · ${suggestion.preferredDurationMinutes} min',
          ),
          _InfoRow(
            icon: Icons.public_rounded,
            text: suggestion.timeZone,
          ),
          if (suggestion.language != null &&
              suggestion.language!.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.translate_rounded,
              text: suggestion.language!,
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: suggestion.hasPendingRequest
                  ? 'Request pending'
                  : 'Send request',
              icon: Icons.handshake_outlined,
              busy: _busy,
              onPressed:
                  suggestion.hasPendingRequest ? null : _sendRequest,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- partnership

class _PartnershipTab extends ConsumerWidget {
  const _PartnershipTab({required this.onFindPartner});

  final VoidCallback onFindPartner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentPartnershipProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentPartnershipProvider);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: SkeletonBox(height: 220, radius: 14),
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(currentPartnershipProvider),
            ),
          ],
        ),
        data: (partnership) {
          if (partnership == null) {
            return ListView(
              padding: AppSpacing.pagePaddingMobile,
              children: [
                AppCard(
                  child: EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'No active prayer partnership',
                    message:
                        'You’re not currently partnered with anyone — and '
                        'that’s perfectly okay. When you connect with a '
                        'partner, your partnership will appear here.',
                    actionLabel: 'Find a partner',
                    onAction: onFindPartner,
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: Breakpoints.isCompact(context)
                ? AppSpacing.pagePaddingMobile
                : const EdgeInsets.all(AppSpacing.xl),
            children: [
              _PartnershipCard(partnership: partnership),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _PartnershipCard extends ConsumerStatefulWidget {
  const _PartnershipCard({required this.partnership});

  final Partnership partnership;

  @override
  ConsumerState<_PartnershipCard> createState() => _PartnershipCardState();
}

class _PartnershipCardState extends ConsumerState<_PartnershipCard> {
  bool _busy = false;

  Partnership get partnership => widget.partnership;

  Future<void> _setStatus(String status, {String? successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.patch(
        '/prayer-partners/partnerships/${partnership.id}',
        body: {'status': status},
      );
      ref.invalidate(currentPartnershipProvider);
      if (mounted && successMessage != null) {
        Toast.success(context, successMessage);
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Unable to update the partnership just now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endPartnership() async {
    final ok = await confirmDialog(
      context,
      title: 'End partnership?',
      message:
          'You and ${partnership.partnerName} will no longer be paired as '
          'prayer partners. You can always find a new partner afterwards — '
          'no hard feelings.',
      confirmLabel: 'End partnership',
      destructive: true,
    );
    if (!ok) return;
    await _setStatus('ENDED', successMessage: 'Partnership ended.');
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block & report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tell us what happened. Your report is sent directly to the '
              'ministry administrators for review.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Reason',
              required: true,
              controller: reasonController,
              maxLines: 4,
              hint: 'Describe the concern…',
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(reasonController.text),
            child: const Text('Send report'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      if (mounted) {
        Toast.error(context, 'Please add a reason before sending the report.');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.post(
        '/prayer-partners/partnerships/${partnership.id}/report',
        body: {'reason': reason.trim()},
      );
      if (mounted) {
        Toast.show(
          context,
          message:
              'Report received. Ministry administrators will review it — '
              'thank you for trusting us with this.',
          tone: ToastTone.info,
          duration: const Duration(seconds: 5),
        );
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to send the report just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = partnership.status == 'ACTIVE';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy100,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  partnership.partnerName.isEmpty
                      ? '?'
                      : partnership.partnerName
                          .trim()
                          .substring(0, 1)
                          .toUpperCase(),
                  style: TextStyle(
                    color: AppColors.navy800,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnership.partnerName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (partnership.startedAt != null)
                      Text(
                        'Partners since '
                        '${DateFormat('d MMM yyyy').format(partnership.startedAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              StatusBadge(
                label: humanizeStatus(partnership.status),
                tone: badgeToneFor(partnership.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (isActive)
                AppButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: () => _setStatus('PAUSED',
                      successMessage:
                          'Partnership paused. Resume anytime — no pressure.'),
                ),
              if (partnership.status == 'PAUSED')
                AppButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  busy: _busy,
                  onPressed: () => _setStatus('ACTIVE',
                      successMessage: 'Partnership resumed. Welcome back!'),
                ),
              if (partnership.status != 'ENDED')
                AppButton(
                  label: 'End partnership',
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _endPartnership,
                ),
              AppButton(
                label: 'Block & report',
                icon: Icons.flag_outlined,
                variant: AppButtonVariant.danger,
                busy: _busy,
                onPressed: _report,
              ),
            ],
          ),
          if (partnership.endedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Ended ${DateFormat('d MMM yyyy').format(partnership.endedAt!.toLocal())}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- requests

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(prayerRequestsProvider('incoming'));
    final outgoing = ref.watch(prayerRequestsProvider('outgoing'));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(prayerRequestsProvider('incoming'));
        ref.invalidate(prayerRequestsProvider('outgoing'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SectionHeader(
            title: 'Received',
            subtitle: 'Members asking to partner with you',
            icon: Icons.download_rounded,
          ),
          incoming.when(
            loading: () => const CardListSkeleton(count: 2),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () =>
                  ref.invalidate(prayerRequestsProvider('incoming')),
            ),
            data: (requests) => requests.isEmpty
                ? const AppCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No requests received',
                      message:
                          'Requests from other members will appear here.',
                    ),
                  )
                : Column(
                    children: [
                      for (final r in requests) ...[
                        _RequestListCard(request: r, isIncoming: true),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Sent',
            subtitle: 'Your requests to other members',
            icon: Icons.upload_rounded,
          ),
          outgoing.when(
            loading: () => const CardListSkeleton(count: 2),
            error: (e, _) => ErrorState(
              error: e,
              compact: true,
              onRetry: () =>
                  ref.invalidate(prayerRequestsProvider('outgoing')),
            ),
            data: (requests) => requests.isEmpty
                ? const AppCard(
                    child: EmptyState(
                      icon: Icons.send_outlined,
                      title: 'No requests sent yet',
                      message:
                          'Find a partner and send a request — it will show '
                          'up here while you wait.',
                    ),
                  )
                : Column(
                    children: [
                      for (final r in requests) ...[
                        _RequestListCard(request: r, isIncoming: false),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _RequestListCard extends ConsumerStatefulWidget {
  const _RequestListCard({required this.request, required this.isIncoming});

  final PrayerRequest request;
  final bool isIncoming;

  @override
  ConsumerState<_RequestListCard> createState() => _RequestListCardState();
}

class _RequestListCardState extends ConsumerState<_RequestListCard> {
  bool _busy = false;

  PrayerRequest get request => widget.request;

  Future<void> _act(String action, String successMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.patch(
        '/prayer-partners/requests/${request.id}',
        body: {'action': action},
      );
      ref.invalidate(prayerRequestsProvider('incoming'));
      ref.invalidate(prayerRequestsProvider('outgoing'));
      ref.invalidate(prayerPartnerSuggestionsProvider);
      ref.invalidate(currentPartnershipProvider);
      if (mounted) Toast.success(context, successMessage);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to update the request just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel request?',
      message: 'Your prayer-partner request will be withdrawn.',
      confirmLabel: 'Cancel request',
      destructive: true,
    );
    if (!ok) return;
    await _act('cancel', 'Request withdrawn.');
  }

  @override
  Widget build(BuildContext context) {
    final otherName = widget.isIncoming
        ? (request.senderName ?? 'A member')
        : (request.recipientName ?? 'A member');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _privacyName(otherName),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(request.status),
                tone: badgeToneFor(request.status),
                small: true,
              ),
            ],
          ),
          if (request.message != null && request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(request.message!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (request.createdAt != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Sent ${DateFormat('d MMM yyyy').format(request.createdAt!.toLocal())}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (widget.isIncoming) ...[
                  AppButton(
                    label: 'Accept',
                    busy: _busy,
                    onPressed: () => _act('accept', 'Request accepted.'),
                  ),
                  AppButton(
                    label: 'Decline',
                    variant: AppButtonVariant.outlined,
                    busy: _busy,
                    onPressed: () => _act('decline', 'Request declined.'),
                  ),
                ] else
                  AppButton(
                    label: 'Cancel request',
                    variant: AppButtonVariant.outlined,
                    busy: _busy,
                    onPressed: _cancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
