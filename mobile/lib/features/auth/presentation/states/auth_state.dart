import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(UserEntity user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.failure({
    required String message,
    String? code,
  }) = _Failure;
}

extension AuthStateX on AuthState {
  bool get isLoading => this is _Loading;
  bool get isAuthenticated => this is _Authenticated;
  UserEntity? get user => this is _Authenticated ? (this as _Authenticated).user : null;
  String? get errorMessage => this is _Failure ? (this as _Failure).message : null;
  String? get errorCode => this is _Failure ? (this as _Failure).code : null;
}
