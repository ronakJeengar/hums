// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_upload_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioUploadState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioUploadState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioUploadState()';
}


}

/// @nodoc
class $AudioUploadStateCopyWith<$Res>  {
$AudioUploadStateCopyWith(AudioUploadState _, $Res Function(AudioUploadState) __);
}


/// Adds pattern-matching-related methods to [AudioUploadState].
extension AudioUploadStatePatterns on AudioUploadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Initial value)?  initial,TResult Function( _FileSelected value)?  fileSelected,TResult Function( _Uploading value)?  uploading,TResult Function( _Uploaded value)?  uploaded,TResult Function( _Failure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _FileSelected() when fileSelected != null:
return fileSelected(_that);case _Uploading() when uploading != null:
return uploading(_that);case _Uploaded() when uploaded != null:
return uploaded(_that);case _Failure() when failure != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Initial value)  initial,required TResult Function( _FileSelected value)  fileSelected,required TResult Function( _Uploading value)  uploading,required TResult Function( _Uploaded value)  uploaded,required TResult Function( _Failure value)  failure,}){
final _that = this;
switch (_that) {
case _Initial():
return initial(_that);case _FileSelected():
return fileSelected(_that);case _Uploading():
return uploading(_that);case _Uploaded():
return uploaded(_that);case _Failure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Initial value)?  initial,TResult? Function( _FileSelected value)?  fileSelected,TResult? Function( _Uploading value)?  uploading,TResult? Function( _Uploaded value)?  uploaded,TResult? Function( _Failure value)?  failure,}){
final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial(_that);case _FileSelected() when fileSelected != null:
return fileSelected(_that);case _Uploading() when uploading != null:
return uploading(_that);case _Uploaded() when uploaded != null:
return uploaded(_that);case _Failure() when failure != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  initial,TResult Function( String filePath,  String fileName,  int fileSizeBytes)?  fileSelected,TResult Function( String filePath,  String fileName,  int fileSizeBytes,  double progress)?  uploading,TResult Function( TrackEntity track)?  uploaded,TResult Function( String message,  String? code,  String? filePath,  String? fileName,  int? fileSizeBytes)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _FileSelected() when fileSelected != null:
return fileSelected(_that.filePath,_that.fileName,_that.fileSizeBytes);case _Uploading() when uploading != null:
return uploading(_that.filePath,_that.fileName,_that.fileSizeBytes,_that.progress);case _Uploaded() when uploaded != null:
return uploaded(_that.track);case _Failure() when failure != null:
return failure(_that.message,_that.code,_that.filePath,_that.fileName,_that.fileSizeBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  initial,required TResult Function( String filePath,  String fileName,  int fileSizeBytes)  fileSelected,required TResult Function( String filePath,  String fileName,  int fileSizeBytes,  double progress)  uploading,required TResult Function( TrackEntity track)  uploaded,required TResult Function( String message,  String? code,  String? filePath,  String? fileName,  int? fileSizeBytes)  failure,}) {final _that = this;
switch (_that) {
case _Initial():
return initial();case _FileSelected():
return fileSelected(_that.filePath,_that.fileName,_that.fileSizeBytes);case _Uploading():
return uploading(_that.filePath,_that.fileName,_that.fileSizeBytes,_that.progress);case _Uploaded():
return uploaded(_that.track);case _Failure():
return failure(_that.message,_that.code,_that.filePath,_that.fileName,_that.fileSizeBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  initial,TResult? Function( String filePath,  String fileName,  int fileSizeBytes)?  fileSelected,TResult? Function( String filePath,  String fileName,  int fileSizeBytes,  double progress)?  uploading,TResult? Function( TrackEntity track)?  uploaded,TResult? Function( String message,  String? code,  String? filePath,  String? fileName,  int? fileSizeBytes)?  failure,}) {final _that = this;
switch (_that) {
case _Initial() when initial != null:
return initial();case _FileSelected() when fileSelected != null:
return fileSelected(_that.filePath,_that.fileName,_that.fileSizeBytes);case _Uploading() when uploading != null:
return uploading(_that.filePath,_that.fileName,_that.fileSizeBytes,_that.progress);case _Uploaded() when uploaded != null:
return uploaded(_that.track);case _Failure() when failure != null:
return failure(_that.message,_that.code,_that.filePath,_that.fileName,_that.fileSizeBytes);case _:
  return null;

}
}

}

/// @nodoc


class _Initial implements AudioUploadState {
  const _Initial();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Initial);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioUploadState.initial()';
}


}




/// @nodoc


class _FileSelected implements AudioUploadState {
  const _FileSelected({required this.filePath, required this.fileName, required this.fileSizeBytes});
  

 final  String filePath;
 final  String fileName;
 final  int fileSizeBytes;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileSelectedCopyWith<_FileSelected> get copyWith => __$FileSelectedCopyWithImpl<_FileSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileSelected&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}


@override
int get hashCode => Object.hash(runtimeType,filePath,fileName,fileSizeBytes);

@override
String toString() {
  return 'AudioUploadState.fileSelected(filePath: $filePath, fileName: $fileName, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class _$FileSelectedCopyWith<$Res> implements $AudioUploadStateCopyWith<$Res> {
  factory _$FileSelectedCopyWith(_FileSelected value, $Res Function(_FileSelected) _then) = __$FileSelectedCopyWithImpl;
@useResult
$Res call({
 String filePath, String fileName, int fileSizeBytes
});




}
/// @nodoc
class __$FileSelectedCopyWithImpl<$Res>
    implements _$FileSelectedCopyWith<$Res> {
  __$FileSelectedCopyWithImpl(this._self, this._then);

  final _FileSelected _self;
  final $Res Function(_FileSelected) _then;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? filePath = null,Object? fileName = null,Object? fileSizeBytes = null,}) {
  return _then(_FileSelected(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Uploading implements AudioUploadState {
  const _Uploading({required this.filePath, required this.fileName, required this.fileSizeBytes, required this.progress});
  

 final  String filePath;
 final  String fileName;
 final  int fileSizeBytes;
 final  double progress;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UploadingCopyWith<_Uploading> get copyWith => __$UploadingCopyWithImpl<_Uploading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uploading&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.progress, progress) || other.progress == progress));
}


@override
int get hashCode => Object.hash(runtimeType,filePath,fileName,fileSizeBytes,progress);

@override
String toString() {
  return 'AudioUploadState.uploading(filePath: $filePath, fileName: $fileName, fileSizeBytes: $fileSizeBytes, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$UploadingCopyWith<$Res> implements $AudioUploadStateCopyWith<$Res> {
  factory _$UploadingCopyWith(_Uploading value, $Res Function(_Uploading) _then) = __$UploadingCopyWithImpl;
@useResult
$Res call({
 String filePath, String fileName, int fileSizeBytes, double progress
});




}
/// @nodoc
class __$UploadingCopyWithImpl<$Res>
    implements _$UploadingCopyWith<$Res> {
  __$UploadingCopyWithImpl(this._self, this._then);

  final _Uploading _self;
  final $Res Function(_Uploading) _then;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? filePath = null,Object? fileName = null,Object? fileSizeBytes = null,Object? progress = null,}) {
  return _then(_Uploading(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class _Uploaded implements AudioUploadState {
  const _Uploaded({required this.track});
  

 final  TrackEntity track;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UploadedCopyWith<_Uploaded> get copyWith => __$UploadedCopyWithImpl<_Uploaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Uploaded&&(identical(other.track, track) || other.track == track));
}


@override
int get hashCode => Object.hash(runtimeType,track);

@override
String toString() {
  return 'AudioUploadState.uploaded(track: $track)';
}


}

/// @nodoc
abstract mixin class _$UploadedCopyWith<$Res> implements $AudioUploadStateCopyWith<$Res> {
  factory _$UploadedCopyWith(_Uploaded value, $Res Function(_Uploaded) _then) = __$UploadedCopyWithImpl;
@useResult
$Res call({
 TrackEntity track
});




}
/// @nodoc
class __$UploadedCopyWithImpl<$Res>
    implements _$UploadedCopyWith<$Res> {
  __$UploadedCopyWithImpl(this._self, this._then);

  final _Uploaded _self;
  final $Res Function(_Uploaded) _then;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? track = null,}) {
  return _then(_Uploaded(
track: null == track ? _self.track : track // ignore: cast_nullable_to_non_nullable
as TrackEntity,
  ));
}


}

/// @nodoc


class _Failure implements AudioUploadState {
  const _Failure(this.message, {this.code, this.filePath, this.fileName, this.fileSizeBytes});
  

 final  String message;
 final  String? code;
 final  String? filePath;
 final  String? fileName;
 final  int? fileSizeBytes;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FailureCopyWith<_Failure> get copyWith => __$FailureCopyWithImpl<_Failure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Failure&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,filePath,fileName,fileSizeBytes);

@override
String toString() {
  return 'AudioUploadState.failure(message: $message, code: $code, filePath: $filePath, fileName: $fileName, fileSizeBytes: $fileSizeBytes)';
}


}

/// @nodoc
abstract mixin class _$FailureCopyWith<$Res> implements $AudioUploadStateCopyWith<$Res> {
  factory _$FailureCopyWith(_Failure value, $Res Function(_Failure) _then) = __$FailureCopyWithImpl;
@useResult
$Res call({
 String message, String? code, String? filePath, String? fileName, int? fileSizeBytes
});




}
/// @nodoc
class __$FailureCopyWithImpl<$Res>
    implements _$FailureCopyWith<$Res> {
  __$FailureCopyWithImpl(this._self, this._then);

  final _Failure _self;
  final $Res Function(_Failure) _then;

/// Create a copy of AudioUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = freezed,Object? filePath = freezed,Object? fileName = freezed,Object? fileSizeBytes = freezed,}) {
  return _then(_Failure(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,filePath: freezed == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String?,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
