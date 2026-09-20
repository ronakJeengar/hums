class UserEntity {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLoginAt;

  const UserEntity({
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
