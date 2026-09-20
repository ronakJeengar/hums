// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileState()';
}


}

/// @nodoc
class $ProfileStateCopyWith<$Res>  {
$ProfileStateCopyWith(ProfileState _, $Res Function(ProfileState) __);
}


/// Adds pattern-matching-related methods to [ProfileState].
extension ProfileStatePatterns on ProfileState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Initial value)?  initial,TResult Function( _Loading value)?  loading,TResult Function( _Loaded value)?  loaded,TResult Function( _Updating value)?  updating,TResult Function( _UploadingAvatar value)?  uploadingAvatar,TResult Function( _Failure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _Loading() when loading != null:
return loading(_that);case _Loaded() when loaded != null:
return loaded(_that);case _Updating() when updating != null:
return updating(_that);case _UploadingAvatar() when uploadingAvatar != null:
return uploadingAvatar(_that);case _Failure() when failure != null:
return failure(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Initial value)  initial,required TResult Function( _Loading value)  loading,required TResult Function( _Loaded value)  loaded,required TResult Function( _Updating value)  updating,required TResult Function( _UploadingAvatar value)  uploadingAvatar,required TResult Function( _Failure value)  failure,}){
final _that = this;
switch (_that) {
case _Initial():
return initial(_that);case _Loading():
return loading(_that);case _Loaded():
return loaded(_that);case _Updating():
return updating(_that);case _UploadingAvatar():
return uploadingAvatar(_that);case _Failure():
return failure(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Initial value)?  initial,TResult? Function( _Loading value)?  loading,TResult? Function( _Loaded value)?  loaded,TResult? Function( _Updating value)?  updating,TResult? Function( _UploadingAvatar value)?  uploadingAvatar,TResult? Function( _Failure value)?  failure,}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _Loading() when loading != null:
return loading(_that);case _Loaded() when loaded != null:
return loaded(_that);case _Updating() when updating != null:
return updating(_that);case _UploadingAvatar() when uploadingAvatar != null:
return uploadingAvatar(_that);case _Failure() when failure != null:
return failure(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function()?  loading,TResult Function( ProfileEntity profile)?  loaded,TResult Function( ProfileEntity profile)?  updating,TResult Function( ProfileEntity profile)?  uploadingAvatar,TResult Function( String message,  String? code,  ProfileEntity? previousProfile)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _Loading() when loading != null:
return loading();case _Loaded() when loaded != null:
return loaded(_that.profile);case _Updating() when updating != null:
return updating(_that.profile);case _UploadingAvatar() when uploadingAvatar != null:
return uploadingAvatar(_that.profile);case _Failure() when failure != null:
return failure(_that.message,_that.code,_that.previousProfile);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function()  loading,required TResult Function( ProfileEntity profile)  loaded,required TResult Function( ProfileEntity profile)  updating,required TResult Function( ProfileEntity profile)  uploadingAvatar,required TResult Function( String message,  String? code,  ProfileEntity? previousProfile)  failure,}) {final _that = this;
switch (_that) {
case _Initial():
return initial();case _Loading():
return loading();case _Loaded():
return loaded(_that.profile);case _Updating():
return updating(_that.profile);case _UploadingAvatar():
return uploadingAvatar(_that.profile);case _Failure():
return failure(_that.message,_that.code,_that.previousProfile);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function()?  loading,TResult? Function( ProfileEntity profile)?  loaded,TResult? Function( ProfileEntity profile)?  updating,TResult? Function( ProfileEntity profile)?  uploadingAvatar,TResult? Function( String message,  String? code,  ProfileEntity? previousProfile)?  failure,}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _Loading() when loading != null:
return loading();case _Loaded() when loaded != null:
return loaded(_that.profile);case _Updating() when updating != null:
return updating(_that.profile);case _UploadingAvatar() when uploadingAvatar != null:
return uploadingAvatar(_that.profile);case _Failure() when failure != null:
return failure(_that.message,_that.code,_that.previousProfile);case _:
  return null;

}
}

}

/// @nodoc


class _Initial implements ProfileState {
  const _Initial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Initial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileState.initial()';
}


}




/// @nodoc


class _Loading implements ProfileState {
  const _Loading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Loading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileState.loading()';
}


}




/// @nodoc


class _Loaded implements ProfileState {
  const _Loaded(this.profile);
  

 final  ProfileEntity profile;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoadedCopyWith<_Loaded> get copyWith => __$LoadedCopyWithImpl<_Loaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Loaded&&(identical(other.profile, profile) || other.profile == profile));
}


@override
int get hashCode => Object.hash(runtimeType,profile);

@override
String toString() {
  return 'ProfileState.loaded(profile: $profile)';
}


}

/// @nodoc
abstract mixin class _$LoadedCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$LoadedCopyWith(_Loaded value, $Res Function(_Loaded) _then) = __$LoadedCopyWithImpl;
@useResult
$Res call({
 ProfileEntity profile
});




}
/// @nodoc
class __$LoadedCopyWithImpl<$Res>
    implements _$LoadedCopyWith<$Res> {
  __$LoadedCopyWithImpl(this._self, this._then);

  final _Loaded _self;
  final $Res Function(_Loaded) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? profile = null,}) {
  return _then(_Loaded(
null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as ProfileEntity,
  ));
}


}

/// @nodoc


class _Updating implements ProfileState {
  const _Updating(this.profile);
  

 final  ProfileEntity profile;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdatingCopyWith<_Updating> get copyWith => __$UpdatingCopyWithImpl<_Updating>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Updating&&(identical(other.profile, profile) || other.profile == profile));
}


@override
int get hashCode => Object.hash(runtimeType,profile);

@override
String toString() {
  return 'ProfileState.updating(profile: $profile)';
}


}

/// @nodoc
abstract mixin class _$UpdatingCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$UpdatingCopyWith(_Updating value, $Res Function(_Updating) _then) = __$UpdatingCopyWithImpl;
@useResult
$Res call({
 ProfileEntity profile
});




}
/// @nodoc
class __$UpdatingCopyWithImpl<$Res>
    implements _$UpdatingCopyWith<$Res> {
  __$UpdatingCopyWithImpl(this._self, this._then);

  final _Updating _self;
  final $Res Function(_Updating) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? profile = null,}) {
  return _then(_Updating(
null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as ProfileEntity,
  ));
}


}

/// @nodoc


class _UploadingAvatar implements ProfileState {
  const _UploadingAvatar(this.profile);
  

 final  ProfileEntity profile;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UploadingAvatarCopyWith<_UploadingAvatar> get copyWith => __$UploadingAvatarCopyWithImpl<_UploadingAvatar>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UploadingAvatar&&(identical(other.profile, profile) || other.profile == profile));
}


@override
int get hashCode => Object.hash(runtimeType,profile);

@override
String toString() {
  return 'ProfileState.uploadingAvatar(profile: $profile)';
}


}

/// @nodoc
abstract mixin class _$UploadingAvatarCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$UploadingAvatarCopyWith(_UploadingAvatar value, $Res Function(_UploadingAvatar) _then) = __$UploadingAvatarCopyWithImpl;
@useResult
$Res call({
 ProfileEntity profile
});




}
/// @nodoc
class __$UploadingAvatarCopyWithImpl<$Res>
    implements _$UploadingAvatarCopyWith<$Res> {
  __$UploadingAvatarCopyWithImpl(this._self, this._then);

  final _UploadingAvatar _self;
  final $Res Function(_UploadingAvatar) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? profile = null,}) {
  return _then(_UploadingAvatar(
null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as ProfileEntity,
  ));
}


}

/// @nodoc


class _Failure implements ProfileState {
  const _Failure(this.message, {this.code, this.previousProfile});
  

 final  String message;
 final  String? code;
 final  ProfileEntity? previousProfile;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FailureCopyWith<_Failure> get copyWith => __$FailureCopyWithImpl<_Failure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Failure&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&(identical(other.previousProfile, previousProfile) || other.previousProfile == previousProfile));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,previousProfile);

@override
String toString() {
  return 'ProfileState.failure(message: $message, code: $code, previousProfile: $previousProfile)';
}


}

/// @nodoc
abstract mixin class _$FailureCopyWith<$Res> implements $ProfileStateCopyWith<$Res> {
  factory _$FailureCopyWith(_Failure value, $Res Function(_Failure) _then) = __$FailureCopyWithImpl;
@useResult
$Res call({
 String message, String? code, ProfileEntity? previousProfile
});




}
/// @nodoc
class __$FailureCopyWithImpl<$Res>
    implements _$FailureCopyWith<$Res> {
  __$FailureCopyWithImpl(this._self, this._then);

  final _Failure _self;
  final $Res Function(_Failure) _then;

/// Create a copy of ProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = freezed,Object? previousProfile = freezed,}) {
  return _then(_Failure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,previousProfile: freezed == previousProfile ? _self.previousProfile : previousProfile // ignore: cast_nullable_to_non_nullable
as ProfileEntity?,
  ));
}


}

// dart format on
