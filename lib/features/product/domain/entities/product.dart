import 'package:equatable/equatable.dart';
import 'product_unit.dart';
import 'special_offer.dart';

/// نوع الوحدة الأساسية للمنتج
enum UnitSystemType {
  discrete,  // قطعة/حبة
  weight,    // كغ/غرام
  volume,    // لتر/مل
  length,    // متر/سم
}

/// دفعة الشراء لتتبع المخزون بدقة (Smart Embedded FIFO)
class PurchaseBatch extends Equatable {
  final double costPrice;
  final double remainingQuantity;
  final DateTime dateAdded;
  final String? supplierName;
  final String? supplierPhone;

  const PurchaseBatch({
    required this.costPrice,
    required this.remainingQuantity,
    required this.dateAdded,
    this.supplierName,
    this.supplierPhone,
  });

  PurchaseBatch copyWith({
    double? costPrice,
    double? remainingQuantity,
    DateTime? dateAdded,
    String? supplierName,
    String? supplierPhone,
  }) {
    return PurchaseBatch(
      costPrice: costPrice ?? this.costPrice,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      dateAdded: dateAdded ?? this.dateAdded,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
    );
  }

  @override
  List<Object?> get props => [costPrice, remainingQuantity, dateAdded, supplierName, supplierPhone];
}

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final double costPrice;
  final double stock; // Modified: int -> double for weight support
  final String category;
  final bool isWeighted;
  final double wholesalePrice;
  final String? expiryDate;
  final String? imageUrl;
  
  // --- New Architecture Fields ---
  final UnitSystemType unitSystemType; 
  final bool isDeleted; // Soft Deletes
  final List<PurchaseBatch> stockBatches; // Embedded FIFO Queue
  final String? coffeeRecipeJson; // Coffee System Payload
  final SpecialOffer? specialOffer; // العرض الخاص والتخفيض الذكي
  
  // --- Legacy fields for backward compatibility (ignored by new UI) ---
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
  bool get isUnlimitedStock => isWeighted || isCoffeeMachineProduct;
  double get wholesalePackPrice => units.where((u) => u.tier == UnitTier.medium).firstOrNull?.price ?? (units.isNotEmpty ? units.first.price : 0.0);
  double get wholesaleCartonPrice => units.where((u) => u.tier == UnitTier.large).firstOrNull?.price ?? (units.isNotEmpty ? units.first.price : 0.0);
  double get cartonCostPrice => units.where((u) => u.tier == UnitTier.large).firstOrNull?.cost ?? (units.isNotEmpty ? units.first.cost : 0.0);
  double get piecesPerPack => units.where((u) => u.tier == UnitTier.small).firstOrNull?.multiplier ?? (units.isNotEmpty ? units.first.multiplier : 20.0);
  double get packsPerCartonCount => units.where((u) => u.tier == UnitTier.medium).firstOrNull?.multiplier ?? (units.isNotEmpty ? units.first.multiplier : 10.0);
  String get unitType => unitSystemType.name;
  String get unit => baseUnitName;
  double get resolvedPiecePrice {
    final small = units.where((u) => u.tier == UnitTier.small).firstOrNull;
    if (small != null && small.price > 0) return small.price;
    if (singlePiecePrice > 0) return singlePiecePrice;
    return (piecesPerPack > 0 ? price / piecesPerPack : price);
  }
  double get resolvedPieceCost {
    final small = units.where((u) => u.tier == UnitTier.small).firstOrNull;
    if (small != null && small.cost > 0) return small.cost;
    return (piecesPerPack > 0 ? costPrice / piecesPerPack : costPrice);
  }
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
    this.stock = 0.0, // Now double
    this.category = 'عام',
    this.isWeighted = false,
    this.wholesalePrice = 0.0,
    this.expiryDate,
    this.imageUrl,
    
    // New Architecture Defaults
    this.unitSystemType = UnitSystemType.discrete,
    this.isDeleted = false,
    this.stockBatches = const [],
    this.coffeeRecipeJson,
    this.specialOffer,

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
    double? stock, // Now double
    String? category,
    bool? isWeighted,
    double? wholesalePrice,
    String? expiryDate,
    String? imageUrl,
    UnitSystemType? unitSystemType,
    bool? isDeleted,
    List<PurchaseBatch>? stockBatches,
    String? coffeeRecipeJson,
    String? baseUnitName,
    List<ProductUnit>? units,
    String? pluCode,
    SpecialOffer? specialOffer,
    bool? isCoffeeMachineProduct,
    bool? isTobacco,
    bool? isBeverage,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      isWeighted: isWeighted ?? this.isWeighted,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      expiryDate: expiryDate ?? this.expiryDate,
      imageUrl: imageUrl ?? this.imageUrl,
      unitSystemType: unitSystemType ?? this.unitSystemType,
      isDeleted: isDeleted ?? this.isDeleted,
      stockBatches: stockBatches ?? this.stockBatches,
      coffeeRecipeJson: coffeeRecipeJson ?? this.coffeeRecipeJson,
      specialOffer: specialOffer ?? this.specialOffer,
      baseUnitName: baseUnitName ?? this.baseUnitName,
      units: units ?? this.units,
      pluCode: pluCode ?? this.pluCode,
      // Legacy fields preserved from current object
      packName: packName,
      packBarcode: packBarcode,
      packMultiplier: packMultiplier,
      packPrice: packPrice,
      cartonBarcode: cartonBarcode,
      cartonPrice: cartonPrice,
      packsPerCarton: packsPerCarton,
      isTobacco: isTobacco ?? this.isTobacco,
      hasCarton: hasCarton,
      hasMultiUnit: hasMultiUnit,
      isCoffeeMachineProduct: isCoffeeMachineProduct ?? this.isCoffeeMachineProduct,
      isBeverage: isBeverage ?? this.isBeverage,
      singlePiecePrice: singlePiecePrice,
    );
  }

  @override
  List<Object?> get props => [
        id, name, barcode, price, costPrice, stock, category,
        isWeighted, wholesalePrice, expiryDate, imageUrl,
        unitSystemType, isDeleted, stockBatches, coffeeRecipeJson,
        specialOffer, baseUnitName, units, pluCode,
      ];
}

