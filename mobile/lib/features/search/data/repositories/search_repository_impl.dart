import 'package:hums_mobile/features/search/data/datasources/search_local_data_source.dart';
import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource _remoteDataSource;
  final SearchLocalDataSource _localDataSource;

  const SearchRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
  );

  @override
  Future<SearchResultEntity> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      return SearchResultEntity(query: '', category: category);
    }

    return await _remoteDataSource.search(
      query: cleanQ,
      category: category,
      limit: limit,
      skip: skip,
    );
  }

  @override
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 8,
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];
    return await _remoteDataSource.getSuggestions(
      query: cleanQ,
      limit: limit,
    );
  }

  @override
  Future<List<String>> getRecentSearches() async {
    return await _localDataSource.getRecentSearches();
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    await _localDataSource.saveRecentSearch(query);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    await _localDataSource.removeRecentSearch(query);
  }

  @override
  Future<void> clearRecentSearches() async {
    await _localDataSource.clearRecentSearches();
  }
}
