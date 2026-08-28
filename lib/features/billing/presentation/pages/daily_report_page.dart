import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/localization/app_localizations.dart';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});

  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isPrinting = false;

  List<Map<String, dynamic>> _getInvoicesForDate(DateTime date) {
    final box = HiveDatabase.invoicesBox;
    final List<Map<String, dynamic>> dailyInvoices = [];
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        final timestamp = map['timestamp'] as String?;
        if (timestamp != null && timestamp.startsWith(dateStr)) {
          dailyInvoices.add(map);
        }
      }
    }

    dailyInvoices.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    return dailyInvoices;
  }

  Future<void> _printZReport(List<Map<String, dynamic>> invoices, double totalRevenue, int totalItems) async {
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
      final dateFormatted = DateFormat('dd/MM/yyyy').format(_selectedDate);
      final reportItems = [
        {'name': context.tr('invoices_count'), 'qty': invoices.length, 'price': '-', 'total': invoices.length},
        {'name': context.tr('items_sold'), 'qty': totalItems, 'price': '-', 'total': totalItems},
      ];

      await printer.printReceipt(
        shopName: context.tr('z_report_header'),
        address1: '${context.tr('date')}: $dateFormatted',
        address2: DateFormat('HH:mm').format(DateTime.now()),
        phone: '',
        items: reportItems,
        total: totalRevenue,
        footer: '---',
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
    final invoices = _getInvoicesForDate(_selectedDate);
    final totalRevenue = invoices.fold<double>(0.0, (sum, inv) => sum + ((inv['totalAmount'] as num?)?.toDouble() ?? 0.0));
    final totalItems = invoices.fold<int>(0, (sum, inv) => sum + ((inv['itemCount'] as num?)?.toInt() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('report_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr('date')}: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(context.tr('change_date')),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                )
              ],
            ),
          ),

          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: context.tr('total_revenue'),
                    value: '${totalRevenue.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                    icon: Icons.monetization_on_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: context.tr('invoices_count'),
                    value: '${invoices.length}',
                    icon: Icons.receipt_long,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Invoices List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Directionality.of(context) == TextDirection.rtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                '${context.tr('today_invoices')} (${invoices.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
              ),
            ),
          ),

          Expanded(
            child: invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(context.tr('no_invoices'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inv = invoices[index];
                      final timeStr = inv['timestamp'] != null
                          ? DateFormat('HH:mm').format(DateTime.parse(inv['timestamp']))
                          : '';
                      final amt = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
                      final count = (inv['itemCount'] as num?)?.toInt() ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${context.tr('today_invoices')} #${index + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('$timeStr • $count ${context.tr('items_count')}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                            Text(
                              '${amt.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Print Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              onPressed: invoices.isEmpty ? null : () => _printZReport(invoices, totalRevenue, totalItems),
              icon: Icons.print,
              label: context.tr('print_z_report'),
              isLoading: _isPrinting,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
