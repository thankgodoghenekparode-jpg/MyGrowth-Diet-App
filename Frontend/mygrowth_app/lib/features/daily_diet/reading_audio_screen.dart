import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_card.dart';

/// Streams an audio message from the programme's public media library.
class ReadingAudioScreen extends StatefulWidget {
  const ReadingAudioScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<ReadingAudioScreen> createState() => _ReadingAudioScreenState();
}

class _ReadingAudioScreenState extends State<ReadingAudioScreen> {
  final AudioPlayer _player = AudioPlayer();
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      await _player.setUrl(widget.url);
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _time(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

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
                  widget.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  )
                else if (_error != null)
                  Text(
                    'This recording could not be loaded. Please try again when you have an internet connection.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  )
                else ...[
                  StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: _player.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration =
                              durationSnapshot.data ?? Duration.zero;
                          final maxMicros = duration.inMicroseconds;
                          final progress = maxMicros == 0
                              ? 0.0
                              : (position.inMicroseconds / maxMicros).clamp(
                                  0.0,
                                  1.0,
                                );
                          return Column(
                            children: [
                              Slider(
                                value: progress,
                                onChanged: maxMicros == 0
                                    ? null
                                    : (value) => _player.seek(
                                        Duration(
                                          microseconds: (maxMicros * value)
                                              .round(),
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_time(position)),
                                    Text(_time(durationSnapshot.data)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      final completed =
                          snapshot.data?.processingState ==
                          ProcessingState.completed;
                      return IconButton.filled(
                        onPressed: () async {
                          if (completed) {
                            await _player.seek(Duration.zero);
                            await _player.play();
                          } else if (playing) {
                            await _player.pause();
                          } else {
                            await _player.play();
                          }
                        },
                        tooltip: playing ? 'Pause' : 'Play',
                        iconSize: 34,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
