import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyric_line_model.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyrics_model.dart';

abstract class LyricsRemoteDataSource {
  /// Fetches lyrics for the given track ID.
  Future<LyricsModel> getLyrics(String trackId);

  /// Triggers asynchronous background lyrics generation.
  Future<LyricsModel> triggerGeneration(String trackId);

  /// Uploads or saves manual lyrics.
  Future<LyricsModel> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineModel>? lines,
  });
}

class LyricsRemoteDataSourceImpl implements LyricsRemoteDataSource {
  final ApiClient _apiClient;

  LyricsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<LyricsModel> getLyrics(String trackId) async {
    final response = await _apiClient.get(ApiEndpoints.trackLyrics(trackId));
    final data = response.data['data'] as Map<String, dynamic>;
    return LyricsModel.fromJson(data);
  }

  @override
  Future<LyricsModel> triggerGeneration(String trackId) async {
    final response =
        await _apiClient.post(ApiEndpoints.trackLyricsGenerate(trackId));
    final data = response.data['data'] as Map<String, dynamic>;
    return LyricsModel.fromJson(data);
  }

  @override
  Future<LyricsModel> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineModel>? lines,
  }) async {
    final payload = {
      'text': ?text,
      'language': ?language,
      'is_synchronized': isSynchronized,
      if (lines != null) 'lines': lines.map((l) => l.toJson()).toList(),
    };
    final response = await _apiClient.post(
      ApiEndpoints.trackLyrics(trackId),
      data: payload,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return LyricsModel.fromJson(data);
  }
}
