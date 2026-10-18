import 'package:hums_mobile/features/playback_settings/domain/entities/playback_settings_entity.dart';

/// Single authoritative decision engine for resolving playback and download qualities.
///
/// Precedence rules (Section 19):
/// 1. Manual / explicit playback selection (session override for current track)
/// 2. Data Saver policy (if active on cellular data -> forces LOW)
/// 3. Network-specific preference (mobileDataQuality on cellular, wifiQuality on Wi-Fi)
/// 4. Global streaming preference (streamingQuality)
/// 5. AUTO network resolution
/// 6. Available rendition fallback
class PlaybackQualityResolver {
  const PlaybackQualityResolver();

  /// Resolves the audio streaming quality tier to request from backend.
  AudioQuality resolveStreamingQuality({
    AudioQuality? sessionOverride,
    required PlaybackSettingsEntity settings,
    required NetworkType networkType,
  }) {
    // 1. Explicit manual session override for current track playback
    if (sessionOverride != null) {
      if (sessionOverride != AudioQuality.auto) {
        return sessionOverride;
      }
    }

    // 2. Data Saver Policy (Section 16 & 17)
    // When Data Saver is ON and on mobile data -> force LOW quality (64 kbps)
    if (settings.dataSaverEnabled && networkType == NetworkType.mobile) {
      return AudioQuality.low;
    }

    // 3. Network-specific preferences (Section 17 & 18)
    if (networkType == NetworkType.mobile) {
      if (settings.mobileDataQuality != AudioQuality.auto) {
        return settings.mobileDataQuality;
      }
    } else if (networkType == NetworkType.wifi) {
      if (settings.wifiQuality != AudioQuality.auto) {
        return settings.wifiQuality;
      }
    }

    // 4. Global streaming preference
    if (settings.streamingQuality != AudioQuality.auto) {
      return settings.streamingQuality;
    }

    // 5. AUTO Resolution
    // On Wi-Fi default to HIGH (192 kbps), on Mobile default to MEDIUM (128 kbps)
    if (networkType == NetworkType.wifi) {
      return AudioQuality.high;
    } else if (networkType == NetworkType.mobile) {
      return AudioQuality.medium;
    }

    return AudioQuality.auto;
  }

  /// Resolves the audio download quality tier.
  AudioQuality resolveDownloadQuality({
    AudioQuality? explicitQuality,
    required PlaybackSettingsEntity settings,
  }) {
    if (explicitQuality != null && explicitQuality != AudioQuality.auto) {
      return explicitQuality;
    }
    return settings.downloadQuality;
  }

  /// Deterministically matches an available bitrate to a target quality tier.
  static String mapBitrateToQualityTier(int bitrateKbps) {
    if (bitrateKbps >= 160) {
      return 'HIGH';
    } else if (bitrateKbps >= 96) {
      return 'MEDIUM';
    } else {
      return 'LOW';
    }
  }

  /// Formats estimated file size per minute of audio.
  static String formatEstimatedSizeMbPerMinute(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return '~0.5 MB/min';
      case AudioQuality.medium:
        return '~1.0 MB/min';
      case AudioQuality.high:
      case AudioQuality.auto:
        return '~1.5 MB/min';
    }
  }
}
