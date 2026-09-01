import 'dart:async';
import '../../../core/data/hive_database.dart';
import '../../../core/utils/barcode_normalizer.dart';
import '../../../core/utils/scale_barcode_parser.dart';
import '../../product/domain/entities/product.dart';

class KioskProductResult {
  final bool found;
  final String barcode;
  final String name;
  final double price;
  final String? category;
  final bool isWeighed;
  final double weight;
  final double pricePerKg;
  final bool isPack;
  final String? packName;
  final int packMultiplier;
  final double singlePrice;
  final double packPrice;
  final double savings;
  final String? imageUrl;

  const KioskProductResult({
    required this.found,
    required this.barcode,
    this.name = '',
    this.price = 0.0,
    this.category,
    this.isWeighed = false,
    this.weight = 0.0,
    this.pricePerKg = 0.0,
    this.isPack = false,
    this.packName,
    this.packMultiplier = 1,
    this.singlePrice = 0.0,
    this.packPrice = 0.0,
    this.savings = 0.0,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'found': found,
        'barcode': barcode,
        'name': name,
        'price': price,
        'category': category,
        'isWeighed': isWeighed,
        'weight': weight,
        'pricePerKg': pricePerKg,
        'isPack': isPack,
        'packName': packName,
        'packMultiplier': packMultiplier,
        'singlePrice': singlePrice,
        'packPrice': packPrice,
        'savings': savings,
        'imageUrl': imageUrl,
      };
}

class KioskService {
  static final StreamController<Map<String, dynamic>> _unlistedScanController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get unlistedScanStream =>
      _unlistedScanController.stream;

  // ذاكرة مؤقتة لمنع إغراق الكاشير بالتنبيهات (Cooldown 5 دقائق لكل باركود مكرر)
  static final Map<String, DateTime> _alertCooldowns = {};

  /// جلب إعدادات الكشك
  static Map<String, dynamic> getSettings() {
    final box = HiveDatabase.settingsBox;
    final shopName = box.get('shop_name', defaultValue: 'Nayli Market') as String;
    return {
      'productDisplayDuration':
          box.get('kiosk_product_display_duration', defaultValue: 10) as int,
      'arrowDirection':
          box.get('kiosk_arrow_direction', defaultValue: 'down') as String,
      'greetingTitle': box.get(
          'kiosk_greeting_title', defaultValue: 'مرحباً بكم في ' + shopName) as String,
      'greetingSubtitle': box.get('kiosk_greeting_subtitle',
          defaultValue: 'مرر باركود السلعة تحت الماسح لمعرفة السعر') as String,
      'promoSlides': List<String>.from(
          box.get('kiosk_promo_slides', defaultValue: <String>[])),
      'soundEnabled':
          box.get('kiosk_sound_enabled', defaultValue: true) as bool,
    };
  }

  /// حفظ إعدادات الكشك
  static Future<void> saveSettings({
    int? productDisplayDuration,
    String? arrowDirection,
    String? greetingTitle,
    String? greetingSubtitle,
    List<String>? promoSlides,
    bool? soundEnabled,
  }) async {
    final box = HiveDatabase.settingsBox;
    if (productDisplayDuration != null) {
      await box.put('kiosk_product_display_duration', productDisplayDuration);
    }
    if (arrowDirection != null) {
      await box.put('kiosk_arrow_direction', arrowDirection);
    }
    if (greetingTitle != null) {
      await box.put('kiosk_greeting_title', greetingTitle);
    }
    if (greetingSubtitle != null) {
      await box.put('kiosk_greeting_subtitle', greetingSubtitle);
    }
    if (promoSlides != null) {
      await box.put('kiosk_promo_slides', promoSlides);
    }
    if (soundEnabled != null) {
      await box.put('kiosk_sound_enabled', soundEnabled);
    }
  }

  /// فحص الباركود حصراً من المخزون الفعلي للمحل (Read-Only)
  static KioskProductResult lookupBarcode(String rawBarcode) {
    final cleanCode = BarcodeNormalizer.clean(rawBarcode);
    if (cleanCode.isEmpty) {
      return const KioskProductResult(found: false, barcode: '');
    }

    final productBox = HiveDatabase.productBox;
    final allProducts = productBox.values.toList();

    // 1. التحقق إن كان باركود ميزان أجبان أو خضر ولحوم (يبدأ بـ 20 أو 21 أو 28...)
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

    // 2. البحث المباشر في المنتجات المسجلة في المحل
    for (final p in allProducts) {
      // مطابقة باركود الحبة
      if (BarcodeNormalizer.matches(p.barcode, cleanCode)) {
        final hasPack = p.packBarcode != null &&
            p.packBarcode!.isNotEmpty &&
            p.packMultiplier > 1 &&
            p.packPrice > 0;
        final expectedSingleTotal = p.price * (hasPack ? p.packMultiplier : 1);
        final packSavings = hasPack ? (expectedSingleTotal - p.packPrice).clamp(0.0, 99999.0) : 0.0;

        return KioskProductResult(
          found: true,
          barcode: p.barcode,
          name: p.name,
          price: p.price,
          category: p.category,
          isPack: false,
          packName: p.packName,
          packMultiplier: p.packMultiplier,
          singlePrice: p.price,
          packPrice: p.packPrice,
          savings: packSavings,
        );
      }

      // مطابقة باركود الحزمة / الكرتونة
      if (p.packBarcode != null &&
          p.packBarcode!.isNotEmpty &&
          BarcodeNormalizer.matches(p.packBarcode, cleanCode)) {
        final packPrice = p.packPrice > 0 ? p.packPrice : (p.price * p.packMultiplier);
        final singleTotal = p.price * p.packMultiplier;
        final savings = (singleTotal - packPrice).clamp(0.0, 99999.0);

        return KioskProductResult(
          found: true,
          barcode: p.packBarcode!,
          name: p.name + ' (' + (p.packName ?? 'حزمة') + ' x' + p.packMultiplier.toString() + ')',
          price: packPrice,
          category: p.category,
          isPack: true,
          packName: p.packName ?? 'حزمة',
          packMultiplier: p.packMultiplier,
          singlePrice: p.price,
          packPrice: packPrice,
          savings: savings,
        );
      }
    }

    // 3. السلعة غير مسجلة في قاعدة البيانات -> تسجيلها وإرسال تنبيه للمدير/الكاشير مع كتم التكرار
    _recordUnlistedScan(cleanCode);

    return KioskProductResult(
      found: false,
      barcode: cleanCode,
    );
  }

  /// تسجيل السلعة المنسية وبث التنبيه للكاشير مع كتم التكرار
  static void _recordUnlistedScan(String barcode) {
    final now = DateTime.now();
    final box = HiveDatabase.settingsBox;

    final rawList = box.get('kiosk_unlisted_scans', defaultValue: <dynamic>[]);
    final List<Map<String, dynamic>> list = rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    int existingIndex = list.indexWhere((item) => item['barcode'] == barcode);
    if (existingIndex >= 0) {
      list[existingIndex]['scanCount'] = (list[existingIndex]['scanCount'] as int? ?? 1) + 1;
      list[existingIndex]['lastScanned'] = now.toIso8601String();
    } else {
      list.insert(0, {
        'barcode': barcode,
        'scanCount': 1,
        'firstScanned': now.toIso8601String(),
        'lastScanned': now.toIso8601String(),
      });
    }

    box.put('kiosk_unlisted_scans', list);

    final lastAlertTime = _alertCooldowns[barcode];
    final shouldAlert = lastAlertTime == null || now.difference(lastAlertTime).inMinutes >= 5;

    if (shouldAlert) {
      _alertCooldowns[barcode] = now;
      _unlistedScanController.add({
        'barcode': barcode,
        'timestamp': now.toIso8601String(),
        'scanCount': existingIndex >= 0 ? list[existingIndex]['scanCount'] : 1,
      });
    }
  }

  /// جلب قائمة السلع المنسية غير المسجلة
  static List<Map<String, dynamic>> getUnlistedScans() {
    final rawList =
        HiveDatabase.settingsBox.get('kiosk_unlisted_scans', defaultValue: <dynamic>[]);
    return rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// حذف سلعة من سجل السلع المنسية (بعد إضافتها للمخزون)
  static Future<void> removeUnlistedScan(String barcode) async {
    final box = HiveDatabase.settingsBox;
    final rawList = box.get('kiosk_unlisted_scans', defaultValue: <dynamic>[]);
    final list = rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((item) => item['barcode'] != barcode)
        .toList();
    await box.put('kiosk_unlisted_scans', list);
  }

  /// مسح كامل سجل السلع المنسية
  static Future<void> clearAllUnlistedScans() async {
    await HiveDatabase.settingsBox.delete('kiosk_unlisted_scans');
  }
}
