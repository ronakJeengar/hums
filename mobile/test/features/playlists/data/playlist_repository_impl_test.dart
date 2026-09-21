import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/playlists/data/datasources/playlist_remote_data_source.dart';
import 'package:hums_mobile/features/playlists/data/models/playlist_model.dart';
import 'package:hums_mobile/features/playlists/data/repositories/playlist_repository_impl.dart';

class MockPlaylistRemoteDataSource extends Mock
    implements PlaylistRemoteDataSource {}

void main() {
  late MockPlaylistRemoteDataSource mockRemote;
  late PlaylistRepositoryImpl repository;

  setUp(() {
    mockRemote = MockPlaylistRemoteDataSource();
    repository = PlaylistRepositoryImpl(mockRemote);
  });

  final testDate = DateTime(2026, 9, 21, 12, 0, 0);

  final tPlaylistModel = PlaylistModel(
    id: 'p-1',
    ownerId: 'u-1',
    name: 'Lo-Fi Study',
    description: 'Chilled beats',
    coverImageKey: 'covers/p-1.webp',
    coverImageUrl: 'https://cdn.hums.audio/covers/p-1.webp',
    isPublic: false,
    trackCount: 1,
    durationSeconds: 180,
    createdAt: testDate,
    updatedAt: testDate,
  );

  final tTrackModel = PlaylistTrackModel(
    id: 'pt-1',
    trackId: 't-1',
    position: 0,
    addedAt: testDate,
    title: 'Warm Rain',
    artistName: 'Artist A',
    durationSeconds: 180,
    status: 'READY',
  );

  final tDetailModel = PlaylistDetailModel(
    playlist: tPlaylistModel,
    tracks: [tTrackModel],
  );

  group('PlaylistRepositoryImpl Tests', () {
    test('listPlaylists returns mapped PlaylistEntity list', () async {
      when(() => mockRemote.listPlaylists(skip: 0, limit: 50))
          .thenAnswer((_) async => [tPlaylistModel]);

      final result = await repository.listPlaylists();

      expect(result.length, 1);
      expect(result.first.id, 'p-1');
      expect(result.first.name, 'Lo-Fi Study');
      verify(() => mockRemote.listPlaylists(skip: 0, limit: 50)).called(1);
    });

    test('getPlaylistDetails returns mapped PlaylistDetailEntity', () async {
      when(() => mockRemote.getPlaylistDetails('p-1'))
          .thenAnswer((_) async => tDetailModel);

      final result = await repository.getPlaylistDetails('p-1');

      expect(result.playlist.id, 'p-1');
      expect(result.tracks.length, 1);
      expect(result.tracks.first.title, 'Warm Rain');
      verify(() => mockRemote.getPlaylistDetails('p-1')).called(1);
    });

    test('createPlaylist calls remoteDataSource and maps entity', () async {
      when(() => mockRemote.createPlaylist(name: 'New', description: 'Desc'))
          .thenAnswer((_) async => tPlaylistModel);

      final result =
          await repository.createPlaylist(name: 'New', description: 'Desc');

      expect(result.id, 'p-1');
      verify(() => mockRemote.createPlaylist(name: 'New', description: 'Desc'))
          .called(1);
    });

    test('deletePlaylist calls remoteDataSource.deletePlaylist', () async {
      when(() => mockRemote.deletePlaylist('p-1'))
          .thenAnswer((_) async {});

      await repository.deletePlaylist('p-1');

      verify(() => mockRemote.deletePlaylist('p-1')).called(1);
    });

    test('addTrack calls remoteDataSource and returns PlaylistDetailEntity',
        () async {
      when(() => mockRemote.addTrack('p-1', 't-1'))
          .thenAnswer((_) async => tDetailModel);

      final result = await repository.addTrack('p-1', 't-1');

      expect(result.tracks.length, 1);
      verify(() => mockRemote.addTrack('p-1', 't-1')).called(1);
    });

    test('reorderTracks calls remoteDataSource and returns PlaylistDetailEntity',
        () async {
      when(() => mockRemote.reorderTracks('p-1', ['t-1']))
          .thenAnswer((_) async => tDetailModel);

      final result = await repository.reorderTracks('p-1', ['t-1']);

      expect(result.tracks.length, 1);
      verify(() => mockRemote.reorderTracks('p-1', ['t-1'])).called(1);
    });
  });
}
