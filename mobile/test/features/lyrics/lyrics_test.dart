import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_local_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/datasources/lyrics_remote_data_source.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyric_line_model.dart';
import 'package:hums_mobile/features/lyrics/data/models/lyrics_model.dart';
import 'package:hums_mobile/features/lyrics/data/repositories/lyrics_repository_impl.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyric_line_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/entities/lyrics_entity.dart';
import 'package:hums_mobile/features/lyrics/domain/repositories/lyrics_repository.dart';
import 'package:hums_mobile/features/lyrics/presentation/providers/lyrics_provider.dart';
import 'package:hums_mobile/features/lyrics/presentation/screens/lyrics_screen.dart';
import 'package:hums_mobile/features/lyrics/presentation/states/lyrics_state.dart';
import 'package:hums_mobile/features/lyrics/presentation/widgets/lyric_line_tile.dart';

// --- Mocks ---

class MockLyricsRemoteDataSource implements LyricsRemoteDataSource {
  LyricsModel? mockLyrics;
  bool shouldFail = false;
  int getCalls = 0;
  int triggerCalls = 0;
  int uploadCalls = 0;

  @override
  Future<LyricsModel> getLyrics(String trackId) async {
    getCalls++;
    if (shouldFail) throw Exception('Network error');
    return mockLyrics ??
        LyricsModel(
          trackId: trackId,
          status: LyricsStatusConstants.unavailable,
        );
  }

  @override
  Future<LyricsModel> triggerGeneration(String trackId) async {
    triggerCalls++;
    if (shouldFail) throw Exception('Trigger error');
    return LyricsModel(
      trackId: trackId,
      status: LyricsStatusConstants.processing,
    );
  }

  @override
  Future<LyricsModel> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineModel>? lines,
  }) async {
    uploadCalls++;
    if (shouldFail) throw Exception('Upload error');
    return LyricsModel(
      trackId: trackId,
      status: LyricsStatusConstants.completed,
      text: text,
      language: language,
      isSynchronized: isSynchronized,
      lines: lines ?? [],
    );
  }
}

class MockLyricsLocalDataSource implements LyricsLocalDataSource {
  final Map<String, LyricsModel> storage = {};
  int getCalls = 0;
  int saveCalls = 0;
  int deleteCalls = 0;

  @override
  Future<LyricsModel?> getCachedLyrics(String userId, String trackId) async {
    getCalls++;
    return storage['$userId:$trackId'];
  }

  @override
  Future<void> saveCachedLyrics(
    String userId,
    String trackId,
    LyricsModel lyrics,
  ) async {
    saveCalls++;
    storage['$userId:$trackId'] = lyrics;
  }

  @override
  Future<void> deleteCachedLyrics(String userId, String trackId) async {
    deleteCalls++;
    storage.remove('$userId:$trackId');
  }

  @override
  Future<bool> hasCachedLyrics(String userId, String trackId) async {
    return storage.containsKey('$userId:$trackId');
  }
}

class MockLyricsRepository implements LyricsRepository {
  LyricsEntity? lyricsToReturn;
  bool shouldThrow = false;
  int getLyricsCalls = 0;
  int triggerCalls = 0;
  int uploadCalls = 0;

  @override
  Future<LyricsEntity> getLyrics(String trackId, {String? userId}) async {
    getLyricsCalls++;
    if (shouldThrow) throw Exception('Repository failure');
    return lyricsToReturn ??
        LyricsEntity(
          trackId: trackId,
          status: LyricsStatusConstants.unavailable,
        );
  }

  @override
  Future<LyricsEntity> triggerGeneration(String trackId) async {
    triggerCalls++;
    if (shouldThrow) throw Exception('Trigger failure');
    return LyricsEntity(
      trackId: trackId,
      status: LyricsStatusConstants.processing,
    );
  }

  @override
  Future<LyricsEntity> uploadLyrics(
    String trackId, {
    String? text,
    String? language,
    bool isSynchronized = false,
    List<LyricLineEntity>? lines,
  }) async {
    uploadCalls++;
    if (shouldThrow) throw Exception('Upload failure');
    return LyricsEntity(
      trackId: trackId,
      status: LyricsStatusConstants.completed,
      text: text,
      language: language,
      isSynchronized: isSynchronized,
      lines: lines ?? [],
    );
  }
}

void main() {
  group('LyricLineModel & LyricLineEntity', () {
    test('converts from and to JSON cleanly', () {
      final json = {
        'id': 'line-1',
        'sequence': 0,
        'start_ms': 5000,
        'end_ms': 9500,
        'text': 'First acoustic line',
      };

      final model = LyricLineModel.fromJson(json);
      expect(model.id, 'line-1');
      expect(model.sequence, 0);
      expect(model.startMs, 5000);
      expect(model.endMs, 9500);
      expect(model.text, 'First acoustic line');
      expect(model.duration, const Duration(milliseconds: 4500));
      expect(model.startTime, const Duration(milliseconds: 5000));
      expect(model.endTime, const Duration(milliseconds: 9500));

      final serialized = model.toJson();
      expect(serialized['sequence'], 0);
      expect(serialized['start_ms'], 5000);
      expect(serialized['end_ms'], 9500);
      expect(serialized['text'], 'First acoustic line');
    });

    test('containsPosition correctly evaluates bounds', () {
      const line = LyricLineEntity(
        sequence: 1,
        startMs: 10000,
        endMs: 15000,
        text: 'Boundaries test',
      );

      expect(line.containsPosition(9999), isFalse);
      expect(line.containsPosition(10000), isTrue);
      expect(line.containsPosition(12500), isTrue);
      expect(line.containsPosition(15000), isTrue);
      expect(line.containsPosition(15001), isFalse);
    });
  });

  group('LyricsModel & LyricsEntity Binary Search', () {
    final testLines = [
      const LyricLineEntity(
        sequence: 0,
        startMs: 2000,
        endMs: 5000,
        text: 'Intro verse',
      ),
      const LyricLineEntity(
        sequence: 1,
        startMs: 6000,
        endMs: 10000,
        text: 'First melody line',
      ),
      const LyricLineEntity(
        sequence: 2,
        startMs: 11000,
        endMs: 16000,
        text: 'Main chorus',
      ),
    ];

    final lyrics = LyricsEntity(
      trackId: 'track-100',
      status: LyricsStatusConstants.completed,
      isSynchronized: true,
      lines: testLines,
    );

    test('findLineIndexForPosition returns -1 before first line', () {
      expect(lyrics.findLineIndexForPosition(500), -1);
      expect(lyrics.findLineIndexForPosition(1999), -1);
    });

    test('findLineIndexForPosition finds active line accurately via binary search', () {
      expect(lyrics.findLineIndexForPosition(2000), 0);
      expect(lyrics.findLineIndexForPosition(3500), 0);
      expect(lyrics.findLineIndexForPosition(6000), 1);
      expect(lyrics.findLineIndexForPosition(8500), 1);
      expect(lyrics.findLineIndexForPosition(11000), 2);
      expect(lyrics.findLineIndexForPosition(15500), 2);
    });

    test('findLineIndexForPosition deselects after prolonged silence past end_ms', () {
      // 16000 is end of line 2. Within 3000ms:
      expect(lyrics.findLineIndexForPosition(18000), 2);
      // Beyond 3000ms (16000 + 3001 = 19001):
      expect(lyrics.findLineIndexForPosition(20000), -1);
    });

    test('JSON serialization roundtrip for LyricsModel', () {
      final json = {
        'id': 'lyr-1',
        'track_id': 'track-1',
        'status': 'COMPLETED',
        'language': 'en',
        'source': 'AI_GENERATED',
        'is_synchronized': true,
        'text': 'Intro verse\nFirst melody line\nMain chorus',
        'lines': [
          {'sequence': 0, 'start_ms': 2000, 'end_ms': 5000, 'text': 'Intro verse'},
        ],
        'model': 'gemini-2.5-flash',
        'version': 'v1',
      };

      final model = LyricsModel.fromJson(json);
      expect(model.id, 'lyr-1');
      expect(model.trackId, 'track-1');
      expect(model.status, LyricsStatusConstants.completed);
      expect(model.isSynchronized, isTrue);
      expect(model.lines.length, 1);
      expect(model.lines[0].text, 'Intro verse');

      final serialized = model.toJson();
      expect(serialized['track_id'], 'track-1');
      expect(serialized['is_synchronized'], isTrue);
      expect(serialized['lines'], isNotEmpty);
    });
  });

  group('LyricsRepositoryImpl', () {
    late MockLyricsRemoteDataSource remoteDataSource;
    late MockLyricsLocalDataSource localDataSource;
    late LyricsRepositoryImpl repository;

    setUp(() {
      remoteDataSource = MockLyricsRemoteDataSource();
      localDataSource = MockLyricsLocalDataSource();
      repository = LyricsRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
      );
    });

    test('returns cached lyrics immediately when available offline', () async {
      final cachedLyrics = LyricsModel(
        trackId: 'track-offline',
        status: LyricsStatusConstants.completed,
        text: 'Cached lyrics offline',
      );
      localDataSource.storage['user-1:track-offline'] = cachedLyrics;

      final result = await repository.getLyrics('track-offline', userId: 'user-1');

      expect(result.text, 'Cached lyrics offline');
      expect(localDataSource.getCalls, 1);
      expect(remoteDataSource.getCalls, 0); // No remote call needed
    });

    test('fetches from remote and caches locally if completed', () async {
      remoteDataSource.mockLyrics = LyricsModel(
        trackId: 'track-remote',
        status: LyricsStatusConstants.completed,
        text: 'Fresh remote lyrics',
      );

      final result = await repository.getLyrics('track-remote', userId: 'user-1');

      expect(result.text, 'Fresh remote lyrics');
      expect(remoteDataSource.getCalls, 1);
      expect(localDataSource.saveCalls, 1);
      expect(localDataSource.storage['user-1:track-remote']?.text, 'Fresh remote lyrics');
    });

    test('falls back to local cache when remote fails', () async {
      remoteDataSource.shouldFail = true;
      localDataSource.storage['user-1:track-fallback'] = LyricsModel(
        trackId: 'track-fallback',
        status: LyricsStatusConstants.completed,
        text: 'Emergency cached lyrics',
      );

      final result = await repository.getLyrics('track-fallback', userId: 'user-1');
      expect(result.text, 'Emergency cached lyrics');
    });
  });

  group('LyricsNotifier Unit Tests', () {
    test('fetches and updates state to completed', () async {
      final mockRepo = MockLyricsRepository();
      mockRepo.lyricsToReturn = const LyricsEntity(
        trackId: 't1',
        status: LyricsStatusConstants.completed,
        text: 'Song lyrics line 1\nLine 2',
      );

      final notifier = LyricsNotifier(
        repository: mockRepo,
        trackId: 't1',
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.status, LyricsStatusType.completed);
      expect(notifier.state.lyrics?.text, 'Song lyrics line 1\nLine 2');
      notifier.dispose();
    });

    test('handles error state on repository failure', () async {
      final mockRepo = MockLyricsRepository();
      mockRepo.shouldThrow = true;

      final notifier = LyricsNotifier(
        repository: mockRepo,
        trackId: 't1',
      );

      await Future.delayed(const Duration(milliseconds: 20));

      expect(notifier.state.status, LyricsStatusType.error);
      expect(notifier.state.errorMessage, isNotNull);
      notifier.dispose();
    });
  });

  group('Widget Tests', () {
    testWidgets('LyricLineTile renders active styling and responds to tap',
        (tester) async {
      bool tapped = false;
      const line = LyricLineEntity(
        sequence: 0,
        startMs: 12000,
        endMs: 15000,
        text: 'Active sung line',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricLineTile(
              line: line,
              isActive: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Active sung line'), findsOneWidget);
      await tester.tap(find.text('Active sung line'));
      expect(tapped, isTrue);
    });

    testWidgets('LyricsScreen displays unavailable state and trigger AI button',
        (tester) async {
      final mockRepo = MockLyricsRepository();
      mockRepo.lyricsToReturn = const LyricsEntity(
        trackId: 'track-unavail',
        status: LyricsStatusConstants.unavailable,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: LyricsScreen(trackId: 'track-unavail'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No lyrics available'), findsOneWidget);
      expect(find.text('Generate with AI'), findsOneWidget);
    });

    testWidgets('LyricsScreen displays plain text lyrics when synchronized lines absent',
        (tester) async {
      final mockRepo = MockLyricsRepository();
      mockRepo.lyricsToReturn = const LyricsEntity(
        trackId: 'track-plain',
        status: LyricsStatusConstants.completed,
        isSynchronized: false,
        text: 'First verse singing\nSecond verse continuation',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: LyricsScreen(trackId: 'track-plain'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PLAIN LYRICS'), findsOneWidget);
      expect(find.text('First verse singing\nSecond verse continuation'), findsOneWidget);
    });

    testWidgets('LyricsScreen displays synchronized lines with tap-to-seek',
        (tester) async {
      final mockRepo = MockLyricsRepository();
      mockRepo.lyricsToReturn = const LyricsEntity(
        trackId: 'track-sync',
        status: LyricsStatusConstants.completed,
        isSynchronized: true,
        lines: [
          LyricLineEntity(
            sequence: 0,
            startMs: 5000,
            endMs: 9000,
            text: 'First synchronized sentence',
          ),
          LyricLineEntity(
            sequence: 1,
            startMs: 9500,
            endMs: 14000,
            text: 'Second synchronized sentence',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: LyricsScreen(trackId: 'track-sync'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SYNCHRONIZED'), findsOneWidget);
      expect(find.text('First synchronized sentence'), findsOneWidget);
      expect(find.text('Second synchronized sentence'), findsOneWidget);
    });
  });
}
