import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';

class PlaybackTrackSummaryModel {
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

  const PlaybackTrackSummaryModel({
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

  factory PlaybackTrackSummaryModel.fromJson(Map<String, dynamic> json) {
    return PlaybackTrackSummaryModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      waveformKey: json['waveform_key'] as String?,
      status: json['status'] as String? ?? 'READY',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'artist_name': artistName,
      'album_name': albumName,
      'genre': genre,
      'duration_seconds': durationSeconds,
      'waveform_key': waveformKey,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  PlaybackTrackSummaryEntity toEntity() {
    return PlaybackTrackSummaryEntity(
      id: id,
      ownerId: ownerId,
      title: title,
      description: description,
      artistName: artistName,
      albumName: albumName,
      genre: genre,
      durationSeconds: durationSeconds,
      waveformKey: waveformKey,
      status: status,
      createdAt: createdAt,
    );
  }
}

class ListeningHistoryItemModel {
  final String id;
  final String trackId;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final double progressPercent;
  final DateTime lastPlayedAt;
  final PlaybackTrackSummaryModel? track;

  const ListeningHistoryItemModel({
    required this.id,
    required this.trackId,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.progressPercent,
    required this.lastPlayedAt,
    this.track,
  });

  factory ListeningHistoryItemModel.fromJson(Map<String, dynamic> json) {
    final pos = (json['position_ms'] as num?)?.toInt() ?? 0;
    final dur = (json['duration_ms'] as num?)?.toInt() ?? 0;
    final percent = (json['progress_percent'] as num?)?.toDouble() ??
        (dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0);

    return ListeningHistoryItemModel(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      positionMs: pos,
      durationMs: dur,
      completed: json['completed'] as bool? ?? false,
      progressPercent: percent,
      lastPlayedAt: json['last_played_at'] != null
          ? DateTime.parse(json['last_played_at'] as String)
          : DateTime.now().toUtc(),
      track: json['track'] != null
          ? PlaybackTrackSummaryModel.fromJson(
              json['track'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'track_id': trackId,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'completed': completed,
      'progress_percent': progressPercent,
      'last_played_at': lastPlayedAt.toUtc().toIso8601String(),
      'track': track?.toJson(),
    };
  }

  ListeningHistoryItemEntity toEntity() {
    return ListeningHistoryItemEntity(
      id: id,
      trackId: trackId,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed,
      progressPercent: progressPercent,
      lastPlayedAt: lastPlayedAt,
      track: track?.toEntity(),
    );
  }
}
