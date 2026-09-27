/// Represents a single timestamped line of lyrics within synchronized lyrics.
class LyricLineEntity {
  final String? id;
  final int sequence;
  final int startMs;
  final int? endMs;
  final String text;

  const LyricLineEntity({
    this.id,
    required this.sequence,
    required this.startMs,
    this.endMs,
    required this.text,
  });

  /// Duration of this lyric line if end timestamp exists.
  Duration? get duration =>
      endMs != null ? Duration(milliseconds: endMs! - startMs) : null;

  /// Start timestamp as a [Duration].
  Duration get startTime => Duration(milliseconds: startMs);

  /// End timestamp as a [Duration], or null.
  Duration? get endTime =>
      endMs != null ? Duration(milliseconds: endMs!) : null;

  /// Checks if the given playback position in milliseconds falls within this lyric line.
  bool containsPosition(int positionMs) {
    if (positionMs < startMs) return false;
    if (endMs != null) {
      return positionMs <= endMs!;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLineEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sequence == other.sequence &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          text == other.text;

  @override
  int get hashCode =>
      Object.hash(id, sequence, startMs, endMs, text);
}
