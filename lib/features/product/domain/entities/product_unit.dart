import 'package:equatable/equatable.dart';

class ProductUnit extends Equatable {
  final String name; // e.g. "علبة", "فاردو", "كرتونة"
  final int multiplier; // How many base units this contains (e.g. 24)
  final String? barcode;
  final double price; // Selling price for this specific unit
  final double cost; // Cost price for this specific unit (optional, can be derived)

  const ProductUnit({
    required this.name,
    required this.multiplier,
    this.barcode,
    required this.price,
    this.cost = 0.0,
  });

  ProductUnit copyWith({
    String? name,
    int? multiplier,
    String? barcode,
    double? price,
    double? cost,
  }) {
    return ProductUnit(
      name: name ?? this.name,
      multiplier: multiplier ?? this.multiplier,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
    );
  }

  @override
  List<Object?> get props => [name, multiplier, barcode, price, cost];
}
