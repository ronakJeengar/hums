import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/domain/repositories/playlist_repository.dart';
import 'package:hums_mobile/features/playlists/presentation/providers/playlist_provider.dart';
import 'package:hums_mobile/features/playlists/presentation/states/playlist_state.dart';

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

void main() {
  late MockPlaylistRepository mockRepo;

  setUp(() {
    mockRepo = MockPlaylistRepository();
  });

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

  final tDetail = PlaylistDetailEntity(
    playlist: tPlaylist,
    tracks: [tTrack],
  );

  group('PlaylistListNotifier Tests', () {
    test('loadPlaylists updates state to loaded on success', () async {
      when(() => mockRepo.listPlaylists())
          .thenAnswer((_) async => [tPlaylist]);

      final notifier = PlaylistListNotifier(mockRepo);
      await notifier.loadPlaylists();

      expect(notifier.state.status, PlaylistListStatus.loaded);
      expect(notifier.state.playlists.length, 1);
      expect(notifier.state.playlists.first.name, 'Evening Jazz');
    });

    test('loadPlaylists updates state to error on ApiException', () async {
      when(() => mockRepo.listPlaylists())
          .thenThrow(const ApiException(code: 'NETWORK_ERROR', message: 'Network Error'));

      final notifier = PlaylistListNotifier(mockRepo);
      await notifier.loadPlaylists();

      expect(notifier.state.status, PlaylistListStatus.error);
      expect(notifier.state.errorMessage, 'Network Error');
    });

    test('deletePlaylist removes item from list on success', () async {
      when(() => mockRepo.listPlaylists())
          .thenAnswer((_) async => [tPlaylist]);
      when(() => mockRepo.deletePlaylist('p-1')).thenAnswer((_) async {});

      final notifier = PlaylistListNotifier(mockRepo);
      await notifier.loadPlaylists();
      expect(notifier.state.playlists.length, 1);

      final success = await notifier.deletePlaylist('p-1');

      expect(success, isTrue);
      expect(notifier.state.playlists.isEmpty, isTrue);
    });

    test('addOrUpdatePlaylist updates list in state', () {
      final notifier = PlaylistListNotifier(mockRepo);
      notifier.addOrUpdatePlaylist(tPlaylist);

      expect(notifier.state.playlists.length, 1);

      final updated = PlaylistEntity(
        id: 'p-1',
        ownerId: 'u-1',
        name: 'Updated Name',
        createdAt: testDate,
        updatedAt: testDate,
      );

      notifier.addOrUpdatePlaylist(updated);
      expect(notifier.state.playlists.length, 1);
      expect(notifier.state.playlists.first.name, 'Updated Name');
    });
  });

  group('PlaylistDetailNotifier Tests', () {
    test('loadDetails updates state to loaded', () async {
      when(() => mockRepo.getPlaylistDetails('p-1'))
          .thenAnswer((_) async => tDetail);

      final notifier = PlaylistDetailNotifier(mockRepo, 'p-1');
      await notifier.loadDetails();

      expect(notifier.state.status, PlaylistDetailStatus.loaded);
      expect(notifier.state.detail?.playlist.name, 'Evening Jazz');
      expect(notifier.state.detail?.tracks.length, 1);
    });

    test('addTrack updates detail on success', () async {
      when(() => mockRepo.addTrack('p-1', 't-2'))
          .thenAnswer((_) async => tDetail);

      final notifier = PlaylistDetailNotifier(mockRepo, 'p-1');
      final success = await notifier.addTrack('t-2');

      expect(success, isTrue);
      expect(notifier.state.detail, isNotNull);
    });

    test('reorderTracks updates detail on success', () async {
      when(() => mockRepo.reorderTracks('p-1', ['t-1']))
          .thenAnswer((_) async => tDetail);

      final notifier = PlaylistDetailNotifier(mockRepo, 'p-1');
      final success = await notifier.reorderTracks(['t-1']);

      expect(success, isTrue);
      expect(notifier.state.detail, isNotNull);
    });
  });

  group('PlaylistFormNotifier Tests', () {
    test('createPlaylist creates playlist and sets success status', () async {
      when(() => mockRepo.createPlaylist(name: 'Jazz', description: null))
          .thenAnswer((_) async => tPlaylist);

      final notifier = PlaylistFormNotifier(mockRepo);
      final result = await notifier.createPlaylist(name: 'Jazz');

      expect(result, isNotNull);
      expect(notifier.state.status, PlaylistFormStatus.success);
      expect(notifier.state.playlist?.name, 'Evening Jazz');
    });
  });
}
