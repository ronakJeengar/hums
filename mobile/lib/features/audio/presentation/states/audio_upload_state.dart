import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';

part 'audio_upload_state.freezed.dart';

@freezed
class AudioUploadState with _$AudioUploadState {
  const factory AudioUploadState.initial() = _Initial;

  const factory AudioUploadState.fileSelected({
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
  }) = _FileSelected;

  const factory AudioUploadState.uploading({
    required String filePath,
    required String fileName,
    required int fileSizeBytes,
    required double progress,
  }) = _Uploading;

  const factory AudioUploadState.uploaded({
    required TrackEntity track,
  }) = _Uploaded;

  const factory AudioUploadState.failure(
    String message, {
    String? code,
    String? filePath,
    String? fileName,
    int? fileSizeBytes,
  }) = _Failure;
}

extension AudioUploadStateX on AudioUploadState {
  bool get isInitial => this is _Initial;
  bool get isFileSelected => this is _FileSelected;
  bool get isUploading => this is _Uploading;
  bool get isUploaded => this is _Uploaded;
  bool get isFailure => this is _Failure;
  bool get isBusy => isUploading;

  String? get selectedFilePath => whenOrNull(
        fileSelected: (path, _, _) => path,
        uploading: (path, _, _, _) => path,
        failure: (_, _, path, _, _) => path,
      );

  String? get selectedFileName => whenOrNull(
        fileSelected: (_, name, _) => name,
        uploading: (_, name, _, _) => name,
        failure: (_, _, _, name, _) => name,
      );

  int? get selectedFileSize => whenOrNull(
        fileSelected: (_, _, size) => size,
        uploading: (_, _, size, _) => size,
        failure: (_, _, _, _, size) => size,
      );

  double get uploadProgress =>
      whenOrNull(
        uploading: (_, _, _, progress) => progress,
      ) ??
      0.0;

  TrackEntity? get uploadedTrack => whenOrNull(
        uploaded: (track) => track,
      );

  String? get errorMessage => whenOrNull(
        failure: (message, _, _, _, _) => message,
      );
}
