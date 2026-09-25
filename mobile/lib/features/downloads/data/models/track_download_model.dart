/// Data Transfer Object representing the backend download authorization response.
class TrackDownloadModel {
  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String status;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int fileSizeBytes;
  final String downloadUrl;
  final DateTime expiresAt;
  final List<double> waveformSamples;

  const TrackDownloadModel({
    required this.trackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    required this.status,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    required this.fileSizeBytes,
    required this.downloadUrl,
    required this.expiresAt,
    this.waveformSamples = const [],
  });

  factory TrackDownloadModel.fromJson(Map<String, dynamic> json) {
    return TrackDownloadModel(
      trackId: json['track_id'] as String,
      title: json['title'] as String,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      status: json['status'] as String,
      format: json['format'] as String,
      codec: json['codec'] as String,
      bitrateKbps: json['bitrate_kbps'] as int? ?? 128,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      downloadUrl: json['download_url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      waveformSamples: (json['waveform_samples'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
  }
}
