import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';

enum LyricsStatusType {
  initial,
  loading,
  processing,
  completed,
  unavailable,
  error,
}

class LyricsState {
  final LyricsStatusType status;
  final LyricsEntity? lyrics;
  final String? errorMessage;
  final bool isTriggeringGeneration;

  const LyricsState({
    this.status = LyricsStatusType.initial,
    this.lyrics,
    this.errorMessage,
    this.isTriggeringGeneration = false,
  });

  bool get isLoading => status == LyricsStatusType.loading;
  bool get isProcessing => status == LyricsStatusType.processing;
  bool get isCompleted => status == LyricsStatusType.completed;
  bool get isUnavailable => status == LyricsStatusType.unavailable;
  bool get isError => status == LyricsStatusType.error;

  LyricsState copyWith({
    LyricsStatusType? status,
    LyricsEntity? lyrics,
    String? errorMessage,
    bool? isTriggeringGeneration,
  }) {
    return LyricsState(
      status: status ?? this.status,
      lyrics: lyrics ?? this.lyrics,
      errorMessage: errorMessage ?? this.errorMessage,
      isTriggeringGeneration:
          isTriggeringGeneration ?? this.isTriggeringGeneration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lyrics == other.lyrics &&
          errorMessage == other.errorMessage &&
          isTriggeringGeneration == other.isTriggeringGeneration;

  @override
  int get hashCode => Object.hash(
        status,
        lyrics,
        errorMessage,
        isTriggeringGeneration,
      );
}
