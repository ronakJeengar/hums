import 'package:hums_mobile/features/library/data/datasources/library_remote_data_source.dart';
import 'package:hums_mobile/features/library/domain/entities/like_status_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/liked_track_entity.dart';
import 'package:hums_mobile/features/library/domain/entities/library_summary_entity.dart';
import 'package:hums_mobile/features/library/domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryRemoteDataSource _remoteDataSource;

  LibraryRepositoryImpl(this._remoteDataSource);

  @override
  Future<LikeStatusEntity> likeTrack(String trackId) =>
      _remoteDataSource.likeTrack(trackId);

  @override
  Future<LikeStatusEntity> unlikeTrack(String trackId) =>
      _remoteDataSource.unlikeTrack(trackId);

  @override
  Future<LikeStatusEntity> getLikeStatus(String trackId) =>
      _remoteDataSource.getLikeStatus(trackId);

  @override
  Future<List<LikedTrackEntity>> getLikedTracks({int page = 1, int size = 20}) =>
      _remoteDataSource.getLikedTracks(page: page, size: size);

  @override
  Future<LibrarySummaryEntity> getLibrarySummary() =>
      _remoteDataSource.getLibrarySummary();
}
