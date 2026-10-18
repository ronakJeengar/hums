import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hums_mobile/core/network/api_client.dart';
import 'package:hums_mobile/features/subscriptions/data/datasources/subscription_remote_data_source.dart';
import 'package:hums_mobile/features/subscriptions/data/repositories/subscription_repository_impl.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:hums_mobile/features/subscriptions/presentation/states/subscription_state.dart';

final subscriptionRemoteDataSourceProvider =
    Provider<SubscriptionRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SubscriptionRemoteDataSourceImpl(apiClient);
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final remote = ref.watch(subscriptionRemoteDataSourceProvider);
  return SubscriptionRepositoryImpl(remote);
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;

  SubscriptionNotifier(this._repository) : super(const SubscriptionState()) {
    loadSubscriptionData();
  }

  /// Authoritatively loads plans, current subscription, and active entitlements from backend.
  Future<void> loadSubscriptionData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.getPlans(),
        _repository.getMySubscription(),
        _repository.getMyEntitlements(),
      ]);

      final plans = results[0] as List<SubscriptionPlanEntity>;
      final currentSub = results[1] as UserSubscriptionEntity?;
      final entitlements = results[2] as UserEntitlementsEntity;

      state = state.copyWith(
        isLoading: false,
        plans: plans,
        currentSubscription: currentSub,
        clearSubscription: currentSub == null,
        entitlements: entitlements,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load subscription data. Please check your connection.',
      );
    }
  }

  /// Initiates purchase verification with the authoritative backend.
  Future<bool> purchasePlan(SubscriptionPlanEntity plan) async {
    state = state.copyWith(
      isPurchasing: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      // Determine platform provider & product identifier
      String provider = 'mock';
      String productId = plan.code;

      if (!Platform.isAndroid && !Platform.isIOS) {
        provider = 'mock';
        productId = plan.appleProductId ?? plan.googleProductId ?? plan.code;
      } else if (Platform.isIOS) {
        provider = 'apple';
        productId = plan.appleProductId ?? plan.code;
      } else if (Platform.isAndroid) {
        provider = 'google';
        productId = plan.googleProductId ?? plan.code;
      }

      // Simulated purchase token for platform test boundary
      final purchaseToken = 'test_token_${plan.billingInterval.toLowerCase()}';
      final transactionId = 'tx_${DateTime.now().millisecondsSinceEpoch}';

      final result = await _repository.verifyPurchase(
        provider: provider,
        productId: productId,
        purchaseToken: purchaseToken,
        transactionId: transactionId,
      );

      if (result.success && result.subscription != null) {
        // Refresh entitlements after authoritative grant
        final entitlements = await _repository.getMyEntitlements();
        state = state.copyWith(
          isPurchasing: false,
          currentSubscription: result.subscription,
          entitlements: entitlements,
          successMessage: 'Welcome to Hums Premium!',
        );
        return true;
      } else {
        state = state.copyWith(
          isPurchasing: false,
          errorMessage: result.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'Purchase could not be completed: $e',
      );
      return false;
    }
  }

  /// Restores previous store purchases for this user account.
  Future<bool> restorePurchases() async {
    state = state.copyWith(
      isRestoring: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final provider = Platform.isIOS ? 'apple' : Platform.isAndroid ? 'google' : 'mock';
      final result = await _repository.restorePurchases(
        provider: provider,
        receiptData: 'restore_receipt_token',
      );

      if (result.success && result.subscription != null) {
        final entitlements = await _repository.getMyEntitlements();
        state = state.copyWith(
          isRestoring: false,
          currentSubscription: result.subscription,
          entitlements: entitlements,
          successMessage: 'Your subscriptions have been restored.',
        );
        return true;
      } else {
        state = state.copyWith(
          isRestoring: false,
          errorMessage: result.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Failed to restore purchases: $e',
      );
      return false;
    }
  }

  /// Clears transient snackbar messages.
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  /// Resets state on sign out to prevent stale account data leakage.
  void reset() {
    state = const SubscriptionState();
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.watch(subscriptionRepositoryProvider));
});

final userEntitlementsProvider = Provider<UserEntitlementsEntity>((ref) {
  return ref.watch(subscriptionNotifierProvider).entitlements;
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionNotifierProvider).isPremium;
});
