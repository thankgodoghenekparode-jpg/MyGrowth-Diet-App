import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_card.dart';

/// Details and in-app reading entry point for a Growth Diet book.
class ReadingBookScreen extends StatelessWidget {
  const ReadingBookScreen({
    super.key,
    required this.title,
    required this.author,
    this.coverAsset,
    this.backCoverAsset,
    required this.fileUrl,
  });

  final String title;
  final String author;
  final String? coverAsset;
  final String? backCoverAsset;
  final String fileUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Book')),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookCovers(front: coverAsset, back: backCoverAsset),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: theme.textTheme.headlineSmall),
                if (author.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    author,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: fileUrl.isEmpty
                        ? null
                        : () => context.push(
                            Uri(
                              path: '/reading/document',
                              queryParameters: {'title': title, 'url': fileUrl},
                            ).toString(),
                          ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Read book'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCovers extends StatelessWidget {
  const _BookCovers({this.front, this.back});

  final String? front;
  final String? back;

  @override
  Widget build(BuildContext context) {
    final covers = [
      if (front != null) (front!, 'Front cover'),
      if (back != null) (back!, 'Back cover'),
    ];
    if (covers.isEmpty) {
      return Center(
        child: Container(
          width: 148,
          height: 196,
          decoration: BoxDecoration(
            color: AppColors.navy700,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 56,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < covers.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    covers[i].$1,
                    height: 196,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      height: 196,
                      color: AppColors.surfaceMuted,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 40,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  covers[i].$2,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
