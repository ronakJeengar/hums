import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/search/domain/entities/search_result_entity.dart';
import 'package:hums_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:hums_mobile/features/search/presentation/providers/search_provider.dart';
import 'package:hums_mobile/features/search/presentation/states/search_state.dart';

class MockSearchRepository implements SearchRepository {
  int callCount = 0;
  String? lastQuery;
  SearchCategory? lastCategory;
  SearchResultEntity? cannedResult;
  Duration delay = Duration.zero;
  Exception? exceptionToThrow;

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

      expect(notifier.state.query, 'Arijit');
      expect(mockRepo.callCount, 0); // Not called immediately

      // Fast-forward less than debounce threshold
      await Future.delayed(const Duration(milliseconds: 150));
      expect(mockRepo.callCount, 0);

      // Fast-forward past 300ms threshold
      await Future.delayed(const Duration(milliseconds: 200));
      expect(mockRepo.callCount, 1);
      expect(mockRepo.lastQuery, 'Arijit');
      expect(notifier.state.isLoaded, true);
    });

    test('empty query resets notifier to initial state immediately', () async {
      notifier.onQueryChanged('Arijit');
      notifier.onQueryChanged('');

      expect(notifier.state.isInitial, true);
      expect(notifier.state.query, '');
      expect(notifier.state.results.isEmpty, true);

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockRepo.callCount, 0); // Cancelled debounce timer
    });

    test('category change instantly triggers search if query is non-empty', () async {
      notifier.onQueryChanged('Kishore');
      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockRepo.callCount, 1);

      notifier.onCategoryChanged(SearchCategory.artists);
      expect(notifier.state.category, SearchCategory.artists);

      // Category change triggers immediate search
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.callCount, 2);
      expect(mockRepo.lastCategory, SearchCategory.artists);
    });

    test('clearSearch cancels pending timers and resets state', () async {
      notifier.onQueryChanged('Active Query');
      notifier.clearSearch();

      expect(notifier.state.isInitial, true);
      expect(notifier.state.query, '');

      await Future.delayed(const Duration(milliseconds: 350));
      expect(mockRepo.callCount, 0);
    });

    test('race condition immunity: ignores slow previous responses', () async {
      // Query 1 has a long delay
      mockRepo.delay = const Duration(milliseconds: 200);
      mockRepo.cannedResult = const SearchResultEntity(query: 'Old Slow');

      notifier.onQueryChanged('Old Slow');
      await Future.delayed(const Duration(milliseconds: 310)); // Query 1 fired

      // Query 2 is typed and finishes faster
      mockRepo.delay = Duration.zero;
      mockRepo.cannedResult = const SearchResultEntity(query: 'New Fast');
      notifier.onQueryChanged('New Fast');
      await Future.delayed(const Duration(milliseconds: 320)); // Query 2 finishes

      // Wait for slow Query 1 to finish in background
      await Future.delayed(const Duration(milliseconds: 100));

      // Active state must be 'New Fast', NOT overwritten by 'Old Slow'
      expect(notifier.state.results.query, 'New Fast');
    });

    test('error during search sets isError status and message', () async {
      mockRepo.exceptionToThrow = Exception('Database unreachable');

      notifier.onQueryChanged('Error Test');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(notifier.state.isError, true);
      expect(notifier.state.errorMessage, contains('Database unreachable'));
    });
  });
}
