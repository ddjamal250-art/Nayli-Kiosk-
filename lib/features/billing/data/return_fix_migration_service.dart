import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import '../../product/data/models/product_model.dart';
import '../../product/domain/entities/product.dart';
import '../../shifts/data/shift_service.dart';

/// خدمة الإصلاح التلقائي والاستصلاح بأثر رجعي لفواتير الإرجاع السابقة التالفة
/// تقوم باستعادة المخزون الضائع (+2x Q)، وتصحيح إشارات الفواتير السابقة، وإعادة احتساب الورديات
class ReturnFixMigrationService {
  static const String migrationKey = 'has_repaired_corrupted_returns_v1';

  /// فحص وإصلاح جميع الفواتير التالفة السابقة بأثر رجعي
  static Future<Map<String, dynamic>> runRetroactiveReturnRepair({bool force = false}) async {
    final result = <String, dynamic>{
      'fixedCount': 0,
      'restoredItemsCount': 0,
      'restoredStockUnits': 0.0,
      'adjustedAmount': 0.0,
      'affectedInvoices': <String>[],
      'affectedProducts': <String>[],
      'alreadyRepaired': false,
    };

    try {
      final settingsBox = HiveDatabase.settingsBox;
      if (!force && settingsBox.get(migrationKey) == true) {
        result['alreadyRepaired'] = true;
        return result;
      }

      final invoicesBox = HiveDatabase.invoicesBox;
      final productBox = HiveDatabase.productBox;
      final customersBox = HiveDatabase.customersBox;

      if (invoicesBox.isEmpty) {
        await settingsBox.put(migrationKey, true);
        return result;
      }

      int fixedCount = 0;
      int restoredItemsCount = 0;
      double restoredStockUnits = 0.0;
      double adjustedAmount = 0.0;
      final List<String> affectedInvoices = [];
      final Set<String> affectedProducts = {};

      for (final key in invoicesBox.keys) {
        final rawInv = invoicesBox.get(key);
        if (rawInv is! Map) continue;

        // تجاهل الفواتير التي تم إصلاحها مسبقاً لمنع التكرار (Idempotency)
        if (rawInv['wasCorruptedReturnFixed'] == true) continue;

        // تجاهل الفواتير الملغاة عبر الزر اليدوي المباشر لأنها استرجعت المخزون في وقتها
        if (rawInv['status'] == 'returned' ||
            rawInv['status'] == 'cancelled' ||
            rawInv['isReturned'] == true) {
          continue;
        }

        final items = (rawInv['items'] as List?) ?? [];
        bool hasReturnSign = false;

        for (final item in items) {
          if (item is! Map) continue;
          final name = (item['name'] ?? '').toString().toLowerCase();
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final total = (item['total'] as num?)?.toDouble() ?? 0.0;

          if (name.contains('إرجاع') ||
              name.contains('retour') ||
              name.contains('استرجاع') ||
              name.contains('return') ||
              (name.startsWith('[') && (name.contains('رجاع') || name.contains('ret'))) ||
              price < 0 ||
              total < 0) {
            hasReturnSign = true;
            break;
          }
        }

        final orderNote = (rawInv['orderNote'] ?? '').toString().toLowerCase();
        final bool noteIndicatesReturn = orderNote.contains('إرجاع') ||
            orderNote.contains('retour') ||
            orderNote.contains('استرجاع');
        final double totalAmt = (rawInv['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final bool isProperReturn = (rawInv['isReturn'] == true && totalAmt <= 0);
        if (isProperReturn) continue; // فواتير الإرجاع النظامية السالبة تم خصمها واسترجاع مخزونها بنجاح ولا تمس

        final bool flagConflict = (rawInv['isReturn'] == true && totalAmt > 0);

        // هل الفاتورة فاتورة إرجاع سابقة تالفة؟ (أي سُجلت كبيع موجب ومبلغ موجب بدلاً من إرجاع سالب)
        final bool isCorruptedReturn = (hasReturnSign && totalAmt > 0) ||
            (noteIndicatesReturn && totalAmt > 0) ||
            flagConflict;
        if (!isCorruptedReturn) continue;

        // 1. استصلاح المخزون لكل منتج في الفاتورة (+2x Q)
        for (final item in items) {
          if (item is! Map) continue;
          String originalId = item['id']?.toString() ?? '';
          if (originalId.isEmpty) continue;

          // تنظيف اللواحق الخاصة بالوحدات
          if (originalId.contains('_carton_')) {
            originalId = originalId.split('_carton_').first;
          } else if (originalId.contains('_piece_')) {
            originalId = originalId.split('_piece_').first;
          } else if (originalId.contains('_meter_')) {
            originalId = originalId.split('_meter_').first;
          } else if (originalId.contains('_ml_')) {
            originalId = originalId.split('_ml_').first;
          } else if (originalId.endsWith('_pack')) {
            originalId = originalId.replaceAll('_pack', '');
          }

          final product = productBox.get(originalId);
          if (product != null) {
            // معالجة منتجات وصفات القهوة (المواد الأولية كالقهوة الخام)
            if (product.coffeeRecipeJson != null) {
              try {
                final recipe = jsonDecode(product.coffeeRecipeJson!);
                if (recipe is List && recipe.isNotEmpty) {
                  for (final r in recipe) {
                    if (r is! Map) continue;
                    final rawId = r['rawProductId']?.toString();
                    if (rawId == null) continue;
                    final double qtyPerCup = (r['qty'] as num?)?.toDouble() ?? 0.0;
                    final rawProduct = productBox.get(rawId);
                    if (rawProduct != null) {
                      final double cupQty = (item['qty'] as num?)?.toDouble()?.abs() ?? 1.0;
                      // كان مخصوماً بمقدار qtyPerCup * cupQty، الاستصلاح الصحيح هو إضافة 2x
                      final restoreGrams = (qtyPerCup * cupQty * 2.0).round();
                      final double newRawStock = (rawProduct.stock + restoreGrams).toDouble();

                      List<PurchaseBatch> rawBatches = List.from(rawProduct.stockBatches);
                      if (rawBatches.isNotEmpty) {
                        rawBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
                        final newest = rawBatches.first;
                        rawBatches[0] = newest.copyWith(
                          remainingQuantity: newest.remainingQuantity + restoreGrams,
                        );
                      } else {
                        rawBatches.add(PurchaseBatch(
                          remainingQuantity: restoreGrams.toDouble(),
                          costPrice: rawProduct.costPrice,
                          dateAdded: DateTime.now(),
                        ));
                      }
                      productBox.put(
                        rawId,
                        rawProduct.copyWith(stock: newRawStock, stockBatches: rawBatches),
                      );
                      affectedProducts.add(rawProduct.name);
                    }
                  }
                }
              } catch (_) {}
            }

            // السلع العادية أو الميزانية
            final double weightKg = ((item['weightKg'] as num?)?.toDouble() ?? 0.0).abs();
            final bool hasWeighable = product.units.any((u) => u.isWeighable && u.isEnabled) || weightKg > 0;

            double unitsToAdd = 0.0;
            if (hasWeighable && weightKg > 0) {
              // الميزاني بالكيلوغرام: نقص بمقدار weightKg، نعوض بـ 2x بالكيلوغرام
              unitsToAdd = (weightKg * 2.0);
            } else {
              final double qty = ((item['qty'] as num?)?.toDouble() ?? 1.0).abs();
              final double? savedMultiplier = (item['unitMultiplier'] as num?)?.toDouble();
              final dynamic rawUnitLevel = item['unitLevel'];
              double multiplier = savedMultiplier != null && savedMultiplier > 0 ? savedMultiplier : 1.0;
              if (savedMultiplier == null && rawUnitLevel != null) {
                if (rawUnitLevel is num) {
                  final u = product.units.where((x) => x.tierIndex == rawUnitLevel.toInt()).firstOrNull;
                  if (u != null && u.multiplier > 0) multiplier = u.multiplier;
                } else if (rawUnitLevel is String) {
                  final u = product.units.where((x) => x.name == rawUnitLevel || (rawUnitLevel == 'carton' && x.tierIndex == 2) || (rawUnitLevel == 'pack' && x.tierIndex == 1)).firstOrNull;
                  if (u != null && u.multiplier > 0) multiplier = u.multiplier;
                }
              }
              // كان مخصوماً بـ qty * multiplier، نعوض بـ 2x
              unitsToAdd = (qty * multiplier * 2.0);
            }

            final double newStock = (product.stock + unitsToAdd).toDouble();
            List<PurchaseBatch> updatedBatches = List.from(product.stockBatches);
            if (updatedBatches.isNotEmpty) {
              updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
              final newest = updatedBatches.first;
              updatedBatches[0] = newest.copyWith(
                remainingQuantity: newest.remainingQuantity + unitsToAdd,
              );
            } else {
              updatedBatches.add(PurchaseBatch(
                remainingQuantity: unitsToAdd,
                costPrice: product.costPrice,
                dateAdded: DateTime.now(),
              ));
            }

            productBox.put(
              originalId,
              product.copyWith(stock: newStock, stockBatches: updatedBatches),
            );

            restoredStockUnits += unitsToAdd;
            restoredItemsCount++;
            affectedProducts.add(product.name);
          }
        }

        // 2. تصحيح ديون الزبون إذا كان الوصل بالكريدي (حيث كان يزيد الدين بدلاً من خصمه)
        final bool isCredit = rawInv['isCredit'] == true;
        final customerId = rawInv['customerId']?.toString();
        if (isCredit && customerId != null && customerId.isNotEmpty) {
          try {
            final cData = customersBox.get(customerId);
            if (cData is Map) {
              final updatedCust = Map<String, dynamic>.from(cData);
              final currDebt = (updatedCust['debt'] as num?)?.toDouble() ??
                  (updatedCust['currentDebt'] as num?)?.toDouble() ??
                  0.0;
              // الوصل كان أضاف totalAmt، والمفروض يخصم totalAmt، إذن نخصم 2 * totalAmt
              final newDebt = (currDebt - (totalAmt.abs() * 2.0)).clamp(0.0, double.infinity);
              updatedCust['debt'] = newDebt;
              updatedCust['currentDebt'] = newDebt;
              await customersBox.put(customerId, updatedCust);
            }
          } catch (_) {}
        }

        // 3. تصحيح الفاتورة لتصبح فاتورة إرجاع سالبة معتمدة رسمياً
        final updatedInv = Map<String, dynamic>.from(rawInv);
        final absTotal = totalAmt.abs();
        final absCost = ((rawInv['totalCost'] as num?)?.toDouble() ?? 0.0).abs();
        final absProfit = ((rawInv['netProfit'] as num?)?.toDouble() ?? (absTotal - absCost)).abs();
        final absPaid = ((rawInv['paidAmount'] as num?)?.toDouble() ?? absTotal).abs();

        updatedInv['totalAmount'] = -absTotal;
        updatedInv['totalCost'] = -absCost;
        updatedInv['netProfit'] = -absProfit;
        updatedInv['paidAmount'] = -absPaid;
        updatedInv['receivedAmount'] = -absPaid;

        if (updatedInv['tobaccoSales'] != null) {
          updatedInv['tobaccoSales'] = -((updatedInv['tobaccoSales'] as num).toDouble().abs());
        }
        if (updatedInv['tobaccoCost'] != null) {
          updatedInv['tobaccoCost'] = -((updatedInv['tobaccoCost'] as num).toDouble().abs());
        }
        if (updatedInv['tobaccoProfit'] != null) {
          updatedInv['tobaccoProfit'] = -((updatedInv['tobaccoProfit'] as num).toDouble().abs());
        }
        if (updatedInv['coffeeSales'] != null) {
          updatedInv['coffeeSales'] = -((updatedInv['coffeeSales'] as num).toDouble().abs());
        }
        if (updatedInv['coffeeCost'] != null) {
          updatedInv['coffeeCost'] = -((updatedInv['coffeeCost'] as num).toDouble().abs());
        }
        if (updatedInv['coffeeProfit'] != null) {
          updatedInv['coffeeProfit'] = -((updatedInv['coffeeProfit'] as num).toDouble().abs());
        }
        if (updatedInv['generalSales'] != null) {
          updatedInv['generalSales'] = -((updatedInv['generalSales'] as num).toDouble().abs());
        }
        if (updatedInv['generalCost'] != null) {
          updatedInv['generalCost'] = -((updatedInv['generalCost'] as num).toDouble().abs());
        }
        if (updatedInv['generalProfit'] != null) {
          updatedInv['generalProfit'] = -((updatedInv['generalProfit'] as num).toDouble().abs());
        }

        updatedInv['isReturn'] = true;
        updatedInv['status'] = 'return';
        updatedInv['wasCorruptedReturnFixed'] = true;
        updatedInv['corruptedReturnFixedAt'] = DateTime.now().toIso8601String();

        await invoicesBox.put(key, updatedInv);

        fixedCount++;
        adjustedAmount += absTotal;
        affectedInvoices.add(key.toString());
      }

      // 4. إذا تم تصحيح فواتير، نعيد احتساب الورديات بالكامل لتسوية الصندوق والأرباح
      if (fixedCount > 0) {
        await ShiftService.repairHistoricalData();
      }

      // وسم الإكمال في الإعدادات لمنع التكرار
      await settingsBox.put(migrationKey, true);

      result['fixedCount'] = fixedCount;
      result['restoredItemsCount'] = restoredItemsCount;
      result['restoredStockUnits'] = restoredStockUnits;
      result['adjustedAmount'] = adjustedAmount;
      result['affectedInvoices'] = affectedInvoices;
      result['affectedProducts'] = affectedProducts.toList();

      debugPrint(
        '✅ ReturnFixMigrationService completed: Fixed $fixedCount corrupted return invoices, restored $restoredStockUnits units across ${affectedProducts.length} products.',
      );

      return result;
    } catch (e, stack) {
      debugPrint('❌ ReturnFixMigrationService failed: $e\n$stack');
      result['error'] = e.toString();
      return result;
    }
  }
}
