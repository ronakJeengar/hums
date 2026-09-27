import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_manager_provider.dart';
import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_local_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_remote_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/repositories/lyrics_repository_impl.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/repositories/lyrics_repository.dart';
import 'package:hums_mobile/features/lyrics/presentation/states/lyrics_state.dart';

// --- Data & Repository Providers ---

final lyricsRemoteDataSourceProvider = Provider<LyricsRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LyricsRemoteDataSourceImpl(apiClient);
});

final lyricsLocalDataSourceProvider = Provider<LyricsLocalDataSource>((ref) {
  final fileManager = ref.watch(downloadFileManagerProvider);
  return LyricsLocalDataSourceImpl(fileManager);
});

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final remote = ref.watch(lyricsRemoteDataSourceProvider);
  final local = ref.watch(lyricsLocalDataSourceProvider);
  return LyricsRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
  );
});

// --- StateNotifier for a specific track's lyrics ---

class LyricsNotifier extends StateNotifier<LyricsState> {
  final LyricsRepository _repository;
  final String trackId;
  final String? userId;
  Timer? _pollingTimer;

  LyricsNotifier({
    required LyricsRepository repository,
    required this.trackId,
    this.userId,
  })  : _repository = repository,
        super(const LyricsState()) {
    fetchLyrics();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchLyrics({bool forceRefresh = false}) async {
    state = state.copyWith(status: LyricsStatusType.loading, errorMessage: null);

    try {
      final lyrics = await _repository.getLyrics(trackId, userId: userId);

      if (lyrics.isProcessing) {
        state = state.copyWith(
          status: LyricsStatusType.processing,
          lyrics: lyrics,
        );
        _startPollingForCompletion();
      } else if (lyrics.isCompleted) {
        _stopPolling();
        state = state.copyWith(
          status: LyricsStatusType.completed,
          lyrics: lyrics,
        );
      } else if (lyrics.isUnavailable) {
        _stopPolling();
        state = state.copyWith(
          status: LyricsStatusType.unavailable,
          lyrics: lyrics,
        );
      } else {
        _stopPolling();
        state = state.copyWith(
          status: LyricsStatusType.unavailable,
          lyrics: lyrics,
        );
      }
    } catch (e) {
      _stopPolling();
      state = state.copyWith(
        status: LyricsStatusType.error,
        errorMessage: 'Unable to load lyrics. Tap to retry.',
      );
    }
  }

  /// Triggers background generation if lyrics are unavailable or failed
  Future<void> requestGeneration() async {
    state = state.copyWith(isTriggeringGeneration: true);
    try {
      final res = await _repository.triggerGeneration(trackId);
      state = state.copyWith(
        status: LyricsStatusType.processing,
        lyrics: res,
        isTriggeringGeneration: false,
      );
      _startPollingForCompletion();
    } catch (e) {
      state = state.copyWith(
        isTriggeringGeneration: false,
        errorMessage: 'Failed to request lyrics generation.',
      );
    }
  }

  /// Uploads or edits manual lyrics
  Future<void> uploadLyrics({
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineEntity>? lines,
  }) async {
    state = state.copyWith(status: LyricsStatusType.loading);
    try {
      final updated = await _repository.uploadLyrics(
        trackId,
        text: text,
        language: language,
        isSynchronized: isSynchronized,
        lines: lines,
      );
      state = state.copyWith(
        status: LyricsStatusType.completed,
        lyrics: updated,
      );
    } catch (e) {
      state = state.copyWith(
        status: LyricsStatusType.error,
        errorMessage: 'Failed to save lyrics.',
      );
    }
  }

  void _startPollingForCompletion() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final fresh = await _repository.getLyrics(trackId, userId: userId);
        if (fresh.isCompleted) {
          timer.cancel();
          state = state.copyWith(
            status: LyricsStatusType.completed,
            lyrics: fresh,
          );
        } else if (fresh.isUnavailable || fresh.isFailed) {
          timer.cancel();
          state = state.copyWith(
            status: LyricsStatusType.unavailable,
            lyrics: fresh,
          );
        }
      } catch (_) {
        // Defensive: retain processing state during transient network issues
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}

final lyricsNotifierProvider =
    StateNotifierProvider.family<LyricsNotifier, LyricsState, String>(
        (ref, trackId) {
  final repository = ref.watch(lyricsRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.user?.id;

  return LyricsNotifier(
    repository: repository,
    trackId: trackId,
    userId: userId,
  );
});

// --- Active Lyric Line Provider (Optimized O(log N) lookup) ---

/// Evaluates active lyric line index via binary search.
/// Only fires a notification to UI listeners when the active line index changes!
final activeLyricLineIndexProvider =
    Provider.family<int, String>((ref, trackId) {
  final playerState = ref.watch(audioPlayerNotifierProvider);

  // If the audio player is playing a different track, there is no active line
  if (playerState.track?.trackId != trackId) {
    return -1;
  }

  final lyricsState = ref.watch(lyricsNotifierProvider(trackId));
  final lyrics = lyricsState.lyrics;

  if (lyrics == null || !lyrics.hasSynchronizedLines) {
    return -1;
  }

  final positionMs = playerState.position.inMilliseconds;
  return lyrics.findLineIndexForPosition(positionMs);
});
