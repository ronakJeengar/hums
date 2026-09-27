import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/search/data/datasources/search_local_data_source.dart';
import 'package:hums_mobile/features/search/data/datasources/search_remote_data_source.dart';
import 'package:hums_mobile/features/search/data/models/search_result_model.dart';
import 'package:hums_mobile/features/search/data/repositories/search_repository_impl.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';

class MockSearchRemoteDataSource implements SearchRemoteDataSource {
  SearchResultModel? mockResult;
  List<String> mockSuggestions = [];
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

  @override
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 8,
  }) async {
    return mockSuggestions;
  }
}

class MockSearchLocalDataSource implements SearchLocalDataSource {
  List<String> recents = [];

  @override
  Future<List<String>> getRecentSearches() async => recents;

  @override
  Future<void> saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    recents = [clean, ...recents.where((s) => s.toLowerCase() != clean.toLowerCase())];
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    recents.remove(query);
  }

  @override
  Future<void> clearRecentSearches() async {
    recents.clear();
  }
}

void main() {
  group('SearchRepositoryImpl Tests', () {
    late MockSearchRemoteDataSource mockRemote;
    late MockSearchLocalDataSource mockLocal;
    late SearchRepositoryImpl repository;

    setUp(() {
      mockRemote = MockSearchRemoteDataSource();
      mockLocal = MockSearchLocalDataSource();
      repository = SearchRepositoryImpl(mockRemote, mockLocal);
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

    test('getSuggestions returns list of autocomplete suggestions', () async {
      mockRemote.mockSuggestions = ['Arijit Singh', 'Aashiqui 2'];
      final suggestions = await repository.getSuggestions(query: 'Ari');
      expect(suggestions, ['Arijit Singh', 'Aashiqui 2']);
    });

    test('recent searches save, load, remove, and clear work as expected', () async {
      await repository.saveRecentSearch('Dil Diyan Gallan');
      expect(await repository.getRecentSearches(), ['Dil Diyan Gallan']);

      await repository.saveRecentSearch('Kesariya');
      expect(await repository.getRecentSearches(), ['Kesariya', 'Dil Diyan Gallan']);

      await repository.removeRecentSearch('Dil Diyan Gallan');
      expect(await repository.getRecentSearches(), ['Kesariya']);

      await repository.clearRecentSearches();
      expect(await repository.getRecentSearches(), isEmpty);
    });
  });
}
