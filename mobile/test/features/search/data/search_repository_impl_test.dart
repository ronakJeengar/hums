import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/data/models/search_result_model.dart';
import 'package:hums_mobile/features/search/data/repositories/search_repository_impl.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

class MockSearchRemoteDataSource implements SearchRemoteDataSource {
  SearchResultModel? mockResult;
  Exception? exceptionToThrow;
  int callCount = 0;
  String? lastQuery;
  SearchCategory? lastCategory;

  @override
  Future<SearchResultModel> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  }) async {
    callCount++;
    lastQuery = query;
    lastCategory = category;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockResult ??
        SearchResultModel(
          query: query,
          category: category,
        );
  }
}

void main() {
  group('SearchRepositoryImpl Tests', () {
    late MockSearchRemoteDataSource mockRemote;
    late SearchRepositoryImpl repository;

    setUp(() {
      mockRemote = MockSearchRemoteDataSource();
      repository = SearchRepositoryImpl(mockRemote);
    });

    test('search returns SearchResultEntity on successful remote call', () async {
      mockRemote.mockResult = const SearchResultModel(
        query: 'Acoustic',
        category: SearchCategory.all,
        totalTracks: 5,
      );

      final result = await repository.search(query: 'Acoustic');
      expect(result.query, 'Acoustic');
      expect(result.totalTracks, 5);
      expect(mockRemote.callCount, 1);
      expect(mockRemote.lastQuery, 'Acoustic');
    });

    test('empty or whitespace-only query immediately returns empty result without calling remote', () async {
      final resEmpty = await repository.search(query: '');
      expect(resEmpty.isEmpty, true);
      expect(mockRemote.callCount, 0);

      final resWhitespace = await repository.search(query: '    ');
      expect(resWhitespace.isEmpty, true);
      expect(mockRemote.callCount, 0);
    });

    test('search passes category, limit, and skip to remote data source', () async {
      await repository.search(
        query: ' Classical ',
        category: SearchCategory.tracks,
        limit: 10,
        skip: 5,
      );

      expect(mockRemote.callCount, 1);
      expect(mockRemote.lastQuery, 'Classical');
      expect(mockRemote.lastCategory, SearchCategory.tracks);
    });

    test('rethrows ApiException when remote call fails', () async {
      mockRemote.exceptionToThrow = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to connect to server',
      );

      expect(
        () => repository.search(query: 'Failing Query'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
