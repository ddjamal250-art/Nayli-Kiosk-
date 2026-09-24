import 'package:equatable/equatable.dart';
import 'product_unit.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final double costPrice;
  final int stock;
  final String category;
  final bool isWeighted;
  final double wholesalePrice;
  final String? expiryDate;
  final String? imageUrl;
  
  // New UOM fields

  // Legacy fields for backward compatibility (ignored by new UI)
  final String? packName;
  final String? packBarcode;
  final int packMultiplier;
  final double packPrice;
  final String? cartonBarcode;
  final double cartonPrice;
  final int packsPerCarton;
  final bool isTobacco;
  final bool hasCarton;
  final bool hasMultiUnit;
  final bool isCoffeeMachineProduct;
  final bool isBeverage;
  final double singlePiecePrice;

  bool get isTobaccoProduct => category.contains('تبغ') || isTobacco;

  final String baseUnitName; 
  final List<ProductUnit> units;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0,
    this.category = 'عام',
    this.isWeighted = false,
    this.wholesalePrice = 0.0,
    this.expiryDate,
    this.imageUrl,
    this.packName,
    this.packBarcode,
    this.packMultiplier = 1,
    this.packPrice = 0.0,
    this.cartonBarcode,
    this.cartonPrice = 0.0,
    this.packsPerCarton = 10,
    this.isTobacco = false,
    this.hasCarton = false,
    this.hasMultiUnit = false,
    this.isCoffeeMachineProduct = false,
    this.isBeverage = false,
    this.singlePiecePrice = 0.0,
    this.baseUnitName = 'قطعة',
    this.units = const [],
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    int? stock,
    String? category,
    bool? isWeighted,
    double? wholesalePrice,
    String? expiryDate,
    String? imageUrl,
    String? baseUnitName,
    List<ProductUnit>? units,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      baseUnitName: baseUnitName ?? this.baseUnitName,
      units: units ?? this.units,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        costPrice,
        stock,
        category,
        isWeighted,
        wholesalePrice,
        expiryDate,
        imageUrl,
        baseUnitName,
        units,
      ];
}


