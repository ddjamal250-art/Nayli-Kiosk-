import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';
import 'product_unit_model.dart';

part 'product_model.g.dart'; // Hive generator

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
  final int stock;
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
  
  // New UOM Fields (Reusing some old indexes, this requires wiping the DB as user agreed)
  @override
  @HiveField(11)
  final String baseUnitName;
  @override
  @HiveField(12)
  final List<ProductUnitModel> units;

  const ProductModel({
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
  }) : super(
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
          units: units,
        );

  @override
  ProductModel copyWith({
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
      units: (units as List<ProductUnitModel>?) ?? this.units,
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
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawIsWeighted = json['isWeighted'];
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'عام',
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      expiryDate: json['expiryDate']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      baseUnitName: json['baseUnitName']?.toString() ?? 'قطعة',
      units: (json['units'] as List<dynamic>?)
              ?.map((u) => ProductUnitModel.fromJson(Map<String, dynamic>.from(u)))
              .toList() ??
          [],
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
    };
  }
}
