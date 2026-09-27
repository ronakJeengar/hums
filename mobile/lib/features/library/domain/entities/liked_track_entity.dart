class LikedTrackEntity {
  final String id;
  final String title;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;
  final int likesCount;
  final bool isLiked;
  final DateTime likedAt;
  final DateTime createdAt;

  const LikedTrackEntity({
    required this.id,
    required this.title,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    this.waveformKey,
    required this.status,
    this.likesCount = 0,
    this.isLiked = true,
    required this.likedAt,
    required this.createdAt,
  });

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
