import 'package:intl/intl.dart';
import '../data/hive_database.dart';
import '../../features/customer/domain/entities/customer.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../utils/app_constants.dart';

class ExcelExportHelper {
  /// Get official store header string for Excel
  static String _getOfficialHeader(String reportTitle) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM for Microsoft Excel Arabic compatibility

    String shopName = AppConstants.defaultShopName;
    String shopPhone = '';
    String shopAddress = '';

    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null) {
        if (shop.name.isNotEmpty) shopName = shop.name;
        if (shop.phone.isNotEmpty) shopPhone = shop.phone;
        if (shop.address.isNotEmpty) shopAddress = shop.address;
      }
    }

    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.now());

    buffer.writeln('=== $shopName ===');
    if (shopAddress.isNotEmpty || shopPhone.isNotEmpty) {
      buffer.writeln('العنوان: $shopAddress | الهاتف: $shopPhone');
    }
    buffer.writeln('الوثيقة: $reportTitle');
    buffer.writeln('تاريخ الاستخراج: $dateStr');
    buffer.writeln('العملة الرسمية: الدينار الجزائري (DZD)');
    buffer.writeln('------------------------------------------------------------');

    return buffer.toString();
  }

  /// 1. Official Products Inventory Sheet (جدول جرد وتقييم المخزون العام)
  static String exportProductsToCsv() {
    final box = HiveDatabase.productBox;
    final products = box.values.toList();

    final buffer = StringBuffer();
    buffer.write(_getOfficialHeader('جدول المخزون العام وتقييم أصول المتجر'));

    buffer.writeln('الرقم,الباركود,اسم المنتج,سعر الشراء (التكلفة دج),سعر البيع (دج),المخزون (الكمية),إجمالي رأس المال بالتكلفة (دج),إجمالي القيمة بسعر البيع (دج),الربح الكامن (دج)');

    double totalCost = 0.0;
    double totalRetail = 0.0;
    int index = 1;

    for (var p in products) {
      final barcode = '"${p.barcode.replaceAll('"', '""')}"';
      final name = '"${p.name.replaceAll('"', '""')}"';
      final cost = p.costPrice;
      final price = p.price;
      final stock = p.stock;
      final lineCostTotal = cost * stock;
      final lineRetailTotal = price * stock;
      final profit = lineRetailTotal - lineCostTotal;

      totalCost += lineCostTotal;
      totalRetail += lineRetailTotal;

      buffer.writeln('$index,$barcode,$name,${cost.toStringAsFixed(2)},${price.toStringAsFixed(2)},$stock,${lineCostTotal.toStringAsFixed(2)},${lineRetailTotal.toStringAsFixed(2)},${profit.toStringAsFixed(2)}');
      index++;
    }

    buffer.writeln('------------------------------------------------------------');
    buffer.writeln('المجموع الإجمالي,,,,' '${products.length} صنف,${totalCost.toStringAsFixed(2)},${totalRetail.toStringAsFixed(2)},${(totalRetail - totalCost).toStringAsFixed(2)}');

    return buffer.toString();
  }

  /// 2. Official Customer Debts Ledger (دفتر ديون الزبائن وكشف الحسابات)
  static String exportDebtsToCsv(List<Customer> customers) {
    final buffer = StringBuffer();
    buffer.write(_getOfficialHeader('دفتر ديون الزبائن والكريدي المعلق'));

    buffer.writeln('الرقم,اسم الزبون الكامل,رقم الهاتف,العنوان,إجمالي الدين الحالي (دج),سقف الائتمان المسموح به,حالة الحساب');

    double totalDebts = 0.0;
    int index = 1;

    for (var c in customers) {
      final name = '"${c.name.replaceAll('"', '""')}"';
      final phone = '"${c.phoneNumber.replaceAll('"', '""')}"';
      final address = '"${c.address.replaceAll('"', '""')}"';
      final debt = c.currentDebt;
      final limit = c.creditLimit;
      final status = debt > 0 ? (debt > limit && limit > 0 ? 'تجاوز السقف ⚠️' : 'عليه دين') : 'خالص (0 دج)';

      totalDebts += debt;

      buffer.writeln('$index,$name,$phone,$address,${debt.toStringAsFixed(2)},${limit > 0 ? limit.toStringAsFixed(2) : "غير محدد"},$status');
      index++;
    }

    buffer.writeln('------------------------------------------------------------');
    buffer.writeln('إجمالي الديون المعلقة في المحل,,,,${totalDebts.toStringAsFixed(2)} دج,,');

    return buffer.toString();
  }

  /// 3. Official Inventory Audit & Reconciliation Sheet (جدول الجرد الميداني وحساب العجز)
  static String exportInventoryAuditToCsv(Map<String, int> countedStock) {
    final box = HiveDatabase.productBox;
    final products = box.values.toList();

    final buffer = StringBuffer();
    buffer.write(_getOfficialHeader('تقرير الجرد الميداني السنوي ومطابقة الفوارق'));

    buffer.writeln('الرقم,الباركود,اسم المنتج,المخزون المسجل (النظري),المخزون الفعلي (المجرود),الفارق (قطعة),سعر التكلفة (دج),قيمة الفارق بالدينار (عجز/فائض),الحالة');

    double totalDiscrepancyCost = 0.0;
    int index = 1;

    for (var p in products) {
      final barcode = '"${p.barcode.replaceAll('"', '""')}"';
      final name = '"${p.name.replaceAll('"', '""')}"';
      final recorded = p.stock;
      final counted = countedStock[p.id] ?? recorded;
      final diff = counted - recorded;
      final diffCost = diff * p.costPrice;

      totalDiscrepancyCost += diffCost;
      final status = diff == 0 ? 'مطابق 🟢' : (diff < 0 ? 'عجز ونقص 🚨' : 'زيادة فائض 🟡');

      buffer.writeln('$index,$barcode,$name,$recorded,$counted,$diff,${p.costPrice.toStringAsFixed(2)},${diffCost.toStringAsFixed(2)},$status');
      index++;
    }

    buffer.writeln('------------------------------------------------------------');
    buffer.writeln('صافي الفارق المالي الإجمالي للجرد,,,,,,,${totalDiscrepancyCost.toStringAsFixed(2)} دج,');

    return buffer.toString();
  }

  /// 4. Official Sales & Profit Daily/Monthly Log (سجل المبيعات والأرباح التفصيلي)
  static String exportSalesLogToCsv(List<Map<String, dynamic>> invoices) {
    final buffer = StringBuffer();
    buffer.write(_getOfficialHeader('سجل المبيعات والأرباح التفصيلي'));

    buffer.writeln('رقم الفاتورة,التاريخ والوقت,نوع الدفع,اسم الزبون,عدد السلع,إجمالي الفاتورة (دج),التكلفة (دج),صافي الربح (دج)');

    double totalSales = 0.0;
    double totalProfits = 0.0;

    for (var inv in invoices) {
      final id = inv['id']?.toString() ?? '-';
      final time = inv['timestamp']?.toString() ?? '';
      final isCredit = inv['isCredit'] == true;
      final payMode = isCredit ? 'كريدي (دين)' : 'كاش (نقداً)';
      final customer = '"${(inv['customerName'] ?? '').toString().replaceAll('"', '""')}"';
      final count = inv['itemCount'] ?? 1;
      final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final cost = (inv['totalCost'] as num?)?.toDouble() ?? (total * 0.8);
      final profit = (inv['netProfit'] as num?)?.toDouble() ?? (total - cost);

      totalSales += total;
      totalProfits += profit;

      buffer.writeln('$id,$time,$payMode,$customer,$count,${total.toStringAsFixed(2)},${cost.toStringAsFixed(2)},${profit.toStringAsFixed(2)}');
    }

    buffer.writeln('------------------------------------------------------------');
    buffer.writeln('المجموع الإجمالي,,,,${invoices.length} فاتورة,${totalSales.toStringAsFixed(2)},,${totalProfits.toStringAsFixed(2)}');

    return buffer.toString();
  }
}
