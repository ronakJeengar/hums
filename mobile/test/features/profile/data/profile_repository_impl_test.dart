import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hums_mobile/features/profile/data/models/profile_model.dart';
import 'package:hums_mobile/features/profile/data/repositories/profile_repository_impl.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  late MockProfileRemoteDataSource mockRemote;
  late ProfileRepositoryImpl repository;

  setUp(() {
    mockRemote = MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(mockRemote);
  });

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tModel = ProfileModel(
    id: 'test-user-uuid',
    name: 'Ronak Jeengar',
    email: 'ronak@example.com',
    username: 'ronak',
    avatarUrl: 'https://cdn.hums.audio/avatars/ronak.webp',
    bio: 'Audio engineer & software developer',
    createdAt: testDate,
    updatedAt: testDate,
  );

  group('ProfileRepositoryImpl Tests', () {
    test('getProfile returns ProfileEntity on success', () async {
      when(() => mockRemote.getProfile()).thenAnswer((_) async => tModel);

      final result = await repository.getProfile();

      expect(result.id, 'test-user-uuid');
      expect(result.name, 'Ronak Jeengar');
      expect(result.email, 'ronak@example.com');
      expect(result.avatarUrl, 'https://cdn.hums.audio/avatars/ronak.webp');
      expect(result.bio, 'Audio engineer & software developer');
      verify(() => mockRemote.getProfile()).called(1);
    });

    test('updateProfile passes parameters and returns updated ProfileEntity', () async {
      final updatedModel = ProfileModel(
        id: 'test-user-uuid',
        name: 'Ronak Updated',
        email: 'newronak@example.com',
        username: 'ronak',
        avatarUrl: 'https://cdn.hums.audio/avatars/ronak.webp',
        bio: 'Updated bio',
        createdAt: testDate,
        updatedAt: testDate,
      );

      when(() => mockRemote.updateProfile(
            name: 'Ronak Updated',
            email: 'newronak@example.com',
            bio: 'Updated bio',
          )).thenAnswer((_) async => updatedModel);

      final result = await repository.updateProfile(
        name: 'Ronak Updated',
        email: 'newronak@example.com',
        bio: 'Updated bio',
      );

      expect(result.name, 'Ronak Updated');
      expect(result.email, 'newronak@example.com');
      expect(result.bio, 'Updated bio');
      verify(() => mockRemote.updateProfile(
            name: 'Ronak Updated',
            email: 'newronak@example.com',
            bio: 'Updated bio',
          )).called(1);
    });

    test('uploadAvatar passes file path and returns updated ProfileEntity', () async {
      when(() => mockRemote.uploadAvatar('path/to/avatar.png'))
          .thenAnswer((_) async => tModel);

      final result = await repository.uploadAvatar('path/to/avatar.png');

      expect(result.avatarUrl, 'https://cdn.hums.audio/avatars/ronak.webp');
      verify(() => mockRemote.uploadAvatar('path/to/avatar.png')).called(1);
    });

    test('removeAvatar calls remote and returns updated ProfileEntity with null avatar', () async {
      final noAvatarModel = ProfileModel(
        id: 'test-user-uuid',
        name: 'Ronak Jeengar',
        email: 'ronak@example.com',
        avatarUrl: null,
        bio: 'Audio engineer & software developer',
        createdAt: testDate,
        updatedAt: testDate,
      );

      when(() => mockRemote.removeAvatar())
          .thenAnswer((_) async => noAvatarModel);

      final result = await repository.removeAvatar();

      expect(result.avatarUrl, isNull);
      verify(() => mockRemote.removeAvatar()).called(1);
    });

    test('rethrows ApiException when remote call fails', () async {
      when(() => mockRemote.getProfile()).thenThrow(
        const ApiException(code: 'UNAUTHORIZED', message: 'Token expired', statusCode: 401),
      );

      expect(
        () => repository.getProfile(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
