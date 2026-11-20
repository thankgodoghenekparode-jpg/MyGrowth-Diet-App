import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/music_track.dart';

/// Bundled fallback so the music library still works if the media host is
/// briefly unreachable. The remote catalog is authoritative when available.
const fallbackMusicTracks = <MusicTrack>[
  MusicTrack(id: 'this-is-the-air-i-breathe', title: 'This Is The Air I Breathe', artist: 'Hillsong Worship', album: 'MyGrowth Music Library', file: 'music-01.mp3', durationSeconds: 313),
  MusicTrack(id: 'dependable-jesus', title: 'Dependable Jesus', artist: 'Esther Oji', album: 'MyGrowth Music Library', file: 'music-02.mp3', durationSeconds: 368),
  MusicTrack(id: 'glorified', title: 'Glorified', artist: 'Esther Oji', album: 'MyGrowth Music Library', file: 'music-03.mp3', durationSeconds: 92),
  MusicTrack(id: 'all-i-see-is-you', title: 'All I See Is You', artist: 'Sinach', album: 'MyGrowth Music Library', file: 'music-04.mp3', durationSeconds: 448),
  MusicTrack(id: 'nothing-like-your-presence', title: 'Nothing Like Your Presence', artist: 'Todd Galberth & Chris Lawson', album: 'MyGrowth Music Library', file: 'music-05.mp3', durationSeconds: 485),
  MusicTrack(id: 'heart-of-worship', title: 'Heart Of Worship', artist: 'Brandon Lake', album: 'MyGrowth Music Library', file: 'music-06.mp3', durationSeconds: 331),
  MusicTrack(id: 'god-im-just-grateful', title: "God I'm Just Grateful", artist: 'Elevation Worship', album: 'MyGrowth Music Library', file: 'music-07.mp3', durationSeconds: 298),
  MusicTrack(id: 'ori-mi', title: 'Ori Mi', artist: 'Neeja', album: 'MyGrowth Music Library', file: 'music-08.mp3', durationSeconds: 171),
  MusicTrack(id: 'the-only-home-i-know', title: 'The Only Home I Know', artist: 'May the Lord Studio', album: 'MyGrowth Music Library', file: 'music-09.mp3', durationSeconds: 176),
  MusicTrack(id: 'this-is-not-the-first-time', title: 'This Is Not The First Time', artist: 'Sunvera Scott', album: 'MyGrowth Music Library', file: 'music-10.mp3', durationSeconds: 230),
];

/// Loads the music catalog published with the backend media library.
final musicCatalogProvider = FutureProvider<List<MusicTrack>>((ref) async {
  final base = AppConfig.libraryContentBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  final uri = Uri.parse('$base/music/tracks.json');
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return fallbackMusicTracks;
    final decoded = _decodeJson(response.body);
    final raw = decoded['tracks'];
    if (raw is! List) return fallbackMusicTracks;
    final tracks = <MusicTrack>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        tracks.add(MusicTrack.fromJson(entry));
      } else if (entry is Map) {
        tracks.add(MusicTrack.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return tracks.isEmpty ? fallbackMusicTracks : List.unmodifiable(tracks);
  } catch (_) {
    return fallbackMusicTracks;
  }
});

Map<String, dynamic> _decodeJson(String body) {
  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic>
      ? decoded
      : Map<String, dynamic>.from(decoded as Map);
}
