import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

abstract class SearchRepository {
  /// Searches catalog items with query, category filter, and pagination.
  Future<SearchResultEntity> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  });

  /// Retrieves fast autocomplete suggestions.
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 8,
  });

  /// Loads locally saved recent searches.
  Future<List<String>> getRecentSearches();

  /// Adds a new query to recent searches.
  Future<void> saveRecentSearch(String query);

  /// Removes an individual query from recent searches.
  Future<void> removeRecentSearch(String query);

  /// Clears all recent searches.
  Future<void> clearRecentSearches();
}
