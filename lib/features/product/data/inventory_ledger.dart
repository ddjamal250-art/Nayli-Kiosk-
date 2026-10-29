import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_unit.dart';
import 'models/product_model.dart';
import '../../billing/domain/entities/cart_item.dart';

/// نتيجة إجمالية لتطبيق عملية البيع على المستودع
class SaleExecutionResult {
  final Map<int, double> itemTotalCosts;
  final List<Map<String, dynamic>> modifiedInventoryItems;

  const SaleExecutionResult({
    required this.itemTotalCosts,
    required this.modifiedInventoryItems,
  });
}

/// نتيجة عملية استهلاك أو تحريك المخزون
class LedgerResult {
  final Product product;
  final double cogs; // Cost of Goods Sold (إجمالي تكلفة البضاعة المباعة)
  final double unitCost; // تكلفة الوحدة الواحدة
  final double quantity;

  const LedgerResult({
    required this.product,
    required this.cogs,
    required this.unitCost,
    required this.quantity,
  });
}

/// خدمة دفتر حركة المخزون المركزي (Single Source of Truth)
/// مسؤولة عن كافة عمليات السحب والإرجاع والاستلام والمطابقة وحسابات الـ FIFO بدقة
class InventoryLedger {
  /// استخراج المعرف الأساسي للمنتج وتجريده من كافة اللواحق والبوادئ
  /// (كرتونة، باك، حبة، مل، مقياس، ميزان إلكتروني scale_)
  static String baseId(String cartProductId) {
    String id = cartProductId.trim();
    if (id.startsWith('scale_')) {
      id = id.substring('scale_'.length);
      final parts = id.split('_');
      // إذا كان الجزء الأخير عبارة عن طابع زمني timestamp
      if (parts.length >= 2 && int.tryParse(parts.last) != null) {
        id = parts.sublist(0, parts.length - 1).join('_');
      }
    }
    for (final suffix in const [
      '_carton_',
      '_pack_',
      '_pack',
      '_piece_',
      '_meter_',
      '_ml_',
      '_unit_',
      '_offer_',
    ]) {
      if (id.contains(suffix)) {
        id = id.split(suffix).first;
        break;
      }
    }
    return id;
  }

  /// كشف وتصحيح التكلفة الشاذة للدفعة (مثلاً إذا كانت مسجلة بسعر الكرتونة بدلاً من الحبة)
  static double sanitizeBatchUnitCost(Product product, double rawBatchCost) {
    if (rawBatchCost <= 0) {
      return product.effectiveCostPrice;
    }
    // إذا كانت تكلفة الدفعة أكبر من سعر بيع الحبة، ولدى المنتج كرتونة بمضاعف مناسب
    if (product.price > 0 && rawBatchCost > product.price) {
      final largeUnit = product.units.where((u) => u.tier == UnitTier.large && u.multiplier > 1).firstOrNull;
      if (largeUnit != null && largeUnit.multiplier > 1) {
        final derived = rawBatchCost / largeUnit.multiplier;
        if (derived <= product.price * 1.05) {
          return derived;
        }
      }
      final mediumUnit = product.units.where((u) => u.tier == UnitTier.medium && u.multiplier > 1).firstOrNull;
      if (mediumUnit != null && mediumUnit.multiplier > 1) {
        final derived = rawBatchCost / mediumUnit.multiplier;
        if (derived <= product.price * 1.05) {
          return derived;
        }
      }
      // إذا كانت التكلفة تفوق سعر البيع بأكثر من 3 أضعاف، نلجأ إلى effectiveCostPrice المحقق
      if (product.effectiveCostPrice > 0 && product.effectiveCostPrice <= product.price) {
        return product.effectiveCostPrice;
      }
    }
    return rawBatchCost;
  }

  /// استهلاك كمية من المخزون بنظام FIFO وحساب التكلفة الحقيقية للبضاعة المباعة
  static LedgerResult consume(
    Product p,
    double qty, {
    bool allowNegative = true,
  }) {
    final double absQty = qty.abs();
    if (absQty <= 0) {
      return LedgerResult(product: p, cogs: 0.0, unitCost: p.effectiveCostPrice, quantity: 0.0);
    }

    final double fallbackCost = p.effectiveCostPrice > 0
        ? p.effectiveCostPrice
        : (p.costPrice > 0 ? p.costPrice : 0.0);

    List<PurchaseBatch> updatedBatches = List.from(p.stockBatches);
    double remainingToDeduct = absQty;
    double fifoCostSum = 0.0;
    PurchaseBatch? lastRefBatch = updatedBatches.isNotEmpty ? updatedBatches.last : null;

    if (updatedBatches.isNotEmpty) {
      // الترتيب زمني تصاعدي (الأقدم أولاً FIFO)
      updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
      lastRefBatch = updatedBatches.last;

      for (int i = 0; i < updatedBatches.length; i++) {
        if (remainingToDeduct <= 0) break;
        final batch = updatedBatches[i];
        if (batch.remainingQuantity <= 0) continue;

        final double safeBatchCost = sanitizeBatchUnitCost(p, batch.costPrice > 0 ? batch.costPrice : fallbackCost);

        if (batch.remainingQuantity <= remainingToDeduct) {
          final double taken = batch.remainingQuantity;
          fifoCostSum += taken * safeBatchCost;
          remainingToDeduct -= taken;
          updatedBatches[i] = batch.copyWith(remainingQuantity: 0.0);
        } else {
          fifoCostSum += remainingToDeduct * safeBatchCost;
          updatedBatches[i] = batch.copyWith(remainingQuantity: batch.remainingQuantity - remainingToDeduct);
          remainingToDeduct = 0.0;
        }
      }
    }

    // إذا تجاوزت الكمية المخزون الموجود (مخزون سالب أو نفاد الدفعات)
    if (remainingToDeduct > 0) {
      fifoCostSum += remainingToDeduct * fallbackCost;
    }

    // تنظيف الدفعات المستهلكة بالكامل مع الاحتفاظ بآخر دفعة مرجعية بكمية 0
    updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
    if (updatedBatches.isEmpty && lastRefBatch != null) {
      updatedBatches.add(lastRefBatch.copyWith(remainingQuantity: 0.0));
    } else if (updatedBatches.isEmpty && fallbackCost > 0) {
      updatedBatches.add(PurchaseBatch(
        costPrice: fallbackCost,
        remainingQuantity: 0.0,
        dateAdded: DateTime.now(),
      ));
    }

    final double newStock = allowNegative
        ? (p.stock - absQty).toDouble()
        : (p.stock - absQty).toDouble().clamp(0.0, 9999999.0);

    final updatedProduct = p.copyWith(
      stock: newStock,
      stockBatches: updatedBatches,
    );

    final double effectiveUnitCost = absQty > 0 ? (fifoCostSum / absQty) : fallbackCost;

    return LedgerResult(
      product: updatedProduct,
      cogs: fifoCostSum,
      unitCost: effectiveUnitCost,
      quantity: absQty,
    );
  }

  /// إرجاع بضاعة إلى المخزون (استرجاع مبيعات أو إلغاء فاتورة)
  static LedgerResult restock(
    Product p,
    double qty, {
    double? unitCost,
  }) {
    final double absQty = qty.abs();
    if (absQty <= 0) {
      return LedgerResult(product: p, cogs: 0.0, unitCost: p.effectiveCostPrice, quantity: 0.0);
    }

    final double effectiveUnitCost = (unitCost != null && unitCost > 0)
        ? unitCost
        : (p.effectiveCostPrice > 0 ? p.effectiveCostPrice : p.costPrice);

    List<PurchaseBatch> updatedBatches = List.from(p.stockBatches);
    if (updatedBatches.isNotEmpty) {
      updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded)); // الأحدث أولاً
      final newest = updatedBatches.first;
      updatedBatches[0] = newest.copyWith(
        remainingQuantity: (newest.remainingQuantity > 0 ? newest.remainingQuantity : 0.0) + absQty,
      );
    } else {
      updatedBatches.add(PurchaseBatch(
        costPrice: effectiveUnitCost,
        remainingQuantity: absQty,
        dateAdded: DateTime.now(),
      ));
    }

    final double newStock = (p.stock + absQty).toDouble();
    final updatedProduct = p.copyWith(
      stock: newStock,
      stockBatches: updatedBatches,
    );

    return LedgerResult(
      product: updatedProduct,
      cogs: absQty * effectiveUnitCost,
      unitCost: effectiveUnitCost,
      quantity: absQty,
    );
  }

  /// استلام دفعة شراء جديدة (Arrivage / Bon d'entrée)
  static Product receive(
    Product p,
    double qty,
    double unitCostPerBaseUnit, {
    DateTime? date,
    String? supplier,
    String? supplierPhone,
  }) {
    final double absQty = qty.abs();
    final safeUnitCost = unitCostPerBaseUnit > 0 ? unitCostPerBaseUnit : p.effectiveCostPrice;

    final newBatch = PurchaseBatch(
      costPrice: safeUnitCost,
      remainingQuantity: absQty,
      dateAdded: date ?? DateTime.now(),
      supplierName: supplier?.trim().isNotEmpty == true ? supplier!.trim() : null,
      supplierPhone: supplierPhone?.trim().isNotEmpty == true ? supplierPhone!.trim() : null,
    );

    // تصفية وتحديث الدفعات
    List<PurchaseBatch> updatedBatches = List.from(p.stockBatches);
    // إزالة الدفعات الصفرية غير الضرورية عند إضافة دفعة جديدة
    updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
    updatedBatches.add(newBatch);

    if (updatedBatches.length > 50) {
      updatedBatches = updatedBatches.sublist(updatedBatches.length - 50);
    }

    final double newStock = (p.stock + absQty).toDouble();

    return p.copyWith(
      stock: newStock,
      costPrice: safeUnitCost,
      stockBatches: updatedBatches,
    );
  }

  /// مطابقة وضبط الدفعات مع المخزون الحقيقي وإعادة التسعير الاختياري
  /// يضمن بشكل صارم: `stock == Σ batch.remainingQuantity`
  static Product reconcile(
    Product p, {
    double? newStock,
    double? repriceTo,
  }) {
    final double targetStock = newStock ?? p.stock;
    final double? safeNewCost = (repriceTo != null && repriceTo > 0) ? repriceTo : null;

    List<PurchaseBatch> updatedBatches = List.from(p.stockBatches);

    // 1. إعادة التسعير إذا تم تمرير سعر جديد
    if (safeNewCost != null) {
      for (int i = 0; i < updatedBatches.length; i++) {
        updatedBatches[i] = updatedBatches[i].copyWith(costPrice: safeNewCost);
      }
    }

    // 2. مطابقة الكميات مع المخزون المستهدف
    if (targetStock <= 0) {
      // نفاد المخزون أو مخزون سالب
      final lastCost = safeNewCost ?? (updatedBatches.isNotEmpty ? updatedBatches.last.costPrice : p.effectiveCostPrice);
      updatedBatches = [
        PurchaseBatch(
          costPrice: lastCost > 0 ? lastCost : p.effectiveCostPrice,
          remainingQuantity: 0.0,
          dateAdded: DateTime.now(),
        ),
      ];
    } else {
      // إجمالي الكمية الحالية في الدفعات الموجبة
      double currentSum = updatedBatches.fold<double>(0.0, (s, b) => s + (b.remainingQuantity > 0 ? b.remainingQuantity : 0.0));
      double diff = targetStock - currentSum;

      if (diff > 0) {
        // عجز في الدفعات: نضيف الكمية الناقصة لأحدث دفعة أو ننشئ واحدة
        if (updatedBatches.isNotEmpty) {
          updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
          final newest = updatedBatches.first;
          updatedBatches[0] = newest.copyWith(
            remainingQuantity: (newest.remainingQuantity > 0 ? newest.remainingQuantity : 0.0) + diff,
            costPrice: safeNewCost ?? newest.costPrice,
          );
        } else {
          updatedBatches.add(PurchaseBatch(
            costPrice: safeNewCost ?? p.effectiveCostPrice,
            remainingQuantity: diff,
            dateAdded: DateTime.now(),
          ));
        }
      } else if (diff < 0) {
        // فائض في الدفعات: نخصم من أقدم دفعة حتى يتطابق المجموع
        double toDeduct = diff.abs();
        updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        for (int i = 0; i < updatedBatches.length; i++) {
          if (toDeduct <= 0) break;
          final b = updatedBatches[i];
          if (b.remainingQuantity <= toDeduct) {
            toDeduct -= b.remainingQuantity;
            updatedBatches[i] = b.copyWith(remainingQuantity: 0.0);
          } else {
            updatedBatches[i] = b.copyWith(remainingQuantity: b.remainingQuantity - toDeduct);
            toDeduct = 0.0;
          }
        }
        updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
        if (updatedBatches.isEmpty) {
          updatedBatches.add(PurchaseBatch(
            costPrice: safeNewCost ?? p.effectiveCostPrice,
            remainingQuantity: targetStock,
            dateAdded: DateTime.now(),
          ));
        }
      }
    }

    return p.copyWith(
      stock: targetStock,
      costPrice: safeNewCost ?? p.costPrice,
      stockBatches: updatedBatches,
    );
  }
}

/// مستودع مركزي لتطبيق مبيعات وحركات المخزون على قاعدة بيانات Hive
class InventoryRepository {
  /// تطبيق عملية بيع كاملة لسلة المشتريات وتحديث المخزون والدفعات
  /// تُرجع كائن SaleExecutionResult يحتوي على خريطة التكلفة وقائمة العناصر المحدثة للبث المباشر
  static Future<SaleExecutionResult> applySale(
    List<CartItem> cartItems, {
    required bool isReturn,
    bool allowNegativeStock = true,
  }) async {
    final productBox = HiveDatabase.productBox;
    final Map<int, double> itemTotalCosts = {};
    final List<Map<String, dynamic>> modifiedInventoryItems = [];

    for (int cartIdx = 0; cartIdx < cartItems.length; cartIdx++) {
      final item = cartItems[cartIdx];
      final originalId = InventoryLedger.baseId(item.product.id);
      final productModel = productBox.get(originalId);

      if (productModel == null) {
        itemTotalCosts[cartIdx] = item.totalCostForInvoice.abs();
        continue;
      }

      final bool isItemReturn = isReturn || item.isReturnItem || item.total < 0;

      // 1. معالجة منتجات وصفات القهوة (المواد الأولية الخام)
      if (productModel.coffeeRecipeJson != null) {
        double recipeTotalCost = 0.0;
        try {
          final recipe = jsonDecode(productModel.coffeeRecipeJson!);
          if (recipe is List && recipe.isNotEmpty) {
            for (final entry in recipe) {
              if (entry is! Map) continue;
              final rawId = entry['rawProductId']?.toString();
              if (rawId == null) continue;
              final double qtyPerCup = (entry['qty'] as num?)?.toDouble() ?? 0.0;
              final String rawUnit = entry['unit']?.toString() ?? 'غرام';
              final bool isPieceUnit = rawUnit == 'حبة' || rawUnit == 'قطعة';
              final rawProduct = productBox.get(rawId);

              if (rawProduct != null) {
                final double deductUnits = qtyPerCup * item.quantity.abs();

                if (isItemReturn) {
                  final restored = InventoryLedger.restock(rawProduct, deductUnits);
                  await productBox.put(rawId, ProductModel.fromEntity(restored.product));
                  final unitIngredientCost = isPieceUnit ? restored.unitCost : (restored.unitCost / 1000.0);
                  recipeTotalCost += unitIngredientCost * deductUnits;
                  modifiedInventoryItems.add({
                    'id': rawId,
                    'barcode': rawProduct.barcode,
                    'newStock': restored.product.stock,
                  });
                } else {
                  final consumed = InventoryLedger.consume(rawProduct, deductUnits, allowNegative: allowNegativeStock);
                  await productBox.put(rawId, ProductModel.fromEntity(consumed.product));
                  final unitIngredientCost = isPieceUnit ? consumed.unitCost : (consumed.unitCost / 1000.0);
                  recipeTotalCost += unitIngredientCost * deductUnits;
                  modifiedInventoryItems.add({
                    'id': rawId,
                    'barcode': rawProduct.barcode,
                    'newStock': consumed.product.stock,
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Recipe processing error in ledger: $e');
        }

        if (recipeTotalCost > 0) {
          itemTotalCosts[cartIdx] = recipeTotalCost;
        } else {
          itemTotalCosts[cartIdx] = item.totalCostForInvoice.abs();
        }
        continue;
      }

      // 2. المنتجات العادية أو الميزانية
      final deductQty = item.totalStockDeduct.abs();
      Product updatedProd;

      if (isItemReturn) {
        final restocked = InventoryLedger.restock(
          productModel,
          deductQty,
          unitCost: item.customUnitCost,
        );
        updatedProd = restocked.product;
        await productBox.put(originalId, ProductModel.fromEntity(updatedProd));
        itemTotalCosts[cartIdx] = restocked.cogs;
      } else {
        final consumed = InventoryLedger.consume(
          productModel,
          deductQty,
          allowNegative: allowNegativeStock,
        );
        updatedProd = consumed.product;
        await productBox.put(originalId, ProductModel.fromEntity(updatedProd));
        // إذا كان البند لم يحدد تكلفة مخصصة صريحة نستخدم تكلفة الـ FIFO المحسوبة
        if (item.customUnitCost == null && consumed.cogs > 0) {
          itemTotalCosts[cartIdx] = consumed.cogs;
        } else {
          itemTotalCosts[cartIdx] = item.totalCostForInvoice.abs();
        }
      }

      modifiedInventoryItems.add({
        'id': originalId,
        'barcode': updatedProd.barcode,
        'newStock': updatedProd.stock,
      });

      // قائمة المشتريات الذكية التلقائية عند انخفاض المخزون
      final bool isLiquid = updatedProd.liquidConfigJson != null || updatedProd.isLiquidProduct;
      final double lowStockThreshold = isLiquid
          ? (updatedProd.liquidConfig?.containerVolume ?? 100.0) * 0.15
          : 5.0;

      if (updatedProd.stock <= lowStockThreshold) {
        final shoppingList = HiveDatabase.shoppingListBox;
        final existingList = shoppingList.get(originalId);
        final double refillQty = isLiquid ? (updatedProd.liquidConfig?.containerVolume ?? 100.0) : 10.0;
        if (existingList == null) {
          shoppingList.put(originalId, {
            'id': originalId,
            'name': updatedProd.name,
            'currentStock': updatedProd.stock,
            'qtyToBuy': refillQty,
          });
        } else if (existingList is Map) {
          final updatedList = Map<String, dynamic>.from(existingList);
          updatedList['currentStock'] = updatedProd.stock;
          shoppingList.put(originalId, updatedList);
        }
      }
    }

    return SaleExecutionResult(
      itemTotalCosts: itemTotalCosts,
      modifiedInventoryItems: modifiedInventoryItems,
    );
  }

  /// استرجاع المخزون عند إلغاء أو حذف فاتورة بيع سابقة
  static Future<void> restoreInvoice(Map invoiceData) async {
    final productBox = HiveDatabase.productBox;
    final rawItems = (invoiceData['items'] as List?) ?? [];

    for (final item in rawItems) {
      if (item is! Map) continue;
      final rawId = item['id']?.toString() ?? '';
      final originalId = InventoryLedger.baseId(rawId);

      final productModel = productBox.get(originalId);
      if (productModel == null) continue;

      // 1. وصفات القهوة (استرجاع كافة المكونات الخام)
      if (productModel.coffeeRecipeJson != null) {
        try {
          final recipe = jsonDecode(productModel.coffeeRecipeJson!);
          if (recipe is List && recipe.isNotEmpty) {
            for (final entry in recipe) {
              if (entry is! Map) continue;
              final rawIngId = entry['rawProductId']?.toString();
              if (rawIngId == null) continue;
              final gramsPerCup = (entry['qty'] as num?)?.toDouble() ?? 0.0;
              final rawProduct = productBox.get(rawIngId);
              if (rawProduct != null) {
                final qty = (item['qty'] as num?)?.toDouble() ?? 1.0;
                final addUnits = gramsPerCup * qty.abs();
                final restored = InventoryLedger.restock(rawProduct, addUnits);
                await productBox.put(rawIngId, ProductModel.fromEntity(restored.product));
              }
            }
          }
        } catch (_) {}
        continue;
      }

      // 2. المنتجات العادية أو الميزانية
      final double qty = ((item['qty'] as num?)?.toDouble() ?? 1.0).abs();
      final double? weightKg = (item['weightKg'] as num?)?.toDouble()?.abs();
      final double? savedStockDeducted = (item['stockDeducted'] as num?)?.toDouble()?.abs();
      final double? savedUnitMultiplier = (item['unitMultiplier'] as num?)?.toDouble();

      final double unitsToAdd = savedStockDeducted ??
          (weightKg != null && weightKg > 0 ? weightKg : (qty * (savedUnitMultiplier ?? 1.0)));

      final double? savedCostPrice = (item['costPrice'] as num?)?.toDouble();

      final restored = InventoryLedger.restock(
        productModel,
        unitsToAdd,
        unitCost: savedCostPrice,
      );
      await productBox.put(originalId, ProductModel.fromEntity(restored.product));
    }
  }
}
