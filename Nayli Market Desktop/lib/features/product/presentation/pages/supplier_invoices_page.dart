import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';

class SupplierInvoicesPage extends StatefulWidget {
  const SupplierInvoicesPage({super.key});

  @override
  State<SupplierInvoicesPage> createState() => _SupplierInvoicesPageState();
}

class _SupplierInvoicesPageState extends State<SupplierInvoicesPage> {
  List<Map<String, dynamic>> _invoices = [];
  double _totalPurchases = 0.0;
  double _totalDebts = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  void _loadInvoices() {
    final box = HiveDatabase.supplierInvoicesBox;
    final List<Map<String, dynamic>> list = [];
    double totalP = 0.0;
    double totalD = 0.0;

    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        list.add(map);
        totalP += (map['totalCost'] as num?)?.toDouble() ?? 0.0;
        totalD += (map['remainingDebt'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // Sort newest first
    list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    setState(() {
      _invoices = list;
      _totalPurchases = totalP;
      _totalDebts = totalD;
    });
  }

  void _showSettleDebtDialog(Map<String, dynamic> invoice) async {
    final remaining = (invoice['remainingDebt'] as num?)?.toDouble() ?? 0.0;
    if (remaining <= 0) return;

    final auth = await SecurityPinHelper.authenticate(context, title: 'تسديد دين للمورد');
    if (!auth || !mounted) return;

    final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسديد دين للمورد: ${invoice['supplierName']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الفاتورة: ${invoice['invoiceNumber']}'),
            const SizedBox(height: 4),
            Text('الدين المتبقي: ${remaining.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المسدد الآن (دج)',
                suffixText: 'دج',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final paid = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (paid <= 0) return;

              final newDebt = (remaining - paid).clamp(0.0, remaining);
              final currentPaid = (invoice['paidAmount'] as num?)?.toDouble() ?? 0.0;

              invoice['paidAmount'] = currentPaid + paid;
              invoice['remainingDebt'] = newDebt;
              invoice['paymentMode'] = newDebt == 0 ? 'cash' : 'partial';

              await HiveDatabase.supplierInvoicesBox.put(invoice['id'], invoice);
              _loadInvoices();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('تأكيد التسديد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل مشتريات الموردين 🚚', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فاتورة مورد جديدة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final auth = await SecurityPinHelper.authenticate(context, title: 'إنشاء فاتورة مورد جديدة');
          if (auth && mounted) {
            await context.push('/products/supplier-invoice/new');
            _loadInvoices();
          }
        },
      ),
      body: Column(
        children: [
          // Financial Summary Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي المشتريات', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 4),
                        Text('${_totalPurchases.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ديون الموردين المستحقة', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                        const SizedBox(height: 4),
                        Text('${_totalDebts.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Invoices List
          Expanded(
            child: _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('لا توجد فواتير موردين مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final inv = _invoices[i];
                      final remainingDebt = (inv['remainingDebt'] as num?)?.toDouble() ?? 0.0;
                      final totalCost = (inv['totalCost'] as num?)?.toDouble() ?? 0.0;
                      final date = DateTime.tryParse(inv['date'] as String? ?? '') ?? DateTime.now();

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.business, color: AppTheme.primaryColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(inv['supplierName'] ?? 'مورد', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: remainingDebt == 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      remainingDebt == 0 ? 'خالصة (كاش)' : 'باقي دين: ${remainingDebt.toStringAsFixed(0)} دج',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: remainingDebt == 0 ? Colors.green[800] : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('رقم: ${inv['invoiceNumber']} | ${inv['itemCount'] ?? 0} أصناف (${inv['totalUnits'] ?? 0} حبة)',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(dateFormat.format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('إجمالي الفاتورة: ${totalCost.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (remainingDebt > 0)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _showSettleDebtDialog(inv),
                                      child: const Text('تسديد دين', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
