class QueueItem {
  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationSeconds;
  final String? waveformKey;
  final String status;

  const QueueItem({
    required this.trackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationSeconds,
    this.waveformKey,
    this.status = 'READY',
  });

  bool get isPlayable => status.toUpperCase() == 'READY';
}

class PlayerQueue {
  final String? playlistId;
  final String? playlistName;
  final List<QueueItem> items;
  final int currentIndex;

  const PlayerQueue({
    this.playlistId,
    this.playlistName,
    required this.items,
    this.currentIndex = 0,
  });

  QueueItem? get currentItem =>
      (currentIndex >= 0 && currentIndex < items.length) ? items[currentIndex] : null;

  bool get hasNext {
    for (int i = currentIndex + 1; i < items.length; i++) {
      if (items[i].isPlayable) return true;
    }
    return false;
  }

  bool get hasPrevious {
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
  }) {
    return PlayerQueue(
      playlistId: playlistId ?? this.playlistId,
      playlistName: playlistName ?? this.playlistName,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
