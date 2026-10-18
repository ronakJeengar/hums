import 'package:hums_mobile/features/playback_settings/data/datasources/playback_settings_local_data_source.dart';
import 'package:hums_mobile/features/playback_settings/data/datasources/playback_settings_remote_data_source.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';
import 'package:hums_mobile/features/playback_settings/domain/repositories/playback_settings_repository.dart';

class PlaybackSettingsRepositoryImpl implements PlaybackSettingsRepository {
  final PlaybackSettingsRemoteDataSource _remoteDataSource;
  final PlaybackSettingsLocalDataSource _localDataSource;

  PlaybackSettingsRepositoryImpl({
    required PlaybackSettingsRemoteDataSource remoteDataSource,
    required PlaybackSettingsLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<PlaybackSettingsEntity> getSettings() async {
    // 1. Read from local cache for instant zero-latency startup
    final cached = await _localDataSource.getCachedSettings();

    // 2. Refresh from backend in background / online
    try {
      final remote = await _remoteDataSource.getSettings();
      await _localDataSource.cacheSettings(remote);
      return remote;
    } catch (_) {
      // Return cached settings if offline or unauthenticated
      return cached;
    }
  }

  @override
  Future<PlaybackSettingsEntity> updateSettings(PlaybackSettingsEntity settings) async {
    // 1. Optimistic write to local storage
    await _localDataSource.cacheSettings(settings);

    // 2. Synchronize with backend
    try {
      final updated = await _remoteDataSource.updateSettings(settings);
      await _localDataSource.cacheSettings(updated);
      return updated;
    } catch (_) {
      // Retain optimistic local settings even if offline
      return settings;
    }
  }
}
