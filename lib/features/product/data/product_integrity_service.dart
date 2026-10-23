import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import 'models/product_model.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_unit.dart';

/// خدمة تدقيق وسلامة بيانات المنتجات والمخزون
/// تعالج المفاتيح المكررة في Hive وتصحح أي كميات سالبة أو مضاعفات وحدات مضخمة ناتجة عن أخطاء سابقة
class ProductIntegrityService {
  static const String integrityKey = 'has_repaired_product_integrity_v2';

  /// فحص وتنظيف شامل لبيانات المنتجات والمخزون
  static Future<Map<String, dynamic>> repairProductDataIntegrity({bool force = false}) async {
    final result = <String, dynamic>{
      'duplicateKeysRemoved': 0,
      'negativeStocksFixed': 0,
      'inflatedUnitsFixed': 0,
      'repairedProducts': <String>[],
    };

    try {
      final settingsBox = HiveDatabase.settingsBox;
      if (!force && settingsBox.get(integrityKey) == true) {
        return result;
      }

      final productBox = HiveDatabase.productBox;
      if (productBox.isEmpty) {
        await settingsBox.put(integrityKey, true);
        return result;
      }

      int duplicatesRemoved = 0;
      int negativeFixed = 0;
      int inflatedUnitsFixed = 0;
      final List<String> repairedProducts = [];

      // 1. تنظيف المفاتيح المكررة (مثلاً إذا حُفظ المنتج بمفتاح الباركود بدلاً من المعرف ID)
      final allKeys = List<dynamic>.from(productBox.keys);
      for (final key in allKeys) {
        final product = productBox.get(key);
        if (product == null) continue;

        final expectedKey = product.id;
        if (key.toString() != expectedKey) {
          // هذا المفتاح ليس هو الـ ID (مثلاً باركود قديم من المزامنة السحابية)
          if (productBox.containsKey(expectedKey)) {
            // المفتاح الصحيح موجود بالفعل، نحذف المفتاح المكرر الزائد
            await productBox.delete(key);
            duplicatesRemoved++;
          } else {
            // المفتاح الصحيح غير موجود، ننقله إلى المفتاح الصحيح ثم نحذف القديم
            await productBox.put(expectedKey, product);
            await productBox.delete(key);
            duplicatesRemoved++;
          }
        }
      }

      // 2. تدقيق المخزون والكميات وسعات الوحدات ومنع القيم السالبة أو المضاعفة خطأً
      for (final key in productBox.keys) {
        final product = productBox.get(key);
        if (product == null) continue;

        bool needsUpdate = false;
        double correctedStock = product.stock;

        // إذا كان المخزون سالباً، نرجعه إلى 0.0
        if (product.stock < 0) {
          correctedStock = 0.0;
          needsUpdate = true;
          negativeFixed++;
        }

        // فحص وإصلاح سعة الكرتونة (UnitTier.large) التي تضاعفت سابقاً بسبب ضربها المتكرر في سعة الباك (UnitTier.medium)
        List<ProductUnit> updatedUnits = List<ProductUnit>.from(product.units);
        final mediumIdx = updatedUnits.indexWhere((u) => u.tier == UnitTier.medium);
        final largeIdx = updatedUnits.indexWhere((u) => u.tier == UnitTier.large);
        if (mediumIdx != -1 && largeIdx != -1) {
          final mediumUnit = updatedUnits[mediumIdx];
          final largeUnit = updatedUnits[largeIdx];
          final pCap = mediumUnit.multiplier;
          final double cCap = largeUnit.multiplier;

          if (pCap > 1 && cCap > pCap) {
            double? expectedCap;
            if (largeUnit.cost > 0 && product.costPrice > 0) {
              expectedCap = largeUnit.cost / product.costPrice;
            } else if (largeUnit.price > 0 && product.price > 0) {
              expectedCap = largeUnit.price / product.price;
            }

            double healedCap = cCap;
            if (expectedCap != null && expectedCap >= 2) {
              while ((healedCap / pCap) >= pCap &&
                  ((healedCap / pCap) - expectedCap).abs() < (healedCap - expectedCap).abs() * 0.5) {
                healedCap = (healedCap / pCap).roundToDouble();
              }
            } else if (!product.isLiquidProduct && healedCap > 250 && (healedCap % pCap == 0)) {
              while (healedCap > 250 && (healedCap / pCap) >= pCap && (healedCap % pCap == 0)) {
                healedCap = (healedCap / pCap).roundToDouble();
              }
            }

            if (healedCap != cCap && healedCap >= pCap) {
              updatedUnits[largeIdx] = ProductUnit(
                name: largeUnit.name,
                barcode: largeUnit.barcode,
                multiplier: healedCap,
                price: largeUnit.price,
                cost: largeUnit.cost,
                tier: largeUnit.tier,
              );
              needsUpdate = true;
              inflatedUnitsFixed++;
            }
          }
        }

        // فحص دفعات الشراء FIFO ومنع أي كميات سالبة فيها
        List<PurchaseBatch> sanitizedBatches = List.from(product.stockBatches);
        bool batchesModified = false;
        for (int i = 0; i < sanitizedBatches.length; i++) {
          if (sanitizedBatches[i].remainingQuantity < 0) {
            sanitizedBatches[i] = sanitizedBatches[i].copyWith(remainingQuantity: 0.0);
            batchesModified = true;
          }
        }

        if (batchesModified) {
          needsUpdate = true;
          sanitizedBatches.removeWhere((b) => b.remainingQuantity <= 0);
        }

        if (needsUpdate) {
          final sanitized = product.copyWith(
            stock: correctedStock,
            units: updatedUnits,
            stockBatches: sanitizedBatches,
          );
          await productBox.put(product.id, sanitized);
          repairedProducts.add(product.name);
        }
      }

      result['duplicateKeysRemoved'] = duplicatesRemoved;
      result['negativeStocksFixed'] = negativeFixed;
      result['inflatedUnitsFixed'] = inflatedUnitsFixed;
      result['repairedProducts'] = repairedProducts;

      await settingsBox.put(integrityKey, true);
      debugPrint('ProductIntegrityService complete: duplicates removed=$duplicatesRemoved, negative stocks healed=$negativeFixed, inflated units fixed=$inflatedUnitsFixed');
    } catch (e) {
      debugPrint('ProductIntegrityService error: $e');
    }

    return result;
  }
}
