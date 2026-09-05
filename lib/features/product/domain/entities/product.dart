import 'package:equatable/equatable.dart';

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
  final String? packBarcode;
  final int packMultiplier;
  final double packPrice;
  final String? packName;
  final String? imageUrl;
  final bool isTobacco;
  final int piecesPerPack;
  final int packsPerCarton;
  final double singlePiecePrice;
  final double cartonPrice;
  final double wholesaleCartonPrice;
  final double wholesalePackPrice;
  final double cartonCostPrice;
  final String unitType; // 'unit', 'meter', 'ml'

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
    this.packBarcode,
    this.packMultiplier = 1,
    this.packPrice = 0.0,
    this.packName,
    this.imageUrl,
    this.isTobacco = false,
    this.piecesPerPack = 20,
    this.packsPerCarton = 10,
    this.singlePiecePrice = 0.0,
    this.cartonPrice = 0.0,
    this.wholesaleCartonPrice = 0.0,
    this.wholesalePackPrice = 0.0,
    this.cartonCostPrice = 0.0,
    this.unitType = 'unit',
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
    String? packBarcode,
    int? packMultiplier,
    double? packPrice,
    String? packName,
    String? imageUrl,
    bool? isTobacco,
    int? piecesPerPack,
    int? packsPerCarton,
    double? singlePiecePrice,
    double? cartonPrice,
    double? wholesaleCartonPrice,
    double? wholesalePackPrice,
    double? cartonCostPrice,
    String? unitType,
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
      packBarcode: packBarcode ?? this.packBarcode,
      packMultiplier: packMultiplier ?? this.packMultiplier,
      packPrice: packPrice ?? this.packPrice,
      packName: packName ?? this.packName,
      imageUrl: imageUrl ?? this.imageUrl,
      isTobacco: isTobacco ?? this.isTobacco,
      piecesPerPack: piecesPerPack ?? this.piecesPerPack,
      packsPerCarton: packsPerCarton ?? this.packsPerCarton,
      singlePiecePrice: singlePiecePrice ?? this.singlePiecePrice,
      cartonPrice: cartonPrice ?? this.cartonPrice,
      wholesaleCartonPrice: wholesaleCartonPrice ?? this.wholesaleCartonPrice,
      wholesalePackPrice: wholesalePackPrice ?? this.wholesalePackPrice,
      cartonCostPrice: cartonCostPrice ?? this.cartonCostPrice,
      unitType: unitType ?? this.unitType,
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
        packBarcode,
        packMultiplier,
        packPrice,
        packName,
        imageUrl,
        isTobacco,
        piecesPerPack,
        packsPerCarton,
        singlePiecePrice,
        cartonPrice,
        wholesaleCartonPrice,
        wholesalePackPrice,
        cartonCostPrice,
        unitType,
      ];
}

