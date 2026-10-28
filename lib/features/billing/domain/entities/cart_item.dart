import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_unit.dart';
import '../../../product/domain/entities/product_option.dart';

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
  /// ملاحظة خاصة بالبند (مثلاً للمطبخ أو الكافي: "بدون سكر"، "زيادة حليب")
  final String? itemNote;
  /// الخيارات الإضافية المختارة (مثلاً: نكهة الفانيلا +20 دج، حجم كبير +50 دج)
  final List<SelectedProductOption>? selectedOptions;

  const CartItem({
    required this.product,
    this.quantity = 1.0,
    this.unitLevel = 'base',
    this.customUnitName,
    this.customUnitPrice,
    this.customUnitCost,
    this.weightKg,
    this.customMultiplier,
    this.itemNote,
    this.selectedOptions,
  });

  ProductUnit? get selectedUnit {
    if (unitLevel == 'base') return null;
    return product.units.firstWhereOrNull((u) => u.name == unitLevel);
  }

  double get optionsPriceDelta {
    if (selectedOptions == null || selectedOptions!.isEmpty) return 0.0;
    return selectedOptions!.fold(0.0, (sum, opt) => sum + opt.priceDelta);
  }

  bool get isReturnItem => unitPrice < 0 || quantity < 0 || total < 0;

  double get unitPrice {
    if (customUnitPrice != null && customUnitPrice != 0) return customUnitPrice!;
    final unit = selectedUnit;
    final basePrice = unit != null ? unit.price : product.price; // Base unit price
    final sign = product.price < 0 ? -1.0 : 1.0;
    return (basePrice.abs() * sign) + (optionsPriceDelta * sign);
  }

  double get unitCost {
    if (customUnitCost != null && customUnitCost! > 0) return customUnitCost!;
    final unit = selectedUnit;
    if (unit != null) {
      if (unit.cost > 0) return unit.cost;
      return product.effectiveCostPrice * unit.multiplier; // Derive cost if not set
    }
    return product.effectiveCostPrice; // Base unit cost
  }

  double get unitPriceEffective => unitPrice;

  double get effectiveUnitCost => unitCost;

  String get unitDisplayName {
    if (customUnitName != null && customUnitName!.trim().isNotEmpty) return customUnitName!.trim();
    if (unitLevel != 'base') return unitLevel;
    return product.baseUnitName;
  }

  String get displayNameWithUnit {
    String name = (unitLevel == 'base' && customUnitName == null)
        ? product.name
        : '${product.name} [$unitDisplayName]';
    if (selectedOptions != null && selectedOptions!.isNotEmpty) {
      final optsText = selectedOptions!.map((o) => o.choiceName).join(', ');
      name += ' ($optsText)';
    }
    if (itemNote != null && itemNote!.trim().isNotEmpty) {
      name += ' [${itemNote!.trim()}]';
    }
    return name;
  }

  String get cartKey {
    final optionsKey = selectedOptions != null && selectedOptions!.isNotEmpty
        ? selectedOptions!.map((o) => '${o.groupName}:${o.choiceName}').join('|')
        : '';
    final noteKey = itemNote?.trim() ?? '';
    if (optionsKey.isEmpty && noteKey.isEmpty) {
      return '${product.id}_$unitLevel';
    }
    return '${product.id}_${unitLevel}_${optionsKey}_$noteKey';
  }

  static double _roundTo2(double val) => (val * 100.0).roundToDouble() / 100.0;

  /// المجموع الإجمالي للبيع مع دعم العروض الخاصة والتخفيضات والإرجاع
  double get total {
    if (weightKg != null) {
      final isNegative = unitPrice < 0 || quantity < 0 || weightKg! < 0;
      final rawTotal = weightKg!.abs() * unitPrice.abs() * quantity.abs();
      final rounded = _roundTo2(rawTotal);
      return isNegative ? -rounded : rounded;
    }

    // إذا تم تحديد عرض خاص أو سعر مخصص بالصفقة مباشرة
    if (unitLevel == 'custom' && customUnitPrice != null) {
      final isNegative = unitPrice < 0 || quantity < 0;
      final t = _roundTo2(customUnitPrice!.abs() * quantity.abs());
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
      final rounded = _roundTo2(totalAmount);
      return isNegative ? -rounded : rounded;
    }

    return _roundTo2(unitPrice * quantity);
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
    return _roundTo2((normalTotal - offerTotal).clamp(0.0, double.infinity));
  }

  /// الكمية الحقيقية للخصم من المخزون
  double get totalStockDeduct {
    if (weightKg != null) return weightKg! * quantity.abs();
    if (customMultiplier != null && customMultiplier! > 0) {
      return quantity * customMultiplier!;
    }
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1.0;
    return quantity * multiplier;
  }

  /// للتوافق مع الكود القديم
  double get totalBaseQuantity {
    if (weightKg != null) return weightKg! * quantity.abs();
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
      final costPerKg = (customUnitCost != null && customUnitCost! > 0)
          ? customUnitCost!
          : ((unit != null && unit.cost > 0) ? unit.cost : product.effectiveCostPrice);
      return _roundTo2(weightKg! * costPerKg * quantity.abs());
    }
    return _roundTo2(unitCost * quantity);
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
    String? itemNote,
    List<SelectedProductOption>? selectedOptions,
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
      itemNote: itemNote ?? this.itemNote,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }

  @override
  List<Object?> get props => [
    product, quantity, unitLevel, customUnitName,
    customUnitPrice, customUnitCost, weightKg, customMultiplier,
    itemNote, selectedOptions,
  ];
}
