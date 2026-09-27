import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';

class FollowingState {
  final List<CreatorProfileEntity> creators;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final int page;
  final String? errorMessage;

  const FollowingState({
    this.creators = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.page = 1,
    this.errorMessage,
  });

  FollowingState copyWith({
    List<CreatorProfileEntity>? creators,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    int? page,
    String? errorMessage,
  }) {
    return FollowingState(
      creators: creators ?? this.creators,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }
}

class FollowingNotifier extends StateNotifier<FollowingState> {
  final CreatorRepository _repository;

  FollowingNotifier(this._repository) : super(const FollowingState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await _repository.getFollowing(page: 1, size: 20);
      state = state.copyWith(
        creators: items,
        isLoading: false,
        page: 1,
        hasMore: items.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load followed artists. Please retry.',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final items = await _repository.getFollowing(page: 1, size: 20);
      state = state.copyWith(
        creators: items,
        isRefreshing: false,
        page: 1,
        hasMore: items.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: 'Failed to refresh followed artists.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isRefreshing || !state.hasMore) return;

    final nextPage = state.page + 1;
    try {
      final items = await _repository.getFollowing(page: nextPage, size: 20);
      state = state.copyWith(
        creators: [...state.creators, ...items],
        page: nextPage,
        hasMore: items.length >= 20,
      );
    } catch (_) {
      // Keep existing list on failure to load next page
    }
  }

  void removeCreator(String creatorId) {
    state = state.copyWith(
      creators: state.creators.where((c) => c.id != creatorId).toList(),
    );
  }
}

final followingNotifierProvider =
    StateNotifierProvider<FollowingNotifier, FollowingState>((ref) {
  final repository = ref.watch(creatorRepositoryProvider);
  return FollowingNotifier(repository);
});
