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

  // --- Universal Multi-Unit Packaging Helpers ---
  bool get isBeverage {
    final cat = category.toLowerCase();
    final n = name.toLowerCase();
    return cat.contains('مشروب') ||
        cat.contains('ماء') ||
        cat.contains('عصير') ||
        cat.contains('boisson') ||
        cat.contains('jus') ||
        cat.contains('eau') ||
        cat.contains('soda') ||
        cat.contains('غازي') ||
        n.contains('قارورة ماء') ||
        n.contains('eau') ||
        n.contains('ماء') ||
        n.contains('عصير') ||
        n.contains('مشروب') ||
        n.contains('كوكا') ||
        n.contains('بيبسي') ||
        n.contains('حمود') ||
        n.contains('رويبة') ||
        n.contains('إفري') ||
        n.contains('رامي') ||
        n.contains('سفن اب') ||
        n.contains('ميراندا') ||
        n.contains('فانتا');
  }

  bool get isTobaccoProduct {
    final cat = category.toLowerCase();
    final n = name.toLowerCase();
    return isTobacco ||
        cat.contains('تبغ') ||
        cat.contains('سجائر') ||
        cat.contains('شمة') ||
        cat.contains('معسل') ||
        cat.contains('tabac') ||
        cat.contains('cigarette') ||
        n.contains('مارلبورو') ||
        n.contains('marlboro') ||
        n.contains('ريم') ||
        n.contains('rym') ||
        n.contains('جولواز') ||
        n.contains('gauloises') ||
        n.contains('وينستون') ||
        n.contains('winston') ||
        n.contains('فيليب موريس') ||
        n.contains('philip morris') ||
        n.contains('سفير') ||
        n.contains('safir') ||
        n.contains('روثمان') ||
        n.contains('rothmans') ||
        n.contains('شمة') ||
        n.contains('سجائر') ||
        n.contains('دخان') ||
        n.contains('سيكار');
  }

  bool get hasSubUnit {
    if (isTobaccoProduct) return true;
    if (isBeverage) return false; // Water/Drinks never sold by 1/20th of a bottle!
    return singlePiecePrice > 0;
  }

  bool get hasCarton {
    if (isTobaccoProduct) return true;
    if (isBeverage) return true; // Drinks can be sold as Fardeau or Bottle
    return (packsPerCarton > 1 && cartonPrice > 0) || (packMultiplier > 1 && packPrice > 0) || cartonPrice > 0;
  }

  bool get hasMultiUnit => hasSubUnit || hasCarton;
  bool get hasMultiUnitPricing => hasMultiUnit;

  int get effectivePacksPerCarton {
    if (packsPerCarton > 0) return packsPerCarton;
    if (packMultiplier > 0) return packMultiplier;
    if (isBeverage) return 6;
    if (isTobaccoProduct) return 10;
    return 10;
  }

  int get effectivePiecesPerPack {
    if (piecesPerPack > 0) return piecesPerPack;
    if (isTobaccoProduct) return 20;
    return 1;
  }

  String get resolvedSubUnitName {
    if (isTobaccoProduct) return 'سيجارة';
    if (category.contains('جبن') || category.contains('أجبان') || category.toLowerCase().contains('fromage')) return 'مثلث / حبة';
    if (category.contains('بيض')) return 'بيضة';
    if (category.contains('قهوة') || category.contains('شاي')) return 'ساشي';
    return 'حبة';
  }

  String get resolvedPackName {
    if (isBeverage) return 'قارورة';
    if (category.contains('جبن') || category.contains('أجبان')) return 'علبة / بواطة';
    if (category.contains('بيض')) return 'بلاطو';
    if (isTobaccoProduct) return 'علبة / باكي';
    return 'علبة';
  }

  String get resolvedCartonName {
    if (packName != null && packName!.trim().isNotEmpty) return packName!.trim();
    if (isTobaccoProduct) return 'كرطوشة';
    if (isBeverage) return 'فاردو';
    if (category.contains('بيض')) return 'كرتونة بيض';
    if (category.contains('علك') || category.contains('حلويات')) return 'شكارة / كرتونة';
    return 'كرتونة / فاردو';
  }

  double get resolvedPiecePrice {
    if (singlePiecePrice > 0) return singlePiecePrice;
    if (effectivePiecesPerPack > 1) {
      return (price / effectivePiecesPerPack).ceilToDouble();
    }
    return price;
  }

  double get resolvedCartonPrice {
    if (cartonPrice > 0) return cartonPrice;
    if (packPrice > 0) return packPrice;
    return (price * effectivePacksPerCarton).roundToDouble();
  }

  double get resolvedPieceCost {
    if (effectivePiecesPerPack > 1) return costPrice / effectivePiecesPerPack;
    return costPrice;
  }

  double get resolvedCartonCost {
    if (cartonCostPrice > 0) return cartonCostPrice;
    return costPrice * effectivePacksPerCarton;
  }
}


