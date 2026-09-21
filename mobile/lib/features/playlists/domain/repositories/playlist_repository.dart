import 'package:hums_mobile/features/playlists/domain/entities/playlist_entity.dart';

abstract class PlaylistRepository {
  Future<List<PlaylistEntity>> listPlaylists({int skip = 0, int limit = 50});
  Future<PlaylistDetailEntity> getPlaylistDetails(String playlistId);
  Future<PlaylistEntity> createPlaylist({required String name, String? description});
  Future<PlaylistEntity> updatePlaylist(
    String playlistId, {
    String? name,
    String? description,
    bool? isPublic,
  });
  Future<void> deletePlaylist(String playlistId);
  Future<PlaylistEntity> uploadCover(String playlistId, String filePath);
  Future<PlaylistEntity> removeCover(String playlistId);
  Future<PlaylistDetailEntity> addTrack(String playlistId, String trackId);
  Future<PlaylistDetailEntity> removeTrack(String playlistId, String trackId);
  Future<PlaylistDetailEntity> reorderTracks(
    String playlistId,
    List<String> trackIds,
  );
}
