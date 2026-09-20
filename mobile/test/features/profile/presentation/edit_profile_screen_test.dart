import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/widgets/hums_button.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/screens/edit_profile_screen.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepository;

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tProfile = ProfileEntity(
    id: 'test-user-id',
    name: 'Ronak Jeengar',
    email: 'ronak@example.com',
    avatarUrl: null,
    bio: 'Audio enthusiast',
    createdAt: testDate,
    updatedAt: testDate,
  );

  setUp(() {
    mockRepository = MockProfileRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: const MaterialApp(
        home: EditProfileScreen(),
      ),
    );
  }

  group('EditProfileScreen Widget Tests', () {
    testWidgets('renders all form fields and Save Changes button',
        (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('validates required name and email on empty submit',
        (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      await tester.pumpWidget(createWidgetUnderTest());

      // Clear the text fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), ''); // Name
      await tester.enterText(textFields.at(1), ''); // Email

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('validates name minimum length', (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      await tester.pumpWidget(createWidgetUnderTest());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'a'); // 1 char
      await tester.enterText(textFields.at(1), 'valid@example.com');

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      await tester.pumpWidget(createWidgetUnderTest());

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Valid Name');
      await tester.enterText(textFields.at(1), 'not-an-email');

      await tester.tap(find.byType(HumsButton));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });
}
