import 'package:hums_mobile/features/subscriptions/domain/entities/subscription_plan_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_entitlements_entity.dart';
import 'package:hums_mobile/features/subscriptions/domain/entities/user_subscription_entity.dart';

class SubscriptionState {
  final bool isLoading;
  final bool isPurchasing;
  final bool isRestoring;
  final List<SubscriptionPlanEntity> plans;
  final UserSubscriptionEntity? currentSubscription;
  final UserEntitlementsEntity entitlements;
  final String? errorMessage;
  final String? successMessage;
  final bool isPending;

  const SubscriptionState({
    this.isLoading = false,
    this.isPurchasing = false,
    this.isRestoring = false,
    this.plans = const [],
    this.currentSubscription,
    this.entitlements = const UserEntitlementsEntity(),
    this.errorMessage,
    this.successMessage,
    this.isPending = false,
  });

  bool get isPremium => entitlements.isPremium;

  SubscriptionPlanEntity? get monthlyPlan =>
      plans.cast<SubscriptionPlanEntity?>().firstWhere(
            (p) => p?.isMonthly == true,
            orElse: () => null,
          );

  SubscriptionPlanEntity? get yearlyPlan =>
      plans.cast<SubscriptionPlanEntity?>().firstWhere(
            (p) => p?.isYearly == true,
            orElse: () => null,
          );

  SubscriptionState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? isRestoring,
    List<SubscriptionPlanEntity>? plans,
    UserSubscriptionEntity? currentSubscription,
    bool clearSubscription = false,
    UserEntitlementsEntity? entitlements,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    bool? isPending,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      plans: plans ?? this.plans,
      currentSubscription: clearSubscription
          ? null
          : (currentSubscription ?? this.currentSubscription),
      entitlements: entitlements ?? this.entitlements,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      isPending: isPending ?? this.isPending,
    );
  }
}
