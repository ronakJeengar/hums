import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';

abstract class LyricsRepository {
  /// Fetches lyrics for a track, checking offline disk storage first if offline or downloaded,
  /// then falling back to remote backend API and caching offline when track is downloaded.
  Future<LyricsEntity> getLyrics(String trackId, {String? userId});

  /// Triggers asynchronous background generation of lyrics via Celery/Gemini.
  Future<LyricsEntity> triggerGeneration(String trackId);

  /// Manually uploads or saves lyrics for a track.
  Future<LyricsEntity> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineEntity>? lines,
  });
}
