import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/audio_player/data/models/playback_model.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';

abstract class AudioPlayerRemoteDataSource {
  Future<TrackPlaybackModel> getPlaybackSource(String trackId);
  Future<List<QueueItem>> getUpNextCandidates({
    String? currentTrackId,
    int limit = 10,
    List<String>? excludeIds,
  });
  Future<List<QueueItem>> resolveTracks(List<String> trackIds);
}

class AudioPlayerRemoteDataSourceImpl implements AudioPlayerRemoteDataSource {
  final ApiClient _apiClient;

  AudioPlayerRemoteDataSourceImpl(this._apiClient);

  @override
  Future<TrackPlaybackModel> getPlaybackSource(String trackId) async {
    final response = await _apiClient.get(
      ApiEndpoints.audioTrackPlayback(trackId),
    );

    final data = response.data as Map<String, dynamic>;
    final trackData = data['data'] as Map<String, dynamic>;
    return TrackPlaybackModel.fromJson(trackData);
  }

  @override
  Future<List<QueueItem>> getUpNextCandidates({
    String? currentTrackId,
    int limit = 10,
    List<String>? excludeIds,
  }) async {
    final url = ApiEndpoints.playerUpNextQuery(
      currentTrackId: currentTrackId,
      limit: limit,
      excludeIds: excludeIds,
    );
    final response = await _apiClient.get(url);
    final data = response.data as Map<String, dynamic>;
    final innerData = data['data'] as Map<String, dynamic>;
    final itemsList = innerData['items'] as List<dynamic>? ?? [];

    return itemsList
        .map((item) => QueueItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<QueueItem>> resolveTracks(List<String> trackIds) async {
    if (trackIds.isEmpty) return [];
    final url = ApiEndpoints.playerResolveTracks(trackIds);
    final response = await _apiClient.get(url);
    final data = response.data as Map<String, dynamic>;
    final innerData = data['data'] as Map<String, dynamic>;
    final itemsList = innerData['items'] as List<dynamic>? ?? [];

    return itemsList
        .map((item) => QueueItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
