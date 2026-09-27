import 'package:hums_mobile/core/utils/uuid_utils.dart';

enum PlaybackRepeatMode {
  off,
  repeatQueue,
  repeatTrack,
}

class QueueItemSource {
  static const String manual = 'manual';
  static const String playlist = 'playlist';
  static const String album = 'album';
  static const String liked = 'liked';
  static const String search = 'search';
  static const String recommendation = 'recommendation';
  static const String smartQueue = 'smart_queue';
  static const String genreMatch = 'genre_match';
  static const String artistMatch = 'artist_match';
}

class QueueItem {
  final String queueItemId;
  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;
  final String source;
  final DateTime addedAt;

  QueueItem({
    String? queueItemId,
    required this.trackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.waveformKey,
    this.status = 'READY',
    this.source = 'playlist',
    DateTime? addedAt,
  })  : queueItemId = queueItemId ?? '${trackId}_${UuidUtils.generate()}',
        addedAt = addedAt ?? DateTime.now();

  bool get isPlayable => status.toUpperCase() == 'READY';

  QueueItem copyWith({
    String? queueItemId,
    String? trackId,
    String? title,
    String? artistName,
    String? albumName,
    int? durationSeconds,
    String? waveformKey,
    String? status,
    String? source,
    DateTime? addedAt,
  }) {
    return QueueItem(
      queueItemId: queueItemId ?? this.queueItemId,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      waveformKey: waveformKey ?? this.waveformKey,
      status: status ?? this.status,
      source: source ?? this.source,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      queueItemId: json['queue_item_id'] as String?,
      trackId: json['id'] as String? ?? json['track_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      waveformKey: json['waveform_key'] as String?,
      status: json['status'] as String? ?? 'READY',
      source: json['source'] as String? ?? 'smart_queue',
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'queue_item_id': queueItemId,
        'id': trackId,
        'title': title,
        'artist_name': artistName,
        'album_name': albumName,
        'duration_seconds': durationSeconds,
        'waveform_key': waveformKey,
        'status': status,
        'source': source,
        'added_at': addedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueItem &&
          runtimeType == other.runtimeType &&
          queueItemId == other.queueItemId;

  @override
  int get hashCode => queueItemId.hashCode;
}

class PlayerQueue {
  final String? playlistId;
  final String? playlistName;
  final List<QueueItem> items;
  final int currentIndex;

  final List<QueueItem> manualItems;
  final List<QueueItem> upNextItems;
  final List<QueueItem> smartItems;
  final List<QueueItem> originalUpNextItems;
  final List<QueueItem> historyItems;
  final bool isShuffled;
  final PlaybackRepeatMode repeatMode;

  const PlayerQueue({
    this.playlistId,
    this.playlistName,
    required this.items,
    this.currentIndex = 0,
    this.manualItems = const [],
    this.upNextItems = const [],
    this.smartItems = const [],
    this.originalUpNextItems = const [],
    this.historyItems = const [],
    this.isShuffled = false,
    this.repeatMode = PlaybackRepeatMode.off,
  });

  QueueItem? get currentItem {
    if (currentIndex >= 0 && currentIndex < items.length) {
      return items[currentIndex];
    }
    return null;
  }

  /// Combined upcoming items prioritized in playback order:
  /// 1. Manual Queue (explicitly added by user)
  /// 2. Up Next (from active playlist / album / collection)
  /// 3. Smart Queue (auto-generated recommendation candidates)
  List<QueueItem> get allUpcomingItems => [
        ...manualItems,
        ...upNextItems,
        ...smartItems,
      ];

  int get upcomingCount => allUpcomingItems.length;

  bool get hasNext {
    if (repeatMode == PlaybackRepeatMode.repeatTrack) return true;
    if (allUpcomingItems.any((item) => item.isPlayable)) return true;
    if (repeatMode == PlaybackRepeatMode.repeatQueue && (historyItems.isNotEmpty || items.isNotEmpty)) {
      return true;
    }
    // Fallback check against legacy items list
    for (int i = currentIndex + 1; i < items.length; i++) {
      if (items[i].isPlayable) return true;
    }
    return false;
  }

  bool get hasPrevious {
    if (historyItems.isNotEmpty) return true;
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (items[i].isPlayable) return true;
    }
    return false;
  }

  int? get nextIndex {
    for (int i = currentIndex + 1; i < items.length; i++) {
      if (items[i].isPlayable) return i;
    }
    return null;
  }

  int? get previousIndex {
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (items[i].isPlayable) return i;
    }
    return null;
  }

  PlayerQueue copyWith({
    String? playlistId,
    String? playlistName,
    List<QueueItem>? items,
    int? currentIndex,
    List<QueueItem>? manualItems,
    List<QueueItem>? upNextItems,
    List<QueueItem>? smartItems,
    List<QueueItem>? originalUpNextItems,
    List<QueueItem>? historyItems,
    bool? isShuffled,
    PlaybackRepeatMode? repeatMode,
  }) {
    return PlayerQueue(
      playlistId: playlistId ?? this.playlistId,
      playlistName: playlistName ?? this.playlistName,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      manualItems: manualItems ?? this.manualItems,
      upNextItems: upNextItems ?? this.upNextItems,
      smartItems: smartItems ?? this.smartItems,
      originalUpNextItems: originalUpNextItems ?? this.originalUpNextItems,
      historyItems: historyItems ?? this.historyItems,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}
