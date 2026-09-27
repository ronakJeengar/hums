import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/social/domain/entities/creator_profile_entity.dart';
import 'package:hums_mobile/features/social/domain/entities/follow_status_entity.dart';
import 'package:hums_mobile/features/social/domain/repositories/creator_repository.dart';
import 'package:hums_mobile/features/social/presentation/providers/follow_notifier.dart';
import 'package:hums_mobile/features/social/presentation/widgets/follow_button.dart';

class FakeCreatorRepository implements CreatorRepository {
  bool isFollowing = false;
  int count = 10;

  @override
  Future<FollowStatusEntity> followCreator(String creatorId) async {
    isFollowing = true;
    count++;
    return FollowStatusEntity(creatorId: creatorId, isFollowing: true, followersCount: count);
  }

  @override
  Future<FollowStatusEntity> unfollowCreator(String creatorId) async {
    isFollowing = false;
    count = count > 0 ? count - 1 : 0;
    return FollowStatusEntity(creatorId: creatorId, isFollowing: false, followersCount: count);
  }

  @override
  Future<FollowStatusEntity> getFollowStatus(String creatorId) async {
    return FollowStatusEntity(creatorId: creatorId, isFollowing: isFollowing, followersCount: count);
  }

  @override
  Future<CreatorDetailEntity> getCreatorProfile(String creatorId) => throw UnimplementedError();

  @override
  Future<List<FollowerUserEntity>> getCreatorFollowers(String creatorId, {int page = 1, int size = 20}) => throw UnimplementedError();

  @override
  Future<List<CreatorProfileEntity>> getFollowing({int page = 1, int size = 20}) => throw UnimplementedError();

  @override
  Future<List<CreatorProfileEntity>> getPopularCreators({int skip = 0, int limit = 20}) => throw UnimplementedError();
}

void main() {
  testWidgets('FollowButton renders Follow when not following, and toggles on tap', (tester) async {
    final fakeRepo = FakeCreatorRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creatorRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FollowButton(
              creatorId: 'c1',
              initialFollowing: false,
              initialCount: 10,
            ),
          ),
        ),
      ),
    );

    // Initial frame
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);

    // Tap Follow button
    await tester.tap(find.text('Follow'));
    await tester.pump(); // Start async call

    // Settled after network response
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);

    // Tap again to unfollow
    await tester.tap(find.text('Following'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);
  });
}
