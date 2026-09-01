import '../../features/product/domain/entities/product.dart';

/// محرك تطبيع ومطابقة الباركود الذكي لحل مشاكل الأصفار البادئة وتنسيقات EAN-13 / UPC-A
class BarcodeNormalizer {
  /// تنظيف الباركود من المسافات والمحارف الخفية
  static String clean(String? barcode) {
    if (barcode == null) return '';
    return barcode.trim().replaceAll(RegExp(r'\s+'), '');
  }

  /// إزالة الأصفار البادئة من الباركود
  static String stripLeadingZeros(String code) {
    final cleaned = clean(code);
    final stripped = cleaned.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }

  /// التحقق من تطابق باركودين بمختلف التنسيقات (EAN-13, UPC-A, EAN-8, Code128)
  static bool matches(String? code1, String? code2) {
    final c1 = clean(code1);
    final c2 = clean(code2);

    if (c1.isEmpty || c2.isEmpty) return false;

    // 1. المطابقة التامة المباشرة
    if (c1 == c2) return true;

    // 2. المطابقة غير الحساسة لحالة الأحرف (للأكواد النصية)
    if (c1.toLowerCase() == c2.toLowerCase()) return true;

    // 3. مطابقة بدون الأصفار البادئة (Leading Zeros)
    final s1 = stripLeadingZeros(c1);
    final s2 = stripLeadingZeros(c2);
    if (s1 == s2 && s1.length >= 4) return true;

    // 4. مطابقة UPC-A (12 أرقام) مع EAN-13 (13 أرقام بإضافة 0 في البداية)
    if (c1.length == 12 && c2.length == 13 && '0' + c1 == c2) return true;
    if (c2.length == 12 && c1.length == 13 && '0' + c2 == c1) return true;

    // 5. مطابقة الباركودات مع إهمال خانة التحقق الأخيرة (Check Digit) إذا كانت أول 12 خانة متطابقة
    if (c1.length == 13 && c2.length == 13 && c1.substring(0, 12) == c2.substring(0, 12)) {
      return true;
    }
    if (c1.length == 12 && c2.length == 12 && c1.substring(0, 11) == c2.substring(0, 11)) {
      return true;
    }

    return false;
  }

  /// البحث عن المنتج المطابق في قائمة المنتجات بدقة ومرونة عالية
  static Product? findProduct(List<Product> products, String scannedBarcode) {
    final cleanScan = clean(scannedBarcode);
    if (cleanScan.isEmpty) return null;

    // أولوية 1: المطابقة التامة المباشرة
    for (final p in products) {
      if (clean(p.barcode) == cleanScan) {
        return p;
      }
    }

    // أولوية 2: المطابقة الذكية الشاملة (UPC-A / EAN-13 / بدون أصفار)
    for (final p in products) {
      if (matches(p.barcode, cleanScan)) {
        return p;
      }
    }

    // أولوية 3: مطابقة باركود الحزمة / الكرتونة (Pack Barcode)
    for (final p in products) {
      if (p.packBarcode != null && p.packBarcode!.isNotEmpty) {
        if (matches(p.packBarcode, cleanScan)) {
          return Product(
            id: '${p.id}_pack',
            name: '${p.name} (${p.packName ?? "حزمة"} x${p.packMultiplier})',
            barcode: p.packBarcode!,
            price: p.packPrice > 0 ? p.packPrice : (p.price * p.packMultiplier),
            costPrice: p.costPrice * p.packMultiplier,
            stock: p.stock ~/ (p.packMultiplier > 0 ? p.packMultiplier : 1),
            category: p.category,
            isWeighted: false,
            packMultiplier: p.packMultiplier,
          );
        }
      }
    }

    return null;
  }

  /// فحص وتفكيك باركود الموازين الإلكترونية (Dibal, CAS, Bizerba, Aclas)
  /// التنسيق الشائع: 20 IIIII WWWWW C (13 رقم EAN-13)
  /// حيث 20 أو 21 بادئة، IIIII كود السلعة، WWWWW الوزن بالجرام أو السعر
  static ScaleBarcodeResult? parseScaleBarcode(
    String barcode, {
    List<String> prefixes = const ['20', '21', '22', '28', '29'],
    bool isPriceBased = false,
  }) {
    final cleanCode = clean(barcode);
    if (cleanCode.length != 13) return null;

    final prefix = cleanCode.substring(0, 2);
    if (!prefixes.contains(prefix)) return null;

    // استخراج كود السلعة الداخلي (5 أرقام بعد البادئة)
    final itemCode = cleanCode.substring(2, 7);
    final strippedItemCode = stripLeadingZeros(itemCode);

    // استخراج القيمة (5 أرقام قبل خانة التحقق الأخيرة)
    final valueRaw = cleanCode.substring(7, 12);
    final valueInt = int.tryParse(valueRaw) ?? 0;

    if (isPriceBased) {
      final price = valueInt.toDouble();
      return ScaleBarcodeResult(
        rawBarcode: cleanCode,
        itemCode: strippedItemCode,
        weightKg: 1.0,
        totalPrice: price,
        isWeightBased: false,
      );
    } else {
      // الوزن بالكيلوجرام (01500 جرام = 1.500 كغ)
      final weightKg = (valueInt / 1000.0);
      return ScaleBarcodeResult(
        rawBarcode: cleanCode,
        itemCode: strippedItemCode,
        weightKg: weightKg > 0 ? weightKg : 1.0,
        isWeightBased: true,
      );
    }
  }

  /// البحث عن منتج ميزان إلكتروني باستخدام نتيجة تفكيك باركود الميزان
  static Product? findScaleProduct(List<Product> products, ScaleBarcodeResult scaleResult) {
    // 1. مطابقة مباشرة لكود السلعة أو كود الميزان
    for (final p in products) {
      final cleanBarcode = clean(p.barcode);
      final stripped = stripLeadingZeros(cleanBarcode);
      if (cleanBarcode == scaleResult.itemCode ||
          stripped == scaleResult.itemCode ||
          cleanBarcode == 'SCALE_${scaleResult.itemCode}' ||
          cleanBarcode == scaleResult.rawBarcode) {
        return p;
      }
    }

    // 2. مطابقة بالبادئة أو التسمية
    for (final p in products) {
      if (p.isWeighted) {
        final cleanBarcode = clean(p.barcode);
        if (cleanBarcode.endsWith(scaleResult.itemCode) ||
            cleanBarcode.contains(scaleResult.itemCode)) {
          return p;
        }
      }
    }

    return null;
  }
}

class ScaleBarcodeResult {
  final String rawBarcode;
  final String itemCode;
  final double weightKg;
  final double? totalPrice;
  final bool isWeightBased;

  const ScaleBarcodeResult({
    required this.rawBarcode,
    required this.itemCode,
    required this.weightKg,
    this.totalPrice,
    this.isWeightBased = true,
  });
}
