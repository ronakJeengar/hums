import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_local_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_remote_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyric_line_model.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/repositories/lyrics_repository.dart';

class LyricsRepositoryImpl implements LyricsRepository {
  final LyricsRemoteDataSource _remoteDataSource;
  final LyricsLocalDataSource _localDataSource;

  LyricsRepositoryImpl({
    required LyricsRemoteDataSource remoteDataSource,
    required LyricsLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<LyricsEntity> getLyrics(String trackId, {String? userId}) async {
    // 1. If user ID is available, check offline disk cache first
    if (userId != null && userId.isNotEmpty) {
      final cached = await _localDataSource.getCachedLyrics(userId, trackId);
      if (cached != null && cached.isCompleted) {
        return cached;
      }
    }

    try {
      // 2. Fetch authoritative lyrics from remote backend
      final remoteLyrics = await _remoteDataSource.getLyrics(trackId);

      // 3. Cache to disk if track is downloaded/cached and lyrics are completed
      if (userId != null &&
          userId.isNotEmpty &&
          remoteLyrics.status == LyricsStatusConstants.completed) {
        await _localDataSource.saveCachedLyrics(userId, trackId, remoteLyrics);
      }

      return remoteLyrics;
    } catch (e) {
      // 4. On network or server error, check if local cache has anything (even fallback)
      if (userId != null && userId.isNotEmpty) {
        final cached = await _localDataSource.getCachedLyrics(userId, trackId);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    }
  }

  @override
  Future<LyricsEntity> triggerGeneration(String trackId) async {
    return await _remoteDataSource.triggerGeneration(trackId);
  }

  @override
  Future<LyricsEntity> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineEntity>? lines,
  }) async {
    final lineModels = lines
        ?.map((l) =>
            l is LyricLineModel ? l : LyricLineModel.fromEntity(l))
        .toList();

    return await _remoteDataSource.uploadLyrics(
      trackId,
      text: text,
      language: language,
      isSynchronized: isSynchronized,
      lines: lineModels,
    );
  }
}
