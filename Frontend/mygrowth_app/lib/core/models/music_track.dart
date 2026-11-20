import '../config/app_config.dart';

/// A playable track in the ministry music library.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.file,
    this.durationSeconds,
    this.cover,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String file;
  final int? durationSeconds;
  final String? cover;

  /// Absolute, publicly cacheable URL for the audio file.
  String get url {
    final parsed = Uri.tryParse(file);
    if (parsed != null && parsed.hasScheme) return file;
    final base = AppConfig.libraryContentBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = file.startsWith('/') ? file : '/music/$file';
    return '$base$path';
  }

  Uri? get artUri {
    if (cover == null || cover!.trim().isEmpty) return null;
    final parsed = Uri.tryParse(cover!);
    if (parsed != null && parsed.hasScheme) return parsed;
    final base = AppConfig.libraryContentBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = cover!.startsWith('/') ? cover! : '/music/$cover';
    return Uri.parse('$base$path');
  }

  String get displayDuration {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    final file = (json['file'] ?? json['url'] ?? '').toString();
    if (file.trim().isEmpty) {
      throw const FormatException('Music track is missing its file name.');
    }
    return MusicTrack(
      id: (json['id'] ?? file).toString(),
      title: (json['title'] ?? file).toString(),
      artist: (json['artist'] ?? '').toString(),
      album: (json['album'] ?? 'MyGrowth Music Library').toString(),
      file: file,
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).round()
          : int.tryParse((json['durationSeconds'] ?? '').toString()),
      cover: json['cover']?.toString(),
    );
  }
}
