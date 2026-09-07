import 'package:equatable/equatable.dart';
import '../../../product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final String unitLevel; // 'pack', 'piece', 'carton'
  final String? customUnitName;
  final double? customUnitPrice;
  final double? customUnitCost;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.unitLevel = 'pack',
    this.customUnitName,
    this.customUnitPrice,
    this.customUnitCost,
  });

  double get unitPrice {
    if (customUnitPrice != null && customUnitPrice! > 0) return customUnitPrice!;
    if (unitLevel == 'piece') return product.resolvedPiecePrice;
    if (unitLevel == 'carton') return product.resolvedCartonPrice;
    return product.price;
  }

  double get unitCost {
    if (customUnitCost != null && customUnitCost! > 0) return customUnitCost!;
    if (unitLevel == 'piece') return product.resolvedPieceCost;
    if (unitLevel == 'carton') return product.resolvedCartonCost;
    return product.costPrice;
  }

  String get unitDisplayName {
    if (customUnitName != null && customUnitName!.trim().isNotEmpty) return customUnitName!.trim();
    if (unitLevel == 'piece') return product.resolvedSubUnitName;
    if (unitLevel == 'carton') return product.resolvedCartonName;
    return product.resolvedPackName;
  }

  String get displayNameWithUnit {
    if (unitLevel == 'pack') return product.name;
    return '${product.name} [$unitDisplayName]';
  }

  String get cartKey => '${product.id}_$unitLevel';

  double get total => unitPrice * quantity;

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
