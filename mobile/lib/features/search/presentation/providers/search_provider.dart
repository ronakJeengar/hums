import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/data/repositories/search_repository_impl.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SearchRemoteDataSourceImpl(apiClient);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final remoteDataSource = ref.watch(searchRemoteDataSourceProvider);
  return SearchRepositoryImpl(remoteDataSource);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  Timer? _debounceTimer;
  int _generationId = 0;

  SearchNotifier(this._repository) : super(const SearchState());

  /// Handles user typing in search bar with 300ms debouncing and race-condition immunity.
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _generationId++;
      state = state.copyWith(
        query: query,
        status: SearchStatus.initial,
        results: SearchResultEntity.empty,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(query: query);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch();
    });
  }

  /// Changes the category filter chip and instantly re-runs search if query exists.
  void onCategoryChanged(SearchCategory newCategory) {
    if (state.category == newCategory) return;
    state = state.copyWith(category: newCategory);

    if (state.query.trim().isNotEmpty) {
      _debounceTimer?.cancel();
      _executeSearch();
    }
  }

  /// Immediate search trigger (e.g. keyboard submit action).
  void searchNow() {
    _debounceTimer?.cancel();
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  /// Clears the active search query and resets to initial prompt state.
  void clearSearch() {
    _debounceTimer?.cancel();
    _generationId++;
    state = SearchState(
      status: SearchStatus.initial,
      query: '',
      category: state.category,
      results: SearchResultEntity.empty,
    );
  }

  /// Retries search upon network or server error.
  void retry() {
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  Future<void> _executeSearch() async {
    final cleanQ = state.query.trim();
    if (cleanQ.isEmpty) {
      state = state.copyWith(
        status: SearchStatus.initial,
        results: SearchResultEntity.empty,
      );
      return;
    }

    final currentGen = ++_generationId;
    state = state.copyWith(status: SearchStatus.loading, errorMessage: null);

    try {
      final results = await _repository.search(
        query: cleanQ,
        category: state.category,
      );

      // Guard against race conditions: ignore response if a newer query was initiated
      if (currentGen != _generationId) return;

      state = state.copyWith(
        status: SearchStatus.loaded,
        results: results,
      );
    } catch (err) {
      if (currentGen != _generationId) return;

      state = state.copyWith(
        status: SearchStatus.error,
        errorMessage: err.toString(),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repository);
});
