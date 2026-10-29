import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import 'models/product_model.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_unit.dart';
import '../../../core/utils/staff_permissions_service.dart';
import 'inventory_ledger.dart';

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

        // إذا كان المخزون سالباً، ولا يُسمح بالبيع بالسالب في المتجر، نرجعه إلى 0.0
        if (product.stock < 0 && !StaffPermissionsService.allowNegativeStockSale) {
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

  static const String cogsMigrationKey = 'has_repaired_corrupted_cogs_and_batches_v1';

  /// استصلاح وإصلاح شامل بأثر رجعي لدفعات الشراء التالفة وفواتير المبيعات والأرباح السابقة
  static Future<Map<String, dynamic>> repairCorruptedBatchesAndInvoicesRetroactively({bool force = false}) async {
    final result = <String, dynamic>{
      'productsHealed': 0,
      'batchesHealed': 0,
      'invoicesHealed': 0,
      'totalProfitAdjusted': 0.0,
      'alreadyRepaired': false,
    };

    try {
      final settingsBox = HiveDatabase.settingsBox;
      if (!force && settingsBox.get(cogsMigrationKey) == true) {
        result['alreadyRepaired'] = true;
        return result;
      }

      final productBox = HiveDatabase.productBox;
      final invoicesBox = HiveDatabase.invoicesBox;

      int productsHealed = 0;
      int batchesHealed = 0;
      int invoicesHealed = 0;
      double profitAdjusted = 0.0;

      // 1. إصلاح دفعات المنتجات وأسعار التكلفة في productBox
      for (final key in productBox.keys) {
        final product = productBox.get(key);
        if (product == null) continue;

        bool productModified = false;
        double healedCostPrice = product.costPrice;

        // استخراج معامل الكرتونة والعلبة إن وجد
        double cartonMult = 1.0;
        final largeUnit = product.units.where((u) => u.tier == UnitTier.large && u.multiplier > 1).firstOrNull;
        if (largeUnit != null) {
          cartonMult = largeUnit.multiplier;
        } else if (product.units.any((u) => u.tier == UnitTier.medium && u.multiplier > 1)) {
          cartonMult = product.units.firstWhere((u) => u.tier == UnitTier.medium).multiplier;
        }

        // فحص وتصحيح costPrice الأساسي للمنتج إذا كان مضخماً بسعر الكرتونة
        if (product.price > 0 && healedCostPrice >= product.price && cartonMult > 1) {
          final candidateCost = healedCostPrice / cartonMult;
          if (candidateCost < product.price) {
            healedCostPrice = candidateCost;
            productModified = true;
          }
        }

        // فحص دفعات الشراء stockBatches وتصحيح أي تكلفة وحدة تفوق سعر البيع
        List<PurchaseBatch> updatedBatches = [];
        for (final batch in product.stockBatches) {
          double batchCost = batch.costPrice;
          if (batchCost > 0 && product.price > 0 && batchCost > product.price) {
            final sanitized = InventoryLedger.sanitizeBatchUnitCost(
              batchCost,
              cartonMultiplier: cartonMult,
              sellingPrice: product.price,
            );
            if (sanitized != batchCost) {
              batchCost = sanitized;
              batchesHealed++;
              productModified = true;
            }
          }
          final qty = batch.remainingQuantity < 0 ? 0.0 : batch.remainingQuantity;
          if (qty != batch.remainingQuantity) {
            productModified = true;
          }
          updatedBatches.add(batch.copyWith(
            costPrice: batchCost,
            remainingQuantity: qty,
          ));
        }

        if (productModified) {
          final updatedProduct = product.copyWith(
            costPrice: healedCostPrice,
            stockBatches: updatedBatches,
          );
          await productBox.put(product.id, updatedProduct);
          productsHealed++;
        }
      }

      // 2. إصلاح فواتير المبيعات السابقة بأثر رجعي في invoicesBox
      if (invoicesBox.isNotEmpty) {
        for (final invKey in invoicesBox.keys) {
          final rawInv = invoicesBox.get(invKey);
          if (rawInv is! Map) continue;

          final inv = Map<String, dynamic>.from(rawInv);
          final items = (inv['items'] as List?)?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          if (items == null || items.isEmpty) continue;

          bool invoiceNeedsUpdate = false;
          double recomputedTotalCost = 0.0;

          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            final rawId = item['id']?.toString() ?? '';
            final baseId = InventoryLedger.baseId(rawId);
            final p = productBox.get(baseId);

            final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final double qty = ((item['qty'] as num?)?.toDouble() ?? 1.0).abs();
            final double? weightKg = (item['weightKg'] as num?)?.toDouble();
            final double effectiveQty = (weightKg != null && weightKg > 0) ? weightKg : qty;
            final double itemTotal = (item['total'] as num?)?.toDouble() ?? (price * effectiveQty);

            double currentItemCost = (item['totalCost'] as num?)?.toDouble() ?? 0.0;
            double currentUnitCost = (item['costPrice'] as num?)?.toDouble() ?? (effectiveQty > 0 ? (currentItemCost / effectiveQty) : 0.0);

            // فحص هل تكلفة الوحدة في الفاتورة كانت مضخمة بشكل غير معقول
            bool itemCostCorrupted = false;
            double healedUnitCost = currentUnitCost;

            if (price > 0 && currentUnitCost > price) {
              itemCostCorrupted = true;
              double cartonMult = (item['unitMultiplier'] as num?)?.toDouble() ?? 1.0;
              if (cartonMult <= 1 && p != null) {
                final largeUnit = p.units.where((u) => u.tier == UnitTier.large && u.multiplier > 1).firstOrNull;
                if (largeUnit != null) cartonMult = largeUnit.multiplier;
              }

              if (cartonMult > 1 && (currentUnitCost / cartonMult) < price) {
                healedUnitCost = currentUnitCost / cartonMult;
              } else if (p != null && p.effectiveCostPrice > 0 && p.effectiveCostPrice < price) {
                healedUnitCost = p.effectiveCostPrice;
              } else {
                healedUnitCost = price * 0.8; // هامش افتراضي معقول 20%
              }
            } else if (currentItemCost < 0) {
              itemCostCorrupted = true;
              healedUnitCost = p != null && p.effectiveCostPrice > 0 ? p.effectiveCostPrice : 0.0;
            }

            if (itemCostCorrupted) {
              final newTotalCost = healedUnitCost * effectiveQty;
              final newProfit = itemTotal - newTotalCost;

              item['costPrice'] = healedUnitCost;
              item['totalCost'] = newTotalCost;
              item['profit'] = newProfit;
              invoiceNeedsUpdate = true;
              recomputedTotalCost += newTotalCost;
            } else {
              recomputedTotalCost += currentItemCost;
            }
          }

          final double totalAmount = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final double previousTotalCost = (inv['totalCost'] as num?)?.toDouble() ?? 0.0;
          final double previousNetProfit = (inv['netProfit'] as num?)?.toDouble() ?? (totalAmount - previousTotalCost);

          if (invoiceNeedsUpdate || (previousNetProfit < 0 && totalAmount > 0 && recomputedTotalCost < totalAmount)) {
            final double newNetProfit = totalAmount - recomputedTotalCost;
            inv['items'] = items;
            inv['totalCost'] = recomputedTotalCost;
            inv['netProfit'] = newNetProfit;

            await invoicesBox.put(invKey, inv);
            invoicesHealed++;
            profitAdjusted += (newNetProfit - previousNetProfit);
          }
        }
      }

      result['productsHealed'] = productsHealed;
      result['batchesHealed'] = batchesHealed;
      result['invoicesHealed'] = invoicesHealed;
      result['totalProfitAdjusted'] = profitAdjusted;

      await settingsBox.put(cogsMigrationKey, true);
      debugPrint('Retroactive COGS and Batches repair completed: productsHealed=$productsHealed, batchesHealed=$batchesHealed, invoicesHealed=$invoicesHealed, profitAdjusted=$profitAdjusted DA');
    } catch (e, stack) {
      debugPrint('Error in repairCorruptedBatchesAndInvoicesRetroactively: $e\n$stack');
    }

    return result;
  }
}
