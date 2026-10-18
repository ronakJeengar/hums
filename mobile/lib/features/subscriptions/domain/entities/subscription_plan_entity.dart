/// Model representing a subscription commercial plan catalog item.
class SubscriptionPlanEntity {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String billingInterval; // NONE, MONTH, YEAR
  final int priceCents;
  final String currency;
  final String? appleProductId;
  final String? googleProductId;
  final bool isActive;
  final int displayOrder;
  final List<String> entitlements;

  const SubscriptionPlanEntity({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.billingInterval,
    required this.priceCents,
    this.currency = 'USD',
    this.appleProductId,
    this.googleProductId,
    this.isActive = true,
    this.displayOrder = 0,
    this.entitlements = const [],
  });

  bool get isFree => code == 'FREE' || priceCents == 0;
  bool get isMonthly => billingInterval.toUpperCase() == 'MONTH';
  bool get isYearly => billingInterval.toUpperCase() == 'YEAR';

  String get formattedPrice {
    if (isFree) return 'Free';
    final dollars = (priceCents / 100).toStringAsFixed(2);
    return '\$$dollars';
  }

  String get billingPeriodLabel {
    if (isYearly) return '/year';
    if (isMonthly) return '/month';
    return '';
  }

  String get priceWithPeriod => '$formattedPrice$billingPeriodLabel';

  factory SubscriptionPlanEntity.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanEntity(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      billingInterval: json['billing_interval'] as String? ?? 'MONTH',
      priceCents: json['price_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      appleProductId: json['apple_product_id'] as String?,
      googleProductId: json['google_product_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      entitlements: (json['entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'billing_interval': billingInterval,
        'price_cents': priceCents,
        'currency': currency,
        'apple_product_id': appleProductId,
        'google_product_id': googleProductId,
        'is_active': isActive,
        'display_order': displayOrder,
        'entitlements': entitlements,
      };
}
