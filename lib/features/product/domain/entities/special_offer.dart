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

  bool get isValid => isEnabled && quantity > 1 && offerPrice > 0;

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
