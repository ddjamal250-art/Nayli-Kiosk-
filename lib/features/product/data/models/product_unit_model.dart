import 'package:hive/hive.dart';
import '../../domain/entities/product_unit.dart';

part 'product_unit_model.g.dart';

@HiveType(typeId: 2) // Assuming 0 is Product, 1 is maybe Shop. I should check if 2 is free.
class ProductUnitModel extends ProductUnit {
  @override
  @HiveField(0)
  final String name;
  @override
  @HiveField(1)
  final int multiplier;
  @override
  @HiveField(2)
  final String? barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final double cost;

  const ProductUnitModel({
    required this.name,
    required this.multiplier,
    this.barcode,
    required this.price,
    this.cost = 0.0,
  }) : super(
          name: name,
          multiplier: multiplier,
          barcode: barcode,
          price: price,
          cost: cost,
        );

  factory ProductUnitModel.fromEntity(ProductUnit unit) {
    return ProductUnitModel(
      name: unit.name,
      multiplier: unit.multiplier,
      barcode: unit.barcode,
      price: unit.price,
      cost: unit.cost,
    );
  }

  ProductUnit toEntity() {
    return ProductUnit(
      name: name,
      multiplier: multiplier,
      barcode: barcode,
      price: price,
      cost: cost,
    );
  }

  factory ProductUnitModel.fromJson(Map<String, dynamic> json) {
    return ProductUnitModel(
      name: json['name']?.toString() ?? '',
      multiplier: (json['multiplier'] as num?)?.toInt() ?? 1,
      barcode: json['barcode']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'multiplier': multiplier,
      'barcode': barcode,
      'price': price,
      'cost': cost,
    };
  }
}
