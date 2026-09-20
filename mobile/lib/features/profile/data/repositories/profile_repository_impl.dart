import 'package:hums_mobile/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';
import 'package:hums_mobile/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  const ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<ProfileEntity> getProfile() async {
    final model = await _remoteDataSource.getProfile();
    return model.toEntity();
  }

  @override
  Future<ProfileEntity> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async {
    final model = await _remoteDataSource.updateProfile(
      name: name,
      email: email,
      bio: bio,
    );
    return model.toEntity();
  }

  @override
  Future<ProfileEntity> uploadAvatar(String filePath) async {
    final model = await _remoteDataSource.uploadAvatar(filePath);
    return model.toEntity();
  }

  @override
  Future<ProfileEntity> removeAvatar() async {
    final model = await _remoteDataSource.removeAvatar();
    return model.toEntity();
  }
}
