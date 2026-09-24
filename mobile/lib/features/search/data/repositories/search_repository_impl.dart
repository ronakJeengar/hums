import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource _remoteDataSource;

  const SearchRepositoryImpl(this._remoteDataSource);

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
}
