import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:hums_mobile/features/subscriptions/presentation/providers/subscription_provider.dart';

class MockSubscriptionRepository implements SubscriptionRepository {
  List<SubscriptionPlanEntity> mockPlans = [
    const SubscriptionPlanEntity(
      id: 'plan_free',
      code: 'FREE',
      name: 'Free Plan',
      billingInterval: 'FREE',
      priceCents: 0,
    ),
    const SubscriptionPlanEntity(
      id: 'plan_monthly',
      code: 'PREMIUM_MONTHLY',
      name: 'Hums Premium Monthly',
      billingInterval: 'MONTH',
      priceCents: 999,
      appleProductId: 'com.hums.monthly',
      googleProductId: 'com.hums.monthly',
    ),
    const SubscriptionPlanEntity(
      id: 'plan_yearly',
      code: 'PREMIUM_YEARLY',
      name: 'Hums Premium Annual',
      billingInterval: 'YEAR',
      priceCents: 9999,
      appleProductId: 'com.hums.yearly',
      googleProductId: 'com.hums.yearly',
    ),
  ];

  UserSubscriptionEntity? mockSubscription;
  UserEntitlementsEntity mockEntitlements = const UserEntitlementsEntity(
    entitlements: [],
    isPremium: false,
    tier: 'FREE',
  );

  bool shouldFailPurchase = false;
  bool shouldFailRestore = false;
  int getPlansCalls = 0;
  int getSubscriptionCalls = 0;
  int getEntitlementsCalls = 0;
  int verifyPurchaseCalls = 0;
  int restoreCalls = 0;

  @override
  Future<List<SubscriptionPlanEntity>> getPlans() async {
    getPlansCalls++;
    return mockPlans;
  }

  @override
  Future<UserSubscriptionEntity?> getMySubscription() async {
    getSubscriptionCalls++;
    return mockSubscription;
  }

  @override
  Future<UserEntitlementsEntity> getMyEntitlements() async {
    getEntitlementsCalls++;
    return mockEntitlements;
  }

  @override
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  }) async {
    verifyPurchaseCalls++;
    if (shouldFailPurchase) {
      return PurchaseResultEntity.failure(
        message: 'Transaction declined by provider.',
        errorCode: 'PROVIDER_DECLINED',
      );
    }

    final now = DateTime.now();
    final verifiedSub = UserSubscriptionEntity(
      id: 'sub_test_123',
      userId: 'user_123',
      planCode: productId.contains('yearly') ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY',
      planName: 'Hums Premium',
      provider: provider,
      providerSubscriptionId: 'store_sub_123',
      providerProductId: productId,
      status: 'ACTIVE',
      isActive: true,
      currentPeriodStart: now,
      currentPeriodEnd: now.add(const Duration(days: 30)),
      cancelAtPeriodEnd: false,
      activeEntitlements: const ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
    );
    mockSubscription = verifiedSub;
    mockEntitlements = const UserEntitlementsEntity(
      entitlements: ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
      isPremium: true,
      tier: 'PREMIUM',
    );

    return PurchaseResultEntity.success(
      subscription: verifiedSub,
      entitlements: const ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
      message: 'Purchase verified successfully.',
    );
  }

  @override
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  }) async {
    restoreCalls++;
    if (shouldFailRestore) {
      return PurchaseResultEntity.failure(
        message: 'No previous purchases found for this Apple/Google account.',
        errorCode: 'NO_PURCHASES_FOUND',
      );
    }

    final now = DateTime.now();
    final restoredSub = UserSubscriptionEntity(
      id: 'sub_restored_456',
      userId: 'user_123',
      planCode: 'PREMIUM_YEARLY',
      planName: 'Hums Premium Annual',
      provider: provider,
      providerSubscriptionId: 'store_sub_456',
      providerProductId: 'com.hums.yearly',
      status: 'ACTIVE',
      isActive: true,
      currentPeriodStart: now.subtract(const Duration(days: 60)),
      currentPeriodEnd: now.add(const Duration(days: 305)),
      cancelAtPeriodEnd: false,
      activeEntitlements: const ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
    );
    mockSubscription = restoredSub;
    mockEntitlements = const UserEntitlementsEntity(
      entitlements: ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
      isPremium: true,
      tier: 'PREMIUM',
    );

    return PurchaseResultEntity.success(
      subscription: restoredSub,
      entitlements: const ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
      message: 'Subscriptions restored successfully.',
    );
  }
}

void main() {
  late MockSubscriptionRepository mockRepo;
  late SubscriptionNotifier notifier;

  setUp(() {
    mockRepo = MockSubscriptionRepository();
    notifier = SubscriptionNotifier(mockRepo);
  });

  test('loadSubscriptionData loads plans, subscription, and entitlements', () async {
    await notifier.loadSubscriptionData();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.plans.length, equals(3));
    expect(notifier.state.currentSubscription, isNull);
    expect(notifier.state.isPremium, isFalse);
    expect(notifier.state.entitlements.hasPremiumAudio, isFalse);
    expect(notifier.state.entitlements.hasOfflineDownloads, isFalse);
    expect(mockRepo.getPlansCalls, greaterThanOrEqualTo(1));
    expect(mockRepo.getSubscriptionCalls, greaterThanOrEqualTo(1));
    expect(mockRepo.getEntitlementsCalls, greaterThanOrEqualTo(1));
  });

  test('purchasePlan success authoritatively grants premium and updates state', () async {
    final yearlyPlan = mockRepo.mockPlans.firstWhere((p) => p.isYearly);

    final success = await notifier.purchasePlan(yearlyPlan);

    expect(success, isTrue);
    expect(notifier.state.isPurchasing, isFalse);
    expect(notifier.state.isPremium, isTrue);
    expect(notifier.state.currentSubscription, isNotNull);
    expect(notifier.state.currentSubscription?.isActive, isTrue);
    expect(notifier.state.entitlements.hasPremiumAudio, isTrue);
    expect(notifier.state.entitlements.hasOfflineDownloads, isTrue);
    expect(notifier.state.successMessage, equals('Welcome to Hums Premium!'));
    expect(notifier.state.errorMessage, isNull);
  });

  test('purchasePlan failure sets error message without granting entitlements', () async {
    mockRepo.shouldFailPurchase = true;
    final monthlyPlan = mockRepo.mockPlans.firstWhere((p) => p.isMonthly);

    final success = await notifier.purchasePlan(monthlyPlan);

    expect(success, isFalse);
    expect(notifier.state.isPurchasing, isFalse);
    expect(notifier.state.isPremium, isFalse);
    expect(notifier.state.currentSubscription, isNull);
    expect(notifier.state.errorMessage, contains('Transaction declined'));
    expect(notifier.state.successMessage, isNull);
  });

  test('restorePurchases success restores active subscription and entitlements', () async {
    final success = await notifier.restorePurchases();

    expect(success, isTrue);
    expect(notifier.state.isRestoring, isFalse);
    expect(notifier.state.isPremium, isTrue);
    expect(notifier.state.currentSubscription?.planCode, equals('PREMIUM_YEARLY'));
    expect(notifier.state.successMessage, equals('Your subscriptions have been restored.'));
  });

  test('restorePurchases failure handles missing store purchase gracefully', () async {
    mockRepo.shouldFailRestore = true;

    final success = await notifier.restorePurchases();

    expect(success, isFalse);
    expect(notifier.state.isRestoring, isFalse);
    expect(notifier.state.isPremium, isFalse);
    expect(notifier.state.errorMessage, contains('No previous purchases found'));
  });

  test('clearMessages wipes transient success and error state', () {
    notifier.clearMessages();
    expect(notifier.state.errorMessage, isNull);
    expect(notifier.state.successMessage, isNull);
  });

  test('reset resets notifier to clean unauthenticated state', () async {
    final yearlyPlan = mockRepo.mockPlans.firstWhere((p) => p.isYearly);
    await notifier.purchasePlan(yearlyPlan);
    expect(notifier.state.isPremium, isTrue);

    notifier.reset();
    expect(notifier.state.isPremium, isFalse);
    expect(notifier.state.currentSubscription, isNull);
    expect(notifier.state.plans, isEmpty);
  });
}
