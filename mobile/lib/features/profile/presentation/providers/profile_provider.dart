import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_exception.dart';
import 'package:hums_mobile/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hums_mobile/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:hums_mobile/features/profile/presentation/states/profile_state.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRemoteDataSourceImpl(apiClient);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(remoteDataSource);
});

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(const ProfileState.initial());

  Future<void> loadProfile() async {
    state = const ProfileState.loading();
    try {
      final profile = await _repository.getProfile();
      state = ProfileState.loaded(profile);
    } on ApiException catch (e) {
      state = ProfileState.failure(e.message, code: e.code);
    } catch (e) {
      state = ProfileState.failure(e.toString());
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async {
    final currentProfile = state.profile;
    if (currentProfile != null) {
      state = ProfileState.updating(currentProfile);
    } else {
      state = const ProfileState.loading();
    }

    try {
      final updated = await _repository.updateProfile(
        name: name,
        email: email,
        bio: bio,
      );
      state = ProfileState.loaded(updated);
      return true;
    } on ApiException catch (e) {
      state = ProfileState.failure(
        e.message,
        code: e.code,
        previousProfile: currentProfile,
      );
      return false;
    } catch (e) {
      state = ProfileState.failure(
        e.toString(),
        previousProfile: currentProfile,
      );
      return false;
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    final currentProfile = state.profile;
    if (currentProfile != null) {
      state = ProfileState.uploadingAvatar(currentProfile);
    } else {
      state = const ProfileState.loading();
    }

    try {
      final updated = await _repository.uploadAvatar(filePath);
      state = ProfileState.loaded(updated);
      return true;
    } on ApiException catch (e) {
      state = ProfileState.failure(
        e.message,
        code: e.code,
        previousProfile: currentProfile,
      );
      return false;
    } catch (e) {
      state = ProfileState.failure(
        e.toString(),
        previousProfile: currentProfile,
      );
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    final currentProfile = state.profile;
    if (currentProfile != null) {
      state = ProfileState.updating(currentProfile);
    } else {
      state = const ProfileState.loading();
    }

    try {
      final updated = await _repository.removeAvatar();
      state = ProfileState.loaded(updated);
      return true;
    } on ApiException catch (e) {
      state = ProfileState.failure(
        e.message,
        code: e.code,
        previousProfile: currentProfile,
      );
      return false;
    } catch (e) {
      state = ProfileState.failure(
        e.toString(),
        previousProfile: currentProfile,
      );
      return false;
    }
  }
}
