import 'package:flutter/foundation.dart';
import '../../../core/data/hive_database.dart';
import '../../customer/data/repositories/customer_repository.dart';
import '../../customer/domain/entities/customer.dart';
import '../../customer/domain/entities/debt_record.dart';
import '../../shifts/data/shift_service.dart';

/// خدمة المصالحة والتدقيق المالي الشامل بأثر رجعي
/// تقوم بإصلاح وتصحيح:
/// 1. تكاليف وأرباح الفواتير السابقة غير المحسوبة أو غير الدقيقة بدون حذف أي سجل
/// 2. تصحيح إشارات المرتجعات وتقسيمات الأقسام (تبغ، قهوة، عام)
/// 3. تدقيق ديون الزبائن وتصحيح الأرصدة التي تضاعفت خطأً عند إنشاء الزبون
/// 4. إعادة مزامنة الورديات والصندوق مع الحسابات المصححة
class FinancialReconciliationService {
  static const String reconciliationKey = 'has_repaired_financial_calculations_v2';

  static Future<Map<String, dynamic>> runRetroactiveFinancialHealing({bool force = false}) async {
    final result = <String, dynamic>{
      'invoicesHealed': 0,
      'customersHealed': 0,
      'totalCostRecovered': 0.0,
      'profitAdjusted': 0.0,
      'alreadyRepaired': false,
    };

    try {
      final settingsBox = HiveDatabase.settingsBox;
      if (!force && settingsBox.get(reconciliationKey) == true) {
        result['alreadyRepaired'] = true;
        return result;
      }

      final invoicesBox = HiveDatabase.invoicesBox;
      final productBox = HiveDatabase.productBox;
      final customersBox = HiveDatabase.customersBox;

      int invoicesHealed = 0;
      int customersHealed = 0;
      double totalCostRecovered = 0.0;
      double profitAdjusted = 0.0;

      // ==========================================
      // 1. تدقيق وإصلاح فواتير المبيعات بأثر رجعي
      // ==========================================
      if (invoicesBox.isNotEmpty) {
        for (final key in invoicesBox.keys) {
          final rawInv = invoicesBox.get(key);
          if (rawInv is! Map) continue;

          final inv = Map<String, dynamic>.from(rawInv);
          final itemsRaw = inv['items'];
          if (itemsRaw is! List) continue;

          final double totalAmount = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final double oldTotalCost = (inv['totalCost'] as num?)?.toDouble() ?? 0.0;
          final double? oldNetProfit = (inv['netProfit'] as num?)?.toDouble();

          final bool isReturn = inv['isReturn'] == true ||
              inv['status'] == 'returned' ||
              totalAmount < 0;

          bool invoiceChanged = false;
          double computedCost = 0.0;
          double tobaccoSales = 0.0;
          double tobaccoCost = 0.0;
          double coffeeSales = 0.0;
          double coffeeCost = 0.0;
          double generalSales = 0.0;
          double generalCost = 0.0;

          final updatedItems = <Map<String, dynamic>>[];

          for (final rawIt in itemsRaw) {
            if (rawIt is! Map) continue;
            final it = Map<String, dynamic>.from(rawIt);

            final isItemReturn = it['isReturnItem'] == true || isReturn;
            final double qtyRaw = ((it['qty'] as num?)?.toDouble() ??
                (it['weightKg'] as num?)?.toDouble() ??
                1.0).abs();
            final double itemQty = isItemReturn ? -qtyRaw : qtyRaw;

            final double price = (it['price'] as num?)?.toDouble() ?? 0.0;
            final double lineTotal = (it['total'] as num?)?.toDouble() ?? (price * itemQty);

            // استعادة تكلفة الشراء الحقيقية إذا كانت مفقودة أو صفرية
            double costPrice = (it['costPrice'] as num?)?.toDouble() ?? 0.0;
            if (costPrice <= 0) {
              costPrice = (it['buyPrice'] as num?)?.toDouble() ?? 0.0;
            }
            if (costPrice <= 0) {
              final prodId = it['id']?.toString() ?? it['productId']?.toString();
              if (prodId != null) {
                final p = productBox.get(prodId);
                if (p != null) {
                  costPrice = p.effectiveCostPrice > 0 ? p.effectiveCostPrice : p.costPrice;
                }
              }
            }
            if (costPrice > 0 && it['costPrice'] != costPrice) {
              it['costPrice'] = costPrice;
              invoiceChanged = true;
            }

            final double itemCost = (isItemReturn ? -1.0 : 1.0) * (costPrice * qtyRaw);
            it['totalCost'] = itemCost;
            it['profit'] = lineTotal - itemCost;
            computedCost += itemCost;

            final cat = it['category']?.toString().trim() ?? '';
            final name = it['name']?.toString().toLowerCase() ?? '';
            final bool isTobacco = it['isTobacco'] == true ||
                cat == 'التبغ والسجائر' ||
                cat == 'تبغ' ||
                cat.contains('تبغ') ||
                cat.contains('سجائر') ||
                name.contains('مارلبورو') ||
                name.contains('نسيم') ||
                name.contains('مالبورو') ||
                name.contains('شيشة') ||
                name.contains('سجائر');

            final bool isCoffee = it['isCoffee'] == true ||
                cat == 'المقهى' ||
                cat == 'قهوة' ||
                cat.contains('مقهى') ||
                name.contains('قهوة') ||
                name.contains('كابوتشينو') ||
                name.contains('نسكافيه');

            it['isTobacco'] = isTobacco;
            it['isCoffee'] = isCoffee;
            it['isReturnItem'] = isItemReturn;

            if (isTobacco) {
              tobaccoSales += lineTotal;
              tobaccoCost += itemCost;
            } else if (isCoffee) {
              coffeeSales += lineTotal;
              coffeeCost += itemCost;
            } else {
              generalSales += lineTotal;
              generalCost += itemCost;
            }

            updatedItems.add(it);
          }

          // تحديد هل الفاتورة تحتاج إلى تحديث
          final double targetCost = (oldTotalCost != 0.0 && !oldTotalCost.isNaN)
              ? (isReturn ? -oldTotalCost.abs() : oldTotalCost)
              : computedCost;

          final double targetNetProfit = (oldNetProfit != null && oldTotalCost != 0.0)
              ? oldNetProfit
              : (totalAmount - targetCost);

          if (inv['totalCost'] == null ||
              oldTotalCost == 0.0 ||
              inv['netProfit'] == null ||
              (isReturn && (oldTotalCost > 0 || (oldNetProfit != null && oldNetProfit > 0))) ||
              inv['tobaccoSales'] == null ||
              invoiceChanged) {
            inv['items'] = updatedItems;
            inv['totalCost'] = targetCost;
            inv['netProfit'] = targetNetProfit;
            inv['isReturn'] = isReturn;
            if (isReturn && inv['status'] != 'returned') {
              inv['status'] = 'returned';
            }
            inv['tobaccoSales'] = tobaccoSales;
            inv['tobaccoCost'] = tobaccoCost;
            inv['coffeeSales'] = coffeeSales;
            inv['coffeeCost'] = coffeeCost;
            inv['generalSales'] = generalSales;
            inv['generalCost'] = generalCost;
            inv['generalProfit'] = generalSales - generalCost;
            inv['wasFinancialHealed'] = true;

            await invoicesBox.put(key, inv);
            invoicesHealed++;
            totalCostRecovered += targetCost.abs();
            profitAdjusted += (targetNetProfit - (oldNetProfit ?? 0.0)).abs();
          }
        }
      }

      // ==========================================
      // 2. تدقيق ديون الزبائن وتصحيح الرصيد الافتتاحي المزدوج
      // ==========================================
      if (customersBox.isNotEmpty) {
        final repo = CustomerRepository();
        for (final key in customersBox.keys) {
          final rawCust = customersBox.get(key);
          if (rawCust is! Map) continue;

          final cust = Customer.fromMap(rawCust);
          final history = repo.getCustomerDebtHistory(cust.id);

          if (history.isEmpty) continue;

          // فحص هل يحتوي السجل على حركة افتتاحية
          final openingRecords = history.where((r) =>
              r.note.contains('افتتاحي') ||
              r.note.contains('initial') ||
              r.note.contains('رصيد افتتاحي سابق')).toList();

          if (openingRecords.isNotEmpty) {
            double creditSum = 0.0;
            double paymentSum = 0.0;

            for (final r in history) {
              if (r.type == DebtTransactionType.purchaseCredit) {
                creditSum += r.amount;
              } else {
                paymentSum += r.amount;
              }
            }

            final double expectedDebt = (creditSum - paymentSum).clamp(0.0, double.infinity);
            final double openingAmount = openingRecords.first.amount;

            // إذا كان دين العميل الحالي مساوياً للرصيد المحسوب + الرصيد الافتتاحي، فالدين تضاعف بسبب الخطأ البرمجي السابق
            if (cust.currentDebt > expectedDebt &&
                (cust.currentDebt - (expectedDebt + openingAmount)).abs() < 0.01) {
              final corrected = cust.copyWith(
                currentDebt: expectedDebt,
                updatedAt: DateTime.now(),
              );
              await repo.saveCustomer(corrected);
              customersHealed++;
              debugPrint('Reconciled doubled initial debt for customer ${cust.name}: ${cust.currentDebt} -> $expectedDebt DA');
            }
          }
        }
      }

      // ==========================================
      // 3. إعادة احتساب الورديات ومزامنة الصندوق
      // ==========================================
      try {
        await ShiftService.repairHistoricalData();
      } catch (e) {
        debugPrint('ShiftService.repairHistoricalData failed inside financial healing: $e');
      }

      result['invoicesHealed'] = invoicesHealed;
      result['customersHealed'] = customersHealed;
      result['totalCostRecovered'] = totalCostRecovered;
      result['profitAdjusted'] = profitAdjusted;

      await settingsBox.put(reconciliationKey, true);
      debugPrint('Financial Reconciliation Completed: invoicesHealed=$invoicesHealed, customersHealed=$customersHealed');
    } catch (e, stack) {
      debugPrint('Error in runRetroactiveFinancialHealing: $e\n$stack');
    }

    return result;
  }
}
