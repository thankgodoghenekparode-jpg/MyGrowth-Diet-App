import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/connect_link_model.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';

final connectLinksProvider = FutureProvider.autoDispose<List<ConnectLink>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/connect-links');
  final data = res.data as Map<String, dynamic>;
  final list = (data['links'] as List<dynamic>? ?? [])
      .map((e) => ConnectLink.fromJson(e as Map<String, dynamic>))
      .toList();
  list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return list;
});

class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(connectLinksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect with me')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(connectLinksProvider),
        child: ListView(
          padding: Breakpoints.isCompact(context)
              ? AppSpacing.pagePaddingMobile
              : const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SectionHeader(
              title: 'Connect with me',
              subtitle: 'Links and QR codes to reach out',
              icon: Icons.link_outlined,
            ),
            links.when(
              loading: () => const CardListSkeleton(count: 3),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(connectLinksProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const AppCard(
                    child: EmptyState(
                      icon: Icons.link_outlined,
                      title: 'No links yet',
                      message: 'Connect links will appear here when added.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final link in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          onTap: () => _openLink(context, link),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.navy50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  _getIcon(link.icon),
                                  color: AppColors.navy700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      link.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if (link.description != null &&
                                        link.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          link.description!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.inkSecondary,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (link.qrCodeUrl != null &&
                                  link.qrCodeUrl!.isNotEmpty)
                                IconButton(
                                  tooltip: 'View QR code',
                                  onPressed: () => _showQr(context, link),
                                  icon: const Icon(Icons.qr_code_2_outlined),
                                ),
                              IconButton(
                                tooltip: 'Copy link',
                                onPressed: () => _copyLink(context, link),
                                icon: const Icon(Icons.copy_outlined),
                              ),
                              const Icon(Icons.open_in_new, size: 18),
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
      ),
    );
  }

  IconData _getIcon(String? icon) {
    switch (icon?.toLowerCase()) {
      case 'whatsapp':
        return Icons.chat;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'youtube':
        return Icons.play_circle_outline;
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
      case 'x':
        return Icons.alternate_email;
      case 'linkedin':
        return Icons.work_outline;
      case 'telegram':
        return Icons.send;
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'website':
      case 'web':
        return Icons.language;
      default:
        return Icons.link;
    }
  }

  Future<void> _openLink(BuildContext context, ConnectLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink(BuildContext context, ConnectLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${link.title} link'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showQr(BuildContext context, ConnectLink link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(link.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (link.qrCodeUrl != null && link.qrCodeUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  link.qrCodeUrl!,
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 250,
                    height: 250,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (link.description != null && link.description!.isNotEmpty)
              Text(
                link.description!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
