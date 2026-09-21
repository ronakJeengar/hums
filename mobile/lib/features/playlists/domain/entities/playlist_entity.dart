class PlaylistEntity {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? coverImageKey;
  final String? coverImageUrl;
  final bool isPublic;
  final int trackCount;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlaylistEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.coverImageKey,
    this.coverImageUrl,
    this.isPublic = false,
    this.trackCount = 0,
    this.durationSeconds = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  String get formattedDuration {
    if (durationSeconds <= 0) return '0 min';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }
}

class PlaylistTrackEntity {
  final String id;
  final String trackId;
  final int position;
  final DateTime addedAt;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;

  const PlaylistTrackEntity({
    required this.id,
    required this.trackId,
    required this.position,
    required this.addedAt,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.waveformKey,
    required this.status,
  });

  bool get isPlayable => status.toUpperCase() == 'READY';

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return '--:--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PlaylistDetailEntity {
  final PlaylistEntity playlist;
  final List<PlaylistTrackEntity> tracks;

  const PlaylistDetailEntity({
    required this.playlist,
    required this.tracks,
  });

  int get trackCount => tracks.length;

  int get totalDurationSeconds =>
      tracks.fold(0, (sum, t) => sum + (t.durationSeconds ?? 0));

  List<PlaylistTrackEntity> get playableTracks =>
      tracks.where((t) => t.isPlayable).toList();
}
