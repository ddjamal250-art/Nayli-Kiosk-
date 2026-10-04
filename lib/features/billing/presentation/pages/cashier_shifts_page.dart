import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/printer_helper.dart';

class CashierShiftsPage extends StatefulWidget {
  const CashierShiftsPage({super.key});

  @override
  State<CashierShiftsPage> createState() => _CashierShiftsPageState();
}

class _CashierShiftsPageState extends State<CashierShiftsPage> {
  Map<String, dynamic>? _activeShift;
  List<Map<String, dynamic>> _pastShifts = [];

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() {
    final box = HiveDatabase.shiftsBox;
    final List<Map<String, dynamic>> past = [];
    Map<String, dynamic>? active;

    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        if (map['isClosed'] == false) {
          active = map;
        } else {
          past.add(map);
        }
      }
    }

    past.sort((a, b) => (b['openedAt'] as String).compareTo(a['openedAt'] as String));

    setState(() {
      _activeShift = active;
      _pastShifts = past;
    });
  }

  void _openShiftDialog() {
    final cashCtrl = TextEditingController(text: '5000');
    final cashierNameCtrl = TextEditingController(text: 'الكاشير 1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.green),
            SizedBox(width: 8),
            Text('بدء مناوبة جديدة (فتح الصندوق)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: cashierNameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الكاشير / البائع', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'رصيد بداية الصندوق (عهدة البداية)',
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
              final initial = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
              final shiftId = const Uuid().v4();
              final newShift = {
                'id': shiftId,
                'cashierName': cashierNameCtrl.text.trim().isEmpty ? 'كاشير' : cashierNameCtrl.text.trim(),
                'openedAt': DateTime.now().toIso8601String(),
                'closedAt': null,
                'initialCash': initial,
                'expectedCash': initial,
                'actualCash': null,
                'difference': 0.0,
                'isClosed': false,
              };

              await HiveDatabase.shiftsBox.put(shiftId, newShift);
              _loadShifts();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('فتح المناوبة الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _closeShiftDialog() {
    if (_activeShift == null) return;
    final initialCash = (_activeShift!['initialCash'] as num?)?.toDouble() ?? 0.0;
    final openedAt = DateTime.tryParse(_activeShift!['openedAt'] as String? ?? '') ?? DateTime.now();

    // Calculate sales cash and expenses since openedAt
    double cashSales = 0.0;
    final invBox = HiveDatabase.invoicesBox;
    for (final key in invBox.keys) {
      final inv = invBox.get(key);
      if (inv is Map) {
        final ts = DateTime.tryParse(inv['timestamp'] as String? ?? '');
        if (ts != null && ts.isAfter(openedAt)) {
          if (inv['isCredit'] != true) {
            cashSales += (inv['paidAmount'] as num?)?.toDouble() ?? (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    double shiftExpenses = 0.0;
    final expBox = HiveDatabase.expensesBox;
    for (final key in expBox.keys) {
      final exp = expBox.get(key);
      if (exp is Map) {
        final d = DateTime.tryParse(exp['date'] as String? ?? '');
        if (d != null && d.isAfter(openedAt)) {
          shiftExpenses += (exp['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    final expectedCash = initialCash + cashSales - shiftExpenses;
    final actualCtrl = TextEditingController(text: expectedCash.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentEntered = double.tryParse(actualCtrl.text.trim()) ?? 0.0;
          final diff = currentEntered - expectedCash;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock, color: Colors.red),
                SizedBox(width: 8),
                Text('إغلاق المناوبة وجرد الصندوق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رصيد البداية: ${initialCash.toStringAsFixed(0)} دج'),
                  Text('مبيعات الكاش (+): ${cashSales.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.green)),
                  Text('المصاريف (-): ${shiftExpenses.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.red)),
                  const Divider(height: 12),
                  Text('المبلغ المتوقع في الدرج: ${expectedCash.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: actualCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الفعلي الموجود في الدرج',
                      suffixText: 'دج',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: diff == 0 ? Colors.green.withOpacity(0.1) : (diff > 0 ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('فارق الصندوق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(
                          diff == 0 ? '✅ مطابق تماماً (0 دج)' : (diff > 0 ? '📈 زيادة: +${diff.toStringAsFixed(0)} دج' : '⚠️ عجز: ${diff.toStringAsFixed(0)} دج'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: diff == 0 ? Colors.green[800] : (diff > 0 ? Colors.blue[800] : Colors.red[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final actual = double.tryParse(actualCtrl.text.trim()) ?? expectedCash;
                  final difference = actual - expectedCash;

                  _activeShift!['closedAt'] = DateTime.now().toIso8601String();
                  _activeShift!['expectedCash'] = expectedCash;
                  _activeShift!['actualCash'] = actual;
                  _activeShift!['difference'] = difference;
                  _activeShift!['isClosed'] = true;

                  await HiveDatabase.shiftsBox.put(_activeShift!['id'], _activeShift!);
                  _loadShifts();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('تأكيد إغلاق المناوبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    double shiftCashSales = 0.0;
    double shiftExpenses = 0.0;
    if (_activeShift != null) {
      final openedAtStr = _activeShift!['openedAt'] as String? ?? '';
      final openedAt = DateTime.tryParse(openedAtStr) ?? DateTime.now();

      final invoicesBox = HiveDatabase.invoicesBox;
      for (final key in invoicesBox.keys) {
        final val = invoicesBox.get(key);
        if (val is Map) {
          final ts = val['timestamp'] as String?;
          final isCredit = val['isCredit'] == true;
          if (ts != null) {
            final invDate = DateTime.tryParse(ts);
            if (invDate != null && invDate.isAfter(openedAt) && !isCredit) {
              final paid = (val['paidAmount'] as num?)?.toDouble() ?? (val['totalAmount'] as num?)?.toDouble() ?? 0.0;
              shiftCashSales += paid;
            }
          }
        }
      }

      final expBox = HiveDatabase.expensesBox;
      for (final key in expBox.keys) {
        final val = expBox.get(key);
        if (val is Map) {
          final d = val['date'] as String?;
          if (d != null) {
            final expDate = DateTime.tryParse(d);
            if (expDate != null && expDate.isAfter(openedAt)) {
              shiftExpenses += (val['amount'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
      }
    }
    final initialCash = ((_activeShift?['initialCash'] as num?)?.toDouble() ?? 0.0);
    final totalExpectedInDrawer = initialCash + shiftCashSales - shiftExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مناوبات الكاسة والصندوق 💼', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active Shift Card & Live Caisse Balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _activeShift != null ? const Color(0xFF0F172A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
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
                          Icon(_activeShift != null ? Icons.lock_open : Icons.lock, color: _activeShift != null ? Colors.greenAccent : Colors.grey, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _activeShift != null ? 'المناوبة الحالية (مفتوحة 🟢)' : 'لا توجد مناوبة مفتوحة حالياً 🔒',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _activeShift != null ? Colors.white : Colors.black87),
                          ),
                        ],
                      ),
                      if (_activeShift != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.greenAccent),
                          ),
                          child: Text(_activeShift!['cashierName'] ?? 'كاشير', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (_activeShift != null) ...[
                    const SizedBox(height: 14),
                    // Live PreonCom Inspired 3-Card Caisse View
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF166534), Color(0xFF15803D)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📥 مقبوضات (Entrées)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                const SizedBox(height: 3),
                                Text('+${shiftCashSales.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF991B1B), Color(0xFFB91C1C)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📤 المصاريف والنفقات', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                const SizedBox(height: 3),
                                Text('-${shiftExpenses.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF2563EB)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💰 رصيد الدرج الإجمالي (Fond + Ventes):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('${totalExpectedInDrawer.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('بداية: ${initialCash.toStringAsFixed(0)} دج', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('إغلاق المناوبة وجرد الصندوق (Clôture)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _closeShiftDialog,
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('بدء مناوبة جديدة (فتح الصندوق)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _openShiftDialog,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Past Shifts History
            const Text('سجل المناوبات السابقة 📜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),

            if (_pastShifts.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: const Text('لا توجد مناوبات مغلقة سابقة', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pastShifts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final shift = _pastShifts[i];
                  final initial = (shift['initialCash'] as num?)?.toDouble() ?? 0.0;
                  final actual = (shift['actualCash'] as num?)?.toDouble() ?? 0.0;
                  final diff = (shift['difference'] as num?)?.toDouble() ?? 0.0;
                  final openedAt = DateTime.tryParse(shift['openedAt'] as String? ?? '') ?? DateTime.now();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: diff == 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        child: Icon(diff == 0 ? Icons.check_circle : Icons.warning_amber, color: diff == 0 ? Colors.green : Colors.red, size: 20),
                      ),
                      title: Text('${shift['cashierName'] ?? 'كاشير'} • Fond: ${initial.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        '${dateFormat.format(openedAt)}\nالموجود: ${actual.toStringAsFixed(0)} دج | الفارق: ${diff == 0 ? '0 دج' : '${diff.toStringAsFixed(0)} دج'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: diff == 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          diff == 0 ? 'مطابق' : (diff > 0 ? '+$diff' : '$diff'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diff == 0 ? Colors.green[800] : Colors.red[800]),
                        ),
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
}
