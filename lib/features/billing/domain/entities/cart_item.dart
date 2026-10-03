import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_unit.dart';

class CartItem extends Equatable {
  final Product product;
  final double quantity; // Changed to double for fractional sales (e.g., 1.5 units)
  final String unitLevel; // Name of the selected unit (e.g. 'فاردو', or 'base' for base unit)
  final String? customUnitName;
  final double? customUnitPrice;
  final double? customUnitCost;
  /// وزن حقيقي بالكيلوغرام للمنتجات الميزانية (null = منتج عادي)
  final double? weightKg;
  /// معامل الضرب المخصص للوحدة عند العروض الخاصة والصفقات المخصصة
  final double? customMultiplier;

  const CartItem({
    required this.product,
    this.quantity = 1.0,
    this.unitLevel = 'base',
    this.customUnitName,
    this.customUnitPrice,
    this.customUnitCost,
    this.weightKg,
    this.customMultiplier,
  });

  ProductUnit? get selectedUnit {
    if (unitLevel == 'base') return null;
    return product.units.firstWhereOrNull((u) => u.name == unitLevel);
  }

  double get unitPrice {
    if (customUnitPrice != null && customUnitPrice! > 0) return customUnitPrice!;
    final unit = selectedUnit;
    if (unit != null) return unit.price;
    return product.price; // Base unit price
  }

  double get unitCost {
    if (customUnitCost != null && customUnitCost! > 0) return customUnitCost!;
    final unit = selectedUnit;
    if (unit != null) {
      if (unit.cost > 0) return unit.cost;
      return product.costPrice * unit.multiplier; // Derive cost if not set
    }
    return product.costPrice; // Base unit cost
  }

  String get unitDisplayName {
    if (customUnitName != null && customUnitName!.trim().isNotEmpty) return customUnitName!.trim();
    if (unitLevel != 'base') return unitLevel;
    return product.baseUnitName;
  }

  String get displayNameWithUnit {
    if (unitLevel == 'base' && customUnitName == null) return product.name;
    return '${product.name} [$unitDisplayName]';
  }

  String get cartKey => '${product.id}_$unitLevel';

  /// المجموع الإجمالي للبيع مع دعم العروض الخاصة والتخفيضات والإرجاع
  double get total {
    if (weightKg != null) return customUnitPrice ?? (weightKg! * unitPrice);

    // إذا تم تحديد عرض خاص أو سعر مخصص بالصفقة مباشرة
    if (unitLevel == 'custom' && customUnitPrice != null) {
      final isNegative = unitPrice < 0 || quantity < 0;
      final t = (customUnitPrice! * quantity.abs());
      return isNegative ? -t : t;
    }

    final currentTier = selectedUnit?.tier ?? UnitTier.small;
    final isNegative = unitPrice < 0 || quantity < 0;
    final absQty = quantity.abs();
    final absPrice = unitPrice.abs();

    final matchingOffers = product.specialOffers
        .where((o) => o.isValid && o.targetTier == currentTier && absQty >= o.quantity)
        .toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    if (matchingOffers.isNotEmpty) {
      double remainingQty = absQty;
      double totalAmount = 0.0;
      for (final offer in matchingOffers) {
        if (remainingQty >= offer.quantity) {
          final int bundles = (remainingQty / offer.quantity).floor();
          totalAmount += bundles * offer.offerPrice;
          remainingQty -= (bundles * offer.quantity);
        }
      }
      totalAmount += (remainingQty * absPrice);
      return isNegative ? -totalAmount : totalAmount;
    }

    return unitPrice * quantity;
  }

  bool get hasOfferApplied {
    if (unitLevel == 'custom') return true;
    final currentTier = selectedUnit?.tier ?? UnitTier.small;
    return product.specialOffers.any(
      (o) => o.isValid && o.targetTier == currentTier && quantity.abs() >= o.quantity,
    );
  }

  double get offerSavedAmount {
    if (!hasOfferApplied) return 0.0;
    final normalTotal = unitPrice.abs() * quantity.abs();
    final offerTotal = total.abs();
    return (normalTotal - offerTotal).clamp(0.0, double.infinity);
  }

  /// الكمية الحقيقية للخصم من المخزون
  double get totalStockDeduct {
    if (weightKg != null) return weightKg!;
    if (customMultiplier != null && customMultiplier! > 0) {
      return quantity * customMultiplier!;
    }
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1.0;
    return quantity * multiplier;
  }

  /// للتوافق مع الكود القديم
  double get totalBaseQuantity {
    if (weightKg != null) return 1.0; 
    if (customMultiplier != null && customMultiplier! > 0) {
      return quantity * customMultiplier!;
    }
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1.0;
    return quantity * multiplier;
  }

  /// التكلفة الحقيقية للفاتورة:
  double get totalCostForInvoice {
    if (weightKg != null) {
      final unit = selectedUnit;
      final costPerKg = (unit != null && unit.cost > 0) ? unit.cost : product.costPrice;
      return weightKg! * costPerKg;
    }
    return unitCost * quantity;
  }

  /// الربح = إجمالي البيع - إجمالي التكلفة
  double get profit => total - totalCostForInvoice;

  CartItem copyWith({
    Product? product,
    double? quantity,
    String? unitLevel,
    String? customUnitName,
    double? customUnitPrice,
    double? customUnitCost,
    double? weightKg,
    double? customMultiplier,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitLevel: unitLevel ?? this.unitLevel,
      customUnitName: customUnitName ?? this.customUnitName,
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
      customUnitCost: customUnitCost ?? this.customUnitCost,
      weightKg: weightKg ?? this.weightKg,
      customMultiplier: customMultiplier ?? this.customMultiplier,
    );
  }

  @override
  List<Object?> get props => [
    product, quantity, unitLevel, customUnitName,
    customUnitPrice, customUnitCost, weightKg, customMultiplier,
  ];
}
