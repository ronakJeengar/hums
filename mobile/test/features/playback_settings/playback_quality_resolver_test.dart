import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_quality_resolver.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

void main() {
  late PlaybackQualityResolver resolver;

  setUp(() {
    resolver = const PlaybackQualityResolver();
  });

  group('PlaybackQualityResolver - Explicit Manual Selection', () {
    test('explicit session quality takes highest precedence over all settings', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.high,
        mobileDataQuality: AudioQuality.high,
        wifiQuality: AudioQuality.high,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: true,
      );

      // Even on mobile with data saver enabled, explicit override takes precedence
      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.mobile,
        sessionOverride: AudioQuality.low,
      );

      expect(result, equals(AudioQuality.low));
    });

    test('explicit session quality overrides auto Wi-Fi', () {
      const settings = PlaybackSettingsEntity();

      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.wifi,
        sessionOverride: AudioQuality.medium,
      );

      expect(result, equals(AudioQuality.medium));
    });
  });

  group('PlaybackQualityResolver - Data Saver Mode', () {
    test('data saver forces LOW on mobile network regardless of preferences', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.high,
        mobileDataQuality: AudioQuality.high,
        wifiQuality: AudioQuality.high,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: true,
      );

      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.mobile,
      );

      expect(result, equals(AudioQuality.low));
    });

    test('data saver does not force LOW on Wi-Fi network', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.high,
        mobileDataQuality: AudioQuality.low,
        wifiQuality: AudioQuality.high,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: true,
      );

      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.wifi,
      );

      expect(result, equals(AudioQuality.high));
    });
  });

  group('PlaybackQualityResolver - Network-Specific Preferences', () {
    test('resolves preferred mobile quality on mobile network', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.high,
        mobileDataQuality: AudioQuality.low,
        wifiQuality: AudioQuality.high,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: false,
      );

      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.mobile,
      );

      expect(result, equals(AudioQuality.low));
    });

    test('resolves preferred Wi-Fi quality on Wi-Fi network', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.low,
        mobileDataQuality: AudioQuality.low,
        wifiQuality: AudioQuality.high,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: false,
      );

      final result = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.wifi,
      );

      expect(result, equals(AudioQuality.high));
    });
  });

  group('PlaybackQualityResolver - Global Streaming Preference Fallback', () {
    test('falls back to streamingQuality when network-specific is auto', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.medium,
        mobileDataQuality: AudioQuality.auto,
        wifiQuality: AudioQuality.auto,
        downloadQuality: AudioQuality.high,
        dataSaverEnabled: false,
      );

      final mobileResult = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.mobile,
      );
      final wifiResult = resolver.resolveStreamingQuality(
        settings: settings,
        networkType: NetworkType.wifi,
      );

      expect(mobileResult, equals(AudioQuality.medium));
      expect(wifiResult, equals(AudioQuality.medium));
    });
  });

  group('PlaybackQualityResolver - Auto Policy', () {
    test('auto policy selects HIGH on Wi-Fi', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.auto,
        mobileDataQuality: AudioQuality.auto,
        wifiQuality: AudioQuality.auto,
      );

      expect(
        resolver.resolveStreamingQuality(settings: settings, networkType: NetworkType.wifi),
        equals(AudioQuality.high),
      );
    });

    test('auto policy selects MEDIUM on mobile network', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.auto,
        mobileDataQuality: AudioQuality.auto,
        wifiQuality: AudioQuality.auto,
      );

      expect(
        resolver.resolveStreamingQuality(settings: settings, networkType: NetworkType.mobile),
        equals(AudioQuality.medium),
      );
    });

    test('auto policy selects AUTO on unknown or offline network', () {
      const settings = PlaybackSettingsEntity(
        streamingQuality: AudioQuality.auto,
        mobileDataQuality: AudioQuality.auto,
        wifiQuality: AudioQuality.auto,
      );

      expect(
        resolver.resolveStreamingQuality(settings: settings, networkType: NetworkType.unknown),
        equals(AudioQuality.auto),
      );
    });
  });

  group('PlaybackQualityResolver - Download Quality Resolution', () {
    test('explicit download quality overrides default settings', () {
      const settings = PlaybackSettingsEntity(
        downloadQuality: AudioQuality.high,
      );

      final result = resolver.resolveDownloadQuality(
        settings: settings,
        explicitQuality: AudioQuality.low,
      );

      expect(result, equals(AudioQuality.low));
    });

    test('falls back to settings download quality when explicit is null or auto', () {
      const settings = PlaybackSettingsEntity(
        downloadQuality: AudioQuality.medium,
      );

      final result1 = resolver.resolveDownloadQuality(settings: settings);
      final result2 = resolver.resolveDownloadQuality(
        settings: settings,
        explicitQuality: AudioQuality.auto,
      );

      expect(result1, equals(AudioQuality.medium));
      expect(result2, equals(AudioQuality.medium));
    });
  });

  group('PlaybackQualityResolver - Bitrate to Tier & Size estimation', () {
    test('maps bitrates to correct tier', () {
      expect(PlaybackQualityResolver.mapBitrateToQualityTier(192), equals('HIGH'));
      expect(PlaybackQualityResolver.mapBitrateToQualityTier(128), equals('MEDIUM'));
      expect(PlaybackQualityResolver.mapBitrateToQualityTier(64), equals('LOW'));
    });

    test('formats estimated size per minute', () {
      expect(PlaybackQualityResolver.formatEstimatedSizeMbPerMinute(AudioQuality.low), equals('~0.5 MB/min'));
      expect(PlaybackQualityResolver.formatEstimatedSizeMbPerMinute(AudioQuality.medium), equals('~1.0 MB/min'));
      expect(PlaybackQualityResolver.formatEstimatedSizeMbPerMinute(AudioQuality.high), equals('~1.5 MB/min'));
    });
  });
}
