import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';
import 'package:hums_mobile/features/history/domain/entities/listening_history_item_entity.dart';
import 'package:hums_mobile/features/history/presentation/providers/history_provider.dart';
import 'package:hums_mobile/features/history/presentation/screens/listening_history_screen.dart';
import 'package:hums_mobile/features/history/presentation/states/history_state.dart';
import 'package:hums_mobile/features/history/presentation/widgets/history_track_tile.dart';

class MockListeningHistoryNotifier extends StateNotifier<ListeningHistoryState>
    with Mock
    implements ListeningHistoryNotifier {
  MockListeningHistoryNotifier(super.state);
}

class MockAudioPlayerNotifier extends StateNotifier<PlayerState>
    with Mock
    implements AudioPlayerNotifier {
  MockAudioPlayerNotifier(super.state);
}

void main() {
  final now = DateTime.now();

  final tItemToday = ListeningHistoryItemEntity(
    id: 'h-1',
    trackId: 't-1',
    positionMs: 60000,
    durationMs: 180000,
    completed: false,
    progressPercent: 0.33,
    lastPlayedAt: now,
    track: PlaybackTrackSummaryEntity(
      id: 't-1',
      ownerId: 'u-1',
      title: 'Acoustic Horizon',
      artistName: 'Luna Echo',
      albumName: 'Serenade',
      durationSeconds: 180,
      status: 'READY',
      createdAt: now,
    ),
  );

  final tItemYesterday = ListeningHistoryItemEntity(
    id: 'h-2',
    trackId: 't-2',
    positionMs: 240000,
    durationMs: 240000,
    completed: true,
    progressPercent: 1.0,
    lastPlayedAt: now.subtract(const Duration(days: 1)),
    track: PlaybackTrackSummaryEntity(
      id: 't-2',
      ownerId: 'u-1',
      title: 'Midnight Breeze',
      artistName: 'Solar Beats',
      albumName: 'Night Sky',
      durationSeconds: 240,
      status: 'READY',
      createdAt: now,
    ),
  );

  Widget createWidgetUnderTest(ListeningHistoryState historyState) {
    return ProviderScope(
      overrides: [
        listeningHistoryNotifierProvider.overrideWith((ref) {
          final notifier = MockListeningHistoryNotifier(historyState);
          when(() => notifier.loadHistory(refresh: any(named: 'refresh')))
              .thenAnswer((_) async {});
          when(() => notifier.loadMore()).thenAnswer((_) async {});
          when(() => notifier.syncOfflineQueue()).thenAnswer((_) async {});
          return notifier;
        }),
        audioPlayerNotifierProvider.overrideWith((ref) {
          return MockAudioPlayerNotifier(const PlayerState());
        }),
      ],
      child: const MaterialApp(
        home: ListeningHistoryScreen(),
      ),
    );
  }

  group('ListeningHistoryScreen Widget Tests', () {
    testWidgets('renders loading spinner when loading and empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ListeningHistoryState(isLoading: true, items: []),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when history has no items',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ListeningHistoryState(isLoading: false, items: []),
        ),
      );

      expect(find.text('No listening history yet'), findsOneWidget);
      expect(
        find.text(
            'Tracks you play will appear here so you can pick up right where you left off.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state with retry button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ListeningHistoryState(
            isLoading: false,
            errorMessage: 'Network timeout',
            items: [],
          ),
        ),
      );

      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders grouped history items with date sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          ListeningHistoryState(
            isLoading: false,
            items: [tItemToday, tItemYesterday],
            total: 2,
          ),
        ),
      );

      // Section headers
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // Track titles
      expect(find.text('Acoustic Horizon'), findsOneWidget);
      expect(find.text('Midnight Breeze'), findsOneWidget);

      // History track tiles rendered
      expect(find.byType(HistoryTrackTile), findsNWidgets(2));
    });

    testWidgets('renders offline sync banner when pending offline events exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          ListeningHistoryState(
            isLoading: false,
            items: [tItemToday],
            total: 1,
            pendingOfflineEventsCount: 3,
          ),
        ),
      );

      expect(find.text('3 offline plays waiting to sync'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
    });
  });
}
