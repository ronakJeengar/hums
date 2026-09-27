import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';

class MockCreatorRepository implements CreatorRepository {
  bool shouldFail = false;
  int followCalls = 0;
  int unfollowCalls = 0;
  int getStatusCalls = 0;
  int mockCount = 10;
  bool mockIsFollowing = false;

  @override
  Future<FollowStatusEntity> followCreator(String creatorId) async {
    followCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    mockIsFollowing = true;
    mockCount++;
    return FollowStatusEntity(
      creatorId: creatorId,
      isFollowing: true,
      followersCount: mockCount,
    );
  }

  @override
  Future<FollowStatusEntity> unfollowCreator(String creatorId) async {
    unfollowCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    mockIsFollowing = false;
    mockCount = mockCount > 0 ? mockCount - 1 : 0;
    return FollowStatusEntity(
      creatorId: creatorId,
      isFollowing: false,
      followersCount: mockCount,
    );
  }

  @override
  Future<FollowStatusEntity> getFollowStatus(String creatorId) async {
    getStatusCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    return FollowStatusEntity(
      creatorId: creatorId,
      isFollowing: mockIsFollowing,
      followersCount: mockCount,
    );
  }

  @override
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId) {
    throw UnimplementedError();
  }

  @override
  Future<List<FollowerUserEntity>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<List<CreatorProfileEntity>> getFollowing({int page = 1, int size = 20}) {
    throw UnimplementedError();
  }

  @override
  Future<List<CreatorProfileEntity>> getPopularCreators({int skip = 0, int limit = 20}) {
    throw UnimplementedError();
  }
}

void main() {
  group('FollowNotifier Unit Tests', () {
    late MockCreatorRepository mockRepo;
    late FollowNotifier notifier;

    setUp(() {
      mockRepo = MockCreatorRepository();
      notifier = FollowNotifier(
        creatorId: 'c123',
        repository: mockRepo,
        initialFollowing: false,
        initialCount: 50,
      );
    });

    test('Initializes with provided parameters', () {
      expect(notifier.state.isFollowing, isFalse);
      expect(notifier.state.followersCount, 50);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('toggleFollow performs optimistic follow and updates on success', () async {
      final future = notifier.toggleFollow();

      // Immediately after invoking, state should be optimistically updated
      expect(notifier.state.isFollowing, isTrue);
      expect(notifier.state.followersCount, 51);
      expect(notifier.state.isLoading, isTrue);

      final result = await future;
      expect(result, isTrue);
      expect(notifier.state.isFollowing, isTrue);
      expect(notifier.state.followersCount, 11); // mockRepo count was 10 + 1 = 11
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(mockRepo.followCalls, 1);
    });

    test('toggleFollow performs optimistic unfollow and updates on success', () async {
      notifier.initialize(isFollowing: true, followersCount: 15);
      mockRepo.mockCount = 15;
      mockRepo.mockIsFollowing = true;

      final future = notifier.toggleFollow();

      expect(notifier.state.isFollowing, isFalse);
      expect(notifier.state.followersCount, 14);
      expect(notifier.state.isLoading, isTrue);

      final result = await future;
      expect(result, isFalse);
      expect(notifier.state.isFollowing, isFalse);
      expect(notifier.state.followersCount, 14);
      expect(notifier.state.isLoading, isFalse);
      expect(mockRepo.unfollowCalls, 1);
    });

    test('toggleFollow rolls back on error', () async {
      mockRepo.shouldFail = true;

      final future = notifier.toggleFollow();

      // Optimistic during call
      expect(notifier.state.isFollowing, isTrue);
      expect(notifier.state.followersCount, 51);

      final result = await future;
      expect(result, isFalse); // rolled back to false
      expect(notifier.state.isFollowing, isFalse);
      expect(notifier.state.followersCount, 50);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('toggleFollow ignores repeated calls while loading', () async {
      // Start follow
      final f1 = notifier.toggleFollow();
      // Try to follow again immediately while loading
      final f2 = notifier.toggleFollow();

      await f1;
      await f2;

      // Only 1 network call should have occurred
      expect(mockRepo.followCalls, 1);
    });
  });
}
