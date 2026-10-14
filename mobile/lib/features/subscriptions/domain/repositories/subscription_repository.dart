import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';

abstract class SubscriptionRepository {
  /// Fetches available commercial subscription plans.
  Future<List<SubscriptionPlanEntity>> getPlans();

  /// Fetches authenticated user's current subscription status.
  Future<UserSubscriptionEntity?> getMySubscription();

  /// Fetches authenticated user's active entitlement grants.
  Future<UserEntitlementsEntity> getMyEntitlements();

  /// Submits platform purchase receipt/token for authoritative server verification.
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  });

  /// Restores previous purchases for the authenticated user.
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  });
}
