import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/screens/playlist_detail_screen.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';

class MockPlaylistDetailNotifier extends StateNotifier<PlaylistDetailState>
    with Mock
    implements PlaylistDetailNotifier {
  MockPlaylistDetailNotifier(super.state);
}

class TestAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  TestAudioPlayerNotifier(super.state);

  void updatePosition(Duration newPosition) {
    state = state.copyWith(position: newPosition);
  }
}

void main() {
  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tPlaylist = PlaylistEntity(
    id: 'p-1',
    ownerId: 'u-1',
    name: 'Evening Jazz',
    createdAt: testDate,
    updatedAt: testDate,
  );

  final tTrack = PlaylistTrackEntity(
    id: 'pt-1',
    trackId: 't-1',
    position: 0,
    addedAt: testDate,
    title: 'Blue in Green',
    status: 'READY',
  );

  final tDetail = PlaylistDetailEntity(playlist: tPlaylist, tracks: [tTrack]);

  const tTrackPlayback = TrackPlaybackEntity(
    trackId: 't-1',
    title: 'Blue in Green',
    artistName: 'Miles Davis',
    albumName: 'Kind of Blue',
    genre: 'Jazz',
    durationSeconds: 300,
    status: 'READY',
    audio: AudioSourceEntity(
      url: 'https://cdn.hums.app/stream/t-1/audio.mp3',
      format: 'mp3',
      codec: 'mp3',
      bitrateKbps: 192,
      durationSeconds: 300,
      fileSizeBytes: 7200000,
    ),
  );

  testWidgets(
    'Measure PlaylistDetailScreen rebuilds during audio playback position updates',
    (WidgetTester tester) async {
      final playerNotifier = TestAudioPlayerNotifier(
        const PlayerState(
          status: PlayerStatus.playing,
          track: tTrackPlayback,
          position: Duration(seconds: 0),
          duration: Duration(seconds: 300),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistDetailNotifierProvider('p-1').overrideWith((ref) {
              final mockNotifier = MockPlaylistDetailNotifier(
                PlaylistDetailState(
                  status: PlaylistDetailStatus.loaded,
                  detail: tDetail,
                ),
              );
              when(() => mockNotifier.loadDetails()).thenAnswer((_) async {});
              return mockNotifier;
            }),
            audioPlayerNotifierProvider.overrideWith((ref) => playerNotifier),
          ],
          child: const MaterialApp(
            home: PlaylistDetailScreen(playlistId: 'p-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistDetailScreen), findsOneWidget);

      // Track whether PlaylistDetailScreen was marked dirty
      int detailDirtyCount = 0;
      for (int i = 1; i <= 10; i++) {
        playerNotifier.updatePosition(Duration(seconds: i));
        final isDetailDirty = tester
            .element(find.byType(PlaylistDetailScreen))
            .dirty;
        if (isDetailDirty) {
          detailDirtyCount++;
        }
        await tester.pump();
      }

      // ignore: avoid_print
      print(
        'PlaylistDetailScreen dirty count on 10 position ticks: $detailDirtyCount',
      );
      expect(detailDirtyCount, 0);
    },
  );
}
