import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';

abstract class AudioRepository {
  /// Uploads an audio file along with track metadata and optional progress callback.
  Future<TrackEntity> uploadAudio({
    required String filePath,
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
    void Function(double progress)? onProgress,
  });

  /// Lists all tracks uploaded by the authenticated user.
  Future<List<TrackEntity>> listTracks({int skip = 0, int limit = 50});

  /// Retrieves full track details by track ID.
  Future<TrackEntity> getTrack(String trackId);

  /// Retrieves lightweight upload and processing status for a track.
  Future<TrackStatusEntity> getTrackStatus(String trackId);
}
