import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/music_track.dart';

enum MusicPlayerStatus { idle, loading, ready, error }

class MusicPlayerState {
  const MusicPlayerState({
    this.status = MusicPlayerStatus.idle,
    this.tracks = const <MusicTrack>[],
    this.currentIndex,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });

  final MusicPlayerStatus status;
  final List<MusicTrack> tracks;
  final int? currentIndex;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final String? error;

  bool get hasTracks => tracks.isNotEmpty;
  MusicTrack? get current =>
      currentIndex != null && currentIndex! < tracks.length
          ? tracks[currentIndex!]
          : null;

  MusicPlayerState copyWith({
    MusicPlayerStatus? status,
    List<MusicTrack>? tracks,
    bool clearCurrentIndex = false,
    int? currentIndex,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    String? error,
    bool clearError = false,
  }) {
    return MusicPlayerState(
      status: status ?? this.status,
      tracks: tracks ?? this.tracks,
      currentIndex: clearCurrentIndex
          ? null
          : (currentIndex ?? this.currentIndex),
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// One app-wide player. Keeping it in a long-lived provider means music keeps
/// playing while the member navigates between screens; just_audio_background
/// also exposes notification/lock-screen controls and OS-level background
/// playback on mobile.
class MusicPlayerController extends Notifier<MusicPlayerState> {
  AudioPlayer? _player;
  ConcatenatingAudioSource? _playlist;
  bool _disposed = false;

  @override
  MusicPlayerState build() {
    ref.keepAlive();
    final player = AudioPlayer();
    _player = player;

    player.currentIndexStream.listen((index) {
      if (_disposed || index == null) return;
      state = state.copyWith(
        currentIndex: index,
        position: Duration.zero,
        duration: player.duration,
      );
    });
    player.positionStream.listen((position) {
      if (_disposed) return;
      state = state.copyWith(position: position);
    });
    player.durationStream.listen((duration) {
      if (_disposed) return;
      state = state.copyWith(
        duration: duration,
        clearDuration: duration == null,
      );
    });
    player.playerStateStream.listen((playerState) {
      if (_disposed) return;
      state = state.copyWith(
        playing: playerState.playing,
        status: playerState.processingState == ProcessingState.completed
            ? MusicPlayerStatus.ready
            : state.status,
      );
    });

    ref.onDispose(() {
      _disposed = true;
      unawaited(player.dispose());
      _player = null;
      _playlist = null;
    });

    return const MusicPlayerState();
  }

  AudioPlayer get player {
    final value = _player;
    if (value == null) throw StateError('Music player is not available.');
    return value;
  }

  Future<void> play(MusicTrack track, {List<MusicTrack>? queue}) async {
    final tracks = queue == null || queue.isEmpty
        ? <MusicTrack>[track]
        : List<MusicTrack>.from(queue);
    var index = tracks.indexWhere((item) => item.id == track.id);
    if (index < 0) {
      tracks.insert(0, track);
      index = 0;
    }
    await playQueue(tracks, index: index);
  }

  Future<void> playQueue(
    List<MusicTrack> tracks, {
    int index = 0,
  }) async {
    if (tracks.isEmpty) return;
    final safeIndex = index < 0 ? 0 : (index >= tracks.length ? 0 : index);
    state = state.copyWith(
      status: MusicPlayerStatus.loading,
      tracks: List.unmodifiable(tracks),
      currentIndex: safeIndex,
      playing: false,
      clearError: true,
      position: Duration.zero,
      clearDuration: true,
    );

    try {
      final sources = tracks.map(_sourceFor).toList(growable: false);
      final playlist = ConcatenatingAudioSource(children: sources);
      _playlist = playlist;
      await player.setAudioSource(
        playlist,
        initialIndex: safeIndex,
        initialPosition: Duration.zero,
      );
      state = state.copyWith(
        status: MusicPlayerStatus.ready,
        duration: player.duration,
        clearDuration: player.duration == null,
      );
      await player.play();
    } catch (error) {
      state = state.copyWith(
        status: MusicPlayerStatus.error,
        error: 'The music could not be loaded. Check your connection and try again.',
      );
    }
  }

  AudioSource _sourceFor(MusicTrack track) {
    return AudioSource.uri(
      Uri.parse(track.url),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        artUri: track.artUri,
        duration: track.durationSeconds == null
            ? null
            : Duration(seconds: track.durationSeconds!),
      ),
    );
  }

  Future<void> togglePlayPause() async {
    if (!state.hasTracks) return;
    try {
      if (player.playerState.playing) {
        await player.pause();
      } else {
        if (player.playerState.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      state = state.copyWith(
        status: MusicPlayerStatus.error,
        error: 'Playback could not be resumed.',
      );
    }
  }

  Future<void> skipNext() async {
    if (!state.hasTracks) return;
    try {
      await player.seekToNext();
    } catch (_) {}
  }

  Future<void> skipPrevious() async {
    if (!state.hasTracks) return;
    try {
      if (player.position.inSeconds > 3) {
        await player.seek(Duration.zero);
      } else {
        await player.seekToPrevious();
      }
    } catch (_) {}
  }

  Future<void> seek(Duration position) async {
    if (!state.hasTracks) return;
    try {
      await player.seek(position);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {}
    _playlist = null;
    state = const MusicPlayerState();
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerController, MusicPlayerState>(
  MusicPlayerController.new,
);
