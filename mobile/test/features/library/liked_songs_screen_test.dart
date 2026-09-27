import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:hums_mobile/features/library/presentation/providers/library_provider.dart';
import 'package:hums_mobile/features/library/presentation/screens/liked_songs_screen.dart';

class MockLikedTracksRepository implements LibraryRepository {
  List<LikedTrackEntity> tracksToReturn = [];
  bool shouldThrow = false;

  @override
  Future<List<LikedTrackEntity>> getLikedTracks({int page = 1, int size = 20}) async {
    if (shouldThrow) throw Exception('API Failure');
    return tracksToReturn;
  }

  @override
  Future<LikeStatusEntity> likeTrack(String trackId) async {
    return LikeStatusEntity(trackId: trackId, isLiked: true, likesCount: 1);
  }

  @override
  Future<LikeStatusEntity> unlikeTrack(String trackId) async {
    return LikeStatusEntity(trackId: trackId, isLiked: false, likesCount: 0);
  }

  @override
  Future<LikeStatusEntity> getLikeStatus(String trackId) async {
    return LikeStatusEntity(trackId: trackId, isLiked: true, likesCount: 1);
  }

  @override
  Future<LibrarySummaryEntity> getLibrarySummary() async {
    return const LibrarySummaryEntity(
      likedTracksCount: 0,
      playlistsCount: 0,
      followingCreatorsCount: 0,
    );
  }
}

void main() {
  testWidgets('LikedSongsScreen renders empty state when no tracks are liked',
      (tester) async {
    final repo = MockLikedTracksRepository()..tracksToReturn = [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: LikedSongsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No liked songs yet.'), findsOneWidget);
    expect(find.text("Tap ❤️ on songs you love and they'll appear here."),
        findsOneWidget);
    expect(find.text('Discover Music'), findsOneWidget);
  });

  testWidgets('LikedSongsScreen renders list of liked tracks with metadata',
      (tester) async {
    final sampleTracks = [
      LikedTrackEntity(
        id: 'track-1',
        title: 'Midnight Echoes',
        artistName: 'Luna Wave',
        albumName: 'Nightfall',
        genre: 'Ambient',
        durationSeconds: 215,
        waveformKey: 'wf-1',
        status: 'READY',
        likedAt: DateTime.parse('2026-09-27T10:00:00Z'),
        createdAt: DateTime.parse('2026-09-20T10:00:00Z'),
      ),
      LikedTrackEntity(
        id: 'track-2',
        title: 'Solar Flare',
        artistName: 'Cosmo',
        albumName: 'Atmosphere',
        genre: 'Electronic',
        durationSeconds: 180,
        waveformKey: 'wf-2',
        status: 'READY',
        likedAt: DateTime.parse('2026-09-26T10:00:00Z'),
        createdAt: DateTime.parse('2026-09-18T10:00:00Z'),
      ),
    ];

    final repo = MockLikedTracksRepository()..tracksToReturn = sampleTracks;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: LikedSongsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and track list
    expect(find.text('Liked Songs'), findsWidgets);
    expect(find.text('Midnight Echoes'), findsOneWidget);
    expect(find.textContaining('Luna Wave'), findsOneWidget);
    expect(find.text('Solar Flare'), findsOneWidget);
    expect(find.textContaining('Cosmo'), findsOneWidget);
  });
}
