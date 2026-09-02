import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductLossItem {
  final String id;
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final double costPrice;
  final double totalLossCost;
  final String reason;
  final String notes;
  final bool isReimbursable;
  final String supplierName;
  final DateTime date;

  ProductLossItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.costPrice,
    required this.totalLossCost,
    required this.reason,
    required this.notes,
    this.isReimbursable = false,
    this.supplierName = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'barcode': barcode,
        'quantity': quantity,
        'costPrice': costPrice,
        'totalLossCost': totalLossCost,
        'reason': reason,
        'notes': notes,
        'isReimbursable': isReimbursable,
        'supplierName': supplierName,
        'date': date.toIso8601String(),
      };

  factory ProductLossItem.fromMap(Map<dynamic, dynamic> map) => ProductLossItem(
        id: map['id'] as String? ?? '',
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? 'سلعة تالفة',
        barcode: map['barcode'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
        totalLossCost: (map['totalLossCost'] as num?)?.toDouble() ?? 0.0,
        reason: map['reason'] as String? ?? 'تلف / كسر',
        notes: map['notes'] as String? ?? '',
        isReimbursable: map['isReimbursable'] == true,
        supplierName: map['supplierName'] as String? ?? '',
        date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
      );
}

class LossesPage extends StatefulWidget {
  const LossesPage({super.key});

  @override
  State<LossesPage> createState() => _LossesPageState();
}

class _LossesPageState extends State<LossesPage> {
  List<ProductLossItem> _losses = [];
  String _selectedReasonFilter = 'الكل';

  static const List<String> lossReasons = [
    '⏳ انتهاء الصلاحية (Périmé)',
    '💥 كسر وأضرار بالمحل (Casse / Bris)',
    '🍂 تلف وفساد السلعة (Avarie / Dégradation)',
    '☕ استهلاك داخلي للمحل والعمال (Consommation Interne)',
    '🎁 عينات تذوق وتوزيع ترويجي (Dégustation / Offert)',
    '📉 عجز جرد مفقود (Coulage / Écart d\'Inventaire)',
    '🔄 إرجاع وتعويض من المورد (Retour Fournisseur / Avoir)',
    'سبب آخر (Autre)',
  ];

  @override
  void initState() {
    super.initState();
    _loadLosses();
  }

  void _loadLosses() {
    final box = HiveDatabase.lossesBox;
    final list = <ProductLossItem>[];
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        list.add(ProductLossItem.fromMap(val));
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    setState(() => _losses = list);
  }

  Future<void> _recordNewLoss(
    Product product,
    int quantity,
    String reason,
    String notes,
    bool isReimbursable,
    String supplierName,
  ) async {
    final lossCost = quantity * product.costPrice;
    final loss = ProductLossItem(
      id: 'loss_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      productName: product.name,
      barcode: product.barcode,
      quantity: quantity,
      costPrice: product.costPrice,
      totalLossCost: lossCost,
      reason: reason,
      notes: notes,
      isReimbursable: isReimbursable,
      supplierName: supplierName,
      date: DateTime.now(),
    );

    await HiveDatabase.lossesBox.put(loss.id, loss.toMap());

    if (mounted) {
      final updatedStock = (product.stock - quantity).clamp(0, 999999);
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        price: product.price,
        costPrice: product.costPrice,
        stock: updatedStock,
      );
      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
    }

    _loadLosses();
    SoundService.playDeleteSound();
    if (mounted) {
      context.showAppSnackBar(
        isReimbursable
            ? '🔄 تم تسجيل إرجاع $quantity قطعة إلى المورد ($supplierName) بدون خسارة على المتجر!'
            : '🗑️ تم تسجيل إتلاف $quantity قطعة من ${product.name} وخصمها من المخزون!',
        backgroundColor: isReimbursable ? Colors.indigo[800]! : Colors.red[800]!,
      );
    }
  }

  void _showAddLossModal() {
    final products = context.read<ProductBloc>().state.products;
    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    String selectedReason = lossReasons.first;
    bool isReimbursable = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filteredProducts = query.isEmpty
              ? products.take(20).toList()
              : products.where((p) => p.name.toLowerCase().contains(query) || BarcodeNormalizer.matches(p.barcode, query)).take(20).toList();

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.remove_shopping_cart_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text('تسجيل سلعة تالفة أو قابلة للتعويض 🗑️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  if (selectedProduct == null) ...[
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن السلعة بالاسم أو الباركود...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = filteredProducts[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('المخزون: ${p.stock} • التكلفة: ${p.costPrice.toStringAsFixed(2)} DA', style: const TextStyle(fontSize: 11)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                              onPressed: () {
                                setModalState(() => selectedProduct = p);
                              },
                              child: const Text('اختيار', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // Product Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.teal),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('المخزون الحالي: ${selectedProduct!.stock} • التكلفة: ${selectedProduct!.costPrice.toStringAsFixed(2)} DA',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              ],
                            ),
                          ),
                          TextButton(onPressed: () => setModalState(() => selectedProduct = null), child: const Text('تغيير')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quantity
                    Row(
                      children: [
                        const Text('الكمية التالفة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, suffixText: 'قطعة'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Reason Dropdown
                    const Text('سبب التلف أو الإتلاف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: lossReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          selectedReason = v!;
                          if (v.contains('المورد') || v.contains('انتهاء')) {
                            isReimbursable = true;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Reimbursable Checkbox (Avoir Fournisseur)
                    Container(
                      decoration: BoxDecoration(
                        color: isReimbursable ? Colors.indigo.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isReimbursable ? Colors.indigo.shade200 : Colors.grey.shade300),
                      ),
                      child: CheckboxListTile(
                        title: const Text('🔄 سلعة قابلة للتعويض من المورد (Retour Fournisseur / Avoir)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: const Text('لن تُخصم من أرباح المتجر الصافية، بل تسجل كدين مسترجع على الموزع', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        value: isReimbursable,
                        activeColor: Colors.indigo,
                        onChanged: (v) => setModalState(() => isReimbursable = v ?? false),
                      ),
                    ),
                    if (isReimbursable) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: supplierCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم الموزع / المورد المسؤول عن التعويض',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Notes
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReimbursable ? Colors.indigo : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(
                        isReimbursable ? 'تأكيد تسجيل الإرجاع للمورد 🔄' : 'تأكيد الإتلاف وخصم المخزون 🗑️',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                        if (qty <= 0) return;
                        Navigator.pop(ctx);
                        _recordNewLoss(
                          selectedProduct!,
                          qty,
                          selectedReason,
                          notesCtrl.text.trim(),
                          isReimbursable,
                          supplierCtrl.text.trim(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLosses = _selectedReasonFilter == 'الكل'
        ? _losses
        : _losses.where((l) => l.reason.contains(_selectedReasonFilter)).toList();

    double totalCostLosses = 0.0;
    double totalReimbursable = 0.0;
    int totalItemsCount = 0;

    for (final l in _losses) {
      if (l.isReimbursable) {
        totalReimbursable += l.totalLossCost;
      } else {
        totalCostLosses += l.totalLossCost;
      }
      totalItemsCount += l.quantity;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('سجل التوالف والكسر 🗑️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.red, size: 28),
            tooltip: 'تسجيل تلف جديد (+)',
            onPressed: _showAddLossModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Financial Summary Cards Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Net Store Loss Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.trending_down, color: Colors.red, size: 18),
                            SizedBox(width: 6),
                            Text('خسائر التلف الصافية:', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${totalCostLosses.toStringAsFixed(2)} DA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
                        const SizedBox(height: 2),
                        const Text('(تُخصم من صافي أرباح المتجر)', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Reimbursable Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.replay_rounded, color: Colors.indigo, size: 18),
                            SizedBox(width: 6),
                            Text('مسترجعات الموردين:', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${totalReimbursable.toStringAsFixed(2)} DA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.indigo.shade900)),
                        const SizedBox(height: 2),
                        const Text('(تعويض مسترجع لا يمس الأرباح)', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Losses List
          Expanded(
            child: filteredLosses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                        const SizedBox(height: 12),
                        const Text('لا توجد سلع تالفة مسجلة! حالة المتجر ممتازة 🎉',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredLosses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final item = filteredLosses[i];
                      final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item.isReimbursable ? Colors.indigo.shade100 : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.isReimbursable ? 'تعويض مورد' : 'تلف نهائي',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.isReimbursable ? Colors.indigo.shade900 : Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('الكمية: ${item.quantity} • التكلفة: ${item.costPrice.toStringAsFixed(2)} DA',
                                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  Text(
                                    '-${item.totalLossCost.toStringAsFixed(2)} DA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: item.isReimbursable ? Colors.indigo : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('السبب: ${item.reason}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(dateFormat.format(item.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              if (item.supplierName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('المورد المسؤول: ${item.supplierName}', style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                              ],
                              if (item.notes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('ملاحظة: ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('تسجيل إتلاف / تعويض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddLossModal,
      ),
    );
  }
}

