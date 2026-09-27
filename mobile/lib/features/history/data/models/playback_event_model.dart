import 'package:hums_mobile/features/history/domain/entities/playback_event_entity.dart';

class PlaybackEventModel {
  final String eventId;
  final String trackId;
  final String eventType;
  final int positionMs;
  final int durationMs;
  final DateTime playedAt;
  final String source;
  final String? deviceId;

  const PlaybackEventModel({
    required this.eventId,
    required this.trackId,
    required this.eventType,
    required this.positionMs,
    required this.durationMs,
    required this.playedAt,
    this.source = 'player',
    this.deviceId,
  });

  factory PlaybackEventModel.fromJson(Map<String, dynamic> json) {
    return PlaybackEventModel(
      eventId: json['event_id'] as String,
      trackId: json['track_id'] as String,
      eventType: json['event_type'] as String,
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      playedAt: DateTime.parse(json['played_at'] as String),
      source: json['source'] as String? ?? 'player',
      deviceId: json['device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'track_id': trackId,
      'event_type': eventType,
      'position_ms': positionMs,
      'duration_ms': durationMs,
      'played_at': playedAt.toUtc().toIso8601String(),
      'source': source,
      if (deviceId != null) 'device_id': deviceId,
    };
  }

  factory PlaybackEventModel.fromEntity(PlaybackEventEntity entity) {
    return PlaybackEventModel(
      eventId: entity.eventId,
      trackId: entity.trackId,
      eventType: entity.eventType,
      positionMs: entity.positionMs,
      durationMs: entity.durationMs,
      playedAt: entity.playedAt,
      source: entity.source,
      deviceId: entity.deviceId,
    );
  }

  PlaybackEventEntity toEntity() {
    return PlaybackEventEntity(
      eventId: eventId,
      trackId: trackId,
      eventType: eventType,
      positionMs: positionMs,
      durationMs: durationMs,
      playedAt: playedAt,
      source: source,
      deviceId: deviceId,
    );
  }
}
