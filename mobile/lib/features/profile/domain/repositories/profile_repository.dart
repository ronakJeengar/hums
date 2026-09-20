import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  /// Fetches the authenticated user's profile.
  Future<ProfileEntity> getProfile();

  /// Updates profile information (name, email, bio).
  Future<ProfileEntity> updateProfile({
    String? name,
    String? email,
    String? bio,
  });

  /// Uploads and sets a new avatar for the user.
  Future<ProfileEntity> uploadAvatar(String filePath);

  /// Removes the user's avatar image.
  Future<ProfileEntity> removeAvatar();
}
