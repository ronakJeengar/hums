import 'download_status.dart';

/// Domain entity representing a persistent offline track download.
class DownloadItem {
  final String id;
  final String trackId;
  final String userId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? artworkUrl;
  final DownloadStatus status;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final String? localPath;
  final String? downloadUrl;
  final DateTime? urlExpiresAt;
  final String format;
  final int? audioBitrate;
  final List<double> waveformSamples;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? error;

  const DownloadItem({
    required this.id,
    required this.trackId,
    required this.userId,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.artworkUrl,
    required this.status,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.localPath,
    this.downloadUrl,
    this.urlExpiresAt,
    this.format = 'm4a',
    this.audioBitrate,
    this.waveformSamples = const [],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.error,
  });

  bool get isUrlExpired {
    if (urlExpiresAt == null) return false;
    // Buffer by 30 seconds
    return DateTime.now().isAfter(urlExpiresAt!.subtract(const Duration(seconds: 30)));
  }

  DownloadItem copyWith({
    String? id,
    String? trackId,
    String? userId,
    String? title,
    String? artistName,
    String? albumName,
    int? durationSeconds,
    String? artworkUrl,
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? localPath,
    String? downloadUrl,
    DateTime? urlExpiresAt,
    String? format,
    int? audioBitrate,
    List<double>? waveformSamples,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? error,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath ?? this.localPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      urlExpiresAt: urlExpiresAt ?? this.urlExpiresAt,
      format: format ?? this.format,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      error: error,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'track_id': trackId,
      'user_id': userId,
      'title': title,
      'artist_name': artistName,
      'album_name': albumName,
      'duration_seconds': durationSeconds,
      'artwork_url': artworkUrl,
      'status': status.name,
      'progress': progress,
      'bytes_downloaded': bytesDownloaded,
      'total_bytes': totalBytes,
      'local_path': localPath,
      'download_url': downloadUrl,
      'url_expires_at': urlExpiresAt?.toIso8601String(),
      'format': format,
      'audio_bitrate': audioBitrate,
      'waveform_samples': waveformSamples,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error': error,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      artworkUrl: json['artwork_url'] as String?,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      bytesDownloaded: json['bytes_downloaded'] as int? ?? 0,
      totalBytes: json['total_bytes'] as int? ?? 0,
      localPath: json['local_path'] as String?,
      downloadUrl: json['download_url'] as String?,
      urlExpiresAt: json['url_expires_at'] != null
          ? DateTime.parse(json['url_expires_at'] as String)
          : null,
      format: (json['format'] as String?) ?? 'm4a',
      audioBitrate: json['audio_bitrate'] as int?,
      waveformSamples: (json['waveform_samples'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      error: json['error'] as String?,
    );
  }
}
