class PlaybackTrackSummaryEntity {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;
  final DateTime createdAt;

  const PlaybackTrackSummaryEntity({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    this.waveformKey,
    required this.status,
    required this.createdAt,
  });

  String get displayArtist => artistName ?? 'Unknown Artist';
  String get displayAlbum => albumName ?? 'Single';

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class ListeningHistoryItemEntity {
  final String id;
  final String trackId;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final double progressPercent;
  final DateTime lastPlayedAt;
  final PlaybackTrackSummaryEntity? track;

  const ListeningHistoryItemEntity({
    required this.id,
    required this.trackId,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.progressPercent,
    required this.lastPlayedAt,
    this.track,
  });

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);

  String get title => track?.title ?? 'Unknown Track';
  String get artist => track?.displayArtist ?? 'Unknown Artist';
  String get album => track?.displayAlbum ?? '';

  String get formattedPosition {
    final s = position.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    if (track != null && track!.durationSeconds != null) {
      return track!.formattedDuration;
    }
    final s = duration.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningHistoryItemEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ListeningHistoryItemEntity(id: $id, trackId: $trackId, progress: ${(progressPercent * 100).toStringAsFixed(1)}%)';
}
