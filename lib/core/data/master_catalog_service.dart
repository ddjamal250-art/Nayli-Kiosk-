import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'master_catalog_seed.dart';

class MasterCatalogService {
  static final MasterCatalogService instance = MasterCatalogService._();
  
  MasterCatalogService._() {
    // تهيئة فورية ومتزامنة لسلع الكتالوج الجزائري لضمان ألا تظهر المكتبة فارغة أبداً
    _categories.addAll(MasterCatalogSeed.categories);
    for (final item in MasterCatalogSeed.items) {
      _barcodeMap[item.barcode.trim()] = item;
      _allItems.add(item);
      _categories.add(item.category);
    }
    _isLoaded = true;
  }

  final Map<String, MasterCatalogItem> _barcodeMap = {};
  final List<MasterCatalogItem> _allItems = [];
  final Set<String> _categories = {'الكل'};
  bool _isLoaded = true;

  bool get isLoaded => _isLoaded;
  List<MasterCatalogItem> get allItems => _allItems.isNotEmpty ? _allItems : MasterCatalogSeed.items;
  List<String> get categoryNames => _categories.toList();

  Future<void> init() async {
    try {
      // 1. Load Algerian Tobacco Products Catalog (تبغ، سجائر، شمة، معسل، لوازم الأكشاك)
      try {
        final tobaccoJsonString = await rootBundle.loadString('assets/data/algerian_tobacco_products.json');
        final List<dynamic> tobaccoList = jsonDecode(tobaccoJsonString) as List<dynamic>;
        for (final raw in tobaccoList) {
          if (raw is Map) {
            final barcode = (raw['barcode'] ?? '').toString().trim();
            if (barcode.isEmpty) continue;

            final name = (raw['name'] ?? '').toString().trim();
            final category = (raw['category'] ?? 'تبغ وسجائر').toString().trim();
            final double retailPrice = (raw['retail_price'] as num?)?.toDouble() ?? 0.0;
            final double costPrice = (raw['cost_price'] as num?)?.toDouble() ?? 0.0;
            final double wholesalePrice = (raw['wholesale_price'] as num?)?.toDouble() ?? 0.0;
            final double cartonPrice = (raw['carton_price'] as num?)?.toDouble() ?? 0.0;
            final double wholesaleCartonPrice = (raw['wholesale_carton_price'] as num?)?.toDouble() ?? 0.0;
            final double singlePiecePrice = (raw['single_piece_price'] as num?)?.toDouble() ?? 0.0;
            final int piecesPerPack = (raw['pieces_per_pack'] as num?)?.toInt() ?? 20;
            final int packsPerCarton = (raw['packs_per_carton'] as num?)?.toInt() ?? 10;
            final bool isTobacco = raw['is_tobacco'] == true || category.contains('تبغ') || category.contains('شمة') || category.contains('معسل');
            final String unitType = (raw['unit_type'] ?? 'piece').toString();

            final catalogItem = MasterCatalogItem(
              barcode: barcode,
              name: name.isNotEmpty ? name : 'منتج تبغ $barcode',
              category: category.isNotEmpty ? category : 'تبغ وسجائر',
              defaultPrice: retailPrice > 0 ? retailPrice : 300.0,
              defaultCost: costPrice > 0 ? costPrice : 270.0,
              imageUrl: raw['image_url']?.toString(),
              isTobacco: isTobacco,
              cartonPrice: cartonPrice,
              wholesaleCartonPrice: wholesaleCartonPrice,
              wholesalePackPrice: wholesalePrice,
              singlePiecePrice: singlePiecePrice,
              piecesPerPack: piecesPerPack,
              packsPerCarton: packsPerCarton,
              unitType: unitType,
            );

            _barcodeMap[barcode] = catalogItem;
            _allItems.removeWhere((i) => i.barcode == barcode);
            _allItems.add(catalogItem);
            if (category.isNotEmpty) _categories.add(category);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Tobacco products json load warning: $e');
      }

      // 2. Load and index algerian_supermarket_products.json (high quality local supermarket items)
      try {
        final supermarketJsonString = await rootBundle.loadString('assets/data/algerian_supermarket_products.json');
        final List<dynamic> supermarketList = jsonDecode(supermarketJsonString) as List<dynamic>;
        for (final raw in supermarketList) {
          if (raw is Map) {
            final barcode = (raw['barcode'] ?? '').toString().trim();
            if (barcode.isEmpty) continue;

            final nameAr = (raw['name_ar'] ?? '').toString().trim();
            final nameFr = (raw['name_fr'] ?? '').toString().trim();
            final brand = (raw['brand'] ?? '').toString().trim();

            String finalName = nameAr.isNotEmpty ? nameAr : nameFr;
            if (brand.isNotEmpty && !finalName.toLowerCase().contains(brand.toLowerCase())) {
              finalName = '$brand - $finalName';
            }

            final category = (raw['category'] ?? 'عام').toString().trim();
            final double price = (raw['indicative_price'] as num?)?.toDouble() ?? 0.0;
            final double cost = (price * 0.85).roundToDouble();

            final catalogItem = MasterCatalogItem(
              barcode: barcode,
              name: finalName.isNotEmpty ? finalName : 'منتج $barcode',
              category: category.isNotEmpty ? category : 'عام',
              defaultPrice: price > 0 ? price : 100.0,
              defaultCost: cost > 0 ? cost : 80.0,
              imageUrl: raw['image_url']?.toString(),
            );

            _barcodeMap[barcode] = catalogItem;
            _allItems.removeWhere((i) => i.barcode == barcode);
            _allItems.add(catalogItem);
            if (category.isNotEmpty) _categories.add(category);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Supermarket json load warning: $e');
      }

      // 3. Load the 15,544 products master database in background
      try {
        final jsonString = await rootBundle.loadString('assets/data/algerian_products_master.json');
        final List<dynamic> jsonList = await compute(_parseJson, jsonString);

        for (final raw in jsonList) {
          if (raw is Map) {
            final barcode = (raw['barcode'] ?? '').toString().trim();
            if (barcode.isEmpty) continue;

            // Don't overwrite higher quality supermarket entries if already present
            if (_barcodeMap.containsKey(barcode)) continue;

            final nameAr = (raw['name_ar'] ?? '').toString().trim();
            final nameFr = (raw['name_fr'] ?? '').toString().trim();
            final nameDefault = (raw['name'] ?? '').toString().trim();
            final brand = (raw['brand'] ?? '').toString().trim();

            String finalName = nameAr.isNotEmpty
                ? nameAr
                : (nameDefault.isNotEmpty ? nameDefault : nameFr);

            if (brand.isNotEmpty && !finalName.toLowerCase().contains(brand.toLowerCase())) {
              finalName = '$brand - $finalName';
            }

            final category = (raw['category'] ?? 'عام').toString().trim();
            final double price = (raw['indicative_price'] as num?)?.toDouble() ?? 0.0;
            final double cost = (price * 0.85).roundToDouble();

            final catalogItem = MasterCatalogItem(
              barcode: barcode,
              name: finalName.isNotEmpty ? finalName : 'منتج جزائري $barcode',
              category: category.isNotEmpty ? category : 'عام',
              defaultPrice: price > 0 ? price : 100.0,
              defaultCost: cost > 0 ? cost : 80.0,
            );

            _barcodeMap[barcode] = catalogItem;
            _allItems.add(catalogItem);
            if (category.isNotEmpty) _categories.add(category);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Master products json load warning: $e');
      }

      // 4. Load the 100k Algerian products dataset in background isolate
      try {
        final json100kString = await rootBundle.loadString('assets/data/algerian_products_100k.json');
        final List<dynamic> json100kList = await compute(_parseJson, json100kString);

        for (final raw in json100kList) {
          if (raw is Map) {
            final barcode = (raw['barcode'] ?? '').toString().trim();
            if (barcode.isEmpty) continue;
            if (_barcodeMap.containsKey(barcode)) continue;

            final nameAr = (raw['name_ar'] ?? '').toString().trim();
            final nameFr = (raw['name_fr'] ?? '').toString().trim();
            final nameDefault = (raw['name'] ?? '').toString().trim();
            final brand = (raw['brand'] ?? '').toString().trim();

            String finalName = nameAr.isNotEmpty
                ? nameAr
                : (nameDefault.isNotEmpty ? nameDefault : nameFr);

            if (brand.isNotEmpty && !finalName.toLowerCase().contains(brand.toLowerCase())) {
              finalName = '$brand - $finalName';
            }

            final category = (raw['category'] ?? 'عام').toString().trim();
            final double price = (raw['indicative_price'] as num?)?.toDouble() ?? 0.0;
            final double cost = (price * 0.85).roundToDouble();

            final catalogItem = MasterCatalogItem(
              barcode: barcode,
              name: finalName.isNotEmpty ? finalName : 'منتج جزائري $barcode',
              category: category.isNotEmpty ? category : 'عام',
              defaultPrice: price > 0 ? price : 100.0,
              defaultCost: cost > 0 ? cost : 80.0,
            );

            _barcodeMap[barcode] = catalogItem;
            _allItems.add(catalogItem);
            if (category.isNotEmpty) _categories.add(category);
          }
        }
      } catch (e) {
        debugPrint('⚠️ 100k dataset load info: $e');
      }

      _isLoaded = true;
      debugPrint('🚀 MasterCatalogService: Fully indexed ${_barcodeMap.length} Algerian products from all dataset files!');
    } catch (e) {
      debugPrint('⚠️ MasterCatalogService overall load error: $e');
      _isLoaded = true;
    }
  }

  static List<dynamic> _parseJson(String jsonStr) {
    return jsonDecode(jsonStr) as List<dynamic>;
  }

  MasterCatalogItem? lookup(String barcode) {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    if (_barcodeMap.containsKey(clean)) {
      return _barcodeMap[clean];
    }
    // Try without leading zeros
    final stripped = clean.replaceFirst(RegExp(r'^0+'), '');
    if (stripped.isNotEmpty && _barcodeMap.containsKey(stripped)) {
      return _barcodeMap[stripped];
    }
    // Try UPC-A to EAN-13 padding (12 digits -> 13 digits)
    if (clean.length == 12 && _barcodeMap.containsKey('0$clean')) {
      return _barcodeMap['0$clean'];
    }
    // Try EAN-13 to UPC-A (13 digits starting with 0 -> 12 digits)
    if (clean.length == 13 && clean.startsWith('0') && _barcodeMap.containsKey(clean.substring(1))) {
      return _barcodeMap[clean.substring(1)];
    }
    return MasterCatalogSeed.lookup(clean);
  }

  List<MasterCatalogItem> search(String query, {String category = 'الكل', int limit = 50}) {
    final q = query.trim().toLowerCase();
    final effectiveLimit = limit > 0 ? limit : 50;
    final List<MasterCatalogItem> results = [];

    // Fast O(1) exact barcode match first
    if (q.isNotEmpty && _barcodeMap.containsKey(q)) {
      final exact = _barcodeMap[q]!;
      if (category == 'الكل' || exact.category == category) {
        results.add(exact);
      }
    }

    final source = allItems;
    for (final item in source) {
      if (results.length >= effectiveLimit) break;
      if (results.any((e) => e.barcode == item.barcode)) continue;

      final matchesCat = category == 'الكل' || item.category == category;
      if (!matchesCat) continue;

      if (q.isEmpty) {
        results.add(item);
      } else if (item.barcode.contains(q) ||
          item.name.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q)) {
        results.add(item);
      }
    }

    return results;
  }

  // Static helper aliases for convenience across UI pages
  static MasterCatalogItem? searchByBarcode(String barcode) => instance.lookup(barcode);
  static List<MasterCatalogItem> getAllItems() => instance.allItems;
  static List<MasterCatalogItem> searchAndFilter({String query = '', String category = 'الكل', int limit = 50}) =>
      instance.search(query, category: category, limit: limit);
  static List<String> get categories => instance._categories.toList();
  static List<String> get categoryList => instance._categories.toList();

  /// =========================================================================
  /// 📦 منظومة التصدير والاستيراد التجاري الشاملة (Universal Algerian Export/Import)
  /// =========================================================================

  /// تصدير الكتالوج بصيغة CSV متوافقة 100% مع برامج التسيير الجزائرية (LogiStock, G-Stock, SoftCaisse, Odoo)
  /// مع إضافة BOM (0xFEFF) لدعم اللغة العربية في Microsoft Excel مباشرة.
  static String exportToCSV({List<MasterCatalogItem>? items}) {
    final list = items ?? instance.allItems;
    final sb = StringBuffer();
    // UTF-8 BOM for seamless Arabic display in MS Excel
    sb.write('\uFEFF');
    // Algerian Market Standard Headers
    sb.writeln('Code_Barre;Designation;Famille;Prix_Vente;Prix_Achat;Unite;Image_URL');
    for (final item in list) {
      final barcode = item.barcode.replaceAll(';', ' ');
      final name = item.name.replaceAll(';', ' ').replaceAll('"', '""');
      final cat = item.category.replaceAll(';', ' ');
      final price = item.defaultPrice.toStringAsFixed(2);
      final cost = item.defaultCost.toStringAsFixed(2);
      final unit = (item.unitType ?? (item.isTobacco ? 'pack' : 'piece')).replaceAll(';', ' ');
      final img = (item.imageUrl ?? '').replaceAll(';', ' ');
      sb.writeln('$barcode;"$name";$cat;$price;$cost;$unit;$img');
    }
    return sb.toString();
  }

  /// تصدير الكتالوج بصيغة SQL Script جاهز للحقن المباشر في قواعد بيانات SQLite / MySQL / PostgreSQL / SQL Server
  static String exportToSQL({List<MasterCatalogItem>? items}) {
    final list = items ?? instance.allItems;
    final sb = StringBuffer();
    sb.writeln('-- ========================================================');
    sb.writeln('-- Nayli Market (نايلي ماركت) - Master Catalog SQL Export');
    sb.writeln('-- Total Products: ${list.length}');
    sb.writeln('-- Generated At: ${DateTime.now().toIso8601String()}');
    sb.writeln('-- ========================================================');
    sb.writeln();
    sb.writeln('CREATE TABLE IF NOT EXISTS master_products (');
    sb.writeln('    barcode VARCHAR(64) PRIMARY KEY,');
    sb.writeln('    name VARCHAR(255) NOT NULL,');
    sb.writeln('    category VARCHAR(100),');
    sb.writeln('    default_price DECIMAL(10,2) DEFAULT 0.0,');
    sb.writeln('    default_cost DECIMAL(10,2) DEFAULT 0.0,');
    sb.writeln('    is_tobacco TINYINT DEFAULT 0,');
    sb.writeln('    unit_type VARCHAR(50) DEFAULT \'piece\',');
    sb.writeln('    image_url TEXT');
    sb.writeln(');');
    sb.writeln();

    final buffer = <String>[];
    for (final item in list) {
      final b = item.barcode.replaceAll("'", "''");
      final n = item.name.replaceAll("'", "''");
      final c = item.category.replaceAll("'", "''");
      final p = item.defaultPrice.toStringAsFixed(2);
      final cost = item.defaultCost.toStringAsFixed(2);
      final isTob = item.isTobacco ? 1 : 0;
      final u = (item.unitType ?? 'piece').replaceAll("'", "''");
      final img = (item.imageUrl ?? '').replaceAll("'", "''");
      buffer.add("('$b', '$n', '$c', $p, $cost, $isTob, '$u', '$img')");

      if (buffer.length >= 100) {
        sb.writeln('INSERT OR REPLACE INTO master_products (barcode, name, category, default_price, default_cost, is_tobacco, unit_type, image_url) VALUES');
        sb.writeln('  ${buffer.join(',\n  ')};');
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      sb.writeln('INSERT OR REPLACE INTO master_products (barcode, name, category, default_price, default_cost, is_tobacco, unit_type, image_url) VALUES');
      sb.writeln('  ${buffer.join(',\n  ')};');
      buffer.clear();
    }
    return sb.toString();
  }

  /// تصدير الكتالوج بصيغة JSON القياسية للتطبيقات الحديثة
  static String exportToJSON({List<MasterCatalogItem>? items}) {
    final list = items ?? instance.allItems;
    final data = list.map((item) => {
      'barcode': item.barcode,
      'name': item.name,
      'category': item.category,
      'default_price': item.defaultPrice,
      'default_cost': item.defaultCost,
      'is_tobacco': item.isTobacco,
      'unit_type': item.unitType,
      'image_url': item.imageUrl,
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// حفظ الملف المصدر محلياً في مجلد مخصص للمستندات والتنزيلات
  static Future<String> saveExportFile(String content, String fileName) async {
    Directory baseDir;
    try {
      baseDir = (await getDownloadsDirectory()) ?? (await getApplicationDocumentsDirectory());
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }
    final exportDir = Directory('${baseDir.path}/NayliMarket_Exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return file.path;
  }

  /// استيراد سلع من ملف CSV خارجي بذكاء وتعيين الحقول تلقائياً
  static int importFromCSV(String csvContent) {
    if (csvContent.trim().isEmpty) return 0;
    
    // Strip BOM if present
    String cleanContent = csvContent;
    if (cleanContent.startsWith('\uFEFF')) {
      cleanContent = cleanContent.substring(1);
    }

    final lines = const LineSplitter().convert(cleanContent);
    if (lines.isEmpty) return 0;

    // Detect delimiter: semicolon, comma, or tab
    final firstLine = lines.first;
    String delimiter = ';';
    if (firstLine.split(';').length >= 3) {
      delimiter = ';';
    } else if (firstLine.split(',').length >= 3) {
      delimiter = ',';
    } else if (firstLine.split('\t').length >= 3) {
      delimiter = '\t';
    }

    // Parse header
    final headers = firstLine.split(delimiter).map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();
    int barcodeCol = -1;
    int nameCol = -1;
    int catCol = -1;
    int priceCol = -1;
    int costCol = -1;
    int imgCol = -1;

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h.contains('code') || h.contains('barcode') || h.contains('cb')) {
        barcodeCol = i;
      } else if (h.contains('desig') || h.contains('name') || h.contains('nom') || h.contains('produit') || h.contains('libelle')) {
        nameCol = i;
      } else if (h.contains('famille') || h.contains('cat') || h.contains('rayon') || h.contains('صنف') || h.contains('قسم')) {
        catCol = i;
      } else if (h.contains('vente') || h.contains('price') || h.contains('prix') || h.contains('pv') || h.contains('سعر')) {
        if (priceCol == -1) priceCol = i;
      } else if (h.contains('achat') || h.contains('cost') || h.contains('pa') || h.contains('شراء')) {
        costCol = i;
      } else if (h.contains('image') || h.contains('photo') || h.contains('img') || h.contains('صورة')) {
        imgCol = i;
      }
    }

    // Fallbacks if header wasn't detected properly
    if (barcodeCol == -1) barcodeCol = 0;
    if (nameCol == -1 && headers.length > 1) nameCol = 1;

    int importedCount = 0;
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = line.split(delimiter).map((c) => c.trim().replaceAll('"', '')).toList();
      if (cols.length <= barcodeCol) continue;

      final barcode = cols[barcodeCol].trim();
      if (barcode.isEmpty) continue;

      final name = (nameCol != -1 && cols.length > nameCol) ? cols[nameCol].trim() : 'منتج $barcode';
      final category = (catCol != -1 && cols.length > catCol && cols[catCol].isNotEmpty) ? cols[catCol].trim() : 'عام';
      final price = (priceCol != -1 && cols.length > priceCol) ? (double.tryParse(cols[priceCol].replaceAll(',', '.')) ?? 0.0) : 0.0;
      final cost = (costCol != -1 && cols.length > costCol) ? (double.tryParse(cols[costCol].replaceAll(',', '.')) ?? (price * 0.85).roundToDouble()) : (price * 0.85).roundToDouble();
      final img = (imgCol != -1 && cols.length > imgCol) ? cols[imgCol].trim() : null;

      final item = MasterCatalogItem(
        barcode: barcode,
        name: name,
        category: category,
        defaultPrice: price > 0 ? price : 100.0,
        defaultCost: cost > 0 ? cost : 80.0,
        imageUrl: img?.isNotEmpty == true ? img : null,
      );

      instance._barcodeMap[barcode] = item;
      instance._allItems.removeWhere((it) => it.barcode == barcode);
      instance._allItems.add(item);
      if (category.isNotEmpty) instance._categories.add(category);
      importedCount++;
    }

    return importedCount;
  }

  /// Parses JSON catalog array and inserts into Master Catalog
  static int importFromJson(String jsonContent) {
    int importedCount = 0;
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is List) {
        for (var obj in decoded) {
          if (obj is Map<String, dynamic>) {
            final barcode = obj['barcode']?.toString() ?? '';
            if (barcode.isEmpty) continue;

            final name = obj['name']?.toString() ?? 'منتج $barcode';
            final category = obj['category']?.toString() ?? 'عام';
            final price = (obj['price'] as num?)?.toDouble() ?? 100.0;
            final cost = (obj['costPrice'] as num?)?.toDouble() ?? (price * 0.85);
            final imageUrl = obj['imageUrl']?.toString();

            final item = MasterCatalogItem(
              barcode: barcode,
              name: name,
              category: category,
              defaultPrice: price,
              defaultCost: cost,
              imageUrl: imageUrl,
            );

            instance._barcodeMap[barcode] = item;
            instance._allItems.removeWhere((it) => it.barcode == barcode);
            instance._allItems.add(item);
            if (category.isNotEmpty) instance._categories.add(category);
            importedCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('JSON Import Error: $e');
    }
    return importedCount;
  }
}