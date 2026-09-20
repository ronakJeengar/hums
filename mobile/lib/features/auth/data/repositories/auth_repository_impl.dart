import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:hums_mobile/features/auth/data/models/user_model.dart';
import 'package:hums_mobile/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<UserEntity> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.register(
      name: name,
      email: email,
      password: password,
    );

    final accessToken = result['access_token'] as String;
    final refreshToken = result['refresh_token'] as String;
    final userModel = UserModel.fromJson(result['user'] as Map<String, dynamic>);

    await _localDataSource.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _localDataSource.saveUser(userModel);

    return userModel.toEntity();
  }

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    final result = await _remoteDataSource.login(
      email: email,
      password: password,
    );

    final accessToken = result['access_token'] as String;
    final refreshToken = result['refresh_token'] as String;
    final userModel = UserModel.fromJson(result['user'] as Map<String, dynamic>);

    await _localDataSource.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _localDataSource.saveUser(userModel);

    return userModel.toEntity();
  }

  @override
  Future<AuthTokensEntity> refreshToken() async {
    final currentRefreshToken = await _localDataSource.getRefreshToken();
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      throw const ApiException(
        code: 'INVALID_REFRESH_TOKEN',
        message: 'No refresh token available.',
        statusCode: 401,
      );
    }

    try {
      final tokens = await _remoteDataSource.refreshToken(currentRefreshToken);
      await _localDataSource.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return tokens.toEntity();
    } catch (e) {
      await _localDataSource.clearAuth();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _localDataSource.getRefreshToken();
      await _remoteDataSource.logout(refreshToken: refreshToken);
    } catch (_) {
      // Ignore network errors during logout to ensure local cleanup succeeds
    } finally {
      await _localDataSource.clearAuth();
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final hasSession = await _localDataSource.hasValidSession();
    if (!hasSession) return null;

    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      await _localDataSource.saveUser(userModel);
      return userModel.toEntity();
    } catch (_) {
      // Fallback to locally cached user if network fails
      final cachedUser = await _localDataSource.getUser();
      return cachedUser?.toEntity();
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _remoteDataSource.requestPasswordReset(email);
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _remoteDataSource.resetPassword(
      token: token,
      newPassword: newPassword,
    );
    await _localDataSource.clearAuth();
  }

  @override
  Future<bool> isAuthenticated() async {
    return await _localDataSource.hasValidSession();
  }
}
