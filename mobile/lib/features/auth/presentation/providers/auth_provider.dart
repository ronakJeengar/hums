import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:hums_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:hums_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';

final authStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(authStorageProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState.initial());

  Future<void> checkAuthStatus() async {
    state = const AuthState.loading();
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );
      state = AuthState.authenticated(user);
      return true;
    } on ApiException catch (e) {
      state = AuthState.failure(message: e.message, code: e.code);
      return false;
    } catch (e) {
      state = const AuthState.failure(
        message: 'Unable to connect. Please check your internet connection.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final user = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      state = AuthState.authenticated(user);
      return true;
    } on ApiException catch (e) {
      state = AuthState.failure(message: e.message, code: e.code);
      return false;
    } catch (e) {
      state = const AuthState.failure(
        message: 'Unable to connect. Please check your internet connection.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthState.loading();
    try {
      await _repository.logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    try {
      await _repository.requestPasswordReset(email);
      return true;
    } on ApiException catch (e) {
      state = AuthState.failure(message: e.message, code: e.code);
      return false;
    } catch (e) {
      state = const AuthState.failure(
        message: 'Unable to request password reset. Please try again later.',
      );
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _repository.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      state = const AuthState.unauthenticated();
      return true;
    } on ApiException catch (e) {
      state = AuthState.failure(message: e.message, code: e.code);
      return false;
    } catch (e) {
      state = const AuthState.failure(
        message: 'Failed to reset password. Please try again.',
      );
      return false;
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
