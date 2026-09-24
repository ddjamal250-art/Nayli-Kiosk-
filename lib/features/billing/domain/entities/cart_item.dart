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

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.unitLevel = 'base',
    this.customUnitName,
    this.customUnitPrice,
    this.customUnitCost,
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

  double get total => unitPrice * quantity;

  // Real quantity in terms of Base Unit (important for inventory deduction)
  int get totalBaseQuantity {
    final unit = selectedUnit;
    final multiplier = unit?.multiplier ?? 1;
    return quantity * multiplier;
  }

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? unitLevel,
    String? customUnitName,
    double? customUnitPrice,
    double? customUnitCost,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitLevel: unitLevel ?? this.unitLevel,
      customUnitName: customUnitName ?? this.customUnitName,
      customUnitPrice: customUnitPrice ?? this.customUnitPrice,
      customUnitCost: customUnitCost ?? this.customUnitCost,
    );
  }

  @override
  List<Object?> get props => [product, quantity, unitLevel, customUnitName, customUnitPrice, customUnitCost];
}
