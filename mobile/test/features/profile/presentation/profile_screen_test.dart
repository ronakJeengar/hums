import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/screens/profile_screen.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepository;

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tProfile = ProfileEntity(
    id: 'test-user-id',
    name: 'Ronak Jeengar',
    email: 'ronak@example.com',
    avatarUrl: null,
    bio: 'Audio enthusiast & developer',
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
        home: ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen Widget Tests', () {
    testWidgets('renders profile details and initials when avatarUrl is null',
        (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Ronak Jeengar'), findsOneWidget);
      expect(find.text('ronak@example.com'), findsOneWidget);
      expect(find.text('Audio enthusiast & developer'), findsOneWidget);
      expect(find.text('RJ'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('displays retry button on failure',
        (WidgetTester tester) async {
      when(() => mockRepository.getProfile()).thenThrow(Exception('Server error'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Could not load profile'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
