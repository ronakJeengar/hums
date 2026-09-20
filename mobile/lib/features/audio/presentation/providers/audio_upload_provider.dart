import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio/data/datasources/audio_remote_data_source.dart';
import 'package:hums_mobile/features/audio/data/repositories/audio_repository_impl.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';
import 'package:hums_mobile/features/audio/presentation/states/audio_upload_state.dart';

final audioRemoteDataSourceProvider = Provider<AudioRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AudioRemoteDataSourceImpl(apiClient);
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  final remoteDataSource = ref.watch(audioRemoteDataSourceProvider);
  return AudioRepositoryImpl(remoteDataSource);
});

final audioUploadNotifierProvider =
    StateNotifierProvider<AudioUploadNotifier, AudioUploadState>((ref) {
  final repository = ref.watch(audioRepositoryProvider);
  return AudioUploadNotifier(repository);
});

final userTracksProvider =
    FutureProvider.autoDispose<List<TrackEntity>>((ref) async {
  final repository = ref.watch(audioRepositoryProvider);
  return repository.listTracks();
});

final trackStatusProvider =
    FutureProvider.autoDispose.family<TrackStatusEntity, String>(
  (ref, trackId) async {
    final repository = ref.watch(audioRepositoryProvider);
    return repository.getTrackStatus(trackId);
  },
);

class AudioUploadNotifier extends StateNotifier<AudioUploadState> {
  final AudioRepository _repository;

  static const List<String> allowedExtensions = [
    'mp3',
    'wav',
    'flac',
    'm4a',
    'aac',
    'ogg',
  ];
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100MB

  AudioUploadNotifier(this._repository)
      : super(const AudioUploadState.initial());

  void selectFile({
    required String path,
    required String name,
    required int size,
  }) {
    final ext = name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      state = AudioUploadState.failure(
        'Unsupported file format (.$ext). Allowed: ${allowedExtensions.join(", ")}',
        code: 'INVALID_AUDIO_FORMAT',
        filePath: path,
        fileName: name,
        fileSizeBytes: size,
      );
      return;
    }

    if (size > maxFileSizeBytes) {
      state = AudioUploadState.failure(
        'File exceeds 100MB size limit (${(size / (1024 * 1024)).toStringAsFixed(1)}MB).',
        code: 'AUDIO_TOO_LARGE',
        filePath: path,
        fileName: name,
        fileSizeBytes: size,
      );
      return;
    }

    state = AudioUploadState.fileSelected(
      filePath: path,
      fileName: name,
      fileSizeBytes: size,
    );
  }

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          selectFile(
            path: file.path!,
            name: file.name,
            size: file.size,
          );
        }
      }
    } catch (e) {
      state = AudioUploadState.failure('Failed to select file: $e');
    }
  }

  Future<bool> uploadAudio({
    required String title,
    String? description,
    String? artistName,
    String? albumName,
    String? genre,
  }) async {
    final filePath = state.selectedFilePath;
    final fileName = state.selectedFileName;
    final fileSizeBytes = state.selectedFileSize;

    if (filePath == null || fileName == null || fileSizeBytes == null) {
      state = const AudioUploadState.failure(
        'Please select an audio file first.',
        code: 'NO_FILE_SELECTED',
      );
      return false;
    }

    if (title.trim().isEmpty) {
      state = AudioUploadState.failure(
        'Track title is required.',
        code: 'INVALID_TRACK_DATA',
        filePath: filePath,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
      return false;
    }

    state = AudioUploadState.uploading(
      filePath: filePath,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      progress: 0.0,
    );

    try {
      final track = await _repository.uploadAudio(
        filePath: filePath,
        title: title.trim(),
        description: description?.trim(),
        artistName: artistName?.trim(),
        albumName: albumName?.trim(),
        genre: genre?.trim(),
        onProgress: (progress) {
          if (mounted && state.isUploading) {
            state = AudioUploadState.uploading(
              filePath: filePath,
              fileName: fileName,
              fileSizeBytes: fileSizeBytes,
              progress: progress,
            );
          }
        },
      );

      state = AudioUploadState.uploaded(track: track);
      return true;
    } on ApiException catch (e) {
      state = AudioUploadState.failure(
        e.message,
        code: e.code,
        filePath: filePath,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
      return false;
    } catch (e) {
      state = AudioUploadState.failure(
        e.toString(),
        filePath: filePath,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
      );
      return false;
    }
  }

  void reset() {
    state = const AudioUploadState.initial();
  }
}
