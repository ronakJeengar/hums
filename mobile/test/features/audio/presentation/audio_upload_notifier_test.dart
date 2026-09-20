import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio/domain/entities/track_entity.dart';
import 'package:hums_mobile/features/audio/domain/repositories/audio_repository.dart';
import 'package:hums_mobile/features/audio/presentation/providers/audio_upload_provider.dart';
import 'package:hums_mobile/features/audio/presentation/states/audio_upload_state.dart';

class MockAudioRepository extends Mock implements AudioRepository {}

void main() {
  late MockAudioRepository mockRepository;
  late AudioUploadNotifier notifier;

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tTrack = TrackEntity(
    id: 'track-123',
    ownerId: 'user-123',
    title: 'Acoustic Sunrise',
    status: 'UPLOADED',
    createdAt: testDate,
    updatedAt: testDate,
    audioFiles: [],
    processingJobs: [
      ProcessingJobEntity(
        id: 'job-123',
        trackId: 'track-123',
        jobType: 'AUDIO_TRANSCODE',
        status: 'PENDING',
        attempts: 0,
        createdAt: testDate,
        updatedAt: testDate,
      ),
    ],
  );

  setUp(() {
    mockRepository = MockAudioRepository();
    notifier = AudioUploadNotifier(mockRepository);
  });

  group('AudioUploadNotifier State Tests', () {
    test('initial state is AudioUploadState.initial()', () {
      expect(notifier.state, const AudioUploadState.initial());
      expect(notifier.state.isInitial, isTrue);
    });

    test('selectFile with valid mp3 sets fileSelected state', () {
      notifier.selectFile(
        path: '/path/to/song.mp3',
        name: 'song.mp3',
        size: 5 * 1024 * 1024,
      );

      expect(notifier.state.isFileSelected, isTrue);
      expect(notifier.state.selectedFileName, 'song.mp3');
      expect(notifier.state.selectedFilePath, '/path/to/song.mp3');
      expect(notifier.state.selectedFileSize, 5 * 1024 * 1024);
    });

    test('selectFile with invalid extension transitions to failure', () {
      notifier.selectFile(
        path: '/path/to/document.pdf',
        name: 'document.pdf',
        size: 1024,
      );

      expect(notifier.state.isFailure, isTrue);
      expect(notifier.state.errorMessage, contains('Unsupported file format'));
    });

    test('selectFile exceeding 100MB transitions to failure', () {
      notifier.selectFile(
        path: '/path/to/huge.wav',
        name: 'huge.wav',
        size: 105 * 1024 * 1024,
      );

      expect(notifier.state.isFailure, isTrue);
      expect(notifier.state.errorMessage, contains('exceeds 100MB'));
    });

    test('uploadAudio without selected file returns false', () async {
      final success = await notifier.uploadAudio(title: 'Some Title');

      expect(success, isFalse);
      expect(notifier.state.isFailure, isTrue);
      expect(notifier.state.errorMessage, contains('select an audio file'));
    });

    test('uploadAudio with empty title returns false', () async {
      notifier.selectFile(
        path: '/path/to/song.mp3',
        name: 'song.mp3',
        size: 1024000,
      );

      final success = await notifier.uploadAudio(title: '   ');

      expect(success, isFalse);
      expect(notifier.state.isFailure, isTrue);
      expect(notifier.state.errorMessage, contains('title is required'));
    });

    test('uploadAudio success transitions through uploading to uploaded',
        () async {
      notifier.selectFile(
        path: '/path/to/song.mp3',
        name: 'song.mp3',
        size: 1024000,
      );

      when(() => mockRepository.uploadAudio(
            filePath: '/path/to/song.mp3',
            title: 'Acoustic Sunrise',
            description: null,
            artistName: null,
            albumName: null,
            genre: null,
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => tTrack);

      final success = await notifier.uploadAudio(title: 'Acoustic Sunrise');

      expect(success, isTrue);
      expect(notifier.state.isUploaded, isTrue);
      expect(notifier.state.uploadedTrack?.id, 'track-123');
      expect(notifier.state.uploadedTrack?.title, 'Acoustic Sunrise');
    });

    test('uploadAudio error transitions to failure', () async {
      notifier.selectFile(
        path: '/path/to/song.mp3',
        name: 'song.mp3',
        size: 1024000,
      );

      when(() => mockRepository.uploadAudio(
            filePath: '/path/to/song.mp3',
            title: 'Acoustic Sunrise',
            description: null,
            artistName: null,
            albumName: null,
            genre: null,
            onProgress: any(named: 'onProgress'),
          )).thenThrow(
        const ApiException(code: 'INVALID_AUDIO_FORMAT', message: 'Invalid magic bytes', statusCode: 400),
      );

      final success = await notifier.uploadAudio(title: 'Acoustic Sunrise');

      expect(success, isFalse);
      expect(notifier.state.isFailure, isTrue);
      expect(notifier.state.errorMessage, 'Invalid magic bytes');
    });

    test('reset clears state back to initial', () {
      notifier.selectFile(
        path: '/path/to/song.mp3',
        name: 'song.mp3',
        size: 1024000,
      );
      expect(notifier.state.isFileSelected, isTrue);

      notifier.reset();
      expect(notifier.state.isInitial, isTrue);
    });
  });
}
