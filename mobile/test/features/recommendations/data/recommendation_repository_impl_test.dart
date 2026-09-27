import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/recommendations/data/datasources/recommendation_remote_data_source.dart';
import 'package:hums_mobile/features/recommendations/data/models/recommendation_section_model.dart';
import 'package:hums_mobile/features/recommendations/data/models/recommendation_track_model.dart';
import 'package:hums_mobile/features/recommendations/data/repositories/recommendation_repository_impl.dart';

class MockRecommendationRemoteDataSource extends Mock
    implements RecommendationRemoteDataSource {}

void main() {
  late MockRecommendationRemoteDataSource mockRemote;
  late RecommendationRepositoryImpl repository;

  setUp(() {
    mockRemote = MockRecommendationRemoteDataSource();
    repository = RecommendationRepositoryImpl(mockRemote);
  });

  const tTrackModel = RecommendationTrackModel(
    id: 'track-1',
    title: 'Warm Beat',
    artistName: 'Producer X',
    genre: 'Lo-Fi',
    durationSeconds: 150,
    status: 'READY',
  );

  const tSectionModel = RecommendationSectionModel(
    id: 'for-you',
    title: 'For You',
    description: 'Personalized for you',
    items: [tTrackModel],
  );

  group('RecommendationRepositoryImpl Tests', () {
    test('getRecommendations returns mapped entities on success', () async {
      when(() => mockRemote.getRecommendations(
            limit: 10,
            section: null,
            refresh: false,
          )).thenAnswer((_) async => [tSectionModel]);

      final result = await repository.getRecommendations();

      expect(result.length, 1);
      expect(result.first.id, 'for-you');
      expect(result.first.title, 'For You');
      expect(result.first.items.length, 1);
      expect(result.first.items.first.id, 'track-1');
      expect(result.first.items.first.title, 'Warm Beat');

      verify(() => mockRemote.getRecommendations(
            limit: 10,
            section: null,
            refresh: false,
          )).called(1);
    });

    test('getRecommendations propagates parameters accurately', () async {
      when(() => mockRemote.getRecommendations(
            limit: 25,
            section: 'trending',
            refresh: true,
          )).thenAnswer((_) async => [tSectionModel]);

      final result = await repository.getRecommendations(
        limit: 25,
        section: 'trending',
        refresh: true,
      );

      expect(result.length, 1);
      verify(() => mockRemote.getRecommendations(
            limit: 25,
            section: 'trending',
            refresh: true,
          )).called(1);
    });

    test('getRecommendations propagates ApiException from data source', () async {
      when(() => mockRemote.getRecommendations(
            limit: 10,
            section: null,
            refresh: false,
          )).thenThrow(
        const ApiException(code: 'SERVER_ERROR', message: 'Internal Server Error'),
      );

      expect(
        () => repository.getRecommendations(),
        throwsA(isA<ApiException>()),
      );
    });

    test('refreshRecommendations calls remote data source successfully', () async {
      when(() => mockRemote.refreshRecommendations()).thenAnswer((_) async {});

      await repository.refreshRecommendations();

      verify(() => mockRemote.refreshRecommendations()).called(1);
    });

    test('refreshRecommendations propagates exceptions', () async {
      when(() => mockRemote.refreshRecommendations()).thenThrow(
        const ApiException(code: 'RATE_LIMITED', message: 'Too many requests'),
      );

      expect(
        () => repository.refreshRecommendations(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
