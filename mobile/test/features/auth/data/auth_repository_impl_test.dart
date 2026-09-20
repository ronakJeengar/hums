import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:hums_mobile/features/auth/data/models/auth_tokens_model.dart';
import 'package:hums_mobile/features/auth/data/models/user_model.dart';
import 'package:hums_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockAuthRemoteDataSource mockRemote;
  late AuthLocalDataSource localDataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    mockRemote = MockAuthRemoteDataSource();
    localDataSource = AuthLocalDataSourceImpl(const FlutterSecureStorage());
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: localDataSource,
    );
  });

  group('AuthRepositoryImpl Tests', () {
    const testUser = {
      'id': '11111111-1111-1111-1111-111111111111',
      'name': 'Test User',
      'email': 'test@example.com',
      'username': 'testuser',
      'full_name': 'Test User',
      'is_active': true,
      'is_verified': false,
    };

    const loginResponse = {
      'access_token': 'mock-access-token',
      'refresh_token': 'mock-refresh-token',
      'token_type': 'Bearer',
      'expires_in': 1800,
      'user': testUser,
    };

    test('login stores tokens and cached user upon success', () async {
      when(() => mockRemote.login(
            email: 'test@example.com',
            password: 'password123',
          )).thenAnswer((_) async => loginResponse);

      final user = await repository.login(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(user.id, '11111111-1111-1111-1111-111111111111');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');

      // Verify token persistence
      final accessToken = await localDataSource.getAccessToken();
      final refreshToken = await localDataSource.getRefreshToken();
      final cachedUser = await localDataSource.getUser();

      expect(accessToken, 'mock-access-token');
      expect(refreshToken, 'mock-refresh-token');
      expect(cachedUser?.email, 'test@example.com');
    });

    test('register stores tokens and cached user upon success', () async {
      when(() => mockRemote.register(
            name: 'New User',
            email: 'new@example.com',
            password: 'password123',
          )).thenAnswer((_) async => {
            ...loginResponse,
            'user': {
              ...testUser,
              'name': 'New User',
              'email': 'new@example.com',
            }
          });

      final user = await repository.register(
        name: 'New User',
        email: 'new@example.com',
        password: 'password123',
      );

      expect(user.name, 'New User');
      expect(user.email, 'new@example.com');

      final accessToken = await localDataSource.getAccessToken();
      expect(accessToken, 'mock-access-token');
    });

    test('refreshToken exchanges token and persists new credentials', () async {
      // Seed initial tokens
      await localDataSource.saveTokens(
        accessToken: 'initial-access',
        refreshToken: 'initial-refresh',
      );

      when(() => mockRemote.refreshToken('initial-refresh')).thenAnswer(
        (_) async => const AuthTokensModel(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
          tokenType: 'Bearer',
          expiresIn: 1800,
        ),
      );

      final newTokens = await repository.refreshToken();
      expect(newTokens.accessToken, 'new-access-token');
      expect(newTokens.refreshToken, 'new-refresh-token');

      expect(await localDataSource.getAccessToken(), 'new-access-token');
      expect(await localDataSource.getRefreshToken(), 'new-refresh-token');
    });

    test('refreshToken clears auth if remote call throws', () async {
      await localDataSource.saveTokens(
        accessToken: 'initial-access',
        refreshToken: 'revoked-refresh',
      );

      when(() => mockRemote.refreshToken('revoked-refresh')).thenThrow(
        const ApiException(code: 'REFRESH_TOKEN_REVOKED', message: 'Revoked', statusCode: 401),
      );

      await expectLater(
        repository.refreshToken(),
        throwsA(isA<ApiException>()),
      );

      // Verify tokens were cleared
      expect(await localDataSource.getAccessToken(), isNull);
      expect(await localDataSource.getRefreshToken(), isNull);
    });

    test('logout clears local storage and calls remote logout', () async {
      await localDataSource.saveTokens(
        accessToken: 'some-access',
        refreshToken: 'some-refresh',
      );
      when(() => mockRemote.logout(refreshToken: 'some-refresh'))
          .thenAnswer((_) async {});

      await repository.logout();

      expect(await localDataSource.getAccessToken(), isNull);
      expect(await localDataSource.getRefreshToken(), isNull);
      verify(() => mockRemote.logout(refreshToken: 'some-refresh')).called(1);
    });

    test('getCurrentUser falls back to cached user when network fails', () async {
      await localDataSource.saveTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      await localDataSource.saveUser(UserModel.fromJson(testUser));

      when(() => mockRemote.getCurrentUser()).thenThrow(
        ApiException.network('No internet connection'),
      );

      final user = await repository.getCurrentUser();
      expect(user, isNotNull);
      expect(user?.email, 'test@example.com');
    });
  });
}
