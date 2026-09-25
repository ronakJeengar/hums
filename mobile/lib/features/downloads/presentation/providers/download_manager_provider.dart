import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/observability/telemetry_service.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_local_data_source.dart';
import 'package:hums_mobile/features/downloads/data/datasources/download_remote_data_source.dart';
import 'package:hums_mobile/features/downloads/data/repositories/download_repository_impl.dart';
import 'package:hums_mobile/features/downloads/data/services/download_file_manager.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_item.dart';
import 'package:hums_mobile/features/downloads/domain/entities/download_status.dart';
import 'package:hums_mobile/features/downloads/domain/repositories/download_repository.dart';
import 'package:hums_mobile/features/downloads/presentation/providers/download_state.dart';

// Providers
final downloadLocalDataSourceProvider = Provider<DownloadLocalDataSource>((ref) {
  final ds = FileStorageDownloadLocalDataSourceImpl();
  return ds;
});

final downloadFileManagerProvider = Provider<DownloadFileManager>((ref) {
  return DownloadFileManager();
});

final downloadRemoteDataSourceProvider = Provider<DownloadRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DownloadRemoteDataSourceImpl(apiClient);
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final remote = ref.watch(downloadRemoteDataSourceProvider);
  final local = ref.watch(downloadLocalDataSourceProvider);
  final fileManager = ref.watch(downloadFileManagerProvider);
  return DownloadRepositoryImpl(
    remoteDataSource: remote,
    localDataSource: local,
    fileManager: fileManager,
  );
});

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, DownloadState>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  final fileManager = ref.watch(downloadFileManagerProvider);
  final telemetry = ref.watch(telemetryServiceProvider);
  final authState = ref.watch(authNotifierProvider);

  final manager = DownloadManager(
    repository: repository,
    fileManager: fileManager,
    telemetry: telemetry,
    initialUserId: authState.user?.id,
  );

  return manager;
});

/// Central download manager coordinating queues, HTTP range downloads,
/// pause/resume, and atomic file finalization.
class DownloadManager extends StateNotifier<DownloadState> {
  final DownloadRepository _repository;
  final DownloadFileManager _fileManager;
  final TelemetryService? _telemetry;
  final Dio _downloadDio;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressUpdate = {};

  /// Maximum concurrent active downloads (FIFO queue).
  final int maxConcurrentDownloads;

  DownloadManager({
    required DownloadRepository repository,
    required DownloadFileManager fileManager,
    TelemetryService? telemetry,
    Dio? downloadDio,
    String? initialUserId,
    this.maxConcurrentDownloads = 2,
  })  : _repository = repository,
        _fileManager = fileManager,
        _telemetry = telemetry,
        _downloadDio = downloadDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
              ),
            ),
        super(DownloadState(activeUserId: initialUserId)) {
    if (initialUserId != null) {
      init(initialUserId);
    }
  }

  /// Initializes the download manager for the active user, running startup recovery.
  Future<void> init(String userId) async {
    state = state.copyWith(isLoading: true, activeUserId: userId);

    try {
      // 1. App restart recovery & orphan cleanup
      await _repository.runStartupCleanup(userId);

      // 2. Load user's downloads from persistent local DB
      final items = await _repository.getDownloadsByUser(userId);
      final itemMap = {for (final item in items) item.trackId: item};
      final totalStorage = await _fileManager.calculateUserStorageUsage(userId);

      state = state.copyWith(
        items: itemMap,
        totalStorageBytes: totalStorage,
        isLoading: false,
      );

      // 3. Process any queued items
      _processQueue();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Switches active user on login/logout (Account isolation Rule 43 & 44).
  Future<void> switchUser(String? newUserId) async {
    // Cancel all active network requests
    for (final token in _cancelTokens.values) {
      token.cancel('User session switched');
    }
    _cancelTokens.clear();

    if (newUserId == null) {
      state = const DownloadState();
      return;
    }

    await init(newUserId);
  }

  /// Enqueues a track for download.
  Future<void> enqueueDownload({
    required String trackId,
    String? title,
    String? artistName,
    String? albumName,
    int? durationSeconds,
    String? artworkUrl,
  }) async {
    final userId = state.activeUserId;
    if (userId == null) {
      throw StateError('Cannot download without an authenticated user');
    }

    // Check if already completed and valid on disk
    final existing = state.items[trackId];
    if (existing != null && existing.status == DownloadStatus.completed) {
      if (await _fileManager.isFinalFileValid(existing.localPath)) {
        return; // Already downloaded and valid
      }
    }

    // If currently downloading or queued, ignore duplicate request
    if (existing != null && existing.status.isActive) {
      return;
    }

    try {
      // 1. Authorize download with backend
      final authorizedItem = await _repository.getAuthorizedDownload(trackId, userId);
      final itemWithMeta = authorizedItem.copyWith(
        title: title ?? authorizedItem.title,
        artistName: artistName ?? authorizedItem.artistName,
        albumName: albumName ?? authorizedItem.albumName,
        durationSeconds: durationSeconds ?? authorizedItem.durationSeconds,
        artworkUrl: artworkUrl ?? authorizedItem.artworkUrl,
        status: DownloadStatus.queued,
        error: null,
      );

      // 2. Persist to DB and update state
      await _repository.saveDownload(itemWithMeta);
      _updateItemInState(itemWithMeta);

      _telemetry?.recordPlaybackEvent(
        eventType: 'download_started',
        trackType: 'track',
      );

      // 3. Trigger queue
      _processQueue();
    } catch (e) {
      // If authorization fails, save failed state
      final failedItem = (existing ??
              DownloadItem(
                id: 'dl_${trackId}_${DateTime.now().millisecondsSinceEpoch}',
                trackId: trackId,
                userId: userId,
                title: title ?? 'Audio Track',
                artistName: artistName,
                albumName: albumName,
                status: DownloadStatus.failed,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                error: e.toString(),
              ))
          .copyWith(
        status: DownloadStatus.failed,
        error: 'Failed to authorize download: $e',
        updatedAt: DateTime.now(),
      );

      await _repository.saveDownload(failedItem);
      _updateItemInState(failedItem);

      _telemetry?.recordPlaybackEvent(
        eventType: 'download_failed',
        errorCategory: 'authorization_failed',
      );
    }
  }

  /// Pauses an active download, preserving partial data (.part file).
  Future<void> pauseDownload(String trackId) async {
    final item = state.items[trackId];
    if (item == null || !item.status.isActive) return;

    // Cancel active HTTP request
    final token = _cancelTokens.remove(trackId);
    token?.cancel('User paused download');

    final updated = item.copyWith(
      status: DownloadStatus.paused,
      updatedAt: DateTime.now(),
    );

    await _repository.updateDownload(updated);
    _updateItemInState(updated);

    _telemetry?.recordPlaybackEvent(
      eventType: 'download_paused',
      trackType: 'track',
    );

    // Pick up next queued item
    _processQueue();
  }

  /// Resumes a paused or failed download.
  Future<void> resumeDownload(String trackId) async {
    final item = state.items[trackId];
    if (item == null || item.status == DownloadStatus.completed) return;

    final updated = item.copyWith(
      status: DownloadStatus.queued,
      error: null,
      updatedAt: DateTime.now(),
    );

    await _repository.updateDownload(updated);
    _updateItemInState(updated);

    _telemetry?.recordPlaybackEvent(
      eventType: 'download_resumed',
      trackType: 'track',
    );

    _processQueue();
  }

  /// Cancels a download and cleans up partial .part files.
  Future<void> cancelDownload(String trackId) async {
    final userId = state.activeUserId;
    if (userId == null) return;

    final token = _cancelTokens.remove(trackId);
    token?.cancel('User cancelled download');

    // Clean up partial file
    await _fileManager.deletePartialFile(userId, trackId);

    final item = state.items[trackId];
    if (item != null) {
      final updated = item.copyWith(
        status: DownloadStatus.cancelled,
        progress: 0.0,
        bytesDownloaded: 0,
        updatedAt: DateTime.now(),
      );
      await _repository.updateDownload(updated);
      _updateItemInState(updated);
    }

    _telemetry?.recordPlaybackEvent(
      eventType: 'download_cancelled',
      trackType: 'track',
    );

    _processQueue();
  }

  /// Retries a failed download.
  Future<void> retryDownload(String trackId) async {
    await resumeDownload(trackId);
  }

  /// Removes a completed or failed download and deletes its local file.
  Future<void> removeDownload(String trackId) async {
    final userId = state.activeUserId;
    if (userId == null) return;

    final token = _cancelTokens.remove(trackId);
    token?.cancel('Download removed');

    await _repository.removeDownload(trackId, userId);

    final updatedMap = Map<String, DownloadItem>.from(state.items)..remove(trackId);
    final totalStorage = await _fileManager.calculateUserStorageUsage(userId);

    state = state.copyWith(
      items: updatedMap,
      totalStorageBytes: totalStorage,
    );
  }

  /// Removes all downloads for current user and purges files.
  Future<void> clearAllDownloads() async {
    final userId = state.activeUserId;
    if (userId == null) return;

    for (final token in _cancelTokens.values) {
      token.cancel('Clearing all downloads');
    }
    _cancelTokens.clear();

    final allTrackIds = state.items.keys.toList();
    for (final trackId in allTrackIds) {
      await _repository.removeDownload(trackId, userId);
    }

    await _fileManager.cleanupOrphanFiles();

    state = state.copyWith(
      items: const {},
      totalStorageBytes: 0,
    );
  }

  /// Queues all tracks in a playlist for download.
  Future<void> downloadPlaylistTracks(List<DownloadItem> trackItems) async {
    for (final item in trackItems) {
      await enqueueDownload(
        trackId: item.trackId,
        title: item.title,
        artistName: item.artistName,
        albumName: item.albumName,
        durationSeconds: item.durationSeconds,
        artworkUrl: item.artworkUrl,
      );
    }
  }

  /// Processes the FIFO queue respecting maxConcurrentDownloads.
  void _processQueue() {
    final activeCount =
        state.items.values.where((i) => i.status == DownloadStatus.downloading).length;
    final availableSlots = maxConcurrentDownloads - activeCount;
    if (availableSlots <= 0) return;

    final queuedItems = state.items.values
        .where((i) => i.status == DownloadStatus.queued)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final toStart = queuedItems.take(availableSlots);
    for (final item in toStart) {
      _executeDownload(item);
    }
  }

  /// Executes file download over network with Range resumption support.
  Future<void> _executeDownload(DownloadItem initialItem) async {
    final userId = state.activeUserId;
    if (userId == null) return;

    var currentItem = initialItem;
    final trackId = currentItem.trackId;

    // Check if download URL expired or absent; refresh if needed
    if (currentItem.downloadUrl == null || currentItem.isUrlExpired) {
      try {
        currentItem = await _repository.getAuthorizedDownload(trackId, userId);
      } catch (e) {
        _handleDownloadFailure(currentItem, 'Expired download authorization: $e');
        return;
      }
    }

    // Transition to downloading
    currentItem = currentItem.copyWith(
      status: DownloadStatus.downloading,
      updatedAt: DateTime.now(),
    );
    _updateItemInState(currentItem);
    await _repository.updateDownload(currentItem);

    final cancelToken = CancelToken();
    _cancelTokens[trackId] = cancelToken;

    IOSink? sink;
    try {
      final partFile = await _fileManager.getPartialFile(userId, trackId);
      final existingBytes = await _fileManager.getPartialFileLength(userId, trackId);

      final headers = <String, dynamic>{};
      if (existingBytes > 0) {
        headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await _downloadDio.get<ResponseBody>(
        currentItem.downloadUrl!,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
        cancelToken: cancelToken,
      );

      final statusCode = response.statusCode ?? 200;
      final isResume = statusCode == 206;

      // If server does not support resume (HTTP 200), start from zero
      final actualStartBytes = isResume ? existingBytes : 0;
      sink = partFile.openWrite(
        mode: isResume ? FileMode.append : FileMode.write,
      );

      // Determine total bytes
      int totalExpected = currentItem.totalBytes;
      final contentLengthHeader = response.headers.value(Headers.contentLengthHeader);
      if (contentLengthHeader != null) {
        final incomingLength = int.tryParse(contentLengthHeader) ?? 0;
        totalExpected = actualStartBytes + incomingLength;
      }

      int receivedBytes = actualStartBytes;

      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) break;
        sink.add(chunk);
        receivedBytes += chunk.length;

        // Throttle progress updates to avoid dirty frame cascades (performance principle)
        _throttleProgressUpdate(
          trackId: trackId,
          received: receivedBytes,
          total: totalExpected,
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (cancelToken.isCancelled) return;

      // 4. Validate and finalize atomically
      final finalizedFile = await _fileManager.finalizeDownload(
        userId: userId,
        trackId: trackId,
        format: currentItem.format,
        expectedSizeBytes: totalExpected,
      );

      final completedItem = currentItem.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        bytesDownloaded: receivedBytes,
        totalBytes: totalExpected,
        localPath: finalizedFile.path,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        error: null,
      );

      await _repository.updateDownload(completedItem);
      _updateItemInState(completedItem);

      final totalStorage = await _fileManager.calculateUserStorageUsage(userId);
      state = state.copyWith(totalStorageBytes: totalStorage);

      _telemetry?.recordPlaybackEvent(
        eventType: 'download_completed',
        trackType: 'track',
      );
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      if (cancelToken.isCancelled) {
        // Cancelled/paused by user intentionally
        return;
      }

      _handleDownloadFailure(currentItem, e.toString());
    } finally {
      _cancelTokens.remove(trackId);
      _processQueue();
    }
  }

  void _throttleProgressUpdate({
    required String trackId,
    required int received,
    required int total,
  }) {
    final now = DateTime.now();
    final last = _lastProgressUpdate[trackId];
    if (last != null && now.difference(last).inMilliseconds < 250) {
      return;
    }
    _lastProgressUpdate[trackId] = now;

    final item = state.items[trackId];
    if (item == null || item.status != DownloadStatus.downloading) return;

    final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    final updated = item.copyWith(
      bytesDownloaded: received,
      totalBytes: total > 0 ? total : item.totalBytes,
      progress: progress,
    );

    _updateItemInState(updated);
  }

  Future<void> _handleDownloadFailure(DownloadItem item, String errorMsg) async {
    final failedItem = item.copyWith(
      status: DownloadStatus.failed,
      error: errorMsg,
      updatedAt: DateTime.now(),
    );

    await _repository.updateDownload(failedItem);
    _updateItemInState(failedItem);

    _telemetry?.recordPlaybackEvent(
      eventType: 'download_failed',
      errorCategory: 'network_or_storage_error',
    );
  }

  void _updateItemInState(DownloadItem item) {
    final updatedMap = Map<String, DownloadItem>.from(state.items);
    updatedMap[item.trackId] = item;
    state = state.copyWith(items: updatedMap);
  }
}
