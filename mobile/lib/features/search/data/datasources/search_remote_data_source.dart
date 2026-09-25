import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/search/data/models/search_result_model.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

abstract class SearchRemoteDataSource {
  Future<SearchResultModel> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  });

  Future<List<String>> getSuggestions({
    required String query,
    int limit = 8,
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final ApiClient _apiClient;

  const SearchRemoteDataSourceImpl(this._apiClient);

  @override
  Future<SearchResultModel> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.search,
      queryParameters: {
        'q': query,
        'type': category.apiValue,
        'limit': limit,
        'skip': skip,
      },
    );

    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return SearchResultModel.fromJson(data, category: category);
  }

  @override
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 8,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.searchSuggestions,
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );

    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    final list = data['suggestions'] as List<dynamic>?;
    return list?.map((e) => e.toString()).toList() ?? [];
  }
}
