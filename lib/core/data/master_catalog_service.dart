import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'master_catalog_seed.dart';

class MasterCatalogService {
  static final MasterCatalogService instance = MasterCatalogService._();
  MasterCatalogService._();

  final Map<String, MasterCatalogItem> _barcodeMap = {};
  final List<MasterCatalogItem> _allItems = [];
  final Set<String> _categories = {'الكل'};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<MasterCatalogItem> get allItems => _allItems.isNotEmpty ? _allItems : MasterCatalogSeed.items;
  List<String> get categories => _categories.toList();

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      // 1. Populate with seed items first as fast fallback
      for (final item in MasterCatalogSeed.items) {
        _barcodeMap[item.barcode.trim()] = item;
        _allItems.add(item);
        _categories.add(item.category);
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
    if (_barcodeMap.containsKey(clean)) {
      return _barcodeMap[clean];
    }
    return MasterCatalogSeed.lookup(clean);
  }

  List<MasterCatalogItem> search(String query, {String category = 'الكل', int limit = 0}) {
    final q = query.trim().toLowerCase();
    final source = allItems;
    final List<MasterCatalogItem> results = [];

    for (final item in source) {
      final matchesCat = category == 'الكل' || item.category == category;
      if (!matchesCat) continue;

      if (q.isEmpty) {
        results.add(item);
      } else if (item.barcode.contains(q) ||
          item.name.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q)) {
        results.add(item);
      }

      if (limit > 0 && results.length >= limit) break;
    }

    return results;
  }
}