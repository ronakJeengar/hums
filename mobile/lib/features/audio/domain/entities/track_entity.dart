class AudioFileEntity {
  final String id;
  final String trackId;
  final String objectKey;
  final String storageProvider;
  final String originalFilename;
  final String mimeType;
  final int fileSizeBytes;
  final DateTime createdAt;

  const AudioFileEntity({
    required this.id,
    required this.trackId,
    required this.objectKey,
    required this.storageProvider,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.createdAt,
  });
}

class ProcessingJobEntity {
  final String id;
  final String trackId;
  final String jobType;
  final String status;
  final int attempts;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProcessingJobEntity({
    required this.id,
    required this.trackId,
    required this.jobType,
    required this.status,
    required this.attempts,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });
}

class AudioRenditionEntity {
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

  const AudioRenditionEntity({
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
}

class TrackEntity {
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
  final List<AudioFileEntity> audioFiles;
  final List<AudioRenditionEntity> renditions;
  final List<ProcessingJobEntity> processingJobs;

  const TrackEntity({
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

  ProcessingJobEntity? get latestJob =>
      processingJobs.isNotEmpty ? processingJobs.first : null;
}

class TrackStatusEntity {
  final String trackId;
  final String title;
  final String status;
  final int? durationSeconds;
  final String? waveformKey;
  final String? processingJobId;
  final String? processingStatus;
  final String? errorMessage;
  final DateTime updatedAt;

  const TrackStatusEntity({
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
}

