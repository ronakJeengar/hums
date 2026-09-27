import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';
import 'package:hums_mobile/features/social/presentation/screens/following_screen.dart';

class FakeFollowingCreatorRepository implements CreatorRepository {
  List<CreatorProfileEntity> mockFollowing = [];
  bool shouldThrow = false;

  @override
  Future<List<CreatorProfileEntity>> getFollowing({int page = 1, int size = 20}) async {
    if (shouldThrow) {
      throw Exception('Server error');
    }
    return mockFollowing;
  }

  @override
  Future<FollowStatusEntity> followCreator(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: true, followersCount: 1);
  }

  @override
  Future<FollowStatusEntity> unfollowCreator(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: false, followersCount: 0);
  }

  @override
  Future<FollowStatusEntity> getFollowStatus(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: true, followersCount: 1);
  }

  @override
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId) => throw UnimplementedError();

  @override
  Future<List<FollowerUserEntity>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) => throw UnimplementedError();

  @override
  Future<List<CreatorProfileEntity>> getPopularCreators({int skip = 0, int limit = 20}) => throw UnimplementedError();
}

class FakeAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  FakeAudioPlayerNotifier() : super(const PlayerState());
}

void main() {
  testWidgets('FollowingScreen shows empty state when user follows no one', (tester) async {
    final fakeRepo = FakeFollowingCreatorRepository();
    fakeRepo.mockFollowing = [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorRepositoryProvider.overrideWithValue(fakeRepo),
          audioPlayerNotifierProvider.overrideWith((ref) => FakeAudioPlayerNotifier()),
        ],
        child: const MaterialApp(
          home: FollowingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("You're not following anyone yet."), findsOneWidget);
    expect(find.text('Follow artists you love to keep up with their music.'), findsOneWidget);
    expect(find.text('Discover Artists'), findsOneWidget);
  });

  testWidgets('FollowingScreen displays followed artists with verified badges', (tester) async {
    final fakeRepo = FakeFollowingCreatorRepository();
    fakeRepo.mockFollowing = [
      CreatorProfileEntity(
        id: 'c-arijit',
        name: 'Arijit Singh',
        followersCount: 1200000,
        isVerified: true,
        createdAt: DateTime.now(),
      ),
      CreatorProfileEntity(
        id: 'c-rahman',
        name: 'A.R. Rahman',
        followersCount: 3500000,
        isVerified: true,
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorRepositoryProvider.overrideWithValue(fakeRepo),
          audioPlayerNotifierProvider.overrideWith((ref) => FakeAudioPlayerNotifier()),
        ],
        child: const MaterialApp(
          home: FollowingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Arijit Singh'), findsOneWidget);
    expect(find.text('A.R. Rahman'), findsOneWidget);
    expect(find.text('1.2M followers'), findsOneWidget);
    expect(find.text('3.5M followers'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNWidgets(2));
  });
}
