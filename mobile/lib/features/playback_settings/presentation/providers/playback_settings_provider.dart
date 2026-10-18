import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/playback_settings/data/datasources/playback_settings_local_data_source.dart';
import 'package:hums_mobile/features/playback_settings/data/datasources/playback_settings_remote_data_source.dart';
import 'package:hums_mobile/features/playback_settings/data/repositories/playback_settings_repository_impl.dart';
import 'package:hums_mobile/features/playback_settings/data/services/network_info_service.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_quality_resolver.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';
import 'package:hums_mobile/features/playback_settings/domain/repositories/playback_settings_repository.dart';

final playbackSettingsLocalDataSourceProvider =
    Provider<PlaybackSettingsLocalDataSource>((ref) {
  return PlaybackSettingsLocalDataSourceImpl();
});

final playbackSettingsRemoteDataSourceProvider =
    Provider<PlaybackSettingsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlaybackSettingsRemoteDataSourceImpl(apiClient);
});

final playbackSettingsRepositoryProvider =
    Provider<PlaybackSettingsRepository>((ref) {
  final remote = ref.watch(playbackSettingsRemoteDataSourceProvider);
  final local = ref.watch(playbackSettingsLocalDataSourceProvider);
  return PlaybackSettingsRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
  );
});

final networkInfoServiceProvider = Provider<NetworkInfoService>((ref) {
  final service = NetworkInfoServiceImpl();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final networkTypeProvider = StateProvider<NetworkType>((ref) {
  final service = ref.watch(networkInfoServiceProvider);
  service.onNetworkTypeChanged.listen((type) {
    ref.controller.state = type;
  });
  return service.currentNetworkType;
});

final playbackQualityResolverProvider =
    Provider<PlaybackQualityResolver>((ref) {
  return const PlaybackQualityResolver();
});

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettingsEntity> {
  final PlaybackSettingsRepository _repository;

  PlaybackSettingsNotifier(this._repository)
      : super(const PlaybackSettingsEntity()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final settings = await _repository.getSettings();
    state = settings;
  }

  Future<void> setStreamingQuality(AudioQuality quality) async {
    final updated = state.copyWith(streamingQuality: quality);
    state = updated;
    await _repository.updateSettings(updated);
  }

  Future<void> setMobileDataQuality(AudioQuality quality) async {
    final updated = state.copyWith(mobileDataQuality: quality);
    state = updated;
    await _repository.updateSettings(updated);
  }

  Future<void> setWifiQuality(AudioQuality quality) async {
    final updated = state.copyWith(wifiQuality: quality);
    state = updated;
    await _repository.updateSettings(updated);
  }

  Future<void> setDownloadQuality(AudioQuality quality) async {
    final updated = state.copyWith(downloadQuality: quality);
    state = updated;
    await _repository.updateSettings(updated);
  }

  Future<void> setDataSaver(bool enabled) async {
    final updated = state.copyWith(dataSaverEnabled: enabled);
    state = updated;
    await _repository.updateSettings(updated);
  }
}

final playbackSettingsNotifierProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettingsEntity>(
        (ref) {
  final repo = ref.watch(playbackSettingsRepositoryProvider);
  return PlaybackSettingsNotifier(repo);
});
