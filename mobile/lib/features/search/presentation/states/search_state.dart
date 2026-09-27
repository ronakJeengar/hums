import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

enum SearchStatus {
  initial,
  loading,
  loaded,
  error,
}

class SearchState {
  final SearchStatus status;
  final String query;
  final SearchCategory category;
  final SearchResultEntity results;
  final List<String> recentSearches;
  final List<String> suggestions;
  final bool isSuggestionsLoading;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.category = SearchCategory.all,
    this.results = SearchResultEntity.empty,
    this.recentSearches = const [],
    this.suggestions = const [],
    this.isSuggestionsLoading = false,
    this.errorMessage,
  });

  bool get isInitial => status == SearchStatus.initial;
  bool get isLoading => status == SearchStatus.loading;
  bool get isLoaded => status == SearchStatus.loaded;
  bool get isError => status == SearchStatus.error;

  bool get hasResults => isLoaded && results.isNotEmpty;
  bool get isEmptyResults => isLoaded && query.trim().isNotEmpty && results.isEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchCategory? category,
    SearchResultEntity? results,
    List<String>? recentSearches,
    List<String>? suggestions,
    bool? isSuggestionsLoading,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      category: category ?? this.category,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
      isSuggestionsLoading: isSuggestionsLoading ?? this.isSuggestionsLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
