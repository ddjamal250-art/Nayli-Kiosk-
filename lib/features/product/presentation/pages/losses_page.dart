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

  static const List<String> lossReasons = [
    'كسر أو تلف بالمحل (Casse)',
    'انتهاء الصلاحية (Périmé)',
    'تلف أثناء النقل والتحميل (Avarie)',
    'عيب مصنعي أو غير صالح (Défaut)',
    'استهلاك شخصي أو عينات (Échantillon)',
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

  Future<void> _recordNewLoss(Product product, int quantity, String reason, String notes) async {
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
        '🗑️ تم تسجيل إتلاف $quantity قطعة من ${product.name} وخصمها من المخزون!',
        backgroundColor: Colors.red[800]!,
      );
    }
  }

  void _showAddLossModal() {
    final products = context.read<ProductBloc>().state.products;
    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    String selectedReason = lossReasons.first;

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
                          Text('تسجيل سلعة تالفة أو مكسورة 🗑️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  if (selectedProduct == null) ...[
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن السلعة بالاسم أو امسح الباركود...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                          onPressed: () async {
                            final scanned = await context.push<String>('/scanner');
                            if (scanned != null && scanned.isNotEmpty) {
                              final matched = BarcodeNormalizer.findProduct(products, scanned);
                              if (matched != null) {
                                setModalState(() => selectedProduct = matched);
                              } else if (ctx.mounted) {
                                context.showAppSnackBar('⚠️ السلعة غير مسجلة في المخزون!', backgroundColor: Colors.orange[800]!);
                              }
                            }
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = filteredProducts[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('المخزون: ${p.stock} | التكلفة: ${p.costPrice.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 11)),
                            onTap: () => setModalState(() => selectedProduct = p),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('المخزون الحالي: ${selectedProduct!.stock} قطعة | سعر التكلفة: ${selectedProduct!.costPrice.toStringAsFixed(0)} دج',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.change_circle_outlined, color: Colors.grey),
                            onPressed: () => setModalState(() => selectedProduct = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'الكمية التالفة',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: InputDecoration(
                        labelText: 'سبب الخسارة أو الإتلاف',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: lossReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedReason = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('تأكيد شطب السلعة وخصمها من المخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () {
                        final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                        if (qty <= 0) return;
                        Navigator.pop(ctx);
                        _recordNewLoss(selectedProduct!, qty, selectedReason, notesCtrl.text.trim());
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
    double totalLossesCost = 0.0;
    int totalUnitsCount = 0;
    for (final l in _losses) {
      totalLossesCost += l.totalLossCost;
      totalUnitsCount += l.quantity;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التوالف والكسر والاهتلاك 🗑️📉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.green),
            tooltip: 'نسخ تقرير التوالف كـ Excel',
            onPressed: () {
              final buffer = StringBuffer();
              buffer.writeln('التاريخ,اسم السلعة,الباركود,الكمية التالفة,سعر التكلفة,إجمالي الخسارة,السبب,ملاحظات');
              for (final l in _losses) {
                buffer.writeln('${DateFormat('yyyy-MM-dd HH:mm').format(l.date)},"${l.productName}",${l.barcode},${l.quantity},${l.costPrice},${l.totalLossCost},"${l.reason}","${l.notes}"');
              }
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              SoundService.playCheckoutSuccess();
              context.showAppSnackBar('📊 تم نسخ تقرير التوالف بتنسيق Excel بنجاح!', backgroundColor: Colors.green[800]!);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('تسجيل إتلاف سلعة', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddLossModal,
      ),
      body: Column(
        children: [
          // Summary Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF881337), Color(0xFF4C0519)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي قيمة الخسائر بالتكلفة:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${totalLossesCost.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(height: 36, width: 1, color: Colors.white24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('إجمالي القطع المشطوبة:', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(
                      '$totalUnitsCount قطعة',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Losses List
          Expanded(
            child: _losses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text('لا توجد سلع تالفة أو مكسورة مسجلة حتى الآن', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('انقر على الزر أدناه لتسجيل أي سلعة تالفة وخصمها من المخزون', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _losses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = _losses[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text('السبب: ${item.reason}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                  Text(DateFormat('yyyy-MM-dd | HH:mm').format(item.date), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${item.quantity} قطعة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                const SizedBox(height: 2),
                                Text('-${item.totalLossCost.toStringAsFixed(0)} دج', style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
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
