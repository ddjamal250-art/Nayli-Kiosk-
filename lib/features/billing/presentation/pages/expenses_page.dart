import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> _expenses = [];
  double _todayExpenses = 0.0;
  double _monthExpenses = 0.0;

  final List<String> _categories = [
    'كراء المحل 🏢',
    'كهرباء وغاز 💡',
    'أجور عمال 👷',
    'نقل وتوصيل 🚚',
    'وجبات وضيافة ☕',
    'صيانة ومستلزمات 🛠️',
    'مصاريف عامة 📝',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    final box = HiveDatabase.expensesBox;
    final List<Map<String, dynamic>> list = [];
    final now = DateTime.now();
    double todayTotal = 0.0;
    double monthTotal = 0.0;

    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        list.add(map);

        final date = DateTime.tryParse(map['date'] as String? ?? '') ?? now;
        final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;

        if (date.year == now.year && date.month == now.month) {
          monthTotal += amount;
          if (date.day == now.day) {
            todayTotal += amount;
          }
        }
      }
    }

    list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    setState(() {
      _expenses = list;
      _todayExpenses = todayTotal;
      _monthExpenses = monthTotal;
    });
  }

  void _showAddExpenseDialog() async {
    final auth = await SecurityPinHelper.authenticate(context, title: 'تسجيل مصروف من الكاسة');
    if (!auth || !mounted) return;

    final titleCtrl = TextEditingController(text: 'مصاريف عامة');
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = _categories.first;
    DateTime expenseDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('➕ تسجيل مصاريف جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع المصروف / التصنيف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selectedCategory = v;
                        titleCtrl.text = v.split(' ').first;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع (دج)',
                    suffixText: 'دج',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'بيان المصروف (مثال: فاتورة سونلغاز)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة إضافية (اختياري)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                final id = const Uuid().v4();
                await HiveDatabase.expensesBox.put(id, {
                  'id': id,
                  'title': titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim(),
                  'category': selectedCategory,
                  'amount': amount,
                  'date': expenseDate.toIso8601String(),
                  'notes': noteCtrl.text.trim(),
                });

                _loadExpenses();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ المصروف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('مصاريف ونفقات المحل 🧾', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('تسجيل مصروف', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: _showAddExpenseDialog,
      ),
      body: Column(
        children: [
          // Header summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مصاريف اليوم', style: TextStyle(fontSize: 11, color: Colors.brown)),
                        const SizedBox(height: 4),
                        Text('${_todayExpenses.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[900])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purple.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي مصاريف الشهر', style: TextStyle(fontSize: 11, color: Colors.purple)),
                        const SizedBox(height: 4),
                        Text('${_monthExpenses.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of Expenses
          Expanded(
            child: _expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('لا توجد مصاريف مسجلة حتى الآن', style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _expenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final exp = _expenses[i];
                      final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
                      final date = DateTime.tryParse(exp['date'] as String? ?? '') ?? DateTime.now();

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withOpacity(0.12),
                            child: const Icon(Icons.outbox, color: Colors.orange),
                          ),
                          title: Text(exp['title'] ?? exp['category'] ?? 'مصروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${exp['category']} • ${dateFormat.format(date)}${exp['notes'] != null && (exp['notes'] as String).isNotEmpty ? '\nملاحظة: ${exp['notes']}' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('-${amount.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                onPressed: () async {
                                  await HiveDatabase.expensesBox.delete(exp['id']);
                                  _loadExpenses();
                                },
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
