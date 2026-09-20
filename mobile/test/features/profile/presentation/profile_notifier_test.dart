import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:hums_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository mockRepository;
  late ProfileNotifier notifier;

  final testDate = DateTime(2026, 9, 20, 12, 0, 0);
  final tProfile = ProfileEntity(
    id: 'user-uuid-123',
    name: 'Ronak Jeengar',
    email: 'ronak@example.com',
    avatarUrl: 'https://cdn.hums.audio/avatars/ronak.webp',
    bio: 'Audio engineer',
    createdAt: testDate,
    updatedAt: testDate,
  );

  setUp(() {
    mockRepository = MockProfileRepository();
    notifier = ProfileNotifier(mockRepository);
  });

  group('ProfileNotifier State Transitions', () {
    test('initial state is ProfileState.initial()', () {
      expect(notifier.state, const ProfileState.initial());
    });

    test('loadProfile transitions to loading then loaded on success', () async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

      final states = <ProfileState>[];
      notifier.addListener(states.add);

      await notifier.loadProfile();

      expect(states, [
        const ProfileState.initial(),
        const ProfileState.loading(),
        ProfileState.loaded(tProfile),
      ]);
    });

    test('loadProfile transitions to failure on error', () async {
      when(() => mockRepository.getProfile()).thenThrow(
        const ApiException(code: 'NOT_FOUND', message: 'User not found', statusCode: 404),
      );

      final states = <ProfileState>[];
      notifier.addListener(states.add);

      await notifier.loadProfile();

      expect(states, [
        const ProfileState.initial(),
        const ProfileState.loading(),
        const ProfileState.failure('User not found', code: 'NOT_FOUND'),
      ]);
    });

    test('updateProfile transitions to updating then loaded on success', () async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);
      await notifier.loadProfile();

      final updatedProfile = tProfile.copyWith(name: 'Ronak Updated');
      when(() => mockRepository.updateProfile(name: 'Ronak Updated', email: 'ronak@example.com', bio: 'Audio engineer'))
          .thenAnswer((_) async => updatedProfile);

      final states = <ProfileState>[];
      notifier.addListener(states.add);

      final success = await notifier.updateProfile(
        name: 'Ronak Updated',
        email: 'ronak@example.com',
        bio: 'Audio engineer',
      );

      expect(success, isTrue);
      expect(states, [
        ProfileState.loaded(tProfile),
        ProfileState.updating(tProfile),
        ProfileState.loaded(updatedProfile),
      ]);
    });

    test('uploadAvatar transitions to uploadingAvatar then loaded on success', () async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);
      await notifier.loadProfile();

      final newAvatarProfile = tProfile.copyWith(avatarUrl: 'https://cdn.hums.audio/avatars/new.webp');
      when(() => mockRepository.uploadAvatar('new_path.jpg'))
          .thenAnswer((_) async => newAvatarProfile);

      final states = <ProfileState>[];
      notifier.addListener(states.add);

      final success = await notifier.uploadAvatar('new_path.jpg');

      expect(success, isTrue);
      expect(states, [
        ProfileState.loaded(tProfile),
        ProfileState.uploadingAvatar(tProfile),
        ProfileState.loaded(newAvatarProfile),
      ]);
    });

    test('removeAvatar transitions to updating then loaded with null avatar', () async {
      when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);
      await notifier.loadProfile();

      final noAvatarProfile = tProfile.copyWith(clearAvatar: true);
      when(() => mockRepository.removeAvatar())
          .thenAnswer((_) async => noAvatarProfile);

      final states = <ProfileState>[];
      notifier.addListener(states.add);

      final success = await notifier.removeAvatar();

      expect(success, isTrue);
      expect(states, [
        ProfileState.loaded(tProfile),
        ProfileState.updating(tProfile),
        ProfileState.loaded(noAvatarProfile),
      ]);
    });
  });
}
