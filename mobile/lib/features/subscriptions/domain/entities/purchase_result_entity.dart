import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';

/// Result envelope returned by purchase verification and restore operations.
class PurchaseResultEntity {
  final bool success;
  final UserSubscriptionEntity? subscription;
  final List<String> entitlements;
  final String message;
  final String? errorCode;

  const PurchaseResultEntity({
    required this.success,
    this.subscription,
    this.entitlements = const [],
    required this.message,
    this.errorCode,
  });

  factory PurchaseResultEntity.success({
    required UserSubscriptionEntity subscription,
    required List<String> entitlements,
    String message = 'Purchase successfully verified.',
  }) {
    return PurchaseResultEntity(
      success: true,
      subscription: subscription,
      entitlements: entitlements,
      message: message,
    );
  }

  factory PurchaseResultEntity.failure({
    required String message,
    String? errorCode,
  }) {
    return PurchaseResultEntity(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}
