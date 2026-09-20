import 'package:dio/dio.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/profile/data/models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();

  Future<ProfileModel> updateProfile({
    String? name,
    String? email,
    String? bio,
  });

  Future<ProfileModel> uploadAvatar(String filePath);

  Future<ProfileModel> removeAvatar();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _apiClient;

  const ProfileRemoteDataSourceImpl(this._apiClient);

  @override
  Future<ProfileModel> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.profile);
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return ProfileModel.fromJson(data);
  }

  @override
  Future<ProfileModel> updateProfile({
    String? name,
    String? email,
    String? bio,
  }) async {
    final requestData = <String, dynamic>{};
    if (name != null) requestData['name'] = name;
    if (email != null) requestData['email'] = email;
    if (bio != null) requestData['bio'] = bio;

    final response = await _apiClient.patch(
      ApiEndpoints.profile,
      data: requestData,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return ProfileModel.fromJson(data);
  }

  @override
  Future<ProfileModel> uploadAvatar(String filePath) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    final response = await _apiClient.post(
      ApiEndpoints.avatar,
      data: formData,
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return ProfileModel.fromJson(data);
  }

  @override
  Future<ProfileModel> removeAvatar() async {
    final response = await _apiClient.delete(ApiEndpoints.avatar);
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;
    return ProfileModel.fromJson(data);
  }
}
