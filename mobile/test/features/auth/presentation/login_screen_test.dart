import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders all expected UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign in to your Hums account'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are submitted empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('toggles password visibility when eye icon tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final passwordFieldFinder = find.byType(TextField).last;
      TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue);

      // Tap toggle
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isFalse);
    });

    testWidgets('submits login when valid email and password entered',
        (WidgetTester tester) async {
      when(() => mockRepository.login(
            email: 'test@example.com',
            password: 'password123',
          )).thenAnswer(
        (_) async => const UserEntity(
          id: 'user-1',
          name: 'Test',
          email: 'test@example.com',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.byType(TextField).first;
      final passwordField = find.byType(TextField).last;

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      verify(() => mockRepository.login(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });
  });
}
