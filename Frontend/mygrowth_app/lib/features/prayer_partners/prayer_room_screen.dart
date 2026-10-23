import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Member Prayer Room: my availability, upcoming sessions, incoming
/// requests and a pointer to the partner directory.
class PrayerRoomScreen extends ConsumerWidget {
  const PrayerRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(prayerAvailabilityProvider);
        ref.invalidate(prayerSessionsProvider('upcoming'));
        ref.invalidate(prayerRequestsProvider('incoming'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          const _IntroCard(),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'My Availability',
            subtitle: 'Let partners know when you can pray together',
            icon: Icons.event_available_outlined,
          ),
          const _AvailabilityCard(),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'Upcoming Prayer Sessions',
            icon: Icons.groups_2_outlined,
            actionLabel: 'Find a partner',
            onAction: () => context.go('/prayer/partners'),
          ),
          const _UpcomingSessions(),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(
            title: 'Pending Requests',
            subtitle: 'Members who would like you as a prayer partner',
            icon: Icons.mark_email_read_outlined,
          ),
          const _PendingRequests(),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: AppButton(
              label: 'Find a Prayer Partner',
              icon: Icons.handshake_outlined,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.go('/prayer/partners'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Short explainer about the opt-in model and privacy guarantees.
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.navy50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.navy700, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About the prayer-partner programme',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'This programme is fully opt-in: only members who choose to '
                  'take part appear in the partner directory. Your exact '
                  'schedule is never shown to others — partners only see '
                  'general availability like preferred days and time ranges. '
                  'You stay in control: pause availability anytime or end a '
                  'partnership with no pressure.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- availability

const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _durationOptions = [15, 20, 30, 45, 60, 90];
const _statusOptions = [
  ('AVAILABLE', 'Available'),
  ('TEMPORARILY_UNAVAILABLE', 'Temporarily unavailable'),
  ('UNAVAILABLE', 'Unavailable'),
];

class _AvailabilityCard extends ConsumerStatefulWidget {
  const _AvailabilityCard();

  @override
  ConsumerState<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends ConsumerState<_AvailabilityCard> {
  final _timeStart = TextEditingController();
  final _timeEnd = TextEditingController();
  final _timeZone = TextEditingController(text: 'Africa/Lagos');
  String _status = 'UNAVAILABLE';
  final Set<int> _days = {};
  int _duration = 30;
  bool _accepting = false;
  bool _initialized = false;
  bool _busy = false;

  static final _timePattern = RegExp(r'^\d{2}:\d{2}$');

  @override
  void dispose() {
    _timeStart.dispose();
    _timeEnd.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  void _initFrom(PrayerAvailability a) {
    _status = _statusOptions.any((o) => o.$1 == a.status)
        ? a.status
        : 'UNAVAILABLE';
    _days
      ..clear()
      ..addAll(a.availableDays);
    _timeStart.text = a.timeStart ?? '';
    _timeEnd.text = a.timeEnd ?? '';
    _timeZone.text = a.timeZone;
    _duration = _durationOptions.contains(a.preferredDurationMinutes)
        ? a.preferredDurationMinutes
        : 30;
    _accepting = a.acceptingRequests;
    _initialized = true;
  }

  Future<void> _save() async {
    final start = _timeStart.text.trim();
    final end = _timeEnd.text.trim();
    if ((start.isNotEmpty && !_timePattern.hasMatch(start)) ||
        (end.isNotEmpty && !_timePattern.hasMatch(end))) {
      Toast.error(context, 'Times must use the HH:MM format, e.g. 18:00.');
      return;
    }
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final availability = PrayerAvailability(
      status: _status,
      availableDays: _days.toList()..sort(),
      timeStart: start.isEmpty ? null : start,
      timeEnd: end.isEmpty ? null : end,
      timeZone: _timeZone.text.trim().isEmpty
          ? 'Africa/Lagos'
          : _timeZone.text.trim(),
      preferredDurationMinutes: _duration,
      acceptingRequests: _accepting,
    );
    try {
      await client.put(
        '/prayer-partners/availability',
        body: availability.toJson(),
      );
      ref.invalidate(prayerAvailabilityProvider);
      if (mounted) {
        Toast.success(context, 'Availability saved.');
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save availability just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(prayerAvailabilityProvider);
    return async.when(
      loading: () => const SkeletonBox(height: 260, radius: 14),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(prayerAvailabilityProvider),
      ),
      data: (availability) {
        if (!_initialized) _initFrom(availability);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDropdown<String>(
                label: 'Status',
                value: _status,
                items: [
                  for (final option in _statusOptions)
                    DropdownMenuItem(
                      value: option.$1,
                      child: Text(option.$2),
                    ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'UNAVAILABLE'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Available days',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_dayLabels[i - 1]),
                      selected: _days.contains(i),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _days.add(i);
                        } else {
                          _days.remove(i);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Preferred start time',
                      controller: _timeStart,
                      hint: '18:00',
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: 'Preferred end time',
                      controller: _timeEnd,
                      hint: '19:00',
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<int>(
                label: 'Preferred session duration',
                value: _duration,
                items: [
                  for (final d in _durationOptions)
                    DropdownMenuItem(value: d, child: Text('$d minutes')),
                ],
                onChanged: (v) =>
                    setState(() => _duration = v ?? 30),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Time zone',
                controller: _timeZone,
                hint: 'Africa/Lagos',
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSwitchRow(
                label: 'Accept new partner requests',
                subtitle:
                    'When off, you stay opted-in but won’t receive new match '
                    'requests.',
                value: _accepting,
                onChanged: (v) => setState(() => _accepting = v),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Save availability',
                icon: Icons.save_outlined,
                expand: true,
                busy: _busy,
                onPressed: _save,
              ),
              if (availability.updatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Last updated '
                    '${DateFormat('d MMM yyyy, HH:mm').format(availability.updatedAt!.toLocal())}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- sessions

class _UpcomingSessions extends ConsumerWidget {
  const _UpcomingSessions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerSessionsProvider('upcoming'));
    return async.when(
      loading: () => const CardListSkeleton(count: 2),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(prayerSessionsProvider('upcoming')),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return AppCard(
            child: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No sessions scheduled yet',
              message:
                  'Your prayer partner sessions will appear here as soon as '
                  'they’re arranged.',
            ),
          );
        }
        return Column(
          children: [
            for (final session in sessions) ...[
              _SessionCard(session: session),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _SessionCard extends ConsumerStatefulWidget {
  const _SessionCard({required this.session});

  final PrayerSession session;

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _busy = false;

  PrayerSession get session => widget.session;

  Future<void> _patch(Map<String, dynamic> body, {String? successMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.patch('/prayer-partners/sessions/${session.id}', body: body);
      ref.invalidate(prayerSessionsProvider('upcoming'));
      if (mounted && successMessage != null) {
        Toast.success(context, successMessage);
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to update the session just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel session?',
      message:
          'This prayer session will be cancelled. Your partner will be '
          'notified — no offence taken on either side.',
      confirmLabel: 'Cancel session',
      destructive: true,
    );
    if (!ok) return;
    await _patch({'status': 'CANCELLED'}, successMessage: 'Session cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final startsAt = session.startsAt?.toLocal();
    final proposedByMe =
        session.proposedById != null && session.proposedById == me?.id;
    final canRespond = session.status == 'PROPOSED' && !proposedByMe;
    final canMarkAttendance = !session.myAttendanceRecorded &&
        (session.status == 'ACCEPTED' || session.status == 'PROPOSED');
    final canCancel =
        session.status == 'PROPOSED' || session.status == 'ACCEPTED';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.partnerName ?? 'Prayer partner',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(session.status),
                tone: badgeToneFor(session.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 15, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              Text(
                startsAt == null
                    ? 'Time to be confirmed'
                    : '${DateFormat('EEEE, d MMM yyyy').format(startsAt)} · '
                        '${DateFormat('HH:mm').format(startsAt)} '
                        '(${session.timeZone})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Icon(Icons.timelapse_rounded,
                  size: 15, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              Text('${session.durationMinutes} minutes',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (session.prayerFocus != null &&
              session.prayerFocus!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Focus: ${session.prayerFocus}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (session.myAttendanceRecorded) ...[
            const SizedBox(height: AppSpacing.xs),
            const StatusBadge(
              label: 'Attendance recorded',
              tone: AppBadgeTone.success,
              small: true,
              icon: Icons.check_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (canRespond) ...[
                AppButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  busy: _busy,
                  onPressed: () => _patch({'status': 'ACCEPTED'},
                      successMessage: 'Session accepted. See you there!'),
                ),
                AppButton(
                  label: 'Decline',
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: () => _patch({'status': 'CANCELLED'},
                      successMessage: 'Session declined.'),
                ),
              ],
              if (canMarkAttendance)
                AppButton(
                  label: session.myAttendanceRecorded
                      ? 'Attendance recorded'
                      : 'Mark attendance',
                  icon: Icons.fact_check_outlined,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: session.myAttendanceRecorded
                      ? null
                      : () => _patch(
                            {
                              'status': 'COMPLETED',
                              'myAttendance': true,
                            },
                            successMessage:
                                'Attendance recorded. Thanks for praying together!',
                          ),
                ),
              if (canCancel)
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _cancel,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- requests

class _PendingRequests extends ConsumerWidget {
  const _PendingRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(prayerRequestsProvider('incoming'));
    return async.when(
      loading: () => const CardListSkeleton(count: 2),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(prayerRequestsProvider('incoming')),
      ),
      data: (requests) {
        final pending = requests.where((r) => r.isPending).toList();
        if (pending.isEmpty) {
          return AppCard(
            child: EmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'No pending requests',
              message:
                  'When someone asks to partner with you in prayer, the '
                  'request will appear here.',
            ),
          );
        }
        return Column(
          children: [
            for (final request in pending) ...[
              _RequestRow(request: request),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class _RequestRow extends ConsumerStatefulWidget {
  const _RequestRow({required this.request});

  final PrayerRequest request;

  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _busy = false;

  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.patch(
        '/prayer-partners/requests/${widget.request.id}',
        body: {'action': action},
      );
      ref.invalidate(prayerRequestsProvider('incoming'));
      ref.invalidate(prayerSessionsProvider('upcoming'));
      ref.invalidate(currentPartnershipProvider);
      if (mounted) {
        Toast.success(
          context,
          action == 'accept'
              ? 'Request accepted — a session can now be arranged.'
              : 'Request declined. That’s completely okay.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to respond just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_outlined,
                  size: 18, color: AppColors.gold600),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.request.senderName ?? 'A member',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.request.createdAt != null)
                Text(
                  DateFormat('d MMM').format(widget.request.createdAt!.toLocal()),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          if (widget.request.message != null &&
              widget.request.message!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(widget.request.message!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppButton(
                label: 'Accept',
                busy: _busy,
                onPressed: () => _act('accept'),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Decline',
                variant: AppButtonVariant.outlined,
                busy: _busy,
                onPressed: () => _act('decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
