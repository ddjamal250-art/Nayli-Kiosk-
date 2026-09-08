import 'dart:async';
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
  DailyReportPage({super.key});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  // Period filter: 0 = Today, 1 = 7 Days, 2 = 30 Days, 3 = This Month, 4 = All Time
  int _selectedPeriod = 0;
  // Department filter: 0 = Total, 1 = Tobacco (تبغ وسجائر), 2 = General Goods (مواد غذائية وعامة)
  int _reportCategoryTab = 0;
  DateTime _customDate = DateTime.now();
  bool _isPrinting = false;
  Timer? _refreshTimer;
  int _secondsRemaining = 20;
  double _cashFloat = 0.0;

  @override
  void initState() {
    super.initState();
    _startLiveRefreshTimer();
    final box = HiveDatabase.settingsBox;
    _cashFloat = (box.get('daily_cash_float') as num?)?.toDouble() ?? 0.0;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startLiveRefreshTimer() {
    _refreshTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining <= 1) {
            _secondsRemaining = 20;
          } else {
            _secondsRemaining--;
          }
        });
      }
    });
  }

  double _calculateCustomerDebts() {
    double total = 0.0;
    try {
      final box = HiveDatabase.customersBox;
      for (var key in box.keys) {
        final c = box.get(key);
        if (c != null) {
          total += (c.totalDebt as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}
    return total;
  }

  double _calculateSupplierDebts() {
    double total = 0.0;
    try {
      final box = HiveDatabase.supplierInvoicesBox;
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final totalAmount = (val['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final paidAmount = (val['paidAmount'] as num?)?.toDouble() ?? 0.0;
          final remaining = totalAmount - paidAmount;
          if (remaining > 0) total += remaining;
        }
      }
    } catch (_) {}
    return total;
  }

  double _calculateTotalLosses() {
    double total = 0.0;
    try {
      final box = HiveDatabase.lossesBox;
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          if (val['isReimbursable'] != true) {
            final loss = (val['totalLossCost'] as num?)?.toDouble() ?? 0.0;
            total += loss;
          }
        }
      }
    } catch (_) {}
    return total;
  }

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

      double coffeeTeaTotal = 0.0;
      for (final inv in invoices) {
        if (inv['items'] is List) {
          for (final it in inv['items']) {
            if (it is Map) {
              final name = (it['name']?.toString() ?? '').toLowerCase();
              final cat = (it['category']?.toString() ?? '').toLowerCase();
              bool isCoffeeTea = ['قهوة', 'شاي', 'cafe', 'thé', 'tea', 'nescafe'].any((k) => name.contains(k) || cat.contains(k));
              if (isCoffeeTea) {
                coffeeTeaTotal += (it['total'] as num?)?.toDouble() ?? (((it['price'] as num?)?.toDouble() ?? 0.0) * ((it['qty'] as num?)?.toInt() ?? 1));
              }
            }
          }
        }
      }

      final reportItems = [
        {'name': 'Nombre Ventes', 'qty': invoices.length, 'price': '-', 'total': invoices.length},
        {'name': 'Articles Vendu', 'qty': itemsCount, 'price': '-', 'total': itemsCount},
        {'name': 'S/T (Cafe/The)', 'qty': '-', 'price': '-', 'total': '${coffeeTeaTotal.toStringAsFixed(0)} DA'},
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

  void _showCashReconciliationDialog(double expectedCash) {
    final floatController = TextEditingController(text: _cashFloat > 0 ? _cashFloat.toStringAsFixed(0) : '');
    final actualController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.point_of_sale, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('تقفيل لاكيس (الصندوق)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            double actualCash = double.tryParse(actualController.text) ?? 0.0;
            double diff = actualCash - expectedCash;
            bool hasShortage = diff < 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: floatController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الخردة الافتتاحية (الصرف)',
                    hintText: 'كم كان في الصندوق صباحاً؟',
                    prefixText: 'دج ',
                  ),
                  onChanged: (v) {
                    final newFloat = double.tryParse(v) ?? 0.0;
                    HiveDatabase.settingsBox.put('daily_cash_float', newFloat);
                    setState(() => _cashFloat = newFloat);
                    setModalState(() {});
                  },
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المال المفترض:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${expectedCash.toStringAsFixed(0)} دج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: actualController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'المال الحقيقي في الصندوق',
                    hintText: 'احسب النقود وأدخل المبلغ',
                    prefixText: 'دج ',
                  ),
                  onChanged: (v) => setModalState(() {}),
                ),
                if (actualController.text.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasShortage ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: hasShortage ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          hasShortage ? '⚠️ يوجد عجز في الصندوق!' : '✅ يوجد زيادة/تطابق في الصندوق',
                          style: TextStyle(fontWeight: FontWeight.bold, color: hasShortage ? Colors.red : Colors.green),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'الفارق: ${diff.abs().toStringAsFixed(0)} دج',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasShortage ? Colors.red : Colors.green),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _getFilteredInvoices();
    final totalRevenue = invoices.fold<double>(0.0, (sum, inv) => sum + ((inv['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final totalCost = invoices.fold<double>(0.0, (sum, inv) => sum + ((inv['totalCost'] as num?)?.toDouble() ?? 0.0));
    final grossProfit = (totalRevenue - totalCost).clamp(0.0, totalRevenue);
    final expenses = _getFilteredExpenses();
    final netProfit = (grossProfit - expenses);

    // Tobacco vs General Department Financial Separation
    double tobaccoRevenue = 0.0;
    double tobaccoCost = 0.0;
    int tobaccoUnitsCount = 0;

    for (final inv in invoices) {
      if (inv['tobaccoSales'] != null) {
        tobaccoRevenue += (inv['tobaccoSales'] as num).toDouble();
        tobaccoCost += (inv['tobaccoCost'] as num?)?.toDouble() ?? 0.0;
      } else if (inv['items'] is List) {
        final items = inv['items'] as List;
        for (final it in items) {
          if (it is Map) {
            final isTob = it['isTobacco'] == true ||
                (it['name']?.toString().contains('مارلبورو') ?? false) ||
                (it['name']?.toString().contains('وينستون') ?? false) ||
                (it['name']?.toString().contains('ريم') ?? false) ||
                (it['name']?.toString().contains('شمة') ?? false) ||
                (it['name']?.toString().contains('معسل') ?? false) ||
                (it['name']?.toString().contains('ال ام') ?? false) ||
                (it['name']?.toString().contains('L&M') ?? false) ||
                (it['category']?.toString().contains('تبغ') ?? false);
            if (isTob) {
              final itTotal = (it['total'] as num?)?.toDouble() ??
                  (((it['price'] as num?)?.toDouble() ?? 0.0) * ((it['qty'] as num?)?.toInt() ?? 1));
              final itCost = (((it['costPrice'] as num?)?.toDouble() ?? 0.0) * ((it['qty'] as num?)?.toInt() ?? 1));
              tobaccoRevenue += itTotal;
              tobaccoCost += itCost;
              tobaccoUnitsCount += ((it['qty'] as num?)?.toInt() ?? 1);
            }
          }
        }
      }
    }

    final tobaccoProfit = (tobaccoRevenue - tobaccoCost).clamp(0.0, double.infinity);
    final generalRevenue = (totalRevenue - tobaccoRevenue).clamp(0.0, double.infinity);
    final generalCost = (totalCost - tobaccoCost).clamp(0.0, double.infinity);
    final generalProfit = (grossProfit - tobaccoProfit).clamp(0.0, double.infinity);

    final totalItemsCount = invoices.fold<int>(0, (sum, inv) => sum + ((inv['itemCount'] as int?) ?? 1));
    final averageBasket = invoices.isNotEmpty ? (totalRevenue / invoices.length) : 0.0;

    final cashSales = invoices.where((i) => i['isCredit'] != true).fold<double>(0.0, (sum, i) => sum + ((i['paidAmount'] as num?)?.toDouble() ?? (i['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final creditSales = invoices.where((i) => i['isCredit'] == true).fold<double>(0.0, (sum, i) => sum + (((i['totalAmount'] as num?)?.toDouble() ?? 0.0) - ((i['paidAmount'] as num?)?.toDouble() ?? 0.0)));

    final supplierCashOut = _getSupplierPayments();
    final cashIn = cashSales;
    final cashOut = expenses + supplierCashOut;
    final netCashFlow = cashIn - cashOut;

    final stockCapital = _calculateStockCapital();
    final customerDebts = _calculateCustomerDebts();
    final supplierDebts = _calculateSupplierDebts();
    final totalLosses = _calculateTotalLosses();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCashReconciliationDialog(_cashFloat + netCashFlow),
        icon: Icon(Icons.calculate, color: Colors.white),
        label: Text('تقفيل لاكيس', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الداشبورد المالي 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  SizedBox(width: 4),
                  Text('${_secondsRemaining}ث', style: TextStyle(color: Colors.green, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            tooltip: 'تحديث الحسابات والبيانات اللحظية',
            onPressed: () {
              setState(() => _secondsRemaining = 20);
              SoundService.playScanBeep();
              HapticFeedback.lightImpact();
              context.showAppSnackBar('🔄 تم تحديث كافة الحسابات والبيانات اللحظية!');
            },
          ),
          IconButton(
            icon: Icon(Icons.table_chart_outlined, color: Colors.green),
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
            icon: Icon(Icons.receipt_long, color: AppTheme.primaryColor),
            tooltip: 'طباعة تقرير Z',
            onPressed: () => _printZReport(invoices, totalRevenue, grossProfit, expenses, netProfit, totalItemsCount, cashSales, creditSales),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cross-Department Financial Health Overview Grid
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hub_outlined, size: 16, color: AppTheme.primaryColor),
                          SizedBox(width: 6),
                          Text('مؤشرات وحسابات أقسام المتجر (محدثة لحظياً):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _secondsRemaining = 20);
                          SoundService.playScanBeep();
                          HapticFeedback.lightImpact();
                        },
                        child: Row(
                          children: [
                            Icon(Icons.sync, size: 13, color: Colors.grey),
                            SizedBox(width: 2),
                            Text('تحديث ($_secondsRemaining ث)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatTile(
                          icon: Icons.menu_book_rounded,
                          color: Colors.orange[800]!,
                          title: 'ديون الزبائن بالسوق',
                          value: '${customerDebts.toStringAsFixed(0)} دج',
                          onTap: () => context.push('/customers'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatTile(
                          icon: Icons.local_shipping_outlined,
                          color: Colors.deepPurple,
                          title: 'ديون الموردين',
                          value: '${supplierDebts.toStringAsFixed(0)} دج',
                          onTap: () => context.push('/products/supplier-invoices'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatTile(
                          icon: Icons.inventory_2_outlined,
                          color: Colors.teal[700]!,
                          title: 'رأس مال المخزون',
                          value: '${stockCapital.toStringAsFixed(0)} دج',
                          onTap: () => context.push('/products/inventory-audit'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatTile(
                          icon: Icons.remove_shopping_cart_rounded,
                          color: Colors.red[700]!,
                          title: 'خسائر التوالف والكسر',
                          value: '${totalLosses.toStringAsFixed(0)} دج',
                          onTap: () => context.push('/products/losses'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Period Filter Chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: Text('اليوم', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 0,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 0),
                  ),
                  SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('7 أيام', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 1,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 1),
                  ),
                  SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('30 يوم', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 2,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 2),
                  ),
                  SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('هذا الشهر', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 3,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 3),
                  ),
                  SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('الكل', style: TextStyle(fontSize: 12)),
                    selected: _selectedPeriod == 4,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (v) => setState(() => _selectedPeriod = 4),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),

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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 20),
                          SizedBox(width: 8),
                          Text('تاريخ التقرير: ${DateFormat('yyyy/MM/dd').format(_customDate)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Text('تغيير التاريخ ✏️', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),
            ],

            // Department Filter Tabs (الإجمالي الشامل vs قسم التبغ والسجائر vs المواد العامة)
            Container(
              margin: EdgeInsets.only(bottom: 14),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCategoryTabButton(
                      label: 'الإجمالي الشامل 📊',
                      index: 0,
                      badge: '${totalRevenue.toStringAsFixed(0)} دج',
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryTabButton(
                      label: 'قسم التبغ 🚬',
                      index: 1,
                      badge: '${tobaccoRevenue.toStringAsFixed(0)} دج',
                      badgeColor: Colors.amber.shade900,
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryTabButton(
                      label: 'المواد العامة 🛒',
                      index: 2,
                      badge: '${generalRevenue.toStringAsFixed(0)} دج',
                      badgeColor: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // Section 1: Revenue & Profits (2x2 Grid)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _reportCategoryTab == 1
                      ? 'أرباح ومبيعات قسم التبغ والسجائر 🚬'
                      : (_reportCategoryTab == 2 ? 'أرباح ومبيعات المواد الغذائية والعامة 🛒' : 'الإيرادات والأرباح الإجمالية 📈'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (_reportCategoryTab != 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _reportCategoryTab == 1 ? Colors.amber.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _reportCategoryTab == 1
                          ? 'نسبة الأرباح: ${(grossProfit > 0 ? (tobaccoProfit / grossProfit * 100) : 0).toStringAsFixed(1)}%'
                          : 'نسبة الأرباح: ${(grossProfit > 0 ? (generalProfit / grossProfit * 100) : 0).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _reportCategoryTab == 1 ? Colors.amber.shade900 : Colors.blue.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: _reportCategoryTab == 1 ? 'مبيعات التبغ' : (_reportCategoryTab == 2 ? 'مبيعات العامة' : 'صافي الإيرادات'),
                    value: '${(_reportCategoryTab == 1 ? tobaccoRevenue : (_reportCategoryTab == 2 ? generalRevenue : totalRevenue)).toStringAsFixed(0)} دج',
                    icon: Icons.point_of_sale,
                    color: _reportCategoryTab == 1 ? Colors.amber.shade800 : Colors.blue,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: _reportCategoryTab == 1 ? 'تكلفة شراء التبغ' : (_reportCategoryTab == 2 ? 'تكلفة العامة' : 'تكلفة المبيعات'),
                    value: '${(_reportCategoryTab == 1 ? tobaccoCost : (_reportCategoryTab == 2 ? generalCost : totalCost)).toStringAsFixed(0)} دج',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: _reportCategoryTab == 1 ? 'أرباح التبغ (Marge)' : (_reportCategoryTab == 2 ? 'أرباح العامة' : 'إجمالي الربح (Brut)'),
                    value: '+${(_reportCategoryTab == 1 ? tobaccoProfit : (_reportCategoryTab == 2 ? generalProfit : grossProfit)).toStringAsFixed(0)} دج',
                    icon: Icons.trending_up,
                    color: Colors.teal,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    title: _reportCategoryTab == 1 ? 'قطع التبغ المباعة' : (_reportCategoryTab == 2 ? 'سلع عامة مباعة' : 'متوسط السلة (Panier)'),
                    value: _reportCategoryTab == 1
                        ? '$tobaccoUnitsCount علبة/حبة'
                        : (_reportCategoryTab == 2 ? '${totalItemsCount - tobaccoUnitsCount} سلعة' : '${averageBasket.toStringAsFixed(0)} دج'),
                    icon: _reportCategoryTab != 0 ? Icons.inventory : Icons.shopping_basket_outlined,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Net Profit Banner (Final Profit = Gross Profit - Expenses)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _reportCategoryTab == 1
                      ? [Color(0xFFD97706), Color(0xFFB45309)]
                      : (_reportCategoryTab == 2
                          ? [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                          : [Colors.green[700]!, Colors.teal[600]!]),
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _reportCategoryTab == 1
                            ? 'صافي أرباح قسم التبغ والسجائر 🚬'
                            : (_reportCategoryTab == 2 ? 'صافي أرباح المواد الغذائية والعامة 🛒' : 'صافي الربح النهائي الشامل (Net)'),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${(_reportCategoryTab == 1 ? tobaccoProfit : (_reportCategoryTab == 2 ? generalProfit : netProfit)).toStringAsFixed(0)} دج',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _reportCategoryTab == 0
                          ? 'المصاريف: -${expenses.toStringAsFixed(0)} دج'
                          : (_reportCategoryTab == 1
                              ? 'هامش التبغ: ${(tobaccoRevenue > 0 ? (tobaccoProfit / tobaccoRevenue * 100) : 0).toStringAsFixed(1)}%'
                              : 'هامش العامة: ${(generalRevenue > 0 ? (generalProfit / generalRevenue * 100) : 0).toStringAsFixed(1)}%'),
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // If Total View, show the side-by-side Tobacco vs General breakdown card
            if (_reportCategoryTab == 0) ...[
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 16, color: Colors.indigo),
                        SizedBox(width: 6),
                        Text(
                          'توزيع الأرباح بين التبغ والسلع العامة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _reportCategoryTab = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('🚬 التبغ والسجائر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text('${(grossProfit > 0 ? (tobaccoProfit / grossProfit * 100) : 0).toStringAsFixed(0)}%',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 11)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text('مبيعات: ${tobaccoRevenue.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 10, color: Colors.black87)),
                                  Text('ربح: +${tobaccoProfit.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _reportCategoryTab = 2),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('🛒 السلع العامة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text('${(grossProfit > 0 ? (generalProfit / grossProfit * 100) : 0).toStringAsFixed(0)}%',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 11)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text('مبيعات: ${generalRevenue.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 10, color: Colors.black87)),
                                  Text('ربح: +${generalProfit.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 18),

            // Section 2: Cash Flow (التدفق النقدي للكاسة)
            Text('حركة الكاش والصندوق (Cash Flow) 💵', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(14),
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
                          Icon(Icons.arrow_downward, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text('CASH IN (محصل كاش):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('+${cashIn.toStringAsFixed(0)} دج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                    ],
                  ),
                  Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.red, size: 18),
                          SizedBox(width: 6),
                          Text('CASH OUT (مصاريف + موردين):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text('-${cashOut.toStringAsFixed(0)} دج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                    ],
                  ),
                  Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('صافي حركة الدرج (Net Cash):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
            SizedBox(height: 18),

            // Section 3: Shop Capital Valuation
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance, color: Colors.indigo, size: 24),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رأس المال المستثمر في السلع والرفوف', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      SizedBox(height: 2),
                      Text('${stockCapital.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Sales Transactions Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('سجل المبيعات (${invoices.length} عملية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('إجمالي القطع: $totalItemsCount', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            SizedBox(height: 8),

            if (invoices.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('لا توجد مبيعات مسجلة في هذه الفترة', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => SizedBox(height: 8),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'الوقت: $timeStr • ${inv['itemCount'] ?? 1} سلع • فائدة: +${profit.toStringAsFixed(0)} دج',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${total.toStringAsFixed(0)} دج',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
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
                    SizedBox(width: 8),
                    Text('تفاصيل الفاتورة #$invoiceId', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📅 التاريخ: $dateFormatted', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('💳 طريقة الدفع: ${isCredit ? 'كريدي (دين)' : 'كاش (نقداً)'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  if (customerName.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text('👤 الزبون: $customerName', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12),
            Text('🛍️ السلع المشتراة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rawItems.length,
                separatorBuilder: (_, __) => Divider(height: 8),
                itemBuilder: (_, idx) {
                  final it = rawItems[idx] as Map;
                  final name = it['name']?.toString() ?? 'سلعة';
                  final qty = it['quantity'] ?? 1;
                  final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('$name × $qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Text('${(price * qty).toStringAsFixed(0)} دج', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المجموع الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${total.toStringAsFixed(0)} دج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.share, size: 18, color: Colors.green),
                    label: Text('مشاركة واتساب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
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
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.print, size: 18),
                    label: Text('إعادة طباعة الوصل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildCategoryTabButton({required String label, required int index, required String badge, Color? badgeColor}) {
    final isSelected = _reportCategoryTab == index;
    return InkWell(
      onTap: () {
        SoundService.playTabSwitch();
        setState(() => _reportCategoryTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: Offset(0, 2))]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black87 : Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? (badgeColor ?? AppTheme.primaryColor) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: EdgeInsets.all(12),
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
              SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
            ],
          ),
          SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMiniStatTile({required IconData icon, required Color color, required String title, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
