import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_card.dart';

/// Audio message destination shown from the Daily Diet reading list.
/// The audio URL will be connected when the ministry uploads the recording.
class ReadingAudioScreen extends StatelessWidget {
  const ReadingAudioScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Audio message'),
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          AppCard(
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.navy50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    color: AppColors.navy700,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                IconButton.filled(
                  onPressed: null,
                  tooltip: 'Audio not uploaded yet',
                  iconSize: 34,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The recording hasn’t been uploaded yet. It will be ready to '
                  'play here once it’s added.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkMuted,
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
