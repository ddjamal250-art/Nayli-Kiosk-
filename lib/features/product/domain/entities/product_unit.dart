import 'package:equatable/equatable.dart';

/// مستوى الوحدة في الهرم
enum UnitTier {
  small,   // الوحدة الصغرى (أدنى تقسيم للبيع)
  medium,  // الوحدة الوسطى
  large,   // الوحدة الكبرى
}

class ProductUnit extends Equatable {
  final String name; // e.g. "علبة", "فاردو", "كرتونة"
  final UnitTier tier;
  final double multiplier; // Capacity in base pieces
  final String? barcode;
  final double price; // Selling price for this specific unit
  final double cost; // Cost price for this specific unit
  /// هل الوحدة مُفعَّلة وتظهر في الكاشير؟
  final bool isEnabled;
  /// هل هي وحدة ميزان؟ (السعر دج/كغ بدل سعر ثابت)
  final bool isWeighable;

  const ProductUnit({
    required this.name,
    this.tier = UnitTier.small,
    required this.multiplier,
    this.barcode,
    required this.price,
    this.cost = 0.0,
    this.isEnabled = true,
    this.isWeighable = false,
  });

  ProductUnit copyWith({
    String? name,
    UnitTier? tier,
    double? multiplier,
    String? barcode,
    double? price,
    double? cost,
    bool? isEnabled,
    bool? isWeighable,
  }) {
    return ProductUnit(
      name: name ?? this.name,
      tier: tier ?? this.tier,
      multiplier: multiplier ?? this.multiplier,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      isEnabled: isEnabled ?? this.isEnabled,
      isWeighable: isWeighable ?? this.isWeighable,
    );
  }

  @override
  List<Object?> get props => [
    name, tier, multiplier, barcode, price, cost,
    isEnabled, isWeighable,
  ];
}
