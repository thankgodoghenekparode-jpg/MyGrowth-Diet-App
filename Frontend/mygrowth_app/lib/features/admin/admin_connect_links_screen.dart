import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/connect_link_model.dart';
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
import 'admin_shared.dart';

final adminConnectLinksProvider = FutureProvider.autoDispose<List<ConnectLink>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/admin/connect-links');
  final data = res.data as Map<String, dynamic>;
  final list = (data['links'] as List<dynamic>? ?? [])
      .map((e) => ConnectLink.fromJson(e as Map<String, dynamic>))
      .toList();
  list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return list;
});

class AdminConnectLinksScreen extends ConsumerWidget {
  const AdminConnectLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AdminConnectLinksBody();
  }
}

class _AdminConnectLinksBody extends ConsumerStatefulWidget {
  const _AdminConnectLinksBody();

  @override
  ConsumerState<_AdminConnectLinksBody> createState() => _AdminConnectLinksBodyState();
}

class _AdminConnectLinksBodyState extends ConsumerState<_AdminConnectLinksBody> {
  Future<void> _openEditor(ConnectLink? link) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _ConnectLinkSheet(link: link),
    );
    if (mounted) ref.invalidate(adminConnectLinksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(adminConnectLinksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminConnectLinksProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Connect with me links',
            subtitle: 'Manage links and QR codes shown to members',
            icon: Icons.link_outlined,
            actionLabel: 'New link',
            onAction: () => _openEditor(null),
          ),
          links.when(
            loading: () => const CardListSkeleton(count: 4),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(adminConnectLinksProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.link_outlined,
                    title: 'No connect links yet',
                    message: 'Add links with QR codes for members to connect.',
                    actionLabel: 'New link',
                    onAction: () => _openEditor(null),
                  ),
                );
              }
              return Column(
                children: [
                  for (final link in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    link.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                StatusBadge(
                                  label: link.isActive ? 'Active' : 'Inactive',
                                  tone: link.isActive
                                      ? AppBadgeTone.success
                                      : AppBadgeTone.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              link.url,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSecondary,
                                  ),
                            ),
                            if (link.description != null &&
                                link.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(link.description!),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Text(
                                  'Order: ${link.sortOrder}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _openEditor(link),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _confirmDelete(ref, link),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(WidgetRef ref, ConnectLink link) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete link?',
      message: 'Remove "${link.title}" from connect links.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/admin/connect-links/${link.id}');
      if (mounted) {
        Toast.success(context, 'Link deleted');
        ref.invalidate(adminConnectLinksProvider);
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Failed to delete link');
    }
  }
}

class _ConnectLinkSheet extends ConsumerStatefulWidget {
  const _ConnectLinkSheet({this.link});

  final ConnectLink? link;

  @override
  ConsumerState<_ConnectLinkSheet> createState() => _ConnectLinkSheetState();
}

class _ConnectLinkSheetState extends ConsumerState<_ConnectLinkSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.link?.title ?? '');
  late final TextEditingController _url = TextEditingController(text: widget.link?.url ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.link?.description ?? '');
  late final TextEditingController _icon = TextEditingController(text: widget.link?.icon ?? '');
  late final TextEditingController _qrCodeUrl = TextEditingController(text: widget.link?.qrCodeUrl ?? '');
  late final TextEditingController _sortOrder = TextEditingController(text: (widget.link?.sortOrder ?? 0).toString());
  bool _isActive = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.link?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _description.dispose();
    _icon.dispose();
    _qrCodeUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) {
      Toast.error(context, 'Title and URL are required');
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'title': _title.text.trim(),
        'url': _url.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'icon': _icon.text.trim().isEmpty ? null : _icon.text.trim(),
        'qrCodeUrl': _qrCodeUrl.text.trim().isEmpty ? null : _qrCodeUrl.text.trim(),
        'sortOrder': int.tryParse(_sortOrder.text.trim()) ?? 0,
        'isActive': _isActive,
      };
      if (widget.link == null) {
        await api.post('/admin/connect-links', body: body);
      } else {
        await api.patch('/admin/connect-links/${widget.link!.id}', body: body);
      }
      if (mounted) {
        Toast.success(context, 'Saved');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Failed to save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.link == null ? 'New connect link' : 'Edit connect link',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Title', required: true, controller: _title),
            const SizedBox(height: fieldGap),
            AppTextField(label: 'URL', required: true, controller: _url),
            const SizedBox(height: fieldGap),
            AppTextField(label: 'Description', controller: _description, maxLines: 2),
            const SizedBox(height: fieldGap),
            AppTextField(label: 'Icon (whatsapp, instagram, youtube, facebook, x, telegram, email, phone, website)', controller: _icon),
            const SizedBox(height: fieldGap),
            AppTextField(label: 'QR Code URL', controller: _qrCodeUrl),
            const SizedBox(height: fieldGap),
            AppTextField(label: 'Sort order', controller: _sortOrder, keyboardType: TextInputType.number),
            const SizedBox(height: fieldGap),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outlined,
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Save',
                    busy: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

