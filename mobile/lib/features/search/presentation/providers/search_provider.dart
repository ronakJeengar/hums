import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/search/data/datasources/search_local_data_source.dart';
import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/data/repositories/search_repository_impl.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SearchRemoteDataSourceImpl(apiClient);
});

final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  final storage = ref.watch(authStorageProvider);
  return SearchLocalDataSourceImpl(storage);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final remoteDataSource = ref.watch(searchRemoteDataSourceProvider);
  final localDataSource = ref.watch(searchLocalDataSourceProvider);
  return SearchRepositoryImpl(remoteDataSource, localDataSource);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repository;
  Timer? _debounceTimer;
  Timer? _suggestionTimer;
  int _generationId = 0;
  int _suggestionGenId = 0;

  SearchNotifier(this._repository) : super(const SearchState()) {
    loadRecentSearches();
  }

  Future<void> loadRecentSearches() async {
    try {
      final recents = await _repository.getRecentSearches();
      state = state.copyWith(recentSearches: recents);
    } catch (_) {}
  }

  /// Handles user typing in search bar with 300ms debouncing and race-condition immunity.
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();

    if (query.trim().isEmpty) {
      _generationId++;
      _suggestionGenId++;
      state = state.copyWith(
        query: query,
        status: SearchStatus.initial,
        results: SearchResultEntity.empty,
        suggestions: [],
        isSuggestionsLoading: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(query: query);

    // Fast suggestion fetch (150ms debounce)
    _suggestionTimer = Timer(const Duration(milliseconds: 150), () {
      _fetchSuggestions(query.trim());
    });

    // Full search fetch (300ms debounce)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch();
    });
  }

  Future<void> _fetchSuggestions(String cleanQ) async {
    if (cleanQ.isEmpty) return;
    final currentGen = ++_suggestionGenId;
    state = state.copyWith(isSuggestionsLoading: true);

    try {
      final suggestions = await _repository.getSuggestions(query: cleanQ);
      if (currentGen != _suggestionGenId) return;
      state = state.copyWith(
        suggestions: suggestions,
        isSuggestionsLoading: false,
      );
    } catch (_) {
      if (currentGen != _suggestionGenId) return;
      state = state.copyWith(isSuggestionsLoading: false);
    }
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
    _suggestionTimer?.cancel();
    if (state.query.trim().isNotEmpty) {
      _executeSearch();
    }
  }

  /// Selects a suggestion and immediately executes search.
  void selectSuggestion(String suggestion) {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    state = state.copyWith(query: suggestion, suggestions: []);
    _executeSearch();
  }

  /// Selects a recent search item and re-runs search.
  void selectRecentSearch(String query) {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    state = state.copyWith(query: query, suggestions: []);
    _executeSearch();
  }

  /// Removes an individual query from recent searches.
  Future<void> removeRecentSearch(String query) async {
    await _repository.removeRecentSearch(query);
    final recents = await _repository.getRecentSearches();
    state = state.copyWith(recentSearches: recents);
  }

  /// Clears all recent searches.
  Future<void> clearRecentSearches() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }

  /// Clears the active search query and resets to initial prompt state.
  void clearSearch() {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    _generationId++;
    _suggestionGenId++;
    state = SearchState(
      status: SearchStatus.initial,
      query: '',
      category: state.category,
      results: SearchResultEntity.empty,
      recentSearches: state.recentSearches,
      suggestions: [],
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
        suggestions: [],
      );
      return;
    }

    final currentGen = ++_generationId;
    state = state.copyWith(
      status: SearchStatus.loading,
      errorMessage: null,
      suggestions: [],
    );

    try {
      final results = await _repository.search(
        query: cleanQ,
        category: state.category,
      );

      if (currentGen != _generationId) return;

      // Save to local recent searches on success
      await _repository.saveRecentSearch(cleanQ);
      final updatedRecents = await _repository.getRecentSearches();

      state = state.copyWith(
        status: SearchStatus.loaded,
        results: results,
        recentSearches: updatedRecents,
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
    _suggestionTimer?.cancel();
    super.dispose();
  }
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repository);
});
