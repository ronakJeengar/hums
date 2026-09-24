import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

abstract class SearchRepository {
  /// Searches catalog items with query, category filter, and pagination.
  Future<SearchResultEntity> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  });
}
