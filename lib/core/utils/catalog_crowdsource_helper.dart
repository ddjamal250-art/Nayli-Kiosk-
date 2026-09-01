import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../data/hive_database.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/shop/data/models/shop_model.dart';

class CatalogCrowdsourceHelper {
  // Dedicated Google Apps Script Endpoint for Discovered Products Catalog
  static const String defaultProductsScriptUrl =
      'https://script.google.com/macros/s/AKfycbyuqN5t5pUm2kxPsTCQ5k1y1qBySWFFFSPd3OW4dK5ynAU45sFaXJMlaD97G4OPO7V4zg/exec';

  /// Silently and asynchronously harvest new products to the developer's cloud catalog
  /// Zero UI impact, zero delay, fire-and-forget with pure UTF-8 encoding
  static void silentHarvest(
    Product product, {
    String category = 'عام',
    String unit = 'حبة',
  }) {
    scheduleMicrotask(() async {
      try {
        if (product.barcode.isEmpty && product.name.isEmpty) return;

        // Get store wilaya/city if available
        String wilaya = 'الجزائر';
        final shopBox = HiveDatabase.shopBox;
        if (shopBox.isNotEmpty) {
          final ShopModel? shop = shopBox.getAt(0);
          if (shop != null && shop.addressLine1.isNotEmpty) {
            wilaya = shop.addressLine1;
          }
        }

        final scriptUrl = HiveDatabase.settingsBox.get(
          'google_products_script_url',
          defaultValue: defaultProductsScriptUrl,
        ) as String;

        final payload = {
          'barcode': product.barcode.trim(),
          'name': product.name.trim(),
          'category': category.trim().isEmpty ? 'عام' : category.trim(),
          'price': product.price,
          'costPrice': product.costPrice,
          'unit': unit,
          'wilaya': wilaya,
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

