import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hums_mobile/features/profile/domain/entities/profile_entity.dart';

part 'profile_state.freezed.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading() = _Loading;
  const factory ProfileState.loaded(ProfileEntity profile) = _Loaded;
  const factory ProfileState.updating(ProfileEntity profile) = _Updating;
  const factory ProfileState.uploadingAvatar(ProfileEntity profile) = _UploadingAvatar;
  const factory ProfileState.failure(
    String message, {
    String? code,
    ProfileEntity? previousProfile,
  }) = _Failure;
}

extension ProfileStateX on ProfileState {
  bool get isLoading => this is _Loading;
  bool get isUpdating => this is _Updating;
  bool get isUploadingAvatar => this is _UploadingAvatar;
  bool get isBusy => isLoading || isUpdating || isUploadingAvatar;

  ProfileEntity? get profile => whenOrNull(
        loaded: (profile) => profile,
        updating: (profile) => profile,
        uploadingAvatar: (profile) => profile,
        failure: (_, _, previousProfile) => previousProfile,
      );

  String? get errorMessage => whenOrNull(
        failure: (message, _, _) => message,
      );

  String? get errorCode => whenOrNull(
        failure: (_, code, _) => code,
      );
}
