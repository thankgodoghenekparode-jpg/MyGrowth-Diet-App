import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/music_player_controller.dart';

/// Compact persistent player shown above the bottom navigation. It keeps the
/// current track visible and controllable from any member screen while the
/// underlying AudioPlayer continues playing in the background.
class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.current;
    if (!state.hasTracks || track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final duration = state.duration;
    final progress = duration == null ||
            duration.inMicroseconds <= 0
        ? 0.0
        : (state.position.inMicroseconds / duration.inMicroseconds).clamp(
            0.0,
            1.0,
          );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
            ),
          ),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              child: Icon(
                track.artUri == null
                    ? Icons.music_note_rounded
                    : Icons.album_rounded,
                size: 20,
              ),
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push('/music'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: state.playing ? 'Pause' : 'Play',
                  icon: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).togglePlayPause(),
                ),
                IconButton(
                  tooltip: 'Next song',
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).skipNext(),
                ),
                IconButton(
                  tooltip: 'Close player',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref.read(musicPlayerProvider.notifier).stop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
