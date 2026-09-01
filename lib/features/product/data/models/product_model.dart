import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

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
  final String? packBarcode;
  @override
  @HiveField(11)
  final int packMultiplier;
  @override
  @HiveField(12)
  final double packPrice;
  @override
  @HiveField(13)
  final String? packName;

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
    this.packBarcode,
    this.packMultiplier = 1,
    this.packPrice = 0.0,
    this.packName,
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
          packBarcode: packBarcode,
          packMultiplier: packMultiplier,
          packPrice: packPrice,
          packName: packName,
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
    String? packBarcode,
    int? packMultiplier,
    double? packPrice,
    String? packName,
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
      packBarcode: packBarcode ?? this.packBarcode,
      packMultiplier: packMultiplier ?? this.packMultiplier,
      packPrice: packPrice ?? this.packPrice,
      packName: packName ?? this.packName,
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
      packBarcode: product.packBarcode,
      packMultiplier: product.packMultiplier,
      packPrice: product.packPrice,
      packName: product.packName,
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
      packBarcode: packBarcode,
      packMultiplier: packMultiplier,
      packPrice: packPrice,
      packName: packName,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'عام',
      isWeighted: json['isWeighted'] as bool? ?? false,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
      expiryDate: json['expiryDate'] as String?,
      packBarcode: json['packBarcode'] as String?,
      packMultiplier: (json['packMultiplier'] as num?)?.toInt() ?? 1,
      packPrice: (json['packPrice'] as num?)?.toDouble() ?? 0.0,
      packName: json['packName'] as String?,
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
      'packBarcode': packBarcode,
      'packMultiplier': packMultiplier,
      'packPrice': packPrice,
      'packName': packName,
    };
  }
}
