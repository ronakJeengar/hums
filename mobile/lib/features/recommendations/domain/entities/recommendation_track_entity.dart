class RecommendationTrackEntity {
  final String id;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String? artworkUrl;
  final String status;
  final String? waveformKey;

  const RecommendationTrackEntity({
    required this.id,
    required this.title,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    this.artworkUrl,
    required this.status,
    this.waveformKey,
  });

  bool get isPlayable => status.toUpperCase() == 'READY';

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
