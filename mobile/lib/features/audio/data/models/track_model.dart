import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';

class AudioFileModel {
  final String id;
  final String trackId;
  final String objectKey;
  final String storageProvider;
  final String originalFilename;
  final String mimeType;
  final int fileSizeBytes;
  final DateTime createdAt;

  const AudioFileModel({
    required this.id,
    required this.trackId,
    required this.objectKey,
    required this.storageProvider,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.createdAt,
  });

  factory AudioFileModel.fromJson(Map<String, dynamic> json) {
    return AudioFileModel(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      objectKey: json['object_key'] as String,
      storageProvider: (json['storage_provider'] as String?) ?? 's3',
      originalFilename: (json['original_filename'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? 'audio/mpeg',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  AudioFileEntity toEntity() {
    return AudioFileEntity(
      id: id,
      trackId: trackId,
      objectKey: objectKey,
      storageProvider: storageProvider,
      originalFilename: originalFilename,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
    );
  }
}

class ProcessingJobModel {
  final String id;
  final String trackId;
  final String jobType;
  final String status;
  final int attempts;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProcessingJobModel({
    required this.id,
    required this.trackId,
    required this.jobType,
    required this.status,
    required this.attempts,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProcessingJobModel.fromJson(Map<String, dynamic> json) {
    return ProcessingJobModel(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      jobType: (json['job_type'] as String?) ?? 'AUDIO_TRANSCODE',
      status: (json['status'] as String?) ?? 'PENDING',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  ProcessingJobEntity toEntity() {
    return ProcessingJobEntity(
      id: id,
      trackId: trackId,
      jobType: jobType,
      status: status,
      attempts: attempts,
      errorMessage: errorMessage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class AudioRenditionModel {
  final String id;
  final String trackId;
  final String storageKey;
  final String storageProvider;
  final String format;
  final String codec;
  final int bitrateKbps;
  final int? sampleRate;
  final int? channels;
  final int? durationSeconds;
  final int fileSizeBytes;
  final DateTime createdAt;

  const AudioRenditionModel({
    required this.id,
    required this.trackId,
    required this.storageKey,
    required this.storageProvider,
    required this.format,
    required this.codec,
    required this.bitrateKbps,
    this.sampleRate,
    this.channels,
    this.durationSeconds,
    required this.fileSizeBytes,
    required this.createdAt,
  });

  factory AudioRenditionModel.fromJson(Map<String, dynamic> json) {
    return AudioRenditionModel(
      id: json['id'] as String,
      trackId: json['track_id'] as String,
      storageKey: json['storage_key'] as String,
      storageProvider: (json['storage_provider'] as String?) ?? 's3',
      format: (json['format'] as String?) ?? 'm4a',
      codec: (json['codec'] as String?) ?? 'aac',
      bitrateKbps: (json['bitrate_kbps'] as num?)?.toInt() ?? 128,
      sampleRate: (json['sample_rate'] as num?)?.toInt(),
      channels: (json['channels'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  AudioRenditionEntity toEntity() {
    return AudioRenditionEntity(
      id: id,
      trackId: trackId,
      storageKey: storageKey,
      storageProvider: storageProvider,
      format: format,
      codec: codec,
      bitrateKbps: bitrateKbps,
      sampleRate: sampleRate,
      channels: channels,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      createdAt: createdAt,
    );
  }
}

class TrackModel {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AudioFileModel> audioFiles;
  final List<AudioRenditionModel> renditions;
  final List<ProcessingJobModel> processingJobs;

  const TrackModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.artistName,
    this.albumName,
    this.genre,
    this.durationSeconds,
    this.waveformKey,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.audioFiles = const [],
    this.renditions = const [],
    this.processingJobs = const [],
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['audio_files'] as List<dynamic>? ?? [];
    final rawRenditions = json['renditions'] as List<dynamic>? ?? [];
    final rawJobs = json['processing_jobs'] as List<dynamic>? ?? [];

    return TrackModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      waveformKey: json['waveform_key'] as String?,
      status: (json['status'] as String?) ?? 'UPLOADED',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      audioFiles: rawFiles
          .map((f) => AudioFileModel.fromJson(f as Map<String, dynamic>))
          .toList(),
      renditions: rawRenditions
          .map((r) => AudioRenditionModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      processingJobs: rawJobs
          .map((j) => ProcessingJobModel.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }

  TrackEntity toEntity() {
    return TrackEntity(
      id: id,
      ownerId: ownerId,
      title: title,
      description: description,
      artistName: artistName,
      albumName: albumName,
      genre: genre,
      durationSeconds: durationSeconds,
      waveformKey: waveformKey,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      audioFiles: audioFiles.map((f) => f.toEntity()).toList(),
      renditions: renditions.map((r) => r.toEntity()).toList(),
      processingJobs: processingJobs.map((j) => j.toEntity()).toList(),
    );
  }
}

class TrackStatusModel {
  final String trackId;
  final String title;
  final String status;
  final int? durationSeconds;
  final String? waveformKey;
  final String? processingJobId;
  final String? processingStatus;
  final String? errorMessage;
  final DateTime updatedAt;

  const TrackStatusModel({
    required this.trackId,
    required this.title,
    required this.status,
    this.durationSeconds,
    this.waveformKey,
    this.processingJobId,
    this.processingStatus,
    this.errorMessage,
    required this.updatedAt,
  });

  factory TrackStatusModel.fromJson(Map<String, dynamic> json) {
    return TrackStatusModel(
      trackId: json['track_id'] as String,
      title: (json['title'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      waveformKey: json['waveform_key'] as String?,
      processingJobId: json['processing_job_id'] as String?,
      processingStatus: json['processing_status'] as String?,
      errorMessage: json['error_message'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  TrackStatusEntity toEntity() {
    return TrackStatusEntity(
      trackId: trackId,
      title: title,
      status: status,
      durationSeconds: durationSeconds,
      waveformKey: waveformKey,
      processingJobId: processingJobId,
      processingStatus: processingStatus,
      errorMessage: errorMessage,
      updatedAt: updatedAt,
    );
  }
}
