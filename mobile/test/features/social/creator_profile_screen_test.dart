import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';
import 'package:hums_mobile/features/social/presentation/screens/creator_profile_screen.dart';

class FakeCreatorProfileRepository implements CreatorRepository {
  CreatorDetailEntity? detail;

  @override
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId) async {
    return detail!;
  }

  @override
  Future<FollowStatusEntity> followCreator(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: true, followersCount: 1200001);
  }

  @override
  Future<FollowStatusEntity> unfollowCreator(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: false, followersCount: 1200000);
  }

  @override
  Future<FollowStatusEntity> getFollowStatus(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: false, followersCount: 1200000);
  }

  @override
  Future<List<FollowerUserEntity>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) => throw UnimplementedError();

  @override
  Future<List<CreatorProfileEntity>> getFollowing({int page = 1, int size = 20}) => throw UnimplementedError();

  @override
  Future<List<CreatorProfileEntity>> getPopularCreators({int skip = 0, int limit = 20}) => throw UnimplementedError();
}

class TrackingAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  PlayerQueue? playedQueue;
  int? playedIndex;

  TrackingAudioPlayerNotifier() : super(const PlayerState());

  @override
  Future<void> playQueue(PlayerQueue queue, {int startIndex = 0}) async {
    playedQueue = queue;
    playedIndex = startIndex;
  }
}

void main() {
  testWidgets('CreatorProfileScreen renders profile header and popular tracks', (tester) async {
    final fakeRepo = FakeCreatorProfileRepository();
    final audioNotifier = TrackingAudioPlayerNotifier();

    final testDate = DateTime(2026, 9, 21);
    fakeRepo.detail = CreatorDetailEntity(
      id: 'c-arijit',
      name: 'Arijit Singh',
      username: 'arijitsingh',
      bio: 'Singer, music composer, and music producer.',
      followersCount: 1200000,
      isVerified: true,
      popularTracks: [
        TrackEntity(
          id: 't-1',
          ownerId: 'u-1',
          title: 'Tum Hi Ho',
          artistName: 'Arijit Singh',
          albumName: 'Aashiqui 2',
          durationSeconds: 262,
          status: 'READY',
          createdAt: testDate,
          updatedAt: testDate,
        ),
        TrackEntity(
          id: 't-2',
          ownerId: 'u-1',
          title: 'Kesariya',
          artistName: 'Arijit Singh',
          albumName: 'Brahmastra',
          durationSeconds: 268,
          status: 'READY',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      ],
      createdAt: testDate,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorRepositoryProvider.overrideWithValue(fakeRepo),
          audioPlayerNotifierProvider.overrideWith((ref) => audioNotifier),
        ],
        child: const MaterialApp(
          home: CreatorProfileScreen(creatorId: 'c-arijit'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Arijit Singh'), findsOneWidget);
    expect(find.text('@arijitsingh'), findsOneWidget);
    expect(find.text('1.2M followers'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Singer, music composer, and music producer.'), findsOneWidget);

    // Verify Popular Tracks
    expect(find.text('Popular Tracks'), findsOneWidget);
    expect(find.text('Tum Hi Ho'), findsOneWidget);

    // Scroll to reveal next track
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Kesariya'), findsOneWidget);

    // Tap track 2: should trigger global player playQueue with startIndex=1
    await tester.tap(find.text('Kesariya'));
    await tester.pump();

    expect(audioNotifier.playedQueue, isNotNull);
    expect(audioNotifier.playedIndex, 1);
    expect(audioNotifier.playedQueue!.items[1].title, 'Kesariya');
  });
}
