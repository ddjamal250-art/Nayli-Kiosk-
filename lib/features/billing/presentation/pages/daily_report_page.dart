import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/excel_export_helper.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/localization/app_localizations.dart';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  // Period filter: 0 = Today, 1 = 7 Days, 2 = 30 Days, 3 = This Month, 4 = All Time
  int _selectedPeriod = 0;
  DateTime _customDate = DateTime.now();
  bool _isPrinting = false;

  List<Map<String, dynamic>> _getFilteredInvoices() {
    final box = HiveDatabase.invoicesBox;
    final List<Map<String, dynamic>> list = [];
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(_customDate);

    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        final timestamp = map['timestamp'] as String?;
        if (timestamp == null) continue;

        final invDate = DateTime.tryParse(timestamp) ?? now;

        if (_selectedPeriod == 0) {
          // Single day (Selected Date)
          if (timestamp.startsWith(todayStr)) {
            list.add(map);
          }
        } else if (_selectedPeriod == 1) {
          // Last 7 days
          if (now.difference(invDate).inDays <= 7) {
            list.add(map);
          }
        } else if (_selectedPeriod == 2) {
          // Last 30 days
          if (now.difference(invDate).inDays <= 30) {
            list.add(map);
          }
        } else if (_selectedPeriod == 3) {
          // This Month
          if (invDate.year == now.year && invDate.month == now.month) {
            list.add(map);
          }
        } else {
          // All Time
          list.add(map);
        }
      }
    }

    list.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return list;
  }

  double _getFilteredExpenses() {
    final box = HiveDatabase.expensesBox;
    double total = 0.0;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(_customDate);

    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        final dateStr = map['date'] as String?;
        final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
        if (dateStr == null) continue;

        final expDate = DateTime.tryParse(dateStr) ?? now;

        if (_selectedPeriod == 0) {
          if (dateStr.startsWith(todayStr)) total += amount;
        } else if (_selectedPeriod == 1) {
          if (now.difference(expDate).inDays <= 7) total += amount;
        } else if (_selectedPeriod == 2) {
          if (now.difference(expDate).inDays <= 30) total += amount;
        } else if (_selectedPeriod == 3) {
          if (expDate.year == now.year && expDate.month == now.month) total += amount;
        } else {
          total += amount;
        }
      }
    }
    return total;
  }

  double _getSupplierPayments() {
    final box = HiveDatabase.supplierInvoicesBox;
    double total = 0.0;
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        final paid = (map['paidAmount'] as num?)?.toDouble() ?? 0.0;
        total += paid;
      }
    }
    return total;
  }

  double _calculateStockCapital() {
    final box = HiveDatabase.productBox;
    double capital = 0.0;
    for (var key in box.keys) {
      final p = box.get(key);
      if (p != null) {
        capital += (p.stock * p.costPrice);
      }
    }
    return capital;
  }

  Future<void> _printZReport(List<Map<String, dynamic>> invoices, double revenue, double grossProfit, double expenses, double netProfit, int itemsCount, double cashTotal, double creditTotal) async {
    final printer = PrinterHelper();
    if (!printer.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printer.connect(savedMac);
        if (!connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('disconnected')), backgroundColor: Colors.red),
          );
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('disconnected')), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isPrinting = true);
    try {
      final dateFormatted = DateFormat('dd/MM/yyyy').format(_customDate);
      final reportItems = [
        {'name': 'Nombre Ventes', 'qty': invoices.length, 'price': '-', 'total': invoices.length},
        {'name': 'Articles Vendu', 'qty': itemsCount, 'price': '-', 'total': itemsCount},
        {'name': 'Ventes Cash', 'qty': '-', 'price': '-', 'total': '${cashTotal.toStringAsFixed(0)} DA'},
        {'name': 'Ventes Credit', 'qty': '-', 'price': '-', 'total': '${creditTotal.toStringAsFixed(0)} DA'},
        {'name': 'Benefice Brut', 'qty': '-', 'price': '-', 'total': '${grossProfit.toStringAsFixed(0)} DA'},
        {'name': 'Depenses', 'qty': '-', 'price': '-', 'total': '${expenses.toStringAsFixed(0)} DA'},
        {'name': 'Benefice Net', 'qty': '-', 'price': '-', 'total': '${netProfit.toStringAsFixed(0)} DA'},
      ];

      await printer.printReceipt(
        shopName: 'RAPPORT Z - CLOTURE',
        address1: '${context.tr('date')}: $dateFormatted',
        address2: DateFormat('HH:mm').format(DateTime.now()),
        phone: '',
        items: reportItems,
        total: revenue,
        footer: '--- CLOTURE DE CAISSE NAYLI ---',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('report_printed')), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _getFilteredInvoices();
    final totalRevenue = invoices.fold<double>(0.0, (sum, inv) => sum + ((inv['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final totalCost = invoices.fold<double>(0.0, (sum, inv) => sum + ((inv['totalCost'] as num?)?.toDouble() ?? 0.0));
    final grossProfit = (totalRevenue - totalCost).clamp(0.0, totalRevenue);
    final expenses = _getFilteredExpenses();
    final netProfit = (grossProfit - expenses);

    final totalItemsCount = invoices.fold<int>(0, (sum, inv) => sum + ((inv['itemCount'] as int?) ?? 1));
    final averageBasket = invoices.isNotEmpty ? (totalRevenue / invoices.length) : 0.0;

    final cashSales = invoices.where((i) => i['isCredit'] != true).fold<double>(0.0, (sum, i) => sum + ((i['paidAmount'] as num?)?.toDouble() ?? (i['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final creditSales = invoices.where((i) => i['isCredit'] == true).fold<double>(0.0, (sum, i) => sum + (((i['totalAmount'] as num?)?.toDouble() ?? 0.0) - ((i['paidAmount'] as num?)?.toDouble() ?? 0.0)));

    final supplierCashOut = _getSupplierPayments();
    final cashIn = cashSales;
    final cashOut = expenses + supplierCashOut;
    final netCashFlow = cashIn - cashOut;

    final stockCapital = _calculateStockCapital();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الداشبورد المالي والتقارير 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            tooltip: 'تصدير جدول المبيعات كـ Excel',
            onPressed: () {
              final csvData = ExcelExportHelper.exportSalesLogToCsv(invoices);
              Clipboard.setData(ClipboardData(text: csvData));
              SoundService.playCheckoutSuccess();
              context.showAppSnackBar(
                '📊 تم نسخ بيانات المبيعات والأرباح الرسمية بتنسيق Excel بنجاح!',
                backgroundColor: Colors.green[800]!,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
            tooltip: 'طباعة تقرير Z',
            onPressed: () => _printZReport(invoices, totalRevenue, grossProfit, expenses, netProfit, totalItemsCount, cashSales, creditSales),
          ),
          IconButton(
            icon: const Icon(Icons.payments_outlined, color: Colors.orange),
            tooltip: 'مصاريف المحل',
            onPressed: () async {
              await context.push('/expenses');
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period Filter Chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('اليوم', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 0,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 0),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('7 أيام', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 1,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 1),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('30 يوم', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 2,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 2),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('هذا الشهر', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 3,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 3),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('الكل', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 4,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date Picker Banner if Today mode
            if (_selectedPeriod == 0) ...[
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _customDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _customDate = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text('تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(_customDate)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Text('تغيير التاريخ ✏️', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Section 1: Revenue & Profits (2x2 Grid)
            const Text('الإيرادات والأرباح 📈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'صافي الإيرادات',
                    value: '${totalRevenue.toStringAsFixed(0)} دج',
                    icon: Icons.point_of_sale,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'تكلفة المبيعات',
                    value: '${totalCost.toStringAsFixed(0)} دج',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'إجمالي الربح (Brut)',
                    value: '+${grossProfit.toStringAsFixed(0)} دج',
                    icon: Icons.trending_up,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: 'متوسط السلة (Panier)',
                    value: '${averageBasket.toStringAsFixed(0)} دج',
                    icon: Icons.shopping_basket_outlined,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Net Profit Banner (Final Profit = Gross Profit - Expenses)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.teal[600]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صافي الربح النهائي (Net)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${netProfit.toStringAsFixed(0)} دج',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'المصاريف: -${expenses.toStringAsFixed(0)} دج',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 2: Cash Flow (التدفق النقدي للكاسة)
            const Text('حركة الكاش والصندوق (Cash Flow) 💵', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          const Text('CASH IN (محصل كاش):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('+${cashIn.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward, color: Colors.red, size: 18),
                          const SizedBox(width: 6),
                          const Text('CASH OUT (مصاريف + موردين):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('-${cashOut.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('صافي حركة الدرج (Net Cash):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(
                        '${netCashFlow >= 0 ? '+' : ''}${netCashFlow.toStringAsFixed(0)} دج',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: netCashFlow >= 0 ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 3: Shop Capital Valuation
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.indigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رأس المال المستثمر في السلع والرفوف', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('${stockCapital.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sales Transactions Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('سجل المبيعات (${invoices.length} عملية)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('إجمالي القطع: $totalItemsCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),

            if (invoices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('لا توجد مبيعات مسجلة في هذه الفترة', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final inv = invoices[i];
                  final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
                  final profit = (inv['netProfit'] as num?)?.toDouble() ?? (total * 0.2);
                  final isCredit = inv['isCredit'] == true;
                  final timeStr = (inv['timestamp'] as String? ?? '').split('T').lastOrNull?.substring(0, 5) ?? '';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => _showInvoiceDetailsModal(inv),
                      leading: CircleAvatar(
                        backgroundColor: isCredit ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        child: Icon(isCredit ? Icons.credit_card : Icons.receipt, color: isCredit ? Colors.red : Colors.green, size: 20),
                      ),
                      title: Text(
                        'فاتورة #${inv['id'] ?? (i + 1)} ${isCredit ? '(كريدي)' : '(كاش)'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'الوقت: $timeStr • ${inv['itemCount'] ?? 1} سلع • فائدة: +${profit.toStringAsFixed(0)} دج',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${total.toStringAsFixed(0)} دج',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceDetailsModal(Map<String, dynamic> inv) {
    final invoiceId = inv['id']?.toString() ?? '1';
    final timestamp = inv['timestamp'] as String? ?? '';
    final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final isCredit = inv['isCredit'] == true;
    final customerName = inv['customerName']?.toString() ?? '';
    final rawItems = inv['items'] as List? ?? [];

    final dateFormatted = timestamp.isNotEmpty
        ? DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.tryParse(timestamp) ?? DateTime.now())
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isCredit ? Icons.credit_card : Icons.receipt_long, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('تفاصيل الفاتورة #$invoiceId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 التاريخ: $dateFormatted', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('💳 طريقة الدفع: ${isCredit ? 'كريدي (دين)' : 'كاش (نقداً)'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  if (customerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('👤 الزبون: $customerName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('🛍️ السلع المشتراة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rawItems.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (_, idx) {
                  final it = rawItems[idx] as Map;
                  final name = it['name']?.toString() ?? 'سلعة';
                  final qty = it['quantity'] ?? 1;
                  final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('$name × $qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Text('${(price * qty).toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${total.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share, size: 18, color: Colors.green),
                    label: const Text('مشاركة واتساب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    onPressed: () {
                      final buffer = StringBuffer();
                      buffer.writeln('🧾 *فاتورة مشتريات #$invoiceId*');
                      buffer.writeln('📅 التاريخ: $dateFormatted');
                      if (customerName.isNotEmpty) buffer.writeln('👤 الزبون: $customerName');
                      buffer.writeln('---------------------------');
                      for (var it in rawItems) {
                        final itMap = it as Map;
                        final pPrice = (itMap['price'] as num?)?.toDouble() ?? 0.0;
                        final pQty = (itMap['quantity'] as num?)?.toInt() ?? 1;
                        buffer.writeln('• ${itMap['name']} × $pQty = ${(pPrice * pQty).toStringAsFixed(0)} دج');
                      }
                      buffer.writeln('---------------------------');
                      buffer.writeln('💰 *المجموع:* ${total.toStringAsFixed(0)} دج');
                      buffer.writeln('✨ شكراً لتعاملكم معنا!');

                      Clipboard.setData(ClipboardData(text: buffer.toString()));
                      Navigator.pop(ctx);
                      context.showAppSnackBar('📋 تم نسخ نص الفاتورة لمشاركتها عبر واتساب!', backgroundColor: Colors.teal[800]!);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('إعادة طباعة الوصل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final printer = PrinterHelper();
                      final printItems = rawItems.map((it) {
                        final itMap = it as Map;
                        final price = (itMap['price'] as num?)?.toDouble() ?? 0.0;
                        final qty = (itMap['quantity'] as num?)?.toInt() ?? 1;
                        return {
                          'name': itMap['name']?.toString() ?? 'سلعة',
                          'qty': qty,
                          'price': price,
                          'total': price * qty,
                        };
                      }).toList();

                      await printer.printReceipt(
                        shopName: 'RECU DE VENTE (DUPLICATA)',
                        address1: 'Facture #$invoiceId',
                        address2: dateFormatted,
                        phone: '',
                        items: printItems,
                        total: total,
                        footer: '--- MERCI POUR VOTRE VISITE ---',
                      );
                      if (context.mounted) {
                        context.showAppSnackBar('✅ تم إرسال أمر إعادة طباعة الوصل!', backgroundColor: Colors.green[800]!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
