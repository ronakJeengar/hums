import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/states/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late AuthNotifier notifier;

  setUp(() {
    mockRepository = MockAuthRepository();
    notifier = AuthNotifier(mockRepository);
  });

  const testUser = UserEntity(
    id: 'user-123',
    name: 'Ronak',
    email: 'ronak@example.com',
  );

  group('AuthNotifier State Transitions', () {
    test('initial state is AuthState.initial()', () {
      expect(notifier.state, const AuthState.initial());
    });

    test('login sets authenticated state on success', () async {
      when(() => mockRepository.login(
            email: 'ronak@example.com',
            password: 'password123',
          )).thenAnswer((_) async => testUser);

      final success = await notifier.login(
        email: 'ronak@example.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(notifier.state, const AuthState.authenticated(testUser));
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user?.name, 'Ronak');
    });

    test('login sets failure state on invalid credentials', () async {
      when(() => mockRepository.login(
            email: 'ronak@example.com',
            password: 'wrongpassword',
          )).thenThrow(
        const ApiException(
          code: 'INVALID_CREDENTIALS',
          message: 'Invalid email or password',
          statusCode: 401,
        ),
      );

      final success = await notifier.login(
        email: 'ronak@example.com',
        password: 'wrongpassword',
      );

      expect(success, isFalse);
      expect(notifier.state.errorMessage, 'Invalid email or password');
      expect(notifier.state.errorCode, 'INVALID_CREDENTIALS');
      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('register sets authenticated state on success', () async {
      when(() => mockRepository.register(
            name: 'Ronak',
            email: 'ronak@example.com',
            password: 'password123',
          )).thenAnswer((_) async => testUser);

      final success = await notifier.register(
        name: 'Ronak',
        email: 'ronak@example.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(notifier.state, const AuthState.authenticated(testUser));
    });

    test('register sets failure state on duplicate email', () async {
      when(() => mockRepository.register(
            name: 'Ronak',
            email: 'ronak@example.com',
            password: 'password123',
          )).thenThrow(
        const ApiException(
          code: 'EMAIL_ALREADY_EXISTS',
          message: 'An account with this email address already exists',
          statusCode: 409,
        ),
      );

      final success = await notifier.register(
        name: 'Ronak',
        email: 'ronak@example.com',
        password: 'password123',
      );

      expect(success, isFalse);
      expect(notifier.state.errorCode, 'EMAIL_ALREADY_EXISTS');
    });

    test('logout transitions to unauthenticated state', () async {
      when(() => mockRepository.logout()).thenAnswer((_) async {});

      await notifier.logout();

      expect(notifier.state, const AuthState.unauthenticated());
      expect(notifier.state.isAuthenticated, isFalse);
    });

    test('checkAuthStatus sets authenticated if user is cached', () async {
      when(() => mockRepository.getCurrentUser()).thenAnswer((_) async => testUser);

      await notifier.checkAuthStatus();

      expect(notifier.state, const AuthState.authenticated(testUser));
    });

    test('checkAuthStatus sets unauthenticated if no user found', () async {
      when(() => mockRepository.getCurrentUser()).thenAnswer((_) async => null);

      await notifier.checkAuthStatus();

      expect(notifier.state, const AuthState.unauthenticated());
    });
  });
}
