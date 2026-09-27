import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/states/like_state.dart';

class LikeNotifier extends StateNotifier<LikeState> {
  final LibraryRepository _repository;
  final Ref? _ref;
  final String _trackId;
  bool _initialized = false;

  LikeNotifier(
    this._repository,
    this._trackId, [
    this._ref,
    bool initialLiked = false,
    int initialCount = 0,
  ]) : super(LikeState(isLiked: initialLiked, likesCount: initialCount));

  void initialize({bool? initialLiked, int? initialCount}) {
    if (_initialized) return;
    _initialized = true;
    if (initialLiked != null || initialCount != null) {
      state = state.copyWith(
        isLiked: initialLiked ?? state.isLiked,
        likesCount: initialCount ?? state.likesCount,
      );
    }
  }

  Future<void> fetchStatus() async {
    try {
      final status = await _repository.getLikeStatus(_trackId);
      state = state.copyWith(
        isLiked: status.isLiked,
        likesCount: status.likesCount,
      );
    } catch (_) {
      // Keep existing state if fetch fails silently
    }
  }

  Future<void> toggleLike() async {
    if (state.isLoading) return;

    final previousState = state;
    final willLike = !state.isLiked;
    final newCount = willLike
        ? state.likesCount + 1
        : (state.likesCount > 0 ? state.likesCount - 1 : 0);

    // 1. Optimistic update
    state = state.copyWith(
      isLiked: willLike,
      likesCount: newCount,
      isLoading: true,
      errorMessage: null,
    );

    try {
      // 2. Synchronize with backend
      final status = willLike
          ? await _repository.likeTrack(_trackId)
          : await _repository.unlikeTrack(_trackId);

      state = state.copyWith(
        isLiked: status.isLiked,
        likesCount: status.likesCount,
        isLoading: false,
      );

      // 3. Reactively update personal library & summaries
      _ref?.invalidate(librarySummaryProvider);
      if (!willLike) {
        _ref?.read(likedTracksNotifierProvider.notifier).removeTrack(_trackId);
      } else {
        _ref?.invalidate(likedTracksNotifierProvider);
      }
    } catch (e) {
      // 4. Rollback on failure
      state = previousState.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update favorite. Please try again.',
      );
    }
  }
}

final likeNotifierProvider =
    StateNotifierProvider.family<LikeNotifier, LikeState, String>((ref, trackId) {
  final repository = ref.watch(libraryRepositoryProvider);
  return LikeNotifier(repository, trackId, ref);
});
