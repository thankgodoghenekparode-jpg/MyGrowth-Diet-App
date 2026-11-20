import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_catalog.dart';
import '../../core/audio/music_player_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/models/music_track.dart';

/// Full music library. The player is app-wide, so playback continues when the
/// member navigates away through the persistent mini player.
class MusicLibraryScreen extends ConsumerWidget {
  const MusicLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(musicCatalogProvider);
    final player = ref.watch(musicPlayerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Music'),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: AppSpacing.pagePaddingMobile,
            child: Text(
              'The music library could not be loaded. Please try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('No music has been added yet.'));
          }
          return ListView(
            padding: AppSpacing.pagePaddingMobile,
            children: [
              Text(
                'Worship and gospel music for your growth journey.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (player.hasTracks) _NowPlayingCard(player: player),
              if (player.hasTracks) const SizedBox(height: AppSpacing.md),
              Text(
                'All songs',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < tracks.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: AppSpacing.md),
                      _TrackRow(
                        track: tracks[i],
                        number: i + 1,
                        active: player.current?.id == tracks[i].id,
                        playing: player.playing,
                        onPlay: () => ref
                            .read(musicPlayerProvider.notifier)
                            .play(tracks[i], queue: tracks),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Music keeps playing while you use the rest of the app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard({required this.player});

  final MusicPlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final duration = player.duration;
    final maxMicros = duration?.inMicroseconds ?? 0;
    final progress = maxMicros <= 0
        ? 0.0
        : (player.position.inMicroseconds / maxMicros).clamp(0.0, 1.0);

    return AppCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: AppColors.iconAccent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(track.artist,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Slider(
            value: progress,
            onChanged: maxMicros <= 0 ||
                    player.status != MusicPlayerStatus.ready
                ? null
                : (value) => ref.read(musicPlayerProvider.notifier).seek(
                      Duration(microseconds: (maxMicros * value).round()),
                    ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(player.position), style: theme.textTheme.bodySmall),
              Text(
                duration == null ? track.displayDuration : _format(duration),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: () =>
                    ref.read(musicPlayerProvider.notifier).skipPrevious(),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                tooltip: player.playing ? 'Pause' : 'Play',
                iconSize: 30,
                icon: Icon(
                  player.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                onPressed: () =>
                    ref.read(musicPlayerProvider.notifier).togglePlayPause(),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: () =>
                    ref.read(musicPlayerProvider.notifier).skipNext(),
              ),
            ],
          ),
          if (player.error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              player.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.number,
    required this.active,
    required this.playing,
    required this.onPlay,
  });

  final MusicTrack track;
  final int number;
  final bool active;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        child: Text('$number'),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.iconAccent : null,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Play ${track.title}',
        icon: Icon(
          active && playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
        onPressed: onPlay,
      ),
      onTap: onPlay,
    );
  }
}
