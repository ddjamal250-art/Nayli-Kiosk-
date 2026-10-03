import 'dart:convert';
import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/special_offer.dart';
import 'product_unit_model.dart';
import '../../domain/entities/product_unit.dart';

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

  @override
  @HiveField(3)
  final String? supplierName;

  @override
  @HiveField(4)
  final String? supplierPhone;

  PurchaseBatchModel({
    required this.costPrice,
    required this.remainingQuantity,
    required this.dateAdded,
    this.supplierName,
    this.supplierPhone,
  }) : super(
          costPrice: costPrice,
          remainingQuantity: remainingQuantity,
          dateAdded: dateAdded,
          supplierName: supplierName,
          supplierPhone: supplierPhone,
        );

  factory PurchaseBatchModel.fromEntity(PurchaseBatch batch) {
    return PurchaseBatchModel(
      costPrice: batch.costPrice,
      remainingQuantity: batch.remainingQuantity,
      dateAdded: batch.dateAdded,
      supplierName: batch.supplierName,
      supplierPhone: batch.supplierPhone,
    );
  }

  factory PurchaseBatchModel.fromJson(Map<String, dynamic> json) {
    return PurchaseBatchModel(
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble() ?? 0.0,
      dateAdded: json['dateAdded'] != null ? DateTime.parse(json['dateAdded']) : DateTime.now(),
      supplierName: json['supplierName']?.toString(),
      supplierPhone: json['supplierPhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'costPrice': costPrice,
      'remainingQuantity': remainingQuantity,
      'dateAdded': dateAdded.toIso8601String(),
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
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

  @HiveField(18)
  final String? specialOfferJson;

  @override
  SpecialOffer? get specialOffer {
    if (specialOfferJson == null || specialOfferJson!.trim().isEmpty) return null;
    try {
      return SpecialOffer.fromJson(jsonDecode(specialOfferJson!));
    } catch (_) {
      return null;
    }
  }

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
    this.specialOfferJson,
    bool isCoffeeMachineProduct = false,
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
          specialOffer: specialOfferJson != null && specialOfferJson.trim().isNotEmpty
              ? SpecialOffer.fromJson(jsonDecode(specialOfferJson))
              : null,
          isCoffeeMachineProduct: isCoffeeMachineProduct,
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
    UnitSystemType? unitSystemType,
    bool? isDeleted,
    List<PurchaseBatch>? stockBatches,
    String? coffeeRecipeJson,
    String? baseUnitName,
    List<ProductUnit>? units,
    String? pluCode,
    SpecialOffer? specialOffer,
    String? specialOfferJson,
    bool? isCoffeeMachineProduct,
    bool? isTobacco,
    bool? isBeverage,
  }) {
    return ProductModel(
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
      specialOfferJson: specialOffer != null
          ? jsonEncode(specialOffer.toJson())
          : (specialOfferJson ?? this.specialOfferJson),
      isCoffeeMachineProduct: isCoffeeMachineProduct ?? this.isCoffeeMachineProduct,
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
      isWeighted: product.isWeighted,
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
      specialOfferJson: product.specialOffer != null ? jsonEncode(product.specialOffer!.toJson()) : null,
      isCoffeeMachineProduct: product.isCoffeeMachineProduct,
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
      isWeighted: isWeighted,
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
      specialOffer: specialOffer,
      isCoffeeMachineProduct: isCoffeeMachineProduct,
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
      specialOfferJson: json['specialOfferJson']?.toString(),
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
      'specialOfferJson': specialOfferJson,
    };
  }
}

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      barcode: fields[2] as String,
      price: (fields[3] as num?)?.toDouble() ?? 0.0,
      stock: (fields[4] as num?)?.toDouble() ?? 0.0,
      costPrice: (fields[5] as num?)?.toDouble() ?? 0.0,
      category: fields[6] as String? ?? 'عام',
      isWeighted: fields[7] as bool? ?? false,
      wholesalePrice: (fields[8] as num?)?.toDouble() ?? 0.0,
      expiryDate: fields[9] as String?,
      imageUrl: fields[10] as String?,
      baseUnitName: fields[11] as String? ?? 'قطعة',
      units: (fields[12] as List?)?.cast<ProductUnitModel>() ?? [],
      unitSystemTypeIndex: fields[13] as int? ?? 0,
      isDeleted: fields[14] as bool? ?? false,
      stockBatchesModels: (fields[15] as List?)?.cast<PurchaseBatchModel>() ?? [],
      coffeeRecipeJson: fields[16] as String?,
      pluCode: fields[17] as String?,
      specialOfferJson: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.stock)
      ..writeByte(5)
      ..write(obj.costPrice)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.isWeighted)
      ..writeByte(8)
      ..write(obj.wholesalePrice)
      ..writeByte(9)
      ..write(obj.expiryDate)
      ..writeByte(10)
      ..write(obj.imageUrl)
      ..writeByte(11)
      ..write(obj.baseUnitName)
      ..writeByte(12)
      ..write(obj.units)
      ..writeByte(13)
      ..write(obj.unitSystemTypeIndex)
      ..writeByte(14)
      ..write(obj.isDeleted)
      ..writeByte(15)
      ..write(obj.stockBatchesModels)
      ..writeByte(16)
      ..write(obj.coffeeRecipeJson)
      ..writeByte(17)
      ..write(obj.pluCode)
      ..writeByte(18)
      ..write(obj.specialOfferJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PurchaseBatchModelAdapter extends TypeAdapter<PurchaseBatchModel> {
  @override
  final int typeId = 3;

  @override
  PurchaseBatchModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseBatchModel(
      costPrice: (fields[0] as num?)?.toDouble() ?? 0.0,
      remainingQuantity: (fields[1] as num?)?.toDouble() ?? 0.0,
      dateAdded: fields[2] as DateTime,
      supplierName: fields[3] as String?,
      supplierPhone: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseBatchModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.costPrice)
      ..writeByte(1)
      ..write(obj.remainingQuantity)
      ..writeByte(2)
      ..write(obj.dateAdded)
      ..writeByte(3)
      ..write(obj.supplierName)
      ..writeByte(4)
      ..write(obj.supplierPhone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseBatchModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
