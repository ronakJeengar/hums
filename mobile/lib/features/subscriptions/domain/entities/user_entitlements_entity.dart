/// Model representing user's active platform permissions and tier.
class UserEntitlementsEntity {
  final List<String> entitlements;
  final bool isPremium;
  final String tier; // FREE or PREMIUM
  final DateTime? expiresAt;

  const UserEntitlementsEntity({
    this.entitlements = const [],
    this.isPremium = false,
    this.tier = 'FREE',
    this.expiresAt,
  });

  bool hasEntitlement(String code) => entitlements.contains(code);

  bool get hasPremiumAudio => hasEntitlement('PREMIUM_AUDIO_QUALITY');
  bool get hasOfflineDownloads => hasEntitlement('OFFLINE_DOWNLOADS');
  bool get hasUnlimitedDownloads => hasEntitlement('UNLIMITED_DOWNLOADS');

  factory UserEntitlementsEntity.fromJson(Map<String, dynamic> json) {
    return UserEntitlementsEntity(
      entitlements: (json['entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPremium: json['is_premium'] as bool? ?? false,
      tier: json['tier'] as String? ?? 'FREE',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'entitlements': entitlements,
        'is_premium': isPremium,
        'tier': tier,
        'expires_at': expiresAt?.toIso8601String(),
      };
}
