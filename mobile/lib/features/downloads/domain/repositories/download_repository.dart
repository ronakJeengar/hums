import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';

/// Abstract contract for offline download persistence and operations.
abstract class DownloadRepository {
  /// Fetches an authorized download URL and metadata for a track from backend.
  Future<DownloadItem> getAuthorizedDownload(String trackId, String userId);

  /// Saves or creates a download record in local storage.
  Future<void> saveDownload(DownloadItem item);

  /// Updates an existing download record.
  Future<void> updateDownload(DownloadItem item);

  /// Retrieves a download record by track ID.
  Future<DownloadItem?> getDownload(String trackId);

  /// Retrieves all downloads for a user.
  Future<List<DownloadItem>> getDownloadsByUser(String userId);

  /// Retrieves completed downloads available for offline playback for a user.
  Future<List<DownloadItem>> getCompletedDownloads(String userId);

  /// Deletes a download record and its local files.
  Future<void> removeDownload(String trackId, String userId);

  /// Calculates total size in bytes of all completed downloads for a user.
  Future<int> getTotalDownloadedBytes(String userId);

  /// Cleans up orphaned or invalid download files on app startup.
  Future<void> runStartupCleanup(String userId);
}
