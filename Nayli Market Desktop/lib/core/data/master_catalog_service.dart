import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
}