import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/audio_player/data/models/playback_model.dart';

abstract class AudioPlayerRemoteDataSource {
  Future<TrackPlaybackModel> getPlaybackSource(String trackId);
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
}
