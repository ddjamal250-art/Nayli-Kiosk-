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

  // Legacy getters - computed from units list or defaults
  double get wholesalePackPrice => units.isNotEmpty ? (units.firstWhere((u) => u.level == 'pack', orElse: () => units.first).wholesalePrice ?? 0.0) : 0.0;
  double get wholesaleCartonPrice => units.isNotEmpty ? (units.firstWhere((u) => u.level == 'carton', orElse: () => units.first).wholesalePrice ?? 0.0) : 0.0;
  double get cartonCostPrice => units.isNotEmpty ? (units.firstWhere((u) => u.level == 'carton', orElse: () => units.first).costPrice ?? 0.0) : 0.0;
  int get piecesPerPack => units.isNotEmpty ? (units.firstWhere((u) => u.level == 'piece', orElse: () => units.first).multiplier) : 20;
  int get packsPerCartonCount => units.isNotEmpty ? (units.firstWhere((u) => u.level == 'pack', orElse: () => units.first).multiplier) : 10;
  String get unitType => units.isNotEmpty ? units.first.type ?? 'piece' : 'piece';
  double get resolvedPiecePrice => singlePiecePrice > 0 ? singlePiecePrice : (piecesPerPack > 0 ? price / piecesPerPack : price);
  double get resolvedPieceCost => piecesPerPack > 0 ? costPrice / piecesPerPack : costPrice;
  String get resolvedPackName => packName ?? 'علبة';
  String get resolvedSubUnitName => baseUnitName;
  double get cupsYield => 0.0;
  bool get hasSubUnit => piecesPerPack > 1;
  bool get hasCustomQuantityPricing => false;

  final String baseUnitName; 
  final List<ProductUnit> units;
  /// كود PLU للميزان التجاري (مثال: "1", "42") — null إذا لا يوجد ميزان
  final String? pluCode;

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
    this.pluCode,
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
    String? pluCode,
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
      pluCode: pluCode ?? this.pluCode,
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
        pluCode,
      ];
}


