import 'package:hums_mobile/features/history/domain/entities/playback_progress_entity.dart';

class PlaybackProgressModel {
  final String trackId;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final double progressPercent;
  final DateTime updatedAt;

  const PlaybackProgressModel({
    required this.trackId,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.progressPercent,
    required this.updatedAt,
  });

  factory PlaybackProgressModel.fromJson(Map<String, dynamic> json) {
    final pos = (json['position_ms'] as num?)?.toInt() ?? 0;
    final dur = (json['duration_ms'] as num?)?.toInt() ?? 0;
    final percent = (json['progress_percent'] as num?)?.toDouble() ??
        (dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0);

    return PlaybackProgressModel(
      trackId: json['track_id'] as String,
      positionMs: pos,
      durationMs: dur,
      completed: json['completed'] as bool? ?? false,
      progressPercent: percent,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': trackId,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'completed': completed,
      'progress_percent': progressPercent,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory PlaybackProgressModel.fromEntity(PlaybackProgressEntity entity) {
    return PlaybackProgressModel(
      trackId: entity.trackId,
      positionMs: entity.positionMs,
      durationMs: entity.durationMs,
      completed: entity.completed,
      progressPercent: entity.progressPercent,
      updatedAt: entity.updatedAt,
    );
  }

  PlaybackProgressEntity toEntity() {
    return PlaybackProgressEntity(
      trackId: trackId,
      positionMs: positionMs,
      durationMs: durationMs,
      completed: completed,
      progressPercent: progressPercent,
      updatedAt: updatedAt,
    );
  }
}
