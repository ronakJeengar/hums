import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_list_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';

class MockPlaylistListNotifier extends StateNotifier<PlaylistListState>
    with Mock
    implements PlaylistListNotifier {
  MockPlaylistListNotifier(super.state);
}

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

void main() {
  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tPlaylist = PlaylistEntity(
    id: 'p-1',
    ownerId: 'u-1',
    name: 'Chill Vibes',
    description: 'Relaxing tunes',
    trackCount: 5,
    durationSeconds: 900,
    createdAt: testDate,
    updatedAt: testDate,
  );

  Widget createWidgetUnderTest(PlaylistListState state) {
    return ProviderScope(
      overrides: [
        playlistListNotifierProvider.overrideWith((ref) {
          final notifier = MockPlaylistListNotifier(state);
          when(() => notifier.loadPlaylists()).thenAnswer((_) async {});
          return notifier;
        }),
        audioPlayerNotifierProvider.overrideWith((ref) {
          return MockAudioPlayerNotifier(const PlayerState());
        }),
      ],
      child: const MaterialApp(
        home: PlaylistListScreen(),
      ),
    );
  }

  group('PlaylistListScreen Widget Tests', () {
    testWidgets('renders loading indicator when status is loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const PlaylistListState(status: PlaylistListStatus.loading),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state message when list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const PlaylistListState(
            status: PlaylistListStatus.loaded,
            playlists: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No playlists yet'), findsOneWidget);
      expect(find.text('Create Playlist'), findsOneWidget);
    });

    testWidgets('renders playlist items when loaded',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          PlaylistListState(
            status: PlaylistListStatus.loaded,
            playlists: [tPlaylist],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chill Vibes'), findsOneWidget);
      expect(find.text('5 tracks • 15 min'), findsOneWidget);
    });
  });
}
