import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

abstract class PlaybackSettingsRemoteDataSource {
  Future<PlaybackSettingsEntity> getSettings();
  Future<PlaybackSettingsEntity> updateSettings(PlaybackSettingsEntity settings);
}

class PlaybackSettingsRemoteDataSourceImpl implements PlaybackSettingsRemoteDataSource {
  final ApiClient _apiClient;

  PlaybackSettingsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<PlaybackSettingsEntity> getSettings() async {
    final response = await _apiClient.get(ApiEndpoints.playbackSettings);
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return PlaybackSettingsEntity.fromJson(payload);
  }

  @override
  Future<PlaybackSettingsEntity> updateSettings(PlaybackSettingsEntity settings) async {
    final response = await _apiClient.put(
      ApiEndpoints.playbackSettings,
      data: settings.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return PlaybackSettingsEntity.fromJson(payload);
  }
}
