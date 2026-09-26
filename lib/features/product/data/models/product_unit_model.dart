import 'package:hive/hive.dart';
import '../../domain/entities/product_unit.dart';

part 'product_unit_model.g.dart';

@HiveType(typeId: 2)
class ProductUnitModel extends ProductUnit {
  @override
  @HiveField(0)
  final String name;
  
  @override
  @HiveField(1)
  final double multiplier;
  
  @override
  @HiveField(2)
  final String? barcode;
  
  @override
  @HiveField(3)
  final double price;
  
  @override
  @HiveField(4)
  final double cost;
  
  @override
  @HiveField(5)
  final bool isEnabled;
  
  @override
  @HiveField(6)
  final bool isWeighable;

  @HiveField(7)
  final int tierIndex;

  ProductUnitModel({
    required this.name,
    required this.multiplier,
    this.barcode,
    required this.price,
    this.cost = 0.0,
    this.isEnabled = true,
    this.isWeighable = false,
    this.tierIndex = 0,
  }) : super(
          name: name,
          multiplier: multiplier,
          barcode: barcode,
          price: price,
          cost: cost,
          isEnabled: isEnabled,
          isWeighable: isWeighable,
          tier: UnitTier.values.length > tierIndex ? UnitTier.values[tierIndex] : UnitTier.small,
        );

  factory ProductUnitModel.fromEntity(ProductUnit unit) {
    return ProductUnitModel(
      name: unit.name,
      multiplier: unit.multiplier,
      barcode: unit.barcode,
      price: unit.price,
      cost: unit.cost,
      isEnabled: unit.isEnabled,
      isWeighable: unit.isWeighable,
      tierIndex: unit.tier.index,
    );
  }

  ProductUnit toEntity() {
    return ProductUnit(
      name: name,
      multiplier: multiplier,
      barcode: barcode,
      price: price,
      cost: cost,
      isEnabled: isEnabled,
      isWeighable: isWeighable,
      tier: UnitTier.values.length > tierIndex ? UnitTier.values[tierIndex] : UnitTier.small,
    );
  }

  factory ProductUnitModel.fromJson(Map<String, dynamic> json) {
    return ProductUnitModel(
      name: json['name']?.toString() ?? '',
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      barcode: json['barcode']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isWeighable: json['isWeighable'] as bool? ?? false,
      tierIndex: (json['tierIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'multiplier': multiplier,
      'barcode': barcode,
      'price': price,
      'cost': cost,
      'isEnabled': isEnabled,
      'isWeighable': isWeighable,
      'tierIndex': tierIndex,
    };
  }
}
