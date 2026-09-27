import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';

class ListeningHistoryState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSyncing;
  final List<ListeningHistoryItemEntity> items;
  final int total;
  final bool hasMore;
  final String? errorMessage;
  final int pendingOfflineEventsCount;

  const ListeningHistoryState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSyncing = false,
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.errorMessage,
    this.pendingOfflineEventsCount = 0,
  });

  ListeningHistoryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSyncing,
    List<ListeningHistoryItemEntity>? items,
    int? total,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    int? pendingOfflineEventsCount,
  }) {
    return ListeningHistoryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSyncing: isSyncing ?? this.isSyncing,
      items: items ?? this.items,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingOfflineEventsCount:
          pendingOfflineEventsCount ?? this.pendingOfflineEventsCount,
    );
  }

  bool get isEmpty => !isLoading && items.isEmpty;
  bool get hasError => errorMessage != null;

  /// Returns items grouped by chronological bucket: "Today", "Yesterday", "Earlier this week", "Older".
  Map<String, List<ListeningHistoryItemEntity>> get groupedItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<ListeningHistoryItemEntity>>{};

    for (final item in items) {
      final playedDate = item.lastPlayedAt.toLocal();
      final itemDay = DateTime(playedDate.year, playedDate.month, playedDate.day);

      final String groupKey;
      if (itemDay == today) {
        groupKey = 'Today';
      } else if (itemDay == yesterday) {
        groupKey = 'Yesterday';
      } else if (itemDay.isAfter(weekAgo)) {
        groupKey = 'Earlier this week';
      } else {
        groupKey = 'Older';
      }

      groups.putIfAbsent(groupKey, () => []).add(item);
    }

    return groups;
  }
}
