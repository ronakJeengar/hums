import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/playback_entity.dart';
import 'package:hums_mobile/features/audio_player/domain/entities/player_queue.dart';
import 'package:hums_mobile/features/audio_player/domain/repositories/audio_player_repository.dart';
import 'package:hums_mobile/features/audio_player/presentation/providers/audio_player_provider.dart';
import 'package:hums_mobile/features/audio_player/presentation/states/player_state.dart';

class MockAudioPlayerRepository extends Mock implements AudioPlayerRepository {}

void main() {
  late MockAudioPlayerRepository mockRepository;
  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;
  late StreamController<Duration> bufferedController;
  late StreamController<bool> isPlayingController;
  late StreamController<bool> isBufferingController;
  late StreamController<bool> isCompletedController;
  late AudioPlayerNotifier notifier;

  TrackPlaybackEntity createPlayback(String trackId, String title) {
    return TrackPlaybackEntity(
      trackId: trackId,
      title: title,
      artistName: 'Artist $trackId',
      albumName: 'Album $trackId',
      durationSeconds: 180,
      status: 'READY',
      audio: AudioSourceEntity(
        url: 'https://cdn.hums.app/stream/$trackId/audio.mp3',
        format: 'mp3',
        codec: 'mp3',
        bitrateKbps: 192,
        durationSeconds: 180,
        fileSizeBytes: 4000000,
      ),
      waveformSamples: const [0.1, 0.4, 0.8, 0.2],
    );
  }

  QueueItem createQueueItem(String id, String title, {String source = QueueItemSource.playlist}) {
    return QueueItem(
      queueItemId: 'item_$id',
      trackId: id,
      title: title,
      artistName: 'Artist $id',
      albumName: 'Album $id',
      durationSeconds: 180,
      status: 'READY',
      source: source,
    );
  }

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(createPlayback('fallback', 'Fallback'));
  });

  setUp(() {
    mockRepository = MockAudioPlayerRepository();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    bufferedController = StreamController<Duration>.broadcast();
    isPlayingController = StreamController<bool>.broadcast();
    isBufferingController = StreamController<bool>.broadcast();
    isCompletedController = StreamController<bool>.broadcast();

    when(() => mockRepository.positionStream).thenAnswer((_) => positionController.stream);
    when(() => mockRepository.durationStream).thenAnswer((_) => durationController.stream);
    when(() => mockRepository.bufferedPositionStream).thenAnswer((_) => bufferedController.stream);
    when(() => mockRepository.isPlayingStream).thenAnswer((_) => isPlayingController.stream);
    when(() => mockRepository.isBufferingStream).thenAnswer((_) => isBufferingController.stream);
    when(() => mockRepository.isCompletedStream).thenAnswer((_) => isCompletedController.stream);

    when(() => mockRepository.getUpNextCandidates(
          currentTrackId: any(named: 'currentTrackId'),
          limit: any(named: 'limit'),
          excludeIds: any(named: 'excludeIds'),
        )).thenAnswer((_) async => []);

    when(() => mockRepository.getPlaybackSource(any()))
        .thenAnswer((invocation) async => createPlayback(invocation.positionalArguments[0] as String, 'Title'));
    when(() => mockRepository.loadTrack(any())).thenAnswer((_) async {});
    when(() => mockRepository.play()).thenAnswer((_) async {});
    when(() => mockRepository.pause()).thenAnswer((_) async {});
    when(() => mockRepository.stop()).thenAnswer((_) async {});

    notifier = AudioPlayerNotifier(mockRepository);
  });

  tearDown(() {
    notifier.dispose();
    positionController.close();
    durationController.close();
    bufferedController.close();
    isPlayingController.close();
    isBufferingController.close();
    isCompletedController.close();
  });

  group('Smart Queue & Up Next Notifier Tests', () {
    test('playNext inserts item at the beginning of manual queue', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      final item1 = createQueueItem('t1', 'Track 1');
      final item2 = createQueueItem('t2', 'Track 2');

      await notifier.addToQueue(item1);
      expect(notifier.state.manualQueue.length, 1);
      expect(notifier.state.manualQueue.first.trackId, 't1');

      // Now playNext item2 -> should be placed before item1
      await notifier.playNext(item2);
      expect(notifier.state.manualQueue.length, 2);
      expect(notifier.state.manualQueue[0].trackId, 't2');
      expect(notifier.state.manualQueue[1].trackId, 't1');
    });

    test('addToQueue appends item to manual queue', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      final item1 = createQueueItem('t1', 'Track 1');
      final item2 = createQueueItem('t2', 'Track 2');

      await notifier.addToQueue(item1);
      await notifier.addToQueue(item2);

      expect(notifier.state.manualQueue.length, 2);
      expect(notifier.state.manualQueue[0].trackId, 't1');
      expect(notifier.state.manualQueue[1].trackId, 't2');
    });

    test('removeQueueItem removes item from manual, upNext, or smart lists', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      final manualItem = createQueueItem('m1', 'Manual 1', source: QueueItemSource.manual);
      await notifier.addToQueue(manualItem);
      expect(notifier.state.manualQueue.length, 1);

      notifier.removeQueueItem('item_m1');
      expect(notifier.state.manualQueue, isEmpty);
    });

    test('reorderManualQueue reorders items properly', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      final itemA = createQueueItem('a', 'Track A');
      final itemB = createQueueItem('b', 'Track B');
      final itemC = createQueueItem('c', 'Track C');

      await notifier.addToQueue(itemA);
      await notifier.addToQueue(itemB);
      await notifier.addToQueue(itemC);

      // Reorder itemC (idx 2) to idx 0
      notifier.reorderManualQueue(2, 0);

      expect(notifier.state.manualQueue[0].trackId, 'c');
      expect(notifier.state.manualQueue[1].trackId, 'a');
      expect(notifier.state.manualQueue[2].trackId, 'b');
    });

    test('clearManualQueue clears only manual queue', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      final item1 = createQueueItem('t1', 'Track 1');
      await notifier.addToQueue(item1);
      expect(notifier.state.manualQueue.length, 1);

      notifier.clearManualQueue();
      expect(notifier.state.manualQueue, isEmpty);
    });

    test('cycleRepeatMode cycles: off -> repeatQueue -> repeatTrack -> off', () {
      expect(notifier.state.repeatMode, PlaybackRepeatMode.off);

      notifier.cycleRepeatMode();
      expect(notifier.state.repeatMode, PlaybackRepeatMode.repeatQueue);

      notifier.cycleRepeatMode();
      expect(notifier.state.repeatMode, PlaybackRepeatMode.repeatTrack);

      notifier.cycleRepeatMode();
      expect(notifier.state.repeatMode, PlaybackRepeatMode.off);
    });

    test('setRepeatMode updates repeat mode directly', () {
      notifier.setRepeatMode(PlaybackRepeatMode.repeatTrack);
      expect(notifier.state.repeatMode, PlaybackRepeatMode.repeatTrack);
    });

    test('toggleShuffle shuffles upNext items and unshuffle restores original order', () async {
      final qItems = [
        createQueueItem('1', 'One'),
        createQueueItem('2', 'Two'),
        createQueueItem('3', 'Three'),
        createQueueItem('4', 'Four'),
        createQueueItem('5', 'Five'),
      ];

      await notifier.playQueue(PlayerQueue(
        items: qItems,
        currentIndex: 0,
        upNextItems: qItems.sublist(1),
      ));

      expect(notifier.state.isShuffled, isFalse);
      expect(notifier.state.upNextQueue.map((e) => e.trackId).toList(), ['2', '3', '4', '5']);

      notifier.toggleShuffle();
      expect(notifier.state.isShuffled, isTrue);

      notifier.toggleShuffle();
      expect(notifier.state.isShuffled, isFalse);
      expect(notifier.state.upNextQueue.map((e) => e.trackId).toList(), ['2', '3', '4', '5']);
    });

    test('skipToNext prioritizes manual queue over upNext and smart queue', () async {
      final nowPlaying = createQueueItem('p0', 'Playing');
      final upNextItem = createQueueItem('u1', 'Up Next 1');
      final manualItem = createQueueItem('m1', 'Manual 1');

      await notifier.playQueue(PlayerQueue(
        items: [nowPlaying, upNextItem],
        currentIndex: 0,
        upNextItems: [upNextItem],
      ));

      notifier.addToQueue(manualItem);

      // Current track is p0
      expect(notifier.state.track?.trackId, 'p0');
      expect(notifier.state.manualQueue.length, 1);
      expect(notifier.state.upNextQueue.length, 1);

      // Skipping next should play manualItem 'm1', NOT 'u1'
      await notifier.skipToNext();
      expect(notifier.state.track?.trackId, 'm1');
      expect(notifier.state.manualQueue, isEmpty);
      expect(notifier.state.upNextQueue.length, 1);

      // Next skip plays 'u1'
      await notifier.skipToNext();
      expect(notifier.state.track?.trackId, 'u1');
      expect(notifier.state.upNextQueue, isEmpty);
    });

    test('skipToPrevious returns to previous track from history', () async {
      final track1 = createQueueItem('t1', 'Track 1');
      final track2 = createQueueItem('t2', 'Track 2');

      await notifier.playQueue(PlayerQueue(
        items: [track1, track2],
        currentIndex: 0,
        upNextItems: [track2],
      ));

      expect(notifier.state.track?.trackId, 't1');

      // Skip forward to t2 (t1 goes to history)
      await notifier.skipToNext();
      expect(notifier.state.track?.trackId, 't2');

      // Skip back to t1
      await notifier.skipToPrevious();
      expect(notifier.state.track?.trackId, 't1');
    });

    test('resetQueueOnLogout clears queue and stops playback', () async {
      final track1 = createQueueItem('t1', 'Track 1');
      await notifier.playQueue(PlayerQueue(items: [track1], currentIndex: 0));

      await notifier.addToQueue(createQueueItem('m1', 'Manual 1'));
      expect(notifier.state.queue?.items, isNotEmpty);

      notifier.resetQueueOnLogout();

      expect(notifier.state.queue, isNull);
      expect(notifier.state.manualQueue, isEmpty);
      expect(notifier.state.upNextQueue, isEmpty);
      expect(notifier.state.smartQueue, isEmpty);
      expect(notifier.state.status, PlayerStatus.idle);
      verify(() => mockRepository.stop()).called(1);
    });

    test('clearAllUpcomingQueue clears manual, upNext, and smart queues', () async {
      final nowPlaying = createQueueItem('p0', 'Now Playing');
      await notifier.playQueue(PlayerQueue(items: [nowPlaying], currentIndex: 0));

      await notifier.addToQueue(createQueueItem('m1', 'Manual'));
      expect(notifier.state.allUpcomingQueue, isNotEmpty);

      notifier.clearAllUpcomingQueue();
      expect(notifier.state.allUpcomingQueue, isEmpty);
      expect(notifier.state.manualQueue, isEmpty);
      expect(notifier.state.upNextQueue, isEmpty);
      expect(notifier.state.smartQueue, isEmpty);
    });
  });
}
