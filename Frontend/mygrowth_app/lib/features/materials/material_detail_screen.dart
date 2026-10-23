import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/material_models.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/toast.dart';
import 'materials_providers.dart';
import 'materials_screen.dart';

/// Full detail view for one study material: metadata, description, honest
/// open/copy actions, completion tracking and reading-list toggle.
class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(materialDetailProvider(materialId));
    return Scaffold(
      appBar: AppBar(title: const Text('Material')),
      body: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 4),
        ),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(materialDetailProvider(materialId)),
        ),
        data: (material) {
          if (material == null) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Material not found',
              message:
                  'This material may have been removed by your ministry. '
                  'Head back to the library to keep studying.',
              actionLabel: 'Back to library',
            );
          }
          return _MaterialDetailView(material: material);
        },
      ),
    );
  }
}

class _MaterialDetailView extends ConsumerStatefulWidget {
  const _MaterialDetailView({required this.material});

  final MaterialItem material;

  @override
  ConsumerState<_MaterialDetailView> createState() =>
      _MaterialDetailViewState();
}

class _MaterialDetailViewState extends ConsumerState<_MaterialDetailView> {
  bool _busy = false;

  MaterialItem get material => widget.material;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// External links: the app has no in-app browser, so we copy the link and
  /// tell the member exactly what happened.
  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    Toast.show(
      context,
      message: 'Link copied — open it in your browser: $url',
      tone: ToastTone.info,
      duration: const Duration(seconds: 5),
    );
  }

  /// Files: probe the file endpoint honestly. We do not fake a player or
  /// renderer; if the service doesn't hand back a downloadable stream or
  /// link we say so.
  Future<void> _openFile() => _run(() async {
        final client = ref.read(apiClientProvider);
        final res = await client.get('/files/${material.fileId}');
        if (!mounted) return;
        if (res is Map<String, dynamic>) {
          final url = res['url'] ??
              res['downloadUrl'] ??
              (res['data'] is Map ? res['data']['url'] : null);
          if (url is String && url.isNotEmpty) {
            _copyLink(url);
            return;
          }
          Toast.show(
            context,
            message:
                'The file service returned metadata only — in-app download '
                'isn’t available yet.',
            tone: ToastTone.info,
          );
          return;
        }
        // The client only decodes JSON; a binary stream comes back as null.
        Toast.show(
          context,
          message:
              'The file exists but this app can’t open files inline yet. '
              'Ask your ministry admin for a shareable link in the meantime.',
          tone: ToastTone.info,
        );
      });

  Future<void> _toggleCompleted() => _run(() async {
        final client = ref.read(apiClientProvider);
        try {
          await client.post('/materials/${material.id}/complete');
        } on ApiException catch (e) {
          if (e.statusCode == 404 || e.statusCode == 501) {
            if (mounted) {
              Toast.show(
                context,
                message: 'Not available yet — completion tracking isn’t '
                    'enabled on the server.',
                tone: ToastTone.info,
              );
            }
            return;
          }
          rethrow;
        }
        ref.invalidate(materialDetailProvider(material.id));
        ref.invalidate(materialsListProvider(false));
        ref.invalidate(materialsListProvider(true));
        if (mounted) {
          Toast.success(
            context,
            material.isCompleted
                ? 'Marked as not completed.'
                : 'Wonderful — marked as completed!',
          );
        }
      });

  Future<void> _toggleSaved() => _run(() async {
        final client = ref.read(apiClientProvider);
        await client.post(
          '/materials/${material.id}/save',
          body: {'saved': !material.savedToReadingList},
        );
        ref.invalidate(materialDetailProvider(material.id));
        ref.invalidate(materialsListProvider(false));
        ref.invalidate(materialsListProvider(true));
        if (mounted) {
          Toast.success(
            context,
            material.savedToReadingList
                ? 'Removed from your reading list.'
                : 'Saved to your reading list.',
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final period = materialPeriodLabel(material);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(materialDetailProvider(material.id));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: ListView(
        padding: Breakpoints.isCompact(context)
            ? AppSpacing.pagePaddingMobile
            : const EdgeInsets.all(AppSpacing.xl),
        children: [
          // ------------------------------------------------- header card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.navy100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        materialCategoryIcon(material.category),
                        color: AppColors.navy700,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (material.author != null &&
                              material.author!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              material.author!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge(
                      label: humanizeStatus(material.category),
                      tone: AppBadgeTone.navy,
                    ),
                    if (period.isNotEmpty)
                      StatusBadge(label: period, tone: AppBadgeTone.gold),
                    if (material.isCompleted)
                      const StatusBadge(
                        label: 'Completed',
                        tone: AppBadgeTone.success,
                        icon: Icons.check_rounded,
                      ),
                    if (material.publishedAt != null)
                      StatusBadge(
                        label:
                            'Published ${DateFormat('d MMM yyyy').format(material.publishedAt!.toLocal())}',
                        tone: AppBadgeTone.neutral,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // ------------------------------------------------ actions
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (material.externalUrl != null &&
                        material.externalUrl!.isNotEmpty)
                      AppButton(
                        label: 'Open link',
                        icon: Icons.open_in_new_rounded,
                        busy: _busy,
                        variant: AppButtonVariant.outlined,
                        onPressed: () => _copyLink(material.externalUrl!),
                      ),
                    if (material.isFile)
                      AppButton(
                        label: 'Open file',
                        icon: Icons.attach_file_rounded,
                        busy: _busy,
                        variant: AppButtonVariant.outlined,
                        onPressed: _openFile,
                      ),
                    AppButton(
                      label: material.isCompleted
                          ? 'Mark as not completed'
                          : 'Mark as completed',
                      icon: material.isCompleted
                          ? Icons.undo_rounded
                          : Icons.check_circle_outline_rounded,
                      busy: _busy,
                      onPressed: _toggleCompleted,
                    ),
                    AppButton(
                      label: material.savedToReadingList
                          ? 'Remove from reading list'
                          : 'Save to reading list',
                      icon: material.savedToReadingList
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_add_outlined,
                      busy: _busy,
                      variant: AppButtonVariant.outlined,
                      onPressed: _toggleSaved,
                    ),
                  ],
                ),
                if (material.externalUrl == null && !material.isFile)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'This material has no attached link or file yet.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ------------------------------------------------ audio notice
          if (material.isAudio) ...[
            const _AudioPlayerPlaceholder(),
            const SizedBox(height: AppSpacing.md),
          ],

          // ------------------------------------------------ description
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  (material.description == null ||
                          material.description!.trim().isEmpty)
                      ? 'No description was provided for this material.'
                      : material.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        color: AppColors.inkSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // -------------------------------------------------- file meta
          if (material.fileType != null || material.fileId != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (material.fileType != null)
                    Text('Type: ${material.fileType}',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (material.createdAt != null)
                    Text(
                      'Added ${DateFormat('d MMM yyyy').format(material.createdAt!.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/materials'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to library'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Honest placeholder for audio materials: no playback is faked.
class _AudioPlayerPlaceholder extends StatelessWidget {
  const _AudioPlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.navy50,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.navy100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.headphones_outlined,
                color: AppColors.navy700, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio material',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Audio playback requires the media endpoint — duration and '
                  'streaming aren’t available yet. This app won’t pretend '
                  'to play audio it can’t deliver.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
