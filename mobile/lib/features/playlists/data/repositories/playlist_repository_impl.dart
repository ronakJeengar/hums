import 'package:hums_mobile/features/playlists/data/datasources/playlist_remote_data_source.dart';
import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';
import 'package:hums_mobile/features/playlists/domain/repositories/playlist_repository.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistRemoteDataSource _remoteDataSource;

  const PlaylistRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<PlaylistEntity>> listPlaylists({int skip = 0, int limit = 50}) async {
    final models = await _remoteDataSource.listPlaylists(skip: skip, limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<PlaylistDetailEntity> getPlaylistDetails(String playlistId) async {
    final model = await _remoteDataSource.getPlaylistDetails(playlistId);
    return model.toEntity();
  }

  @override
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String? description,
  }) async {
    final model = await _remoteDataSource.createPlaylist(
      name: name,
      description: description,
    );
    return model.toEntity();
  }

  @override
  Future<PlaylistEntity> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final model = await _remoteDataSource.updatePlaylist(
      playlistId,
      name: name,
      description: description,
      isPublic: isPublic,
    );
    return model.toEntity();
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _remoteDataSource.deletePlaylist(playlistId);
  }

  @override
  Future<PlaylistEntity> uploadCover(String playlistId, String filePath) async {
    final model = await _remoteDataSource.uploadCover(playlistId, filePath);
    return model.toEntity();
  }

  @override
  Future<PlaylistEntity> removeCover(String playlistId) async {
    final model = await _remoteDataSource.removeCover(playlistId);
    return model.toEntity();
  }

  @override
  Future<PlaylistDetailEntity> addTrack(String playlistId, String trackId) async {
    final model = await _remoteDataSource.addTrack(playlistId, trackId);
    return model.toEntity();
  }

  @override
  Future<PlaylistDetailEntity> removeTrack(String playlistId, String trackId) async {
    final model = await _remoteDataSource.removeTrack(playlistId, trackId);
    return model.toEntity();
  }

  @override
  Future<PlaylistDetailEntity> reorderTracks(
    String playlistId,
    List<String> trackIds,
  ) async {
    final model = await _remoteDataSource.reorderTracks(playlistId, trackIds);
    return model.toEntity();
  }
}
