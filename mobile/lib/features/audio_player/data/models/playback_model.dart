import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/playback_settings/domain/entities/playback_quality_resolver.dart';

class AudioRenditionModel {
  final String id;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int? sampleRate;
  final int? durationSeconds;
  final int fileSizeBytes;
  final String quality;

  const AudioRenditionModel({
    required this.id,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    this.sampleRate,
    this.durationSeconds,
    required this.fileSizeBytes,
    required this.quality,
  });

  factory AudioRenditionModel.fromJson(Map<String, dynamic> json) {
    final bitrate = (json['bitrate_kbps'] as num?)?.toInt() ?? 128;
    return AudioRenditionModel(
      id: (json['id'] as String?) ?? '',
      format: (json['format'] as String?) ?? 'm4a',
      codec: (json['codec'] as String?) ?? 'aac',
      bitrateKbps: bitrate,
      sampleRate: (json['sample_rate'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      quality: (json['quality'] as String?) ??
          PlaybackQualityResolver.mapBitrateToQualityTier(bitrate),
    );
  }

  AudioRenditionEntity toEntity() {
    return AudioRenditionEntity(
      id: id,
      format: format,
      codec: codec,
      bitrateKbps: bitrateKbps,
      sampleRate: sampleRate,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      quality: quality,
    );
  }
}

class AudioSourceModel {
  final String url;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int? durationSeconds;
  final int fileSizeBytes;
  final String? quality;

  const AudioSourceModel({
    required this.url,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    this.durationSeconds,
    required this.fileSizeBytes,
    this.quality,
  });

  factory AudioSourceModel.fromJson(Map<String, dynamic> json) {
    final bitrate = (json['bitrate_kbps'] as num?)?.toInt() ?? 128;
    return AudioSourceModel(
      url: json['url'] as String,
      format: (json['format'] as String?) ?? 'm4a',
      codec: (json['codec'] as String?) ?? 'aac',
      bitrateKbps: bitrate,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      quality: (json['quality'] as String?) ??
          PlaybackQualityResolver.mapBitrateToQualityTier(bitrate),
    );
  }

  AudioSourceEntity toEntity() {
    return AudioSourceEntity(
      url: url,
      format: format,
      codec: codec,
      bitrateKbps: bitrateKbps,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      quality: quality,
    );
  }
}

class TrackPlaybackModel {
  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String status;
  final AudioSourceModel audio;
  final List<double> waveformSamples;
  final List<AudioRenditionModel> availableRenditions;

  const TrackPlaybackModel({
    required this.trackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    required this.status,
    required this.audio,
    this.waveformSamples = const [],
    this.availableRenditions = const [],
  });

  factory TrackPlaybackModel.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['waveform_samples'] as List<dynamic>? ?? [];
    final rawRenditions = json['available_renditions'] as List<dynamic>? ?? [];

    return TrackPlaybackModel(
      trackId: json['track_id'] as String,
      title: (json['title'] as String?) ?? '',
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'READY',
      audio: AudioSourceModel.fromJson(json['audio'] as Map<String, dynamic>),
      waveformSamples: rawSamples.map((s) => (s as num).toDouble()).toList(),
      availableRenditions: rawRenditions
          .map((r) => AudioRenditionModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  TrackPlaybackEntity toEntity() {
    return TrackPlaybackEntity(
      trackId: trackId,
      title: title,
      artistName: artistName,
      albumName: albumName,
      genre: genre,
      durationSeconds: durationSeconds,
      status: status,
      audio: audio.toEntity(),
      waveformSamples: waveformSamples,
      availableRenditions:
          availableRenditions.map((r) => r.toEntity()).toList(),
    );
  }
}
