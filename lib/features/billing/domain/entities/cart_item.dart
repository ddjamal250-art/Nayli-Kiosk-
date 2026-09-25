import 'package:equatable/equatable.dart';
import 'package:collection/collection.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_unit.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final String unitLevel; // Name of the selected unit (e.g. 'فاردو', or 'base' for base unit)
  final String? customUnitName;
  final double? customUnitPrice;
  final double? customUnitCost;
  /// وزن حقيقي بالكيلوغرام للمنتجات الميزانية (null = منتج عادي)
  final double? weightKg;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.unitLevel = 'base',
    this.customUnitName,
    this.customUnitPrice,
    this.customUnitCost,
    this.weightKg,
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

  /// المجموع الإجمالي للبيع
  double get total {
    if (weightKg != null) return customUnitPrice ?? (weightKg! * unitPrice);
    return unitPrice * quantity;
  }

  /// الكمية الحقيقية للخصم من المخزون:
  /// - منتج ميزاني: weightKg (بالكغ — يُضرب ×1000 عند الخزن بالغرام)
  /// - منتج عادي: quantity × multiplier
  double get totalStockDeduct {
    if (weightKg != null) return weightKg!;
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1;
    return (quantity * multiplier).toDouble();
  }

  /// للتوافق مع الكود القديم (المنتجات العادية فقط)
  int get totalBaseQuantity {
    if (weightKg != null) return 1; // الخصم الحقيقي عبر totalStockDeduct
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1;
    return quantity * multiplier;
  }

  /// التكلفة الحقيقية للفاتورة:
  /// - منتج ميزاني: وزن × تكلفة/كغ
  /// - منتج عادي: تكلفة × عدد
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
    int? quantity,
    String? unitLevel,
    String? customUnitName,
    double? customUnitPrice,
    double? customUnitCost,
    double? weightKg,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitLevel: unitLevel ?? this.unitLevel,
      customUnitName: customUnitName ?? this.customUnitName,
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
      customUnitCost: customUnitCost ?? this.customUnitCost,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  @override
  List<Object?> get props => [
    product, quantity, unitLevel, customUnitName,
    customUnitPrice, customUnitCost, weightKg,
  ];
}
