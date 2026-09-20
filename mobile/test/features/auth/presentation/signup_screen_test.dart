import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';
import 'package:hums_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:hums_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:hums_mobile/features/auth/presentation/screens/signup_screen.dart';
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
        home: SignupScreen(),
      ),
    );
  }

  group('SignupScreen Widget Tests', () {
    testWidgets('renders all expected signup form fields', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('validates required fields on empty submit', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('validates minimum password length', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final nameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'short');

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('submits registration when form is valid', (WidgetTester tester) async {
      when(() => mockRepository.register(
            name: 'Ronak',
            email: 'ronak@example.com',
            password: 'password123',
          )).thenAnswer(
        (_) async => const UserEntity(
          id: 'user-2',
          name: 'Ronak',
          email: 'ronak@example.com',
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      final nameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await tester.enterText(nameField, 'Ronak');
      await tester.enterText(emailField, 'ronak@example.com');
      await tester.enterText(passwordField, 'password123');

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      verify(() => mockRepository.register(
            name: 'Ronak',
            email: 'ronak@example.com',
            password: 'password123',
          )).called(1);
    });
  });
}
