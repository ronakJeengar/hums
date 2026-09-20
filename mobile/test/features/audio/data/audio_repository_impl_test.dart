import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/audio/data/datasources/audio_remote_data_source.dart';
import 'package:hums_mobile/features/audio/data/models/track_model.dart';
import 'package:hums_mobile/features/audio/data/repositories/audio_repository_impl.dart';

class MockAudioRemoteDataSource extends Mock
    implements AudioRemoteDataSource {}

void main() {
  late MockAudioRemoteDataSource mockRemote;
  late AudioRepositoryImpl repository;

  setUp(() {
    mockRemote = MockAudioRemoteDataSource();
    repository = AudioRepositoryImpl(mockRemote);
  });

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);

  final tTrackModel = TrackModel(
    id: 'track-uuid-1',
    ownerId: 'user-uuid-1',
    title: 'Midnight Hums',
    description: 'Acoustic evening session',
    artistName: 'Ronak',
    albumName: 'Nightfall',
    genre: 'Ambient',
    status: 'UPLOADED',
    createdAt: testDate,
    updatedAt: testDate,
    audioFiles: [
      AudioFileModel(
        id: 'file-uuid-1',
        trackId: 'track-uuid-1',
        objectKey: 'audio/original/user/track/file.mp3',
        storageProvider: 's3',
        originalFilename: 'midnight.mp3',
        mimeType: 'audio/mpeg',
        fileSizeBytes: 1024000,
        createdAt: testDate,
      ),
    ],
    processingJobs: [
      ProcessingJobModel(
        id: 'job-uuid-1',
        trackId: 'track-uuid-1',
        jobType: 'AUDIO_TRANSCODE',
        status: 'PENDING',
        attempts: 0,
        createdAt: testDate,
        updatedAt: testDate,
      ),
    ],
  );

  final tStatusModel = TrackStatusModel(
    trackId: 'track-uuid-1',
    title: 'Midnight Hums',
    status: 'UPLOADED',
    processingJobId: 'job-uuid-1',
    processingStatus: 'PENDING',
    updatedAt: testDate,
  );

  group('AudioRepositoryImpl Tests', () {
    test('uploadAudio delegates to remote data source and returns TrackEntity',
        () async {
      when(() => mockRemote.uploadAudio(
            filePath: 'test/song.mp3',
            title: 'Midnight Hums',
            description: 'Acoustic evening session',
            artistName: 'Ronak',
            albumName: 'Nightfall',
            genre: 'Ambient',
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => tTrackModel);

      final result = await repository.uploadAudio(
        filePath: 'test/song.mp3',
        title: 'Midnight Hums',
        description: 'Acoustic evening session',
        artistName: 'Ronak',
        albumName: 'Nightfall',
        genre: 'Ambient',
      );

      expect(result.id, 'track-uuid-1');
      expect(result.title, 'Midnight Hums');
      expect(result.status, 'UPLOADED');
      expect(result.audioFiles.length, 1);
      expect(result.processingJobs.length, 1);
      expect(result.latestJob?.status, 'PENDING');
      verify(() => mockRemote.uploadAudio(
            filePath: 'test/song.mp3',
            title: 'Midnight Hums',
            description: 'Acoustic evening session',
            artistName: 'Ronak',
            albumName: 'Nightfall',
            genre: 'Ambient',
            onProgress: any(named: 'onProgress'),
          )).called(1);
    });

    test('listTracks returns list of TrackEntity', () async {
      when(() => mockRemote.listTracks(skip: 0, limit: 50))
          .thenAnswer((_) async => [tTrackModel]);

      final result = await repository.listTracks();

      expect(result.length, 1);
      expect(result.first.id, 'track-uuid-1');
      expect(result.first.title, 'Midnight Hums');
      verify(() => mockRemote.listTracks(skip: 0, limit: 50)).called(1);
    });

    test('getTrack returns single TrackEntity', () async {
      when(() => mockRemote.getTrack('track-uuid-1'))
          .thenAnswer((_) async => tTrackModel);

      final result = await repository.getTrack('track-uuid-1');

      expect(result.id, 'track-uuid-1');
      expect(result.title, 'Midnight Hums');
      verify(() => mockRemote.getTrack('track-uuid-1')).called(1);
    });

    test('getTrackStatus returns TrackStatusEntity', () async {
      when(() => mockRemote.getTrackStatus('track-uuid-1'))
          .thenAnswer((_) async => tStatusModel);

      final result = await repository.getTrackStatus('track-uuid-1');

      expect(result.trackId, 'track-uuid-1');
      expect(result.status, 'UPLOADED');
      expect(result.processingStatus, 'PENDING');
      verify(() => mockRemote.getTrackStatus('track-uuid-1')).called(1);
    });

    test('rethrows ApiException when remote fails', () async {
      when(() => mockRemote.getTrack('track-uuid-1')).thenThrow(
        const ApiException(code: 'NOT_FOUND', message: 'Track not found', statusCode: 404),
      );

      expect(
        () => repository.getTrack('track-uuid-1'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
