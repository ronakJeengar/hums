/// Model representing the authenticated user's authoritative subscription state.
class UserSubscriptionEntity {
  final String id;
  final String userId;
  final String planCode;
  final String planName;
  final String provider;
  final String? providerSubscriptionId;
  final String? providerProductId;
  final String status;
  final bool isActive;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? gracePeriodEnd;
  final List<String> activeEntitlements;

  const UserSubscriptionEntity({
    required this.id,
    required this.userId,
    required this.planCode,
    required this.planName,
    required this.provider,
    this.providerSubscriptionId,
    this.providerProductId,
    required this.status,
    required this.isActive,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    this.gracePeriodEnd,
    this.activeEntitlements = const [],
  });

  bool get isCanceled => status == 'CANCELED' || cancelAtPeriodEnd;
  bool get isInGracePeriod => status == 'IN_GRACE_PERIOD';
  bool get isExpired => status == 'EXPIRED';
  bool get isRevoked => status == 'REVOKED';

  DateTime get effectiveExpiryDate => gracePeriodEnd ?? currentPeriodEnd;

  String get statusDisplayLabel {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return cancelAtPeriodEnd ? 'Cancels at period end' : 'Active';
      case 'IN_GRACE_PERIOD':
        return 'Grace Period (Billing Retry)';
      case 'PAST_DUE':
        return 'Past Due';
      case 'CANCELED':
        return 'Canceled';
      case 'EXPIRED':
        return 'Expired';
      case 'REVOKED':
        return 'Revoked';
      case 'PENDING':
        return 'Pending Verification';
      default:
        return status;
    }
  }

  factory UserSubscriptionEntity.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionEntity(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      planCode: json['plan_code'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      providerSubscriptionId: json['provider_subscription_id'] as String?,
      providerProductId: json['provider_product_id'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      isActive: json['is_active'] as bool? ?? false,
      currentPeriodStart: DateTime.parse(
          json['current_period_start'] as String? ?? DateTime.now().toIso8601String()),
      currentPeriodEnd: DateTime.parse(
          json['current_period_end'] as String? ?? DateTime.now().toIso8601String()),
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      gracePeriodEnd: json['grace_period_end'] != null
          ? DateTime.parse(json['grace_period_end'] as String)
          : null,
      activeEntitlements: (json['active_entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plan_code': planCode,
        'plan_name': planName,
        'provider': provider,
        'provider_subscription_id': providerSubscriptionId,
        'provider_product_id': providerProductId,
        'status': status,
        'is_active': isActive,
        'current_period_start': currentPeriodStart.toIso8601String(),
        'current_period_end': currentPeriodEnd.toIso8601String(),
        'cancel_at_period_end': cancelAtPeriodEnd,
        'grace_period_end': gracePeriodEnd?.toIso8601String(),
        'active_entitlements': activeEntitlements,
      };
}
