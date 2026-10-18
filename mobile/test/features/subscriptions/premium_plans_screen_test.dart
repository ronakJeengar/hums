import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/purchase_result_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/repositories/subscription_repository.dart';
import 'package:hums_mobile/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:hums_mobile/features/subscriptions/presentation/screens/premium_plans_screen.dart';

class MockWidgetSubscriptionRepository implements SubscriptionRepository {
  List<SubscriptionPlanEntity> plans = [
    const SubscriptionPlanEntity(
      id: 'plan_monthly',
      code: 'PREMIUM_MONTHLY',
      name: 'Hums Premium Monthly',
      billingInterval: 'MONTH',
      priceCents: 999,
    ),
    const SubscriptionPlanEntity(
      id: 'plan_yearly',
      code: 'PREMIUM_YEARLY',
      name: 'Hums Premium Annual',
      billingInterval: 'YEAR',
      priceCents: 9999,
    ),
  ];

  @override
  Future<List<SubscriptionPlanEntity>> getPlans() async => plans;

  @override
  Future<UserSubscriptionEntity?> getMySubscription() async => null;

  @override
  Future<UserEntitlementsEntity> getMyEntitlements() async =>
      const UserEntitlementsEntity(isPremium: false, tier: 'FREE');

  @override
  Future<PurchaseResultEntity> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
    String? transactionId,
    String? originalTransactionId,
  }) async {
    final now = DateTime.now();
    return PurchaseResultEntity.success(
      subscription: UserSubscriptionEntity(
        id: 'sub_widget_1',
        userId: 'u1',
        planCode: 'PREMIUM_YEARLY',
        planName: 'Hums Premium Annual',
        provider: provider,
        status: 'ACTIVE',
        isActive: true,
        currentPeriodStart: now,
        currentPeriodEnd: now.add(const Duration(days: 365)),
        cancelAtPeriodEnd: false,
      ),
      entitlements: const ['PREMIUM_AUDIO_QUALITY'],
      message: 'Subscribed successfully',
    );
  }

  @override
  Future<PurchaseResultEntity> restorePurchases({
    required String provider,
    String? receiptData,
    List<String>? purchaseTokens,
  }) async =>
      PurchaseResultEntity.failure(message: 'No previous purchases found');
}

void main() {
  testWidgets('PremiumPlansScreen renders benefits, plans, and subscribe button',
      (WidgetTester tester) async {
    final mockRepo = MockWidgetSubscriptionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: PremiumPlansScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and value proposition
    expect(find.text('Hums Premium'), findsWidgets);
    expect(find.textContaining('Pristine Audio'), findsOneWidget);
    expect(find.textContaining('192 kbps'), findsOneWidget);
    expect(find.textContaining('Offline Downloads'), findsOneWidget);

    // Verify plans rendered
    expect(find.text('Hums Premium Annual'), findsOneWidget);
    expect(find.text('Hums Premium Monthly'), findsOneWidget);
    expect(find.text(r'$99.99'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);

    // Verify CTA button
    expect(find.text('Get Hums Premium Annual'), findsOneWidget);

    // Scroll down to make Monthly plan card visible, then tap
    await tester.ensureVisible(find.text('Hums Premium Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hums Premium Monthly'));
    await tester.pumpAndSettle();

    // Verify CTA button label updated to selected plan
    expect(find.text('Get Hums Premium Monthly'), findsOneWidget);
  });
}
