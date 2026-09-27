import 'dart:convert';
import 'package:hums_mobile/features/downloads/data/services/download_file_manager.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyrics_model.dart';

abstract class LyricsLocalDataSource {
  Future<LyricsModel?> getCachedLyrics(String userId, String trackId);
  Future<void> saveCachedLyrics(String userId, String trackId, LyricsModel lyrics);
  Future<void> deleteCachedLyrics(String userId, String trackId);
  Future<bool> hasCachedLyrics(String userId, String trackId);
}

class LyricsLocalDataSourceImpl implements LyricsLocalDataSource {
  final DownloadFileManager _fileManager;

  LyricsLocalDataSourceImpl(this._fileManager);

  @override
  Future<LyricsModel?> getCachedLyrics(String userId, String trackId) async {
    try {
      final file = await _fileManager.getLyricsFile(userId, trackId);
      if (!await file.exists()) {
        return null;
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) {
        return null;
      }
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return LyricsModel.fromJson(jsonMap);
    } catch (_) {
      // Gracefully fall back if disk read or JSON parse fails
      return null;
    }
  }

  @override
  Future<void> saveCachedLyrics(
    String userId,
    String trackId,
    LyricsModel lyrics,
  ) async {
    try {
      final file = await _fileManager.getLyricsFile(userId, trackId);
      final jsonString = jsonEncode(lyrics.toJson());
      await file.writeAsString(jsonString, flush: true);
    } catch (_) {
      // Defensive fail-open: file caching failure should not break app flow
    }
  }

  @override
  Future<void> deleteCachedLyrics(String userId, String trackId) async {
    try {
      final file = await _fileManager.getLyricsFile(userId, trackId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Defensive
    }
  }

  @override
  Future<bool> hasCachedLyrics(String userId, String trackId) async {
    try {
      return await _fileManager.hasLyricsFile(userId, trackId);
    } catch (_) {
      return false;
    }
  }
}
