import 'package:dio/dio.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/core/network/api_endpoints.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';

abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionPlanEntity>> getPlans();
  Future<UserSubscriptionEntity?> getMySubscription();
  Future<UserEntitlementsEntity> getMyEntitlements();
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  });
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  });
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final ApiClient _apiClient;

  SubscriptionRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<SubscriptionPlanEntity>> getPlans() async {
    final response = await _apiClient.get(ApiEndpoints.subscriptionPlans);
    final data = response.data as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((p) => SubscriptionPlanEntity.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserSubscriptionEntity?> getMySubscription() async {
    final response = await _apiClient.get(ApiEndpoints.mySubscription);
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'];
    if (payload == null) return null;
    return UserSubscriptionEntity.fromJson(payload as Map<String, dynamic>);
  }

  @override
  Future<UserEntitlementsEntity> getMyEntitlements() async {
    final response = await _apiClient.get(ApiEndpoints.myEntitlements);
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>? ?? {};
    return UserEntitlementsEntity.fromJson(payload);
  }

  @override
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'provider': provider,
        'product_id': productId,
        'purchase_token': purchaseToken,
      };
      if (transactionId != null) {
        requestBody['transaction_id'] = transactionId;
      }
      if (originalTransactionId != null) {
        requestBody['original_transaction_id'] = originalTransactionId;
      }

      final response = await _apiClient.post(
        ApiEndpoints.verifyPurchase,
        data: requestBody,
      );

      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      final subJson = payload['subscription'] as Map<String, dynamic>;
      final entitlements = (payload['entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];

      return PurchaseResultEntity.success(
        subscription: UserSubscriptionEntity.fromJson(subJson),
        entitlements: entitlements,
        message: payload['message'] as String? ?? 'Purchase verified.',
      );
    } on DioException catch (e) {
      String message = 'Purchase verification failed.';
      String? code;
      if (e.response?.data is Map<String, dynamic>) {
        final err = (e.response!.data as Map<String, dynamic>)['error'];
        if (err is Map<String, dynamic>) {
          message = err['message'] as String? ?? message;
          code = err['code'] as String?;
        }
      }
      return PurchaseResultEntity.failure(message: message, errorCode: code);
    } catch (e) {
      return PurchaseResultEntity.failure(message: e.toString());
    }
  }

  @override
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'provider': provider,
      };
      if (receiptData != null) {
        requestBody['receipt_data'] = receiptData;
      }
      if (purchaseTokens != null) {
        requestBody['purchase_tokens'] = purchaseTokens;
      }

      final response = await _apiClient.post(
        ApiEndpoints.restorePurchases,
        data: requestBody,
      );

      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      final restored = payload['restored'] as bool? ?? false;
      final subJson = payload['active_subscription'] as Map<String, dynamic>?;
      final entitlements = (payload['active_entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];

      if (restored && subJson != null) {
        return PurchaseResultEntity.success(
          subscription: UserSubscriptionEntity.fromJson(subJson),
          entitlements: entitlements,
          message: payload['message'] as String? ?? 'Purchases restored.',
        );
      } else {
        return PurchaseResultEntity.failure(
          message: payload['message'] as String? ?? 'No purchases restored.',
        );
      }
    } on DioException catch (e) {
      String message = 'Failed to restore purchases.';
      String? code;
      if (e.response?.data is Map<String, dynamic>) {
        final err = (e.response!.data as Map<String, dynamic>)['error'];
        if (err is Map<String, dynamic>) {
          message = err['message'] as String? ?? message;
          code = err['code'] as String?;
        }
      }
      return PurchaseResultEntity.failure(message: message, errorCode: code);
    } catch (e) {
      return PurchaseResultEntity.failure(message: e.toString());
    }
  }
}
