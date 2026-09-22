import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_section_entity.dart';
import 'package:hums_mobile/features/recommendations/domain/entities/recommendation_track_entity.dart';
import 'package:hums_mobile/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:hums_mobile/features/recommendations/presentation/providers/recommendation_provider.dart';
import 'package:hums_mobile/features/recommendations/presentation/states/recommendation_state.dart';

class MockRecommendationRepository extends Mock
    implements RecommendationRepository {}

void main() {
  late MockRecommendationRepository mockRepo;
  late RecommendationNotifier notifier;

  setUp(() {
    mockRepo = MockRecommendationRepository();
    notifier = RecommendationNotifier(mockRepo);
  });

  const tTrack = RecommendationTrackEntity(
    id: 'track-1',
    title: 'Warm Beat',
    artistName: 'Producer X',
    genre: 'Lo-Fi',
    durationSeconds: 150,
    status: 'READY',
  );

  const tSection = RecommendationSectionEntity(
    id: 'for-you',
    title: 'For You',
    description: 'Personalized for you',
    items: [tTrack],
  );

  group('RecommendationNotifier Tests', () {
    test('initial state has default values', () {
      expect(notifier.state.status, RecommendationStatus.initial);
      expect(notifier.state.sections, isEmpty);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.isInitial, isTrue);
    });

    test('loadRecommendations transitions to loaded with sections on success',
        () async {
      when(() => mockRepo.getRecommendations(refresh: false))
          .thenAnswer((_) async => [tSection]);

      await notifier.loadRecommendations();

      expect(notifier.state.status, RecommendationStatus.loaded);
      expect(notifier.state.sections.length, 1);
      expect(notifier.state.sections.first.id, 'for-you');
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.isLoaded, isTrue);
      expect(notifier.state.isEmpty, isFalse);
    });

    test('loadRecommendations does not re-fetch if already loaded with sections and refresh is false',
        () async {
      when(() => mockRepo.getRecommendations(refresh: false))
          .thenAnswer((_) async => [tSection]);

      await notifier.loadRecommendations();
      expect(notifier.state.isLoaded, isTrue);

      // Second call without refresh
      await notifier.loadRecommendations();
      verify(() => mockRepo.getRecommendations(refresh: false)).called(1);
    });

    test('loadRecommendations handles ApiException correctly', () async {
      when(() => mockRepo.getRecommendations(refresh: false)).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'Failed to fetch recommendations'),
      );

      await notifier.loadRecommendations();

      expect(notifier.state.status, RecommendationStatus.error);
      expect(notifier.state.errorMessage, 'Failed to fetch recommendations');
      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.isRefreshing, isFalse);
    });

    test('loadRecommendations handles unexpected generic exception', () async {
      when(() => mockRepo.getRecommendations(refresh: false)).thenThrow(
        Exception('Unexpected error occurred'),
      );

      await notifier.loadRecommendations();

      expect(notifier.state.status, RecommendationStatus.error);
      expect(notifier.state.errorMessage, contains('Unexpected error occurred'));
      expect(notifier.state.hasError, isTrue);
    });

    test('loadRecommendations with refresh=true sets isRefreshing', () async {
      when(() => mockRepo.getRecommendations(refresh: true))
          .thenAnswer((_) async => [tSection]);

      await notifier.loadRecommendations(refresh: true);

      expect(notifier.state.status, RecommendationStatus.loaded);
      expect(notifier.state.isRefreshing, isFalse);
      expect(notifier.state.sections.length, 1);
    });

    test('refresh triggers refreshRecommendations and updates state', () async {
      when(() => mockRepo.refreshRecommendations()).thenAnswer((_) async {});
      when(() => mockRepo.getRecommendations(refresh: true))
          .thenAnswer((_) async => [tSection]);

      await notifier.refresh();

      verify(() => mockRepo.refreshRecommendations()).called(1);
      verify(() => mockRepo.getRecommendations(refresh: true)).called(1);
      expect(notifier.state.status, RecommendationStatus.loaded);
      expect(notifier.state.sections.length, 1);
    });

    test('refresh catches error and sets error state if refresh fails',
        () async {
      when(() => mockRepo.refreshRecommendations()).thenThrow(
        const ApiException(code: 'RATE_LIMIT', message: 'Rate limited'),
      );

      await notifier.refresh();

      expect(notifier.state.status, RecommendationStatus.error);
      expect(notifier.state.errorMessage, 'Rate limited');
      expect(notifier.state.isRefreshing, isFalse);
    });
  });
}
