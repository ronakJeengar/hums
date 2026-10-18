import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';
import 'package:hums_mobile/features/playback_settings/domain/repositories/playback_settings_repository.dart';
import 'package:hums_mobile/features/playback_settings/presentation/providers/playback_settings_provider.dart';

class MockPlaybackSettingsRepository implements PlaybackSettingsRepository {
  PlaybackSettingsEntity currentSettings = const PlaybackSettingsEntity();
  int getCalls = 0;
  int updateCalls = 0;
  bool shouldFail = false;

  @override
  Future<PlaybackSettingsEntity> getSettings() async {
    getCalls++;
    if (shouldFail) throw Exception('Network error');
    return currentSettings;
  }

  @override
  Future<PlaybackSettingsEntity> updateSettings(PlaybackSettingsEntity settings) async {
    updateCalls++;
    if (shouldFail) throw Exception('Network error');
    currentSettings = settings;
    return currentSettings;
  }
}

void main() {
  late MockPlaybackSettingsRepository mockRepository;
  late PlaybackSettingsNotifier notifier;

  setUp(() {
    mockRepository = MockPlaybackSettingsRepository();
    notifier = PlaybackSettingsNotifier(mockRepository);
  });

  test('initial state has sensible defaults', () {
    expect(notifier.state.streamingQuality, equals(AudioQuality.auto));
    expect(notifier.state.dataSaverEnabled, isFalse);
    expect(notifier.state.wifiQuality, equals(AudioQuality.high));
  });

  test('loadSettings loads settings from repository', () async {
    mockRepository.currentSettings = const PlaybackSettingsEntity(
      streamingQuality: AudioQuality.high,
      mobileDataQuality: AudioQuality.medium,
      wifiQuality: AudioQuality.high,
      downloadQuality: AudioQuality.medium,
      dataSaverEnabled: true,
    );

    await notifier.loadSettings();

    expect(notifier.state.streamingQuality, equals(AudioQuality.high));
    expect(notifier.state.mobileDataQuality, equals(AudioQuality.medium));
    expect(notifier.state.dataSaverEnabled, isTrue);
    expect(mockRepository.getCalls, equals(2));
  });

  test('setDataSaver updates state and persists through repository', () async {
    await notifier.setDataSaver(true);

    expect(notifier.state.dataSaverEnabled, isTrue);
    expect(mockRepository.updateCalls, equals(1));
    expect(mockRepository.currentSettings.dataSaverEnabled, isTrue);
  });

  test('setStreamingQuality updates state and persists', () async {
    await notifier.setStreamingQuality(AudioQuality.low);

    expect(notifier.state.streamingQuality, equals(AudioQuality.low));
    expect(mockRepository.updateCalls, equals(1));
  });

  test('setMobileDataQuality updates state and persists', () async {
    await notifier.setMobileDataQuality(AudioQuality.medium);

    expect(notifier.state.mobileDataQuality, equals(AudioQuality.medium));
    expect(mockRepository.updateCalls, equals(1));
  });

  test('setWifiQuality updates state and persists', () async {
    await notifier.setWifiQuality(AudioQuality.medium);

    expect(notifier.state.wifiQuality, equals(AudioQuality.medium));
    expect(mockRepository.updateCalls, equals(1));
  });

  test('setDownloadQuality updates state and persists', () async {
    await notifier.setDownloadQuality(AudioQuality.low);

    expect(notifier.state.downloadQuality, equals(AudioQuality.low));
    expect(mockRepository.updateCalls, equals(1));
  });
}
