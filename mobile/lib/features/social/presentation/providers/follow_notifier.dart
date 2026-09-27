import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/social/data/datasources/creator_remote_data_source.dart';
import 'package:hums_mobile/features/social/data/repositories/creator_repository_impl.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/states/follow_state.dart';

final creatorRemoteDataSourceProvider = Provider<CreatorRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CreatorRemoteDataSourceImpl(apiClient);
});

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  final remoteDataSource = ref.watch(creatorRemoteDataSourceProvider);
  return CreatorRepositoryImpl(remoteDataSource);
});

class FollowNotifier extends StateNotifier<FollowState> {
  final String creatorId;
  final CreatorRepository _repository;
  bool _initialized = false;

  FollowNotifier({
    required this.creatorId,
    required CreatorRepository repository,
    bool initialFollowing = false,
    int initialCount = 0,
  })  : _repository = repository,
        super(FollowState(
          isFollowing: initialFollowing,
          followersCount: initialCount,
        ));

  void initialize({required bool isFollowing, required int followersCount}) {
    if (!_initialized) {
      _initialized = true;
      state = state.copyWith(
        isFollowing: isFollowing,
        followersCount: followersCount,
      );
    }
  }

  Future<void> fetchStatus() async {
    try {
      final status = await _repository.getFollowStatus(creatorId);
      _initialized = true;
      state = state.copyWith(
        isFollowing: status.isFollowing,
        followersCount: status.followersCount,
        isLoading: false,
      );
    } catch (_) {
      // Keep existing state on transient fetch error
    }
  }

  Future<bool> toggleFollow() async {
    if (state.isLoading) return state.isFollowing;

    final prevFollowing = state.isFollowing;
    final prevCount = state.followersCount;

    // 1. Optimistic UI update
    final optimisticFollowing = !prevFollowing;
    final optimisticCount = optimisticFollowing
        ? prevCount + 1
        : max(0, prevCount - 1);

    state = state.copyWith(
      isFollowing: optimisticFollowing,
      followersCount: optimisticCount,
      isLoading: true,
      errorMessage: null,
    );

    // 2. Perform authoritative network mutation
    try {
      final result = prevFollowing
          ? await _repository.unfollowCreator(creatorId)
          : await _repository.followCreator(creatorId);

      _initialized = true;
      state = state.copyWith(
        isFollowing: result.isFollowing,
        followersCount: result.followersCount,
        isLoading: false,
      );
      return result.isFollowing;
    } catch (e) {
      // 3. Rollback on failure
      state = state.copyWith(
        isFollowing: prevFollowing,
        followersCount: prevCount,
        isLoading: false,
        errorMessage: 'Failed to update follow status. Please try again.',
      );
      return prevFollowing;
    }
  }
}

final followNotifierProvider =
    StateNotifierProvider.family<FollowNotifier, FollowState, String>((ref, creatorId) {
  final repository = ref.watch(creatorRepositoryProvider);
  return FollowNotifier(
    creatorId: creatorId,
    repository: repository,
  );
});
