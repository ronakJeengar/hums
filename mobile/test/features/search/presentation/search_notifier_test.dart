import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';

class MockSearchRepository implements SearchRepository {
  int callCount = 0;
  String? lastQuery;
  SearchCategory? lastCategory;
  SearchResultEntity? cannedResult;
  Duration delay = Duration.zero;
  Exception? exceptionToThrow;
  List<String> recents = [];
  List<String> suggestions = [];

  @override
  Future<SearchResultEntity> search({
    required String query,
    SearchCategory category = SearchCategory.all,
    int limit = 20,
    int skip = 0,
  }) async {
    callCount++;
    lastQuery = query;
    lastCategory = category;

    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return cannedResult ?? SearchResultEntity(query: query, category: category);
  }

  @override
  Future<List<String>> getSuggestions({required String query, int limit = 8}) async {
    return suggestions;
  }

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
  group('SearchNotifier Tests', () {
    late MockSearchRepository mockRepo;
    late SearchNotifier notifier;

    setUp(() {
      mockRepo = MockSearchRepository();
      notifier = SearchNotifier(mockRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state is initial and empty', () {
      expect(notifier.state.isInitial, true);
      expect(notifier.state.query, '');
      expect(notifier.state.category, SearchCategory.all);
      expect(notifier.state.results.isEmpty, true);
    });

    test('onQueryChanged debounces requests for 300ms', () async {
      notifier.onQueryChanged('A');
      notifier.onQueryChanged('Ar');
      notifier.onQueryChanged('Arijit');

      expect(mockRepo.callCount, 0);

      // Fast forward past debounce
      await Future.delayed(const Duration(milliseconds: 350));

      expect(mockRepo.callCount, 1);
      expect(mockRepo.lastQuery, 'Arijit');
      expect(notifier.state.isLoaded, true);
    });

    test('empty query resets notifier to initial state immediately', () async {
      notifier.onQueryChanged('Arijit');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(notifier.state.isLoaded, true);

      notifier.onQueryChanged('');
      expect(notifier.state.isInitial, true);
      expect(notifier.state.results.isEmpty, true);
      expect(notifier.state.query, '');
    });

    test('category change instantly triggers search if query is non-empty', () async {
      notifier.onQueryChanged('Arijit');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockRepo.callCount, 1);

      notifier.onCategoryChanged(SearchCategory.artists);
      expect(notifier.state.category, SearchCategory.artists);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.callCount, 2);
      expect(mockRepo.lastCategory, SearchCategory.artists);
    });

    test('clearSearch cancels pending timers and resets state', () async {
      notifier.onQueryChanged('Pending');
      notifier.clearSearch();

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockRepo.callCount, 0);
      expect(notifier.state.isInitial, true);
      expect(notifier.state.query, '');
    });

    test('race condition immunity: ignores slow previous responses', () async {
      mockRepo.delay = const Duration(milliseconds: 100);

      notifier.onQueryChanged('FastQuery1');
      await Future.delayed(const Duration(milliseconds: 310));

      notifier.onQueryChanged('FastQuery2');
      await Future.delayed(const Duration(milliseconds: 310));

      await Future.delayed(const Duration(milliseconds: 150));

      expect(notifier.state.results.query, 'FastQuery2');
    });

    test('error during search sets isError status and message', () async {
      mockRepo.exceptionToThrow = Exception('Network Failure');

      notifier.onQueryChanged('QueryWillFail');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(notifier.state.isError, true);
      expect(notifier.state.errorMessage, contains('Network Failure'));
    });

    test('recent searches can be removed and cleared', () async {
      mockRepo.recents = ['Arijit', 'Pritam'];
      await notifier.loadRecentSearches();
      expect(notifier.state.recentSearches, ['Arijit', 'Pritam']);

      await notifier.removeRecentSearch('Arijit');
      expect(notifier.state.recentSearches, ['Pritam']);

      await notifier.clearRecentSearches();
      expect(notifier.state.recentSearches, isEmpty);
    });
  });
}
