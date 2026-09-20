import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/screens/user_tracks_screen.dart';

class MockAudioRepository extends Mock implements AudioRepository {}

void main() {
  late MockAudioRepository mockRepository;

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tTracks = [
    TrackEntity(
      id: 'track-1',
      ownerId: 'user-1',
      title: 'Midnight Echoes',
      artistName: 'Luna Wave',
      genre: 'Chillout',
      description: 'Late night chill acoustic vibes',
      status: 'UPLOADED',
      createdAt: testDate,
      updatedAt: testDate,
      audioFiles: [],
      processingJobs: [
        ProcessingJobEntity(
          id: 'job-1',
          trackId: 'track-1',
          jobType: 'AUDIO_TRANSCODE',
          status: 'PENDING',
          attempts: 0,
          createdAt: testDate,
          updatedAt: testDate,
        ),
      ],
    ),
  ];

  setUp(() {
    mockRepository = MockAudioRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        audioRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: const MaterialApp(
        home: UserTracksScreen(),
      ),
    );
  }

  group('UserTracksScreen Widget Tests', () {
    testWidgets('renders empty state when user has no tracks',
        (WidgetTester tester) async {
      when(() => mockRepository.listTracks(skip: 0, limit: 50))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('My Uploads'), findsOneWidget);
      expect(find.text('No Tracks Uploaded Yet'), findsOneWidget);
      expect(find.text('Upload your first track or podcast episode to start streaming.'),
          findsOneWidget);
    });

    testWidgets('renders track items with metadata and status chips',
        (WidgetTester tester) async {
      when(() => mockRepository.listTracks(skip: 0, limit: 50))
          .thenAnswer((_) async => tTracks);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('My Uploads'), findsOneWidget);
      expect(find.text('Midnight Echoes'), findsOneWidget);
      expect(find.text('Luna Wave'), findsOneWidget);
      expect(find.text('UPLOADED'), findsOneWidget);
      expect(find.text('Genre: Chillout'), findsOneWidget);
      expect(find.text('Job: PENDING'), findsOneWidget);
    });
  });
}
