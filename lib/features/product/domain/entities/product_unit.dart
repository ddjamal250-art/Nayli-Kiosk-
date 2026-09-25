import 'package:equatable/equatable.dart';

class ProductUnit extends Equatable {
  final String name; // e.g. "علبة", "فاردو", "كرتونة"
  final int multiplier; // How many base units this contains (e.g. 24)
  final String? barcode;
  final double price; // Selling price for this specific unit
  final double cost; // Cost price for this specific unit (optional, can be derived)
  final String? level; // 'piece', 'pack', 'carton', 'weighable'
  final String? type; // 'piece', 'meter', 'ml'
  final double? wholesalePrice;
  final double? costPrice;
  /// هل الوحدة مُفعَّلة وتظهر في الكاشير؟
  final bool isEnabled;
  /// هل هي وحدة ميزان؟ (السعر دج/كغ بدل سعر ثابت)
  final bool isWeighable;

  const ProductUnit({
    required this.name,
    required this.multiplier,
    this.barcode,
    required this.price,
    this.cost = 0.0,
    this.level,
    this.type,
    this.wholesalePrice,
    this.costPrice,
    this.isEnabled = true,
    this.isWeighable = false,
  });

  ProductUnit copyWith({
    String? name,
    int? multiplier,
    String? barcode,
    double? price,
    double? cost,
    String? level,
    String? type,
    double? wholesalePrice,
    double? costPrice,
    bool? isEnabled,
    bool? isWeighable,
  }) {
    return ProductUnit(
      name: name ?? this.name,
      multiplier: multiplier ?? this.multiplier,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      level: level ?? this.level,
      type: type ?? this.type,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      costPrice: costPrice ?? this.costPrice,
      isEnabled: isEnabled ?? this.isEnabled,
      isWeighable: isWeighable ?? this.isWeighable,
    );
  }

  @override
  List<Object?> get props => [
    name, multiplier, barcode, price, cost,
    level, type, wholesalePrice, costPrice,
    isEnabled, isWeighable,
  ];
}
