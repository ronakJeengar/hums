class PlaybackProgressEntity {
  final String trackId;
  final int positionMs;
  final int durationMs;
  final bool completed;
  final double progressPercent;
  final DateTime updatedAt;

  const PlaybackProgressEntity({
    required this.trackId,
    required this.positionMs,
    required this.durationMs,
    required this.completed,
    required this.progressPercent,
    required this.updatedAt,
  });

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackProgressEntity &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId &&
          positionMs == other.positionMs &&
          durationMs == other.durationMs &&
          completed == other.completed;

  @override
  int get hashCode => Object.hash(trackId, positionMs, durationMs, completed);

  @override
  String toString() =>
      'PlaybackProgressEntity(trackId: $trackId, pos: $positionMs, dur: $durationMs, done: $completed)';
}
