import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';

class AudioSourceModel {
  final String url;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int? durationSeconds;
  final int fileSizeBytes;

  const AudioSourceModel({
    required this.url,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    this.durationSeconds,
    required this.fileSizeBytes,
  });

  factory AudioSourceModel.fromJson(Map<String, dynamic> json) {
    return AudioSourceModel(
      url: json['url'] as String,
      format: (json['format'] as String?) ?? 'm4a',
      codec: (json['codec'] as String?) ?? 'aac',
      bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 128,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
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
  });

  factory TrackPlaybackModel.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['waveform_samples'] as List<dynamic>? ?? [];

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
    );
  }
}
