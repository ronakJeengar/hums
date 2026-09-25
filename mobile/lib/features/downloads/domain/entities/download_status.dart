/// Represents the discrete lifecycle states of an offline download.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  removing;

  bool get isQueued => this == DownloadStatus.queued;
  bool get isDownloading => this == DownloadStatus.downloading;
  bool get isPaused => this == DownloadStatus.paused;
  bool get isCompleted => this == DownloadStatus.completed;
  bool get isFailed => this == DownloadStatus.failed;
  bool get isCancelled => this == DownloadStatus.cancelled;
  bool get isRemoving => this == DownloadStatus.removing;

  bool get isActive => isQueued || isDownloading;
}
