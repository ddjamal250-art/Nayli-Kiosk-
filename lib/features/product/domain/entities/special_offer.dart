import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'product_unit.dart';

/// كلاس يمثل العروض الخاصة والتخفيضات الذكية للمنتج
/// يتيح تحديد العرض على مستوى (كرتونة، علبة، أو حبة)
class SpecialOffer extends Equatable {
  final UnitTier targetTier; // small = حبة, medium = علبة, large = كرتونة
  final double quantity; // كمية العرض مثلاً 3 حبات أو 2 علبة
  final double offerPrice; // السعر الإجمالي للعرض مثلاً 100 دج بدل 120 دج
  final bool isEnabled;

  const SpecialOffer({
    this.targetTier = UnitTier.small,
    this.quantity = 0.0,
    this.offerPrice = 0.0,
    this.isEnabled = false,
  });

  bool get isValid => isEnabled && quantity > 0 && offerPrice > 0;

  String get tierNameAr {
    switch (targetTier) {
      case UnitTier.large:
        return 'كرتونة';
      case UnitTier.medium:
        return 'علبة';
      case UnitTier.small:
        return 'حبة';
    }
  }

  String get label => '${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} $tierNameAr بـ ${offerPrice.toStringAsFixed(0)} دج';

  Map<String, dynamic> toJson() => {
        'targetTier': targetTier.index,
        'quantity': quantity,
        'offerPrice': offerPrice,
        'isEnabled': isEnabled,
      };

  factory SpecialOffer.fromJson(Map<String, dynamic> json) => SpecialOffer(
        targetTier: UnitTier.values.length > (json['targetTier'] as int? ?? 0)
            ? UnitTier.values[json['targetTier'] as int? ?? 0]
            : UnitTier.small,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        offerPrice: (json['offerPrice'] as num?)?.toDouble() ?? 0.0,
        isEnabled: json['isEnabled'] as bool? ?? false,
      );

  static List<SpecialOffer> listFromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return const [];
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => SpecialOffer.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else if (decoded is Map) {
        return [SpecialOffer.fromJson(Map<String, dynamic>.from(decoded))];
      }
    } catch (_) {}
    return const [];
  }

  static String listToJsonString(List<SpecialOffer> offers) {
    if (offers.isEmpty) return '';
    return json.encode(offers.map((e) => e.toJson()).toList());
  }

  /// حساب الإجمالي للبيع أو الإرجاع
  /// إذا اشترى الزبون مضاعفات كمية العرض، يُحسب بسعر العرض، والمتبقي بالسعر العادي
  double calculateTotal({required double itemQty, required double normalUnitPrice}) {
    if (!isValid || itemQty <= 0) return itemQty * normalUnitPrice;

    final int bundles = (itemQty / quantity).floor();
    final double remainder = itemQty - (bundles * quantity);
    return (bundles * offerPrice) + (remainder * normalUnitPrice);
  }

  SpecialOffer copyWith({
    UnitTier? targetTier,
    double? quantity,
    double? offerPrice,
    bool? isEnabled,
  }) {
    return SpecialOffer(
      targetTier: targetTier ?? this.targetTier,
      quantity: quantity ?? this.quantity,
      offerPrice: offerPrice ?? this.offerPrice,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [targetTier, quantity, offerPrice, isEnabled];
}
