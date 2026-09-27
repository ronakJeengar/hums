import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:hums_mobile/features/library/presentation/providers/like_notifier.dart';

class MockLibraryRepository implements LibraryRepository {
  bool shouldFail = false;
  int likeCalls = 0;
  int unlikeCalls = 0;
  int getStatusCalls = 0;
  int mockLikesCount = 5;
  bool mockIsLiked = false;

  @override
  Future<LikeStatusEntity> likeTrack(String trackId) async {
    likeCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    mockIsLiked = true;
    mockLikesCount++;
    return LikeStatusEntity(
      trackId: trackId,
      isLiked: true,
      likesCount: mockLikesCount,
    );
  }

  @override
  Future<LikeStatusEntity> unlikeTrack(String trackId) async {
    unlikeCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    mockIsLiked = false;
    mockLikesCount = mockLikesCount > 0 ? mockLikesCount - 1 : 0;
    return LikeStatusEntity(
      trackId: trackId,
      isLiked: false,
      likesCount: mockLikesCount,
    );
  }

  @override
  Future<LikeStatusEntity> getLikeStatus(String trackId) async {
    getStatusCalls++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    return LikeStatusEntity(
      trackId: trackId,
      isLiked: mockIsLiked,
      likesCount: mockLikesCount,
    );
  }

  @override
  Future<LibrarySummaryEntity> getLibrarySummary() => throw UnimplementedError();

  @override
  Future<List<LikedTrackEntity>> getLikedTracks({int page = 1, int size = 20}) =>
      throw UnimplementedError();
}

void main() {
  late MockLibraryRepository mockRepository;
  late LikeNotifier notifier;
  const trackId = 'track-abc-123';

  setUp(() {
    mockRepository = MockLibraryRepository();
    notifier = LikeNotifier(mockRepository, trackId);
  });

  group('LikeNotifier Tests', () {
    test('initial state has default unliked values', () {
      expect(notifier.state.isLiked, false);
      expect(notifier.state.likesCount, 0);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, null);
    });

    test('initialize updates state with provided values', () {
      notifier.initialize(initialLiked: true, initialCount: 42);
      expect(notifier.state.isLiked, true);
      expect(notifier.state.likesCount, 42);
    });

    test('fetchStatus updates state with server response', () async {
      mockRepository.mockIsLiked = true;
      mockRepository.mockLikesCount = 15;

      await notifier.fetchStatus();

      expect(mockRepository.getStatusCalls, 1);
      expect(notifier.state.isLiked, true);
      expect(notifier.state.likesCount, 15);
      expect(notifier.state.isLoading, false);
    });

    test('toggleLike optimistically likes track and syncs with server', () async {
      notifier.initialize(initialLiked: false, initialCount: 5);

      final future = notifier.toggleLike();

      // Immediately after triggering, state is optimistically updated
      expect(notifier.state.isLiked, true);
      expect(notifier.state.likesCount, 6);

      await future;

      expect(mockRepository.likeCalls, 1);
      expect(mockRepository.unlikeCalls, 0);
      expect(notifier.state.isLiked, true);
      expect(notifier.state.likesCount, 6);
    });

    test('toggleLike optimistically unlikes track and syncs with server', () async {
      notifier.initialize(initialLiked: true, initialCount: 5);

      final future = notifier.toggleLike();

      // Optimistic update
      expect(notifier.state.isLiked, false);
      expect(notifier.state.likesCount, 4);

      await future;

      expect(mockRepository.unlikeCalls, 1);
      expect(mockRepository.likeCalls, 0);
      expect(notifier.state.isLiked, false);
      expect(notifier.state.likesCount, 4);
    });

    test('toggleLike rolls back optimistic state on server failure', () async {
      notifier.initialize(initialLiked: false, initialCount: 5);
      mockRepository.shouldFail = true;

      await notifier.toggleLike();

      expect(mockRepository.likeCalls, 1);
      // Reverted back to initial state
      expect(notifier.state.isLiked, false);
      expect(notifier.state.likesCount, 5);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });
}
