import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/screens/upload_audio_screen.dart';

class MockAudioRepository extends Mock implements AudioRepository {}

void main() {
  late MockAudioRepository mockRepository;

  setUp(() {
    mockRepository = MockAudioRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        audioRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: const MaterialApp(
        home: UploadAudioScreen(),
      ),
    );
  }

  group('UploadAudioScreen Widget Tests', () {
    testWidgets('renders all upload components and form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Upload Audio'), findsOneWidget);
      expect(find.text('Select Audio File'), findsOneWidget);
      expect(find.text('Supported: MP3, WAV, FLAC, M4A, AAC, OGG (Max 100MB)'),
          findsOneWidget);
      expect(find.text('Track Metadata'), findsOneWidget);
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Artist Name'), findsOneWidget);
      expect(find.text('Album Name'), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Upload Track'), findsOneWidget);
    });

    testWidgets('entering metadata into text fields works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final titleFinder = find.widgetWithText(TextFormField, '');
      await tester.enterText(titleFinder.first, 'My Masterpiece');
      await tester.pump();

      expect(find.text('My Masterpiece'), findsOneWidget);
    });
  });
}
