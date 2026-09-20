import 'package:hums_mobile/features/auth/domain/entities/auth_tokens_entity.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> register({
    required String name,
    required String email,
    required String password,
  });

  Future<UserEntity> login({
    required String email,
    required String password,
  });

  Future<AuthTokensEntity> refreshToken();

  Future<void> logout();

  Future<UserEntity?> getCurrentUser();

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<bool> isAuthenticated();
}
