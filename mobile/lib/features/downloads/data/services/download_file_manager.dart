import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages physical filesystem storage, partial download files (.part),
/// atomic finalization, and space calculations for offline audio files.
class DownloadFileManager {
  final Directory? _baseDirOverride;

  DownloadFileManager({Directory? baseDirectory}) : _baseDirOverride = baseDirectory;

  /// Returns the base directory for downloads.
  Future<Directory> getBaseDirectory() async {
    if (_baseDirOverride != null) {
      return _baseDirOverride;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(appDocDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Returns the isolated directory for a specific user's track.
  Future<Directory> getTrackDirectory(String userId, String trackId) async {
    final base = await getBaseDirectory();
    final trackDir = Directory(p.join(base.path, userId, trackId));
    if (!await trackDir.exists()) {
      await trackDir.create(recursive: true);
    }
    return trackDir;
  }

  /// Returns the temporary partial file path during downloading.
  Future<File> getPartialFile(String userId, String trackId) async {
    final trackDir = await getTrackDirectory(userId, trackId);
    return File(p.join(trackDir.path, 'audio.part'));
  }

  /// Returns the finalized completed audio file path.
  Future<File> getFinalFile(String userId, String trackId, String format) async {
    final trackDir = await getTrackDirectory(userId, trackId);
    final ext = format.startsWith('.') ? format.substring(1) : format;
    return File(p.join(trackDir.path, 'audio.$ext'));
  }

  /// Checks how many bytes have already been downloaded to .part file for resume.
  Future<int> getPartialFileLength(String userId, String trackId) async {
    final partFile = await getPartialFile(userId, trackId);
    if (await partFile.exists()) {
      return await partFile.length();
    }
    return 0;
  }

  /// Atomically finalizes a completed download from .part to final audio file after validation.
  Future<File> finalizeDownload({
    required String userId,
    required String trackId,
    required String format,
    required int expectedSizeBytes,
  }) async {
    final partFile = await getPartialFile(userId, trackId);
    if (!await partFile.exists()) {
      throw const FileSystemException('Partial download file does not exist');
    }

    final currentLength = await partFile.length();
    if (currentLength == 0) {
      await partFile.delete();
      throw const FileSystemException('Downloaded file is empty (0 bytes)');
    }

    // Sanity validation: If expectedSizeBytes > 0, verify partial file is at least 90% of expected
    if (expectedSizeBytes > 0 && currentLength < (expectedSizeBytes * 0.90)) {
      throw FileSystemException(
        'Downloaded file size ($currentLength bytes) is less than expected ($expectedSizeBytes bytes)',
      );
    }

    final finalFile = await getFinalFile(userId, trackId, format);
    // If a previous final file exists, remove it before atomic rename
    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    // Atomic move / rename
    final completedFile = await partFile.rename(finalFile.path);
    return completedFile;
  }

  /// Deletes all files and the directory for a specific track.
  Future<void> deleteTrackFiles(String userId, String trackId) async {
    final trackDir = await getTrackDirectory(userId, trackId);
    if (await trackDir.exists()) {
      await trackDir.delete(recursive: true);
    }
  }

  /// Deletes only the partial .part file if present (e.g. on cancel).
  Future<void> deletePartialFile(String userId, String trackId) async {
    final partFile = await getPartialFile(userId, trackId);
    if (await partFile.exists()) {
      await partFile.delete();
    }
  }

  /// Validates whether a completed download file exists and is readable on disk.
  Future<bool> isFinalFileValid(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return false;
    final file = File(localPath);
    if (!await file.exists()) return false;
    final len = await file.length();
    return len > 0;
  }

  /// Calculates total size in bytes of all completed downloads for a user.
  Future<int> calculateUserStorageUsage(String userId) async {
    final base = await getBaseDirectory();
    final userDir = Directory(p.join(base.path, userId));
    if (!await userDir.exists()) return 0;

    int totalBytes = 0;
    await for (final entity in userDir.list(recursive: true, followLinks: false)) {
      if (entity is File && !entity.path.endsWith('.part')) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes;
  }

  /// Cleans up orphaned .part files or empty folders on startup.
  Future<void> cleanupOrphanFiles() async {
    try {
      final base = await getBaseDirectory();
      if (!await base.exists()) return;

      final now = DateTime.now();
      await for (final entity in base.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.part')) {
          final stat = await entity.stat();
          // Remove .part files older than 24 hours
          if (now.difference(stat.modified).inHours >= 24) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // Defensive fail-open
    }
  }
}
