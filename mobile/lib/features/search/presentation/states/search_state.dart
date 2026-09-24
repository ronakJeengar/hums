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
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.category = SearchCategory.all,
    this.results = SearchResultEntity.empty,
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
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      category: category ?? this.category,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
