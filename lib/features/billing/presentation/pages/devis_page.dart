import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/billing_bloc.dart';

class DevisPage extends StatefulWidget {
  const DevisPage({super.key});

  @override
  State<DevisPage> createState() => _DevisPageState();
}

class _DevisPageState extends State<DevisPage> {
  List<Map<String, dynamic>> _devisList = [];

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

  void _loadDevis() {
    final box = HiveDatabase.devisBox;
    final List<Map<String, dynamic>> list = [];
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        list.add(Map<String, dynamic>.from(val));
      }
    }
    list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    setState(() {
      _devisList = list;
    });
  }

  void _convertToSale(Map<String, dynamic> devis) {
    final items = (devis['items'] as List?) ?? [];
    if (items.isEmpty) return;

    final billingBloc = context.read<BillingBloc>();
    billingBloc.add(ClearCartEvent());

    for (final it in items) {
      final name = it['name'] as String? ?? 'سلعة';
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final costPrice = (it['costPrice'] as num?)?.toDouble() ?? (price * 0.8);
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;

      for (int i = 0; i < qty; i++) {
        billingBloc.add(AddCustomItemEvent(
          name: name,
          price: price,
          costPrice: costPrice,
          barcode: it['barcode'] as String? ?? 'DEVIS_${DateTime.now().millisecondsSinceEpoch}',
        ));
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم استرجاع عرض الأسعار (${devis['clientName']}) إلى سلة البيع!'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );

    context.go('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض الأسعار والفواتير المبدئية (Devis) 📄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: AppTheme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: _devisList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('لا توجد عروض أسعار أو فواتير مبدئية محفوظة', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 6),
                  const Text('يمكنك حفظ أي سلة كـ Devis من صفحة الدفع', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _devisList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final devis = _devisList[i];
                final client = devis['clientName'] ?? 'زبون عام';
                final total = (devis['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final date = DateTime.tryParse(devis['date'] as String? ?? '') ?? DateTime.now();
                final items = (devis['items'] as List?) ?? [];

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
                                Icon(Icons.person_pin, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 6),
                                Text(client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Devis مبدئي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} أصناف • ${dateFormat.format(date)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي: ${total.toStringAsFixed(0)} دج',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  onPressed: () async {
                                    await HiveDatabase.devisBox.delete(devis['id']);
                                    _loadDevis();
                                  },
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 14),
                                  label: const Text('تحويل لبيع نهائي', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () => _convertToSale(devis),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
