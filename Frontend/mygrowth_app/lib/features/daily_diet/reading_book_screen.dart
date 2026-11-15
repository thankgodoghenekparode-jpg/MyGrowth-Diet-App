import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';

/// Destination for a book in the Growth Diet reading list.
///
/// Book files are uploaded separately, so this screen provides the selected
/// book details until its reading content is available in the app.
class ReadingBookScreen extends StatelessWidget {
  const ReadingBookScreen({
    super.key,
    required this.title,
    required this.author,
  });

  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Book')),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 148,
                    height: 196,
                    decoration: BoxDecoration(
                      color: AppColors.navy700,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy900.withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.navy50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.navy700),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This book has been added to your reading list. '
                          'Its reading file will be available here after it is uploaded.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
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
