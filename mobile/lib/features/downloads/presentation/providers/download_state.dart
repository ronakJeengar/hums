import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';

/// Immutable presentation state representing current downloads and storage usage.
class DownloadState {
  final Map<String, DownloadItem> items;
  final int totalStorageBytes;
  final bool isLoading;
  final String? activeUserId;

  const DownloadState({
    this.items = const {},
    this.totalStorageBytes = 0,
    this.isLoading = false,
    this.activeUserId,
  });

  /// All download items sorted by date descending.
  List<DownloadItem> get allItems => items.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Downloads currently downloading or waiting in queue.
  List<DownloadItem> get activeDownloads => items.values
      .where((item) => item.status.isActive)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Completed downloads available for offline playback.
  List<DownloadItem> get completedDownloads => items.values
      .where((item) => item.status == DownloadStatus.completed)
      .toList()
    ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));

  /// Downloads that failed.
  List<DownloadItem> get failedDownloads => items.values
      .where((item) => item.status == DownloadStatus.failed)
      .toList();

  /// Gets download status for a given track, defaulting to null if not downloaded.
  DownloadStatus? getStatus(String trackId) => items[trackId]?.status;

  /// Returns true if the track is downloaded and ready for offline playback.
  bool isDownloaded(String trackId) =>
      items[trackId]?.status == DownloadStatus.completed &&
      items[trackId]?.localPath != null;

  /// Returns true if the track is currently downloading or queued.
  bool isDownloadingOrQueued(String trackId) =>
      items[trackId]?.status.isActive ?? false;

  /// Returns download progress for a given track [0.0 to 1.0].
  double getProgress(String trackId) => items[trackId]?.progress ?? 0.0;

  DownloadState copyWith({
    Map<String, DownloadItem>? items,
    int? totalStorageBytes,
    bool? isLoading,
    String? activeUserId,
  }) {
    return DownloadState(
      items: items ?? this.items,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      isLoading: isLoading ?? this.isLoading,
      activeUserId: activeUserId ?? this.activeUserId,
    );
  }
}
