import '../../features/product/domain/entities/product.dart';

/// محرك تطبيع ومطابقة الباركود الذكي لحل مشاكل الأصفار البادئة وتنسيقات EAN-13 / UPC-A
class BarcodeNormalizer {
  /// تنظيف الباركود أو رمز QR من المسافات والمحارف الخفية
  static String clean(String? barcode) {
    if (barcode == null) return '';
    return barcode.trim().replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]+'), '');
  }

  /// يقوم بتحويل رموز لوحة المفاتيح الفرنسية (AZERTY) إلى أرقامها الحقيقية
  /// عند استخدام ماسح باركود في نظام ويندوز مضبوط على لغة فرنسية
  static String normalizeAzertyInput(String raw) {
    if (raw.isEmpty) return raw;
    const azertyMap = {
      '&': '1',
      'é': '2',
      '"': '3',
      '\'': '4',
      '(': '5',
      '-': '6',
      'è': '7',
      '_': '8',
      'ç': '9',
      'à': '0',
    };
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final char = raw[i];
      buffer.write(azertyMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// إزالة الأصفار البادئة من الباركود
  static String stripLeadingZeros(String code) {
    final cleaned = clean(code);
    final stripped = cleaned.replaceFirst(RegExp(r'^0+'), '');
    return stripped.isEmpty ? '0' : stripped;
  }

  /// التحقق مما إذا كان النص المدخل باركود أو رمز QR (وليس اسماً مكتوباً للبحث)
  static bool isBarcodeOrQrCode(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // لا يمكن أن يكون باركود/QR إذا كان يحتوي على فراغات وكلمات عربية
    if (trimmed.contains(' ') && !trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed)) {
      return false; // نصوص عربية تعني اسم منتج
    }

    final cleaned = clean(trimmed);
    if (cleaned.length < 3) return false;

    // 1. أرقام فقط بطول معتبر (6 إلى 30 خانة)
    if (RegExp(r'^\d{6,30}$').hasMatch(cleaned)) return true;

    // 2. روابط إنترنت (شائعة جداً في رموز QR للمنتجات الأمريكية والصينية)
    if (cleaned.toLowerCase().startsWith('http://') || cleaned.toLowerCase().startsWith('https://')) {
      return true;
    }

    // 3. بادئات نظام نايل ماركت أو معايير GS1 الرسمية
    if (cleaned.startsWith('NAYLI:') ||
        cleaned.startsWith('(01)') ||
        cleaned.startsWith('01') && cleaned.length >= 16 && RegExp(r'^01\d{14}').hasMatch(cleaned)) {
      return true;
    }

    // 4. كود أبجدي-رقمي بدون مسافات بطول 4-60 خانة (مثل ASIN الأمريكي B08N5WRWNW أو الأكواد الصينية CN-...)
    if (RegExp(r'^[A-Za-z0-9\-_:/.]{4,60}$').hasMatch(cleaned)) {
      // يجب أن يحتوي على رقم أو حرف لاتيني كبير أو علامة خاصة
      if (RegExp(r'[0-9]').hasMatch(cleaned) || RegExp(r'[A-Za-z]').hasMatch(cleaned)) {
        return true;
      }
    }

    return false;
  }

  /// استخراج كل المعرفات المحتملة من باركود أو رمز QR (GS1 Digital Link، روابط، أكواد نقية)
  static List<String> getLookupCandidates(String? input) {
    final cleaned = clean(input);
    if (cleaned.isEmpty) return const [];

    final candidates = <String>[cleaned];

    // أ. رموز نايل ماركت الداخلية
    if (cleaned.startsWith('NAYLI:ITEM:')) {
      final stripped = cleaned.substring('NAYLI:ITEM:'.length).trim();
      if (stripped.isNotEmpty) candidates.add(stripped);
    }

    // ب. معيار GS1 Digital Link الحديث (شائع في أمريكا والصين)
    // أمثلة: https://id.gs1.org/01/06130140001019 أو https://brand.com/01/06130140001019/21/SER
    final gs1Match = RegExp(r'/(?:01|gtin)/(\d{8,14})', caseSensitive: false).firstMatch(cleaned);
    if (gs1Match != null) {
      final gtin = gs1Match.group(1)!;
      candidates.add(gtin);
      candidates.add(stripLeadingZeros(gtin));
    }

    // ج. معيار GS1 Application Identifiers مع أقواس (01)GTIN
    final aiMatch = RegExp(r'\(01\)(\d{8,14})').firstMatch(cleaned);
    if (aiMatch != null) {
      final gtin = aiMatch.group(1)!;
      candidates.add(gtin);
      candidates.add(stripLeadingZeros(gtin));
    } else if (cleaned.startsWith('01') && cleaned.length >= 16 && RegExp(r'^01\d{14}').hasMatch(cleaned)) {
      final gtin = cleaned.substring(2, 16);
      candidates.add(gtin);
      candidates.add(stripLeadingZeros(gtin));
    }

    // د. روابط الإنترنت ومنصات التجارة العالمية (أمازون ASIN، مواقع صينية، معلمات URL)
    if (cleaned.toLowerCase().startsWith('http://') || cleaned.toLowerCase().startsWith('https://')) {
      // أمازون ASIN (مثل /dp/B08N5WRWNW)
      final asinMatch = RegExp(r'/dp/([A-Za-z0-9]{10})').firstMatch(cleaned);
      if (asinMatch != null) {
        candidates.add(asinMatch.group(1)!);
      }

      // معرفات المتاجر الصينية (مثل JD item: /1000123456.html)
      final jdMatch = RegExp(r'/(\d{6,16})(?:\.html)?(?:$|[?#])').firstMatch(cleaned);
      if (jdMatch != null) {
        candidates.add(jdMatch.group(1)!);
      }

      // استخراج المعلمات الشائعة من الرابط: ?id= أو ?sku= أو ?code= أو ?barcode= أو ?gtin= أو ?sn=
      final paramMatch = RegExp(
        r'[?&](?:id|sku|code|barcode|gtin|sn|item_id|item)=([^&#]+)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (paramMatch != null) {
        final val = Uri.decodeComponent(paramMatch.group(1)!).trim();
        if (val.isNotEmpty) candidates.add(val);
      }

      // الجزء الأخير من مسار الرابط إذا كان رمزاً نقياً
      try {
        final uri = Uri.parse(cleaned);
        if (uri.pathSegments.isNotEmpty) {
          final lastSeg = uri.pathSegments.last.replaceAll(RegExp(r'\.(html|htm|php|jsp)$', caseSensitive: false), '').trim();
          if (lastSeg.isNotEmpty && RegExp(r'^[A-Za-z0-9\-_]{4,30}$').hasMatch(lastSeg)) {
            candidates.add(lastSeg);
          }
        }
      } catch (_) {}
    }

    // هـ. الأكواد التي تبدأ ببادئات مثل SN: أو SKU: أو CODE:
    final prefMatch = RegExp(r'^(?:SN|SKU|CODE|BARCODE|ID|LOT)[:=](.+)$', caseSensitive: false).firstMatch(cleaned);
    if (prefMatch != null) {
      final rawVal = prefMatch.group(1)!.trim();
      if (rawVal.isNotEmpty) candidates.add(rawVal);
    }

    // توليد كل المتغيرات الممكنة للأرقام (UPC/EAN وبدون أصفار)
    final results = <String>[];
    for (final c in candidates) {
      if (!results.contains(c)) results.add(c);
      final stripped = stripLeadingZeros(c);
      if (stripped.length >= 4 && !results.contains(stripped)) {
        results.add(stripped);
      }
      // تحويل UPC-A (12) إلى EAN-13 (13 مع 0 في البداية) والعكس
      if (c.length == 12 && RegExp(r'^\d{12}$').hasMatch(c)) {
        final ean = '0$c';
        if (!results.contains(ean)) results.add(ean);
      } else if (c.length == 13 && c.startsWith('0') && RegExp(r'^\d{13}$').hasMatch(c)) {
        final upc = c.substring(1);
        if (!results.contains(upc)) results.add(upc);
      }
    }

    return results;
  }

  /// التحقق من تطابق باركودين أو رمزي QR بمختلف التنسيقات (EAN-13, UPC-A, QR Code, GS1 Digital Link)
  static bool matches(String? code1, String? code2) {
    final c1 = clean(code1);
    final c2 = clean(code2);

    if (c1.isEmpty || c2.isEmpty) return false;

    // 1. المطابقة التامة المباشرة
    if (c1 == c2) return true;

    // 2. المطابقة غير الحساسة لحالة الأحرف (للأكواد النصية ورموز QR)
    if (c1.toLowerCase() == c2.toLowerCase()) return true;

    // 3. مطابقة بدون الأصفار البادئة (Leading Zeros)
    final s1 = stripLeadingZeros(c1);
    final s2 = stripLeadingZeros(c2);
    if (s1 == s2 && s1.length >= 4) return true;

    // 4. مطابقة UPC-A (12 أرقام) مع EAN-13 (13 أرقام بإضافة 0 في البداية)
    if (c1.length == 12 && c2.length == 13 && '0' + c1 == c2) return true;
    if (c2.length == 12 && c1.length == 13 && '0' + c2 == c1) return true;

    // 5. مطابقة الباركودات مع إهمال خانة التحقق الأخيرة (Check Digit)
    if (c1.length == 13 && c2.length == 13 && c1.substring(0, 12) == c2.substring(0, 12)) {
      return true;
    }
    if (c1.length == 12 && c2.length == 12 && c1.substring(0, 11) == c2.substring(0, 11)) {
      return true;
    }

    // 6. المطابقة الذكية عبر فك رموز الـ QR كود و GS1 Digital Link
    final candidates1 = getLookupCandidates(c1);
    final candidates2 = getLookupCandidates(c2);

    for (final cand1 in candidates1) {
      final cand1Lower = cand1.toLowerCase();
      for (final cand2 in candidates2) {
        if (cand1 == cand2 || cand1Lower == cand2.toLowerCase()) {
          return true;
        }
        // مطابقة الأرقام المتماثلة في المرشحات
        final str1 = stripLeadingZeros(cand1);
        final str2 = stripLeadingZeros(cand2);
        if (str1 == str2 && str1.length >= 4) {
          return true;
        }
      }
    }

    return false;
  }

  /// البحث عن المنتج المطابق في قائمة المنتجات بدقة ومرونة عالية (يدعم الباركود والـ QR كود)
  static T? findProduct<T extends Product>(List<T> products, String scannedBarcode) {
    final cleanScan = clean(scannedBarcode);
    if (cleanScan.isEmpty) return null;

    final candidates = getLookupCandidates(cleanScan);

    // أولوية 1: المطابقة التامة المباشرة للباركود المسجل
    for (final p in products) {
      if (clean(p.barcode) == cleanScan) {
        return p;
      }
    }

    // أولوية 2: المطابقة الذكية لمرشحات الـ QR كود مع باركود المنتج
    for (final cand in candidates) {
      for (final p in products) {
        if (clean(p.barcode) == cand || matches(p.barcode, cand)) {
          return p;
        }
      }
    }

    // أولوية 3: مطابقة باركود الكرتونة / الفاردو (Carton Barcode)
    for (final p in products) {
      if (p.cartonBarcode != null && p.cartonBarcode!.isNotEmpty) {
        for (final cand in candidates) {
          if (matches(p.cartonBarcode, cand)) {
            return p;
          }
        }
      }
    }

    // أولوية 4: مطابقة باركود العلبة / الباقة (Pack Barcode)
    for (final p in products) {
      if (p.packBarcode != null && p.packBarcode!.isNotEmpty) {
        for (final cand in candidates) {
          if (matches(p.packBarcode, cand)) {
            return p;
          }
        }
      }
    }

    // أولوية 5: مطابقة وحدات المنتج الفرعية (Multi-Units)
    for (final p in products) {
      for (final u in p.units) {
        if (u.barcode != null && u.barcode!.isNotEmpty) {
          for (final cand in candidates) {
            if (matches(u.barcode, cand)) {
              return p;
            }
          }
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
  static T? findScaleProduct<T extends Product>(List<T> products, ScaleBarcodeResult scaleResult) {
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
