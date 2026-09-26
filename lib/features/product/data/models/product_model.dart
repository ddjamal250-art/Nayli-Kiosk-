import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';
import 'product_unit_model.dart';
import '../../domain/entities/product_unit.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 3)
class PurchaseBatchModel extends PurchaseBatch {
  @override
  @HiveField(0)
  final double costPrice;
  
  @override
  @HiveField(1)
  final double remainingQuantity;
  
  @override
  @HiveField(2)
  final DateTime dateAdded;

  PurchaseBatchModel({
    required this.costPrice,
    required this.remainingQuantity,
    required this.dateAdded,
  }) : super(
          costPrice: costPrice,
          remainingQuantity: remainingQuantity,
          dateAdded: dateAdded,
        );

  factory PurchaseBatchModel.fromEntity(PurchaseBatch batch) {
    return PurchaseBatchModel(
      costPrice: batch.costPrice,
      remainingQuantity: batch.remainingQuantity,
      dateAdded: batch.dateAdded,
    );
  }

  factory PurchaseBatchModel.fromJson(Map<String, dynamic> json) {
    return PurchaseBatchModel(
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble() ?? 0.0,
      dateAdded: json['dateAdded'] != null ? DateTime.parse(json['dateAdded']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'costPrice': costPrice,
      'remainingQuantity': remainingQuantity,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }
}

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final double stock; // Changed to double
  @override
  @HiveField(5)
  final double costPrice;
  @override
  @HiveField(6)
  final String category;
  @override
  @HiveField(7)
  final bool isWeighted;
  @override
  @HiveField(8)
  final double wholesalePrice;
  @override
  @HiveField(9)
  final String? expiryDate;
  @override
  @HiveField(10)
  final String? imageUrl;
  
  @override
  @HiveField(11)
  final String baseUnitName;
  @override
  @HiveField(12)
  final List<ProductUnitModel> units;

  // --- New Fields ---
  @HiveField(13)
  final int unitSystemTypeIndex;
  
  @override
  @HiveField(14)
  final bool isDeleted;
  
  @HiveField(15)
  final List<PurchaseBatchModel> stockBatchesModels;
  
  @override
  @HiveField(16)
  final String? coffeeRecipeJson;

  @override
  @HiveField(17)
  final String? pluCode;

  ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.costPrice = 0.0,
    this.category = 'عام',
    this.isWeighted = false,
    this.wholesalePrice = 0.0,
    this.expiryDate,
    this.imageUrl,
    this.baseUnitName = 'قطعة',
    this.units = const [],
    this.pluCode,
    this.unitSystemTypeIndex = 0,
    this.isDeleted = false,
    this.stockBatchesModels = const [],
    this.coffeeRecipeJson,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          costPrice: costPrice,
          category: category,
          isWeighted: isWeighted,
          wholesalePrice: wholesalePrice,
          expiryDate: expiryDate,
          imageUrl: imageUrl,
          baseUnitName: baseUnitName,
          units: units,
          pluCode: pluCode,
          unitSystemType: UnitSystemType.values.length > unitSystemTypeIndex ? UnitSystemType.values[unitSystemTypeIndex] : UnitSystemType.discrete,
          isDeleted: isDeleted,
          stockBatches: stockBatchesModels,
          coffeeRecipeJson: coffeeRecipeJson,
        );

  @override
  ProductModel copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    double? stock,
    String? category,
    bool? isWeighted,
    double? wholesalePrice,
    String? expiryDate,
    String? imageUrl,
    String? baseUnitName,
    List<ProductUnit>? units,
    String? pluCode,
    UnitSystemType? unitSystemType,
    bool? isDeleted,
    List<PurchaseBatch>? stockBatches,
    String? coffeeRecipeJson,
  }) {
    return ProductModel(
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
      units: units != null
          ? units.map((u) => ProductUnitModel.fromEntity(u)).toList()
          : this.units,
      pluCode: pluCode ?? this.pluCode,
      unitSystemTypeIndex: unitSystemType?.index ?? this.unitSystemTypeIndex,
      isDeleted: isDeleted ?? this.isDeleted,
      stockBatchesModels: stockBatches != null 
          ? stockBatches.map((b) => PurchaseBatchModel.fromEntity(b)).toList() 
          : this.stockBatchesModels,
      coffeeRecipeJson: coffeeRecipeJson ?? this.coffeeRecipeJson,
    );
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      costPrice: product.costPrice,
      category: product.category,
      wholesalePrice: product.wholesalePrice,
      expiryDate: product.expiryDate,
      imageUrl: product.imageUrl,
      baseUnitName: product.baseUnitName,
      units: product.units.map((u) => ProductUnitModel.fromEntity(u)).toList(),
      pluCode: product.pluCode,
      unitSystemTypeIndex: product.unitSystemType.index,
      isDeleted: product.isDeleted,
      stockBatchesModels: product.stockBatches.map((b) => PurchaseBatchModel.fromEntity(b)).toList(),
      coffeeRecipeJson: product.coffeeRecipeJson,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      costPrice: costPrice,
      category: category,
      wholesalePrice: wholesalePrice,
      expiryDate: expiryDate,
      imageUrl: imageUrl,
      baseUnitName: baseUnitName,
      units: units.map((u) => u.toEntity()).toList(),
      pluCode: pluCode,
      unitSystemType: UnitSystemType.values.length > unitSystemTypeIndex ? UnitSystemType.values[unitSystemTypeIndex] : UnitSystemType.discrete,
      isDeleted: isDeleted,
      stockBatches: stockBatchesModels,
      coffeeRecipeJson: coffeeRecipeJson,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'عام',
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      expiryDate: json['expiryDate']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      baseUnitName: json['baseUnitName']?.toString() ?? 'قطعة',
      units: (json['units'] as List<dynamic>?)
              ?.map((u) => ProductUnitModel.fromJson(Map<String, dynamic>.from(u)))
              .toList() ?? [],
      pluCode: json['pluCode']?.toString(),
      unitSystemTypeIndex: (json['unitSystemTypeIndex'] as num?)?.toInt() ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      stockBatchesModels: (json['stockBatches'] as List<dynamic>?)
              ?.map((b) => PurchaseBatchModel.fromJson(Map<String, dynamic>.from(b)))
              .toList() ?? [],
      coffeeRecipeJson: json['coffeeRecipeJson']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock': stock,
      'costPrice': costPrice,
      'category': category,
      'isWeighted': isWeighted,
      'wholesalePrice': wholesalePrice,
      'expiryDate': expiryDate,
      'imageUrl': imageUrl,
      'baseUnitName': baseUnitName,
      'units': units.map((u) => u.toJson()).toList(),
      'pluCode': pluCode,
      'unitSystemTypeIndex': unitSystemTypeIndex,
      'isDeleted': isDeleted,
      'stockBatches': stockBatchesModels.map((b) => b.toJson()).toList(),
      'coffeeRecipeJson': coffeeRecipeJson,
    };
  }
}
