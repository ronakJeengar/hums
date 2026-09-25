import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:hums_mobile/features/history/data/datasources/history_local_data_source.dart';
import 'package:hums_mobile/features/history/data/datasources/history_remote_data_source.dart';
import 'package:hums_mobile/features/history/data/repositories/history_repository_impl.dart';
import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';
import 'package:hums_mobile/features/history/domain/repositories/history_repository.dart';
import 'package:hums_mobile/features/history/presentation/states/history_state.dart';

final historyLocalDataSourceProvider = Provider<HistoryLocalDataSource>((ref) {
  final ds = FileStorageHistoryLocalDataSourceImpl();
  return ds;
});

final historyRemoteDataSourceProvider =
    Provider<HistoryRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HistoryRemoteDataSourceImpl(apiClient);
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final remote = ref.watch(historyRemoteDataSourceProvider);
  final local = ref.watch(historyLocalDataSourceProvider);
  return HistoryRepositoryImpl(
    remote,
    local,
    () => ref.read(authNotifierProvider).user?.id ?? '',
  );
});

final listeningHistoryNotifierProvider =
    StateNotifierProvider<ListeningHistoryNotifier, ListeningHistoryState>(
        (ref) {
  final repo = ref.watch(historyRepositoryProvider);
  return ListeningHistoryNotifier(repo);
});

class ListeningHistoryNotifier extends StateNotifier<ListeningHistoryState> {
  final HistoryRepository _repository;

  ListeningHistoryNotifier(this._repository)
      : super(const ListeningHistoryState());

  Future<void> loadHistory({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      items: refresh ? [] : state.items,
    );

    try {
      final items = await _repository.getListeningHistory(skip: 0, limit: 50);
      final pendingCount = await _repository.getPendingOfflineEventCount();

      state = state.copyWith(
        isLoading: false,
        items: items,
        total: items.length,
        hasMore: items.length >= 50,
        pendingOfflineEventsCount: pendingCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load listening history: $e',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final moreItems = await _repository.getListeningHistory(
        skip: state.items.length,
        limit: 50,
      );

      final combined = List<ListeningHistoryItemEntity>.from(state.items)
        ..addAll(moreItems);

      state = state.copyWith(
        isLoadingMore: false,
        items: combined,
        total: combined.length,
        hasMore: moreItems.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> deleteItem(String trackId) async {
    final prevItems = state.items;
    final updated = prevItems.where((i) => i.trackId != trackId).toList();

    state = state.copyWith(items: updated, total: updated.length);

    try {
      await _repository.deleteHistoryItem(trackId);
    } catch (_) {
      // Revert on failure
      state = state.copyWith(items: prevItems, total: prevItems.length);
    }
  }

  Future<void> clearAll() async {
    final prevItems = state.items;
    state = state.copyWith(items: [], total: 0, hasMore: false);

    try {
      await _repository.clearHistory();
    } catch (_) {
      state = state.copyWith(items: prevItems, total: prevItems.length);
    }
  }

  Future<void> syncOfflineQueue() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);

    try {
      final synced = await _repository.syncOfflineEvents();
      final pendingCount = await _repository.getPendingOfflineEventCount();
      state = state.copyWith(
        isSyncing: false,
        pendingOfflineEventsCount: pendingCount,
      );
      if (synced > 0) {
        await loadHistory(refresh: true);
      }
    } catch (_) {
      state = state.copyWith(isSyncing: false);
    }
  }
}
