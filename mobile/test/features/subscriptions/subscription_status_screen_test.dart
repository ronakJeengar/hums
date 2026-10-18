import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:hums_mobile/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:hums_mobile/features/subscriptions/presentation/screens/subscription_status_screen.dart';

class MockStatusSubscriptionRepository implements SubscriptionRepository {
  final UserSubscriptionEntity? subscription;
  final UserEntitlementsEntity entitlements;

  MockStatusSubscriptionRepository({
    this.subscription,
    this.entitlements = const UserEntitlementsEntity(),
  });

  @override
  Future<List<SubscriptionPlanEntity>> getPlans() async => [];

  @override
  Future<UserSubscriptionEntity?> getMySubscription() async => subscription;

  @override
  Future<UserEntitlementsEntity> getMyEntitlements() async => entitlements;

  @override
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  }) async =>
      PurchaseResultEntity.failure(message: 'Unused in status screen test');

  @override
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  }) async =>
      PurchaseResultEntity.failure(message: 'Unused in status screen test');
}

void main() {
  testWidgets('SubscriptionStatusScreen renders Free tier with Upgrade option',
      (WidgetTester tester) async {
    final mockRepo = MockStatusSubscriptionRepository(
      subscription: null,
      entitlements: const UserEntitlementsEntity(
        entitlements: [],
        isPremium: false,
        tier: 'FREE',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Free tier state
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Hums Free Tier'), findsOneWidget);
    expect(find.text('Upgrade to Hums Premium'), findsOneWidget);
    expect(find.text('YOUR CURRENT FREE ACCESS'), findsOneWidget);
    expect(find.text('AVAILABLE WITH PREMIUM'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('SubscriptionStatusScreen renders Active Premium with entitlements & manage button',
      (WidgetTester tester) async {
    final now = DateTime(2026, 10, 1);
    final mockRepo = MockStatusSubscriptionRepository(
      subscription: UserSubscriptionEntity(
        id: 'sub_999',
        userId: 'u_999',
        planCode: 'PREMIUM_YEARLY',
        planName: 'Hums Premium Annual',
        provider: 'apple',
        status: 'ACTIVE',
        isActive: true,
        currentPeriodStart: now,
        currentPeriodEnd: DateTime(2027, 10, 1),
        cancelAtPeriodEnd: false,
        activeEntitlements: const [
          'PREMIUM_AUDIO_QUALITY',
          'OFFLINE_DOWNLOADS',
        ],
      ),
      entitlements: const UserEntitlementsEntity(
        entitlements: ['PREMIUM_AUDIO_QUALITY', 'OFFLINE_DOWNLOADS'],
        isPremium: true,
        tier: 'PREMIUM',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Active Premium details
    expect(find.text('Hums Premium Annual'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('APPLE'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('2027-10-01'), findsOneWidget);
    expect(find.text('Manage Subscription'), findsOneWidget);
    expect(find.text('Change Plan'), findsOneWidget);
    expect(find.text('ACTIVE PREMIUM ENTITLEMENTS'), findsOneWidget);
  });
}
