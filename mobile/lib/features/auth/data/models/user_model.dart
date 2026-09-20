import 'package:hums_mobile/features/auth/domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.isActive = true,
    this.isVerified = false,
    this.lastLoginAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? (json['full_name'] as String?) ?? (json['username'] as String?) ?? '',
      email: json['email'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      isVerified: (json['is_verified'] as bool?) ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'is_verified': isVerified,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      email: email,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      isActive: isActive,
      isVerified: isVerified,
      lastLoginAt: lastLoginAt,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      username: entity.username,
      fullName: entity.fullName,
      avatarUrl: entity.avatarUrl,
      isActive: entity.isActive,
      isVerified: entity.isVerified,
      lastLoginAt: entity.lastLoginAt,
    );
  }
}
