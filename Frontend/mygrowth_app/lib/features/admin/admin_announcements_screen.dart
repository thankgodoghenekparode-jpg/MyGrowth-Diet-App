import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/notification_models.dart';
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
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Announcements: create, publish, archive and delete ministry announcements.
class AdminAnnouncementsScreen extends ConsumerWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AnnouncementsBody();
  }
}

class _AnnouncementsBody extends ConsumerStatefulWidget {
  const _AnnouncementsBody();

  @override
  ConsumerState<_AnnouncementsBody> createState() =>
      _AnnouncementsBodyState();
}

class _AnnouncementsBodyState extends ConsumerState<_AnnouncementsBody> {
  String _status = '';

  Future<void> _openEditor(Announcement? announcement) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _AnnouncementSheet(announcement: announcement),
    );
    if (mounted) ref.invalidate(adminAnnouncementsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(adminAnnouncementsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAnnouncementsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Announcements',
            subtitle: 'Keep members informed; publish when you are ready',
            icon: Icons.campaign_outlined,
            actionLabel: 'New announcement',
            onAction: () => _openEditor(null),
          ),
          AppCard(
            child: AppDropdown<String>(
              label: 'Status',
              value: _status,
              items: const [
                DropdownMenuItem(value: '', child: Text('All statuses')),
                DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
                DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          announcements.when(
            loading: () => const CardListSkeleton(count: 4),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminAnnouncementsProvider),
            ),
            data: (items) {
              final filtered = _status.isEmpty
                  ? items
                  : items.where((a) => a.status == _status).toList();
              if (filtered.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.campaign_outlined,
                    title: items.isEmpty
                        ? 'No announcements yet'
                        : 'Nothing with this status',
                    message: items.isEmpty
                        ? 'Post an announcement to keep everyone aligned on '
                            'the programme.'
                        : 'Try a different status filter.',
                    actionLabel: 'New announcement',
                    onAction: () => _openEditor(null),
                  ),
                );
              }
              return Column(
                children: [
                  for (final a in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AnnouncementCard(
                        announcement: a,
                        onEdit: () => _openEditor(a),
                        onChanged: () =>
                            ref.invalidate(adminAnnouncementsProvider),
                      ),
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

class _AnnouncementCard extends ConsumerStatefulWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onChanged,
  });

  final Announcement announcement;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  bool _busy = false;

  Future<void> _run(String success, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged();
      Toast.success(context, success);
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t complete that just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Publish this announcement?',
      message: widget.announcement.audience == 'ADMINS_ONLY'
          ? 'Administrators will see it in the app.'
          : 'All members will be notified (unless notifications are switched '
              'off in Settings).',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    await _run('Announcement published.', () async {
      await ref
          .read(apiClientProvider)
          .post('/admin/announcements/${widget.announcement.id}/publish');
    });
  }

  Future<void> _archive() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Archive this announcement?',
      message: 'It is hidden from the app but kept on record.',
      confirmLabel: 'Archive',
    );
    if (!confirmed || !mounted) return;
    await _run('Announcement archived.', () async {
      await ref
          .read(apiClientProvider)
          .post('/admin/announcements/${widget.announcement.id}/archive');
    });
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this announcement?',
      message: 'This permanently removes it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run('Announcement deleted.', () async {
      await ref
          .read(apiClientProvider)
          .delete('/admin/announcements/${widget.announcement.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: humanizeStatus(a.status),
                tone: badgeToneFor(a.status),
                small: true,
              ),
              const SizedBox(width: AppSpacing.xxs),
              StatusBadge(
                label: a.audience == 'ADMINS_ONLY' ? 'Admins only' : 'All members',
                tone: AppBadgeTone.navy,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(a.body, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Created ${fmtDate(a.createdAt)}'
            '${a.createdByName == null ? '' : ' · by ${a.createdByName}'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (a.link != null && a.link!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 14, color: AppColors.inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    a.link!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: widget.onEdit,
              ),
              if (a.status != 'PUBLISHED')
                AppButton(
                  label: 'Publish',
                  icon: Icons.publish_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _publish,
                ),
              if (a.status != 'ARCHIVED')
                AppButton(
                  label: 'Archive',
                  icon: Icons.archive_outlined,
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _archive,
                ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.text,
                busy: _busy,
                onPressed: _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementSheet extends ConsumerStatefulWidget {
  const _AnnouncementSheet({this.announcement});

  final Announcement? announcement;

  @override
  ConsumerState<_AnnouncementSheet> createState() => _AnnouncementSheetState();
}

class _AnnouncementSheetState extends ConsumerState<_AnnouncementSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.announcement?.title ?? '');
  late final TextEditingController _body =
      TextEditingController(text: widget.announcement?.body ?? '');
  late final TextEditingController _link =
      TextEditingController(text: widget.announcement?.link ?? '');
  late String _audience = widget.announcement?.audience == 'ADMINS_ONLY'
      ? 'ADMINS_ONLY'
      : 'ALL_MEMBERS';
  late DateTime? _startsAt = widget.announcement?.startsAt;
  late DateTime? _endsAt = widget.announcement?.endsAt;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  String? _iso(DateTime? value, {bool endOfDay = false}) {
    if (value == null) return null;
    final d = endOfDay
        ? DateTime(value.year, value.month, value.day, 23, 59, 59)
        : DateTime(value.year, value.month, value.day);
    return d.toUtc().toIso8601String();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      Toast.error(context, 'A title and body are required.');
      return;
    }
    setState(() => _saving = true);
    final link = _link.text.trim();
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'audience': _audience,
      'link': link.isEmpty ? null : link,
      'startsAt': _iso(_startsAt),
      'endsAt': _iso(_endsAt, endOfDay: true),
    };
    try {
      final client = ref.read(apiClientProvider);
      final a = widget.announcement;
      if (a == null) {
        await client.post('/admin/announcements', body: body);
      } else {
        await client.patch('/admin/announcements/${a.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(context, 'Announcement saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this announcement just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.announcement != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editing ? 'Edit announcement' : 'New announcement',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Save as a draft, then publish when it is ready.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Title',
          controller: _title,
          required: true,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Message',
          controller: _body,
          maxLines: 5,
          required: true,
        ),
        const SizedBox(height: fieldGap),
        AppDropdown<String>(
          label: 'Audience',
          value: _audience,
          items: const [
            DropdownMenuItem(value: 'ALL_MEMBERS', child: Text('All members')),
            DropdownMenuItem(value: 'ADMINS_ONLY', child: Text('Admins only')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _audience = value);
          },
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Link (optional)',
          controller: _link,
          hint: 'https://…',
        ),
        const SizedBox(height: fieldGap),
        Row(
          children: [
            Expanded(
              child: AppDateField(
                label: 'Starts (optional)',
                value: _startsAt,
                onChanged: (value) => setState(() => _startsAt = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDateField(
                label: 'Ends (optional)',
                value: _endsAt,
                onChanged: (value) => setState(() => _endsAt = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: editing ? 'Save announcement' : 'Create announcement',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
