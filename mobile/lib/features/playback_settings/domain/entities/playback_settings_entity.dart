/// Supported playback and download audio quality tiers.
enum AudioQuality {
  auto,
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case AudioQuality.auto:
        return 'Auto';
      case AudioQuality.low:
        return 'Low (64 kbps)';
      case AudioQuality.medium:
        return 'Medium (128 kbps)';
      case AudioQuality.high:
        return 'High (192 kbps)';
    }
  }

  String get description {
    switch (this) {
      case AudioQuality.auto:
        return 'Optimizes quality and data usage dynamically based on your network.';
      case AudioQuality.low:
        return '64 kbps AAC. Uses the least data (~0.5 MB/min). Ideal for constrained networks.';
      case AudioQuality.medium:
        return '128 kbps AAC. Balanced fidelity and data usage (~1.0 MB/min).';
      case AudioQuality.high:
        return '192 kbps AAC. Highest acoustic fidelity (~1.5 MB/min). Ideal for Wi-Fi and headphones.';
    }
  }

  int get targetBitrateKbps {
    switch (this) {
      case AudioQuality.auto:
        return 192;
      case AudioQuality.low:
        return 64;
      case AudioQuality.medium:
        return 128;
      case AudioQuality.high:
        return 192;
    }
  }

  String toApiValue() => name.toUpperCase();

  static AudioQuality fromApiValue(String? value) {
    if (value == null) return AudioQuality.auto;
    switch (value.trim().toUpperCase()) {
      case 'LOW':
        return AudioQuality.low;
      case 'MEDIUM':
        return AudioQuality.medium;
      case 'HIGH':
        return AudioQuality.high;
      case 'AUTO':
      default:
        return AudioQuality.auto;
    }
  }
}

/// Network connectivity states for adaptive playback routing.
enum NetworkType {
  wifi,
  mobile,
  offline,
  unknown;

  bool get isWifi => this == NetworkType.wifi;
  bool get isMobile => this == NetworkType.mobile;
  bool get isOffline => this == NetworkType.offline;
}

/// User playback quality configuration.
class PlaybackSettingsEntity {
  final AudioQuality streamingQuality;
  final AudioQuality mobileDataQuality;
  final AudioQuality wifiQuality;
  final AudioQuality downloadQuality;
  final bool dataSaverEnabled;

  const PlaybackSettingsEntity({
    this.streamingQuality = AudioQuality.auto,
    this.mobileDataQuality = AudioQuality.low,
    this.wifiQuality = AudioQuality.high,
    this.downloadQuality = AudioQuality.high,
    this.dataSaverEnabled = false,
  });

  PlaybackSettingsEntity copyWith({
    AudioQuality? streamingQuality,
    AudioQuality? mobileDataQuality,
    AudioQuality? wifiQuality,
    AudioQuality? downloadQuality,
    bool? dataSaverEnabled,
  }) {
    return PlaybackSettingsEntity(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      mobileDataQuality: mobileDataQuality ?? this.mobileDataQuality,
      wifiQuality: wifiQuality ?? this.wifiQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      dataSaverEnabled: dataSaverEnabled ?? this.dataSaverEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'streaming_quality': streamingQuality.toApiValue(),
        'mobile_data_quality': mobileDataQuality.toApiValue(),
        'wifi_quality': wifiQuality.toApiValue(),
        'download_quality': downloadQuality.toApiValue(),
        'data_saver_enabled': dataSaverEnabled,
      };

  factory PlaybackSettingsEntity.fromJson(Map<String, dynamic> json) {
    return PlaybackSettingsEntity(
      streamingQuality: AudioQuality.fromApiValue(json['streaming_quality'] as String?),
      mobileDataQuality: AudioQuality.fromApiValue(json['mobile_data_quality'] as String?),
      wifiQuality: AudioQuality.fromApiValue(json['wifi_quality'] as String?),
      downloadQuality: AudioQuality.fromApiValue(json['download_quality'] as String?),
      dataSaverEnabled: json['data_saver_enabled'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackSettingsEntity &&
          runtimeType == other.runtimeType &&
          streamingQuality == other.streamingQuality &&
          mobileDataQuality == other.mobileDataQuality &&
          wifiQuality == other.wifiQuality &&
          downloadQuality == other.downloadQuality &&
          dataSaverEnabled == other.dataSaverEnabled;

  @override
  int get hashCode => Object.hash(
        streamingQuality,
        mobileDataQuality,
        wifiQuality,
        downloadQuality,
        dataSaverEnabled,
      );
}
