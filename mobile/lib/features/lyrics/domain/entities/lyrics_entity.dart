import 'package:flutter/foundation.dart';
import 'lyric_line_entity.dart';

/// Status values representing the lifecycle of lyrics for a track.
abstract class LyricsStatusConstants {
  static const String pending = 'PENDING';
  static const String processing = 'PROCESSING';
  static const String completed = 'COMPLETED';
  static const String failed = 'FAILED';
  static const String unavailable = 'UNAVAILABLE';
}

/// Source values representing how the lyrics were created.
abstract class LyricsSourceConstants {
  static const String aiGenerated = 'AI_GENERATED';
  static const String uploaded = 'UPLOADED';
  static const String manual = 'MANUAL';
}

/// Represents the authoritative lyrics entity for a track.
class LyricsEntity {
  final String? id;
  final String trackId;
  final String status;
  final String? language;
  final String source;
  final bool isSynchronized;
  final String? text;
  final List<LyricLineEntity> lines;
  final String? model;
  final String version;
  final String? errorMessage;
  final DateTime? updatedAt;

  const LyricsEntity({
    this.id,
    required this.trackId,
    required this.status,
    this.language,
    this.source = LyricsSourceConstants.aiGenerated,
    this.isSynchronized = false,
    this.text,
    this.lines = const [],
    this.model,
    this.version = 'v1',
    this.errorMessage,
    this.updatedAt,
  });

  bool get isCompleted => status == LyricsStatusConstants.completed;
  bool get isProcessing =>
      status == LyricsStatusConstants.processing ||
      status == LyricsStatusConstants.pending;
  bool get isUnavailable => status == LyricsStatusConstants.unavailable;
  bool get isFailed => status == LyricsStatusConstants.failed;
  bool get hasSynchronizedLines => isSynchronized && lines.isNotEmpty;
  bool get hasPlainText => text != null && text!.trim().isNotEmpty;

  /// Returns the line index corresponding to a given playback position in milliseconds
  /// using binary search ($O(\log N)$).
  ///
  /// If the position is before the first line, returns -1.
  /// If between lines or during a line, returns the index of the most recently passed line.
  int findLineIndexForPosition(int positionMs) {
    if (lines.isEmpty) return -1;
    if (positionMs < lines.first.startMs) return -1;

    int low = 0;
    int high = lines.length - 1;
    int result = -1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final line = lines[mid];

      if (line.startMs <= positionMs) {
        result = mid;
        low = mid + 1; // search right to find most recently started line
      } else {
        high = mid - 1;
      }
    }

    if (result != -1 && lines[result].endMs != null) {
      if (positionMs > lines[result].endMs!) {
        // If silence duration exceeds 3 seconds past line's end_ms, deselect
        if (positionMs - lines[result].endMs! > 3000) {
          return -1;
        }
      }
    }

    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          trackId == other.trackId &&
          status == other.status &&
          language == other.language &&
          source == other.source &&
          isSynchronized == other.isSynchronized &&
          text == other.text &&
          listEquals(lines, other.lines) &&
          model == other.model &&
          version == other.version &&
          errorMessage == other.errorMessage &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        trackId,
        status,
        language,
        source,
        isSynchronized,
        text,
        Object.hashAll(lines),
        model,
        version,
        errorMessage,
        updatedAt,
      );
}
