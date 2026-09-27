import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/widgets/like_button.dart';

class FakeLibraryRepository implements LibraryRepository {
  bool isLiked = false;
  int count = 10;

  @override
  Future<LikeStatusEntity> likeTrack(String trackId) async {
    isLiked = true;
    count++;
    return LikeStatusEntity(trackId: trackId, isLiked: true, likesCount: count);
  }

  @override
  Future<LikeStatusEntity> unlikeTrack(String trackId) async {
    isLiked = false;
    count = count > 0 ? count - 1 : 0;
    return LikeStatusEntity(trackId: trackId, isLiked: false, likesCount: count);
  }

  @override
  Future<LikeStatusEntity> getLikeStatus(String trackId) async {
    return LikeStatusEntity(trackId: trackId, isLiked: isLiked, likesCount: count);
  }

  @override
  Future<LibrarySummaryEntity> getLibrarySummary() => throw UnimplementedError();

  @override
  Future<List<LikedTrackEntity>> getLikedTracks({int page = 1, int size = 20}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('LikeButton renders unliked icon when initialLiked is false',
      (tester) async {
    final fakeRepo = FakeLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LikeButton(
              trackId: 'track-1',
              initialLiked: false,
              initialCount: 5,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('LikeButton renders filled heart icon when initialLiked is true',
      (tester) async {
    final fakeRepo = FakeLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LikeButton(
              trackId: 'track-2',
              initialLiked: true,
              initialCount: 12,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('LikeButton toggles optimistic state and triggers repository on tap',
      (tester) async {
    final fakeRepo = FakeLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LikeButton(
              trackId: 'track-3',
              initialLiked: false,
              initialCount: 0,
              showCount: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    // Tap to like
    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(fakeRepo.isLiked, isTrue);
  });

  testWidgets('LikeButton includes accessibility semantics', (tester) async {
    final fakeRepo = FakeLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LikeButton(
              trackId: 'track-4',
              trackTitle: 'Midnight Melody',
              initialLiked: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Like Midnight Melody'),
      findsOneWidget,
    );
  });
}
