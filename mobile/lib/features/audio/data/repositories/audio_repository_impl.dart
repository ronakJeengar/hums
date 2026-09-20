import 'package:hums_mobile/features/audio/data/datasources/audio_remote_data_source.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioRemoteDataSource _remoteDataSource;

  const AudioRepositoryImpl(this._remoteDataSource);

  @override
  Future<TrackEntity> uploadAudio({
    required String filePath,
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
    void Function(double progress)? onProgress,
  }) async {
    final model = await _remoteDataSource.uploadAudio(
      filePath: filePath,
      title: title,
      description: description,
      artistName: artistName,
      albumName: albumName,
      genre: genre,
      onProgress: onProgress,
    );
    return model.toEntity();
  }

  @override
  Future<List<TrackEntity>> listTracks({int skip = 0, int limit = 50}) async {
    final models = await _remoteDataSource.listTracks(skip: skip, limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<TrackEntity> getTrack(String trackId) async {
    final model = await _remoteDataSource.getTrack(trackId);
    return model.toEntity();
  }

  @override
  Future<TrackStatusEntity> getTrackStatus(String trackId) async {
    final model = await _remoteDataSource.getTrackStatus(trackId);
    return model.toEntity();
  }
}
