import 'package:hums_mobile/features/downloads/data/datasources/download_local_data_source.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_remote_data_source.dart';
import 'package:hums_mobile/features/downloads/data/services/download_file_manager.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';
import 'package:hums_mobile/features/downloads/domain/repositories/download_repository.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final DownloadRemoteDataSource _remoteDataSource;
  final DownloadLocalDataSource _localDataSource;
  final DownloadFileManager _fileManager;

  DownloadRepositoryImpl({
    required DownloadRemoteDataSource remoteDataSource,
    required DownloadLocalDataSource localDataSource,
    required DownloadFileManager fileManager,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _fileManager = fileManager;

  @override
  Future<DownloadItem> getAuthorizedDownload(String trackId, String userId) async {
    final remote = await _remoteDataSource.getAuthorizedDownload(trackId);
    final now = DateTime.now();

    final existing = await _localDataSource.getDownload(trackId);
    if (existing != null) {
      return existing.copyWith(
        downloadUrl: remote.downloadUrl,
        urlExpiresAt: remote.expiresAt,
        totalBytes: remote.fileSizeBytes,
        format: remote.format,
        audioBitrate: remote.bitrateKbps,
        waveformSamples: remote.waveformSamples,
        updatedAt: now,
      );
    }

    return DownloadItem(
      id: 'dl_${trackId}_${now.millisecondsSinceEpoch}',
      trackId: trackId,
      userId: userId,
      title: remote.title,
      artistName: remote.artistName,
      albumName: remote.albumName,
      durationSeconds: remote.durationSeconds,
      status: DownloadStatus.queued,
      totalBytes: remote.fileSizeBytes,
      downloadUrl: remote.downloadUrl,
      urlExpiresAt: remote.expiresAt,
      format: remote.format,
      audioBitrate: remote.bitrateKbps,
      waveformSamples: remote.waveformSamples,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> saveDownload(DownloadItem item) async {
    await _localDataSource.saveDownload(item);
  }

  @override
  Future<void> updateDownload(DownloadItem item) async {
    await _localDataSource.updateDownload(item);
  }

  @override
  Future<DownloadItem?> getDownload(String trackId) async {
    return await _localDataSource.getDownload(trackId);
  }

  @override
  Future<List<DownloadItem>> getDownloadsByUser(String userId) async {
    return await _localDataSource.getDownloadsByUser(userId);
  }

  @override
  Future<List<DownloadItem>> getCompletedDownloads(String userId) async {
    return await _localDataSource.getCompletedDownloads(userId);
  }

  @override
  Future<void> removeDownload(String trackId, String userId) async {
    final item = await _localDataSource.getDownload(trackId);
    if (item != null) {
      await _localDataSource.updateDownload(
        item.copyWith(status: DownloadStatus.removing),
      );
    }

    // Delete disk files
    await _fileManager.deleteTrackFiles(userId, trackId);
    // Delete record from DB
    await _localDataSource.deleteDownload(trackId);
  }

  @override
  Future<int> getTotalDownloadedBytes(String userId) async {
    return await _localDataSource.getTotalDownloadedBytes(userId);
  }

  @override
  Future<void> runStartupCleanup(String userId) async {
    final items = await _localDataSource.getDownloadsByUser(userId);
    for (final item in items) {
      // 1. App restart recovery: Interrupted downloads transition to paused
      if (item.status == DownloadStatus.downloading) {
        await _localDataSource.updateDownload(
          item.copyWith(
            status: DownloadStatus.paused,
            updatedAt: DateTime.now(),
          ),
        );
      }
      // 2. Validate completed downloads still exist on disk
      else if (item.status == DownloadStatus.completed) {
        final isValid = await _fileManager.isFinalFileValid(item.localPath);
        if (!isValid) {
          await _localDataSource.updateDownload(
            item.copyWith(
              status: DownloadStatus.failed,
              error: 'File missing from device storage',
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    }

    // 3. Clean up orphaned .part files older than 24h
    await _fileManager.cleanupOrphanFiles();
  }
}
