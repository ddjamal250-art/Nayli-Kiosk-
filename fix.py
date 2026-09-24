import re

# 1. Product.dart
p_file = r'd:\repos\Nayli Market -custom-\lib\features\product\domain\entities\product.dart'
with open(p_file, 'r', encoding='utf-8') as f:
    p_content = f.read()

legacy_fields = '''
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

  final String baseUnitName;'''

p_content = p_content.replace('  final String baseUnitName;', legacy_fields)

legacy_args = '''    this.packName,
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
    this.baseUnitName = 'قطعة','''

p_content = p_content.replace("    this.baseUnitName = 'قطعة',", legacy_args)

with open(p_file, 'w', encoding='utf-8') as f:
    f.write(p_content)

# 2. ProductModel.dart
pm_file = r'd:\repos\Nayli Market -custom-\lib\features\product\data\models\product_model.dart'
with open(pm_file, 'r', encoding='utf-8') as f:
    pm_content = f.read()

pm_content = pm_content.replace(
    "import 'product_unit_model.dart';",
    "import 'product_unit_model.dart';\nimport '../../domain/entities/product_unit.dart';"
)

legacy_hive = '''  @override
  @HiveField(13)
  final String? packBarcode;

  @override
  @HiveField(14)
  final String? packName;

  @override
  @HiveField(15)
  final int packMultiplier;

  @override
  @HiveField(16)
  final double packPrice;

  @override
  @HiveField(17)
  final String? cartonBarcode;

  @override
  @HiveField(18)
  final double cartonPrice;

  @override
  @HiveField(19)
  final int packsPerCarton;

  @override
  @HiveField(20)
  final bool isTobacco;

  const ProductModel({'''

pm_content = pm_content.replace('  const ProductModel({', legacy_hive)

legacy_pm_args = '''    this.packBarcode,
    this.packName,
    this.packMultiplier = 1,
    this.packPrice = 0.0,
    this.cartonBarcode,
    this.cartonPrice = 0.0,
    this.packsPerCarton = 10,
    this.isTobacco = false,
    this.baseUnitName = 'قطعة','''

pm_content = pm_content.replace("    this.baseUnitName = 'قطعة',", legacy_pm_args)

legacy_super = '''          packName: packName,
          packBarcode: packBarcode,
          packMultiplier: packMultiplier,
          packPrice: packPrice,
          cartonBarcode: cartonBarcode,
          cartonPrice: cartonPrice,
          packsPerCarton: packsPerCarton,
          isTobacco: isTobacco,
          baseUnitName: baseUnitName,'''

pm_content = pm_content.replace('          baseUnitName: baseUnitName,', legacy_super)

legacy_fromEntity = '''      packName: product.packName,
      packBarcode: product.packBarcode,
      packMultiplier: product.packMultiplier,
      packPrice: product.packPrice,
      cartonBarcode: product.cartonBarcode,
      cartonPrice: product.cartonPrice,
      packsPerCarton: product.packsPerCarton,
      isTobacco: product.isTobacco,
      units: product.units.map((u) => ProductUnitModel.fromEntity(u)).toList(),'''

pm_content = pm_content.replace('      units: product.units.map((u) => ProductUnitModel.fromEntity(u)).toList(),', legacy_fromEntity)

legacy_toEntity = '''      packName: packName,
      packBarcode: packBarcode,
      packMultiplier: packMultiplier,
      packPrice: packPrice,
      cartonBarcode: cartonBarcode,
      cartonPrice: cartonPrice,
      packsPerCarton: packsPerCarton,
      isTobacco: isTobacco,
      baseUnitName: baseUnitName,'''

pm_content = pm_content.replace('      baseUnitName: baseUnitName,\n      units: units.map((u) => u.toEntity()).toList(),', legacy_toEntity + '\n      units: units.map((u) => u.toEntity()).toList(),')

with open(pm_file, 'w', encoding='utf-8') as f:
    f.write(pm_content)

# 3. KioskService.dart
k_file = r'd:\repos\Nayli Market -custom-\lib\features\billing\data\kiosk_service.dart'
with open(k_file, 'r', encoding='utf-8') as f:
    k_content = f.read()

new_method = '''  static KioskProductResult lookupBarcode(String rawBarcode) {
    final cleanCode = BarcodeNormalizer.clean(rawBarcode);
    if (cleanCode.isEmpty) {
      return const KioskProductResult(found: false, barcode: '');
    }

    final productBox = HiveDatabase.productBox;
    final allProducts = productBox.values.toList();

    // 1. Barcode scale checking
    if (ScaleBarcodeParser.isScaleBarcode(cleanCode)) {
      final parsed = ScaleBarcodeParser.parse(cleanCode);
      if (parsed != null) {
        Product? matchedProduct;
        for (final p in allProducts) {
          if (p.barcode == parsed.itemCode ||
              BarcodeNormalizer.stripLeadingZeros(p.barcode) ==
                  BarcodeNormalizer.stripLeadingZeros(parsed.itemCode)) {
            matchedProduct = p;
            break;
          }
        }

        if (matchedProduct != null) {
          final isWeightFormat = cleanCode.startsWith('28') || cleanCode.startsWith('29');
          final calculatedWeight = isWeightFormat ? parsed.weightOrPrice : (parsed.weightOrPrice / (matchedProduct.price > 0 ? matchedProduct.price : 1.0));
          final calculatedPrice = isWeightFormat ? (parsed.weightOrPrice * matchedProduct.price) : parsed.weightOrPrice;

          return KioskProductResult(
            found: true,
            barcode: cleanCode,
            name: matchedProduct.name,
            price: calculatedPrice,
            category: matchedProduct.category,
            isWeighed: true,
            weight: calculatedWeight,
            pricePerKg: matchedProduct.price,
          );
        }
      }
    }

    // 2. Direct search
    for (final p in allProducts) {
      if (BarcodeNormalizer.matches(p.barcode, cleanCode)) {
        return KioskProductResult(
          found: true,
          barcode: p.barcode,
          name: p.name,
          price: p.price,
          category: p.category,
          isUnit: false,
          singlePrice: p.price,
          savings: 0.0,
        );
      }

      for (final u in p.units) {
        if (u.barcode != null &&
            u.barcode!.isNotEmpty &&
            BarcodeNormalizer.matches(u.barcode, cleanCode)) {
          
          final expectedSingleTotal = p.price * u.multiplier;
          final savings = (expectedSingleTotal - u.price).clamp(0.0, 99999.0);

          return KioskProductResult(
            found: true,
            barcode: u.barcode!,
            name: p.name + ' (' + u.name + ' x' + u.multiplier.toString() + ')',
            price: u.price,
            category: p.category,
            isUnit: true,
            unitName: u.name,
            unitMultiplier: u.multiplier,
            singlePrice: p.price,
            savings: savings,
          );
        }
      }
    }

    // 3. Unlisted
    _recordUnlistedScan(cleanCode);

    return KioskProductResult(
      found: false,
      barcode: cleanCode,
    );
  }'''

parts = k_content.split('static KioskProductResult lookupBarcode(String rawBarcode) {')
if len(parts) == 2:
    subparts = parts[1].split('static void _recordUnlistedScan')
    final_content = parts[0] + new_method + '\n\n  static void _recordUnlistedScan' + subparts[1]
    
    # Fix KioskProductResult constructor
    final_content = final_content.replace('this.isPack = false,\n    this.packName,\n    this.packMultiplier = 1,\n    this.packPrice = 0.0,\n    this.savings = 0.0,', 'this.isUnit = false,\n    this.unitName,\n    this.unitMultiplier = 1,\n    this.singlePrice = 0.0,\n    this.savings = 0.0,')
    final_content = final_content.replace('final bool isPack;', 'final bool isUnit;')
    final_content = final_content.replace('final String? packName;', 'final String? unitName;')
    final_content = final_content.replace('final int packMultiplier;', 'final int unitMultiplier;')
    final_content = final_content.replace('final double packPrice;', 'final double singlePrice;')
    
    final_content = final_content.replace("'isPack': isPack,", "'isUnit': isUnit,")
    final_content = final_content.replace("'packName': packName,", "'unitName': unitName,")
    final_content = final_content.replace("'packMultiplier': packMultiplier,", "'unitMultiplier': unitMultiplier,")
    final_content = final_content.replace("'packPrice': packPrice,", "'singlePrice': singlePrice,")
    
    with open(k_file, 'w', encoding='utf-8') as f:
        f.write(final_content)

# 4. LocalSyncServer.dart
ls_file = r'd:\repos\Nayli Market -custom-\lib\core\data\local_sync_server.dart'
with open(ls_file, 'r', encoding='utf-8') as f:
    ls_content = f.read()

ls_content = ls_content.replace('var isPack = product.isPack;', 'var isUnit = product.isUnit;')
ls_content = ls_content.replace('var packName = product.packName;', 'var unitName = product.unitName;')
ls_content = ls_content.replace('var packMultiplier = product.packMultiplier;', 'var unitMultiplier = product.unitMultiplier;')
ls_content = ls_content.replace('var packPrice = product.packPrice;', 'var singlePrice = product.singlePrice;')

ls_content = ls_content.replace('data.isPack', 'data.isUnit')
ls_content = ls_content.replace('data.packName', 'data.unitName')
ls_content = ls_content.replace('data.packMultiplier', 'data.unitMultiplier')
ls_content = ls_content.replace('data.packPrice', 'data.singlePrice')
ls_content = ls_content.replace("'isPack': result.isPack,", "'isUnit': result.isUnit,")
ls_content = ls_content.replace("'packName': result.packName,", "'unitName': result.unitName,")
ls_content = ls_content.replace("'packMultiplier': result.packMultiplier,", "'unitMultiplier': result.unitMultiplier,")
ls_content = ls_content.replace("'packPrice': result.packPrice,", "'singlePrice': result.singlePrice,")

with open(ls_file, 'w', encoding='utf-8') as f:
    f.write(ls_content)

print("Done")
