class AudioSourceEntity {
  final String url;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int? durationSeconds;
  final int fileSizeBytes;

  const AudioSourceEntity({
    required this.url,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    this.durationSeconds,
    required this.fileSizeBytes,
  });
}

class TrackPlaybackEntity {
  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String status;
  final AudioSourceEntity audio;
  final List<double> waveformSamples;

  const TrackPlaybackEntity({
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
}
