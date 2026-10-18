import 'package:hums_mobile/features/subscriptions/data/datasources/subscription_remote_data_source.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource _remoteDataSource;

  SubscriptionRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<SubscriptionPlanEntity>> getPlans() {
    return _remoteDataSource.getPlans();
  }

  @override
  Future<UserSubscriptionEntity?> getMySubscription() {
    return _remoteDataSource.getMySubscription();
  }

  @override
  Future<UserEntitlementsEntity> getMyEntitlements() {
    return _remoteDataSource.getMyEntitlements();
  }

  @override
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  }) {
    return _remoteDataSource.verifyPurchase(
      provider: provider,
      productId: productId,
      purchaseToken: purchaseToken,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
    );
  }

  @override
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  }) {
    return _remoteDataSource.restorePurchases(
      provider: provider,
      receiptData: receiptData,
      purchaseTokens: purchaseTokens,
    );
  }
}
