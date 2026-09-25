class PlaybackEventEntity {
  final String eventId;
  final String trackId;
  final String eventType;
  final int positionMs;
  final int durationMs;
  final DateTime playedAt;
  final String source;
  final String? deviceId;

  const PlaybackEventEntity({
    required this.eventId,
    required this.trackId,
    required this.eventType,
    required this.positionMs,
    required this.durationMs,
    required this.playedAt,
    this.source = 'player',
    this.deviceId,
  });

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackEventEntity &&
          runtimeType == other.runtimeType &&
          eventId == other.eventId;

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'PlaybackEventEntity(eventId: $eventId, trackId: $trackId, type: $eventType, pos: $positionMs)';
}
