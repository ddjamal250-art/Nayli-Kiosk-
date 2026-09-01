import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

class QuickItemData {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final String icon;
  final String barcode;
  final String shortCode;
  final int stock;
  final String? linkedProductId;
  final int orderIndex;

  QuickItemData({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.icon,
    required this.barcode,
    this.shortCode = '',
    this.stock = 0,
    this.linkedProductId,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'costPrice': costPrice,
    'icon': icon,
    'barcode': barcode,
    'shortCode': shortCode,
    'stock': stock,
    'linkedProductId': linkedProductId,
    'orderIndex': orderIndex,
  };

  factory QuickItemData.fromMap(Map<dynamic, dynamic> map, {int index = 0}) => QuickItemData(
    id: map['id']?.toString() ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
    name: map['name']?.toString() ?? '',
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
    icon: map['icon']?.toString() ?? '🏷️',
    barcode: map['barcode']?.toString() ?? '',
    shortCode: map['shortCode']?.toString() ?? '',
    stock: (map['stock'] as num?)?.toInt() ?? 0,
    linkedProductId: map['linkedProductId']?.toString(),
    orderIndex: (map['orderIndex'] as num?)?.toInt() ?? index,
  );
}

class QuickItemsManagerDialog extends StatefulWidget {
  const QuickItemsManagerDialog({super.key});

  @override
  State<QuickItemsManagerDialog> createState() => _QuickItemsManagerDialogState();
}

class _QuickItemsManagerDialogState extends State<QuickItemsManagerDialog> {
  List<QuickItemData> _items = [];
  bool _isLoading = true;

  static const List<String> _popularEmojis = [
    '🥖', '🥚', '🍲', '🫓', '🥛', '☕', '💧', '🛍️',
    '🥪', '🍰', '🧀', '🥤', '🥩', '🍗', '🍉', '🍎',
    '🍟', '🍕', '🍯', '🧈', '🧂', '🍬', '🍫', '🏷️',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuickItems();
  }

  void _loadQuickItems() {
    final box = HiveDatabase.quickItemsBox;
    final saved = box.values.toList();
    final List<QuickItemData> list = [];

    for (int i = 0; i < saved.length; i++) {
      if (saved[i] is Map) {
        list.add(QuickItemData.fromMap(saved[i] as Map, index: i));
      }
    }

    if (list.isEmpty) {
      // Default standard Algerian quick staples
      final defaults = [
        QuickItemData(id: 'bread', name: 'خبز باكيط (Baguette)', price: 10.0, costPrice: 8.5, icon: '🥖', barcode: '2000000000018', shortCode: '1', stock: 150, orderIndex: 0),
        QuickItemData(id: 'egg_single', name: 'حبة بيض (Œuf)', price: 20.0, costPrice: 17.0, icon: '🥚', barcode: '2000000000025', shortCode: '2', stock: 360, orderIndex: 1),
        QuickItemData(id: 'chakhchoukha', name: 'شخشوخة / تريدة تقليدية', price: 120.0, costPrice: 90.0, icon: '🍲', barcode: '2000000000032', shortCode: '3', stock: 50, orderIndex: 2),
        QuickItemData(id: 'kesra', name: 'كسرة رخساس / فطير', price: 50.0, costPrice: 35.0, icon: '🫓', barcode: '2000000000049', shortCode: '4', stock: 40, orderIndex: 3),
        QuickItemData(id: 'milk_bag', name: 'حليب شكارة مدعم (Lait)', price: 25.0, costPrice: 23.5, icon: '🥛', barcode: '2000000000056', shortCode: '5', stock: 80, orderIndex: 4),
        QuickItemData(id: 'water_500', name: 'قارورة ماء 0.5L', price: 25.0, costPrice: 18.0, icon: '💧', barcode: '2000000000063', shortCode: '6', stock: 120, orderIndex: 5),
        QuickItemData(id: 'plastic_bag', name: 'كيس تسوق بلاستيكي', price: 5.0, costPrice: 2.0, icon: '🛍️', barcode: '2000000000070', shortCode: '7', stock: 500, orderIndex: 6),
      ];

      for (var item in defaults) {
        box.put(item.id, item.toMap());
        _syncWithProductBox(item);
      }
      list.addAll(defaults);
    }

    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    setState(() {
      _items = list;
      _isLoading = false;
    });
  }

  void _syncWithProductBox(QuickItemData item) {
    final productBox = HiveDatabase.productBox;
    final existing = productBox.values.where((p) => p.barcode == item.barcode || p.id == item.id).firstOrNull;

    final productModel = ProductModel(
      id: existing?.id ?? item.id,
      name: item.name,
      barcode: item.barcode,
      price: item.price,
      costPrice: item.costPrice,
      stock: existing != null ? existing.stock : item.stock,
      category: 'بيع سريع',
      isWeighted: false,
      wholesalePrice: item.price,
    );

    productBox.put(productModel.id, productModel);
    CatalogCrowdsourceHelper.silentHarvest(
      productModel.toEntity(),
      category: 'بيع سريع',
      unit: 'حبة',
    );
    context.read<ProductBloc>().add(LoadProducts());
  }

  Future<void> _saveOrder() async {
    final box = HiveDatabase.quickItemsBox;
    await box.clear();
    for (int i = 0; i < _items.length; i++) {
      final updated = QuickItemData(
        id: _items[i].id,
        name: _items[i].name,
        price: _items[i].price,
        costPrice: _items[i].costPrice,
        icon: _items[i].icon,
        barcode: _items[i].barcode,
        shortCode: _items[i].shortCode,
        stock: _items[i].stock,
        linkedProductId: _items[i].linkedProductId,
        orderIndex: i,
      );
      await box.put(updated.id, updated.toMap());
      _syncWithProductBox(updated);
    }
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _items.removeAt(index);
        _items.insert(index - 1, item);
      });
      _saveOrder();
      SoundService.playTabSwitch();
    }
  }

  void _moveDown(int index) {
    if (index < _items.length - 1) {
      setState(() {
        final item = _items.removeAt(index);
        _items.insert(index + 1, item);
      });
      _saveOrder();
      SoundService.playTabSwitch();
    }
  }

  void _showAddEditModal({QuickItemData? existingItem}) {
    SoundService.playTabSwitch();
    final nameController = TextEditingController(text: existingItem?.name ?? '');
    final priceController = TextEditingController(text: existingItem != null ? existingItem.price.toStringAsFixed(2) : '');
    final costController = TextEditingController(text: existingItem != null ? existingItem.costPrice.toStringAsFixed(2) : '');
    final stockController = TextEditingController(text: existingItem != null ? existingItem.stock.toString() : '50');
    final barcodeController = TextEditingController(text: existingItem?.barcode ?? BarcodeGeneratorHelper.generateUniqueInStoreEan13());
    final shortCodeController = TextEditingController(text: existingItem?.shortCode ?? BarcodeGeneratorHelper.generateNextShortSku());
    String selectedEmoji = existingItem?.icon ?? '🥖';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(existingItem != null ? Icons.edit_note_rounded : Icons.add_circle_outline, color: Colors.teal, size: 28),
                const SizedBox(width: 8),
                Text(existingItem != null ? 'تعديل منتج البيع السريع' : 'إضافة منتج بيع سريع جديد', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji Selector Row
                    const Text('اختر أيقونة السلعة (الإيموجي):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _popularEmojis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final em = _popularEmojis[i];
                          final isSelected = selectedEmoji == em;
                          return InkWell(
                            onTap: () => setModalState(() => selectedEmoji = em),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.teal.shade100 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: isSelected ? 2 : 1),
                              ),
                              child: Text(em, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    TextField(
                      controller: nameController,
                      autofocus: existingItem == null,
                      decoration: const InputDecoration(
                        labelText: 'اسم السلعة (مثلاً: خبز تقليدي / شخشوخة / بيض) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prices Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر البيع (د.ج) *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سعر الشراء / التكلفة (د.ج)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stock & Shortcode Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المخزون الحالي (القطع)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: shortCodeController,
                            decoration: const InputDecoration(
                              labelText: 'الرمز السريع بالكيبورد (مثلاً 1 للخبز)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Barcode field
                    TextField(
                      controller: barcodeController,
                      decoration: InputDecoration(
                        labelText: 'الباركود الداخلي المولد (EAN-13)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'توليد باركود داخلي جديد',
                          icon: const Icon(Icons.refresh, color: Colors.teal),
                          onPressed: () {
                            setModalState(() {
                              barcodeController.text = BarcodeGeneratorHelper.generateUniqueInStoreEan13();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('حفظ وربط بالمخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                  final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                  final stock = int.tryParse(stockController.text.trim()) ?? 0;
                  final barcode = barcodeController.text.trim();
                  final shortCode = shortCodeController.text.trim();

                  if (name.isEmpty || price <= 0 || barcode.isEmpty) {
                    SnackbarHelper.showWarning(context, 'يرجى إدخال اسم السلعة وسعر بيع صحيح');
                    return;
                  }

                  final newItem = QuickItemData(
                    id: existingItem?.id ?? 'quick_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    price: price,
                    costPrice: cost,
                    icon: selectedEmoji,
                    barcode: barcode,
                    shortCode: shortCode,
                    stock: stock,
                    orderIndex: existingItem?.orderIndex ?? _items.length,
                  );

                  final box = HiveDatabase.quickItemsBox;
                  box.put(newItem.id, newItem.toMap());
                  _syncWithProductBox(newItem);

                  Navigator.pop(ctx);
                  _loadQuickItems();
                  SoundService.playSaveSuccess();
                  SnackbarHelper.showSuccess(context, 'تم حفظ "$name" ومزامنته مع المخزون العام!');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteItem(QuickItemData item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text('حذف "${item.name}" من البيع السريع؟'),
          ],
        ),
        content: const Text('سيتم حذف السلعة من مربعات البيع السريع (يبقى سجلها في الأرشيف).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              HiveDatabase.quickItemsBox.delete(item.id);
              _loadQuickItems();
              SoundService.playDeleteSound();
              SnackbarHelper.showSuccess(context, 'تم حذف السلعة من البيع السريع');
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 750,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.dashboard_customize_rounded, color: Colors.teal, size: 30),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة وترتيب مربعات البيع السريع (Quick Sell Manager)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('استخدم الأسهم 🔼 🔽 أو السحب لإعادة ترتيب السلع حسب الأكثر مبيعاً في محلك',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('إضافة سلعة سريعة (+)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditModal(),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            // Reorderable List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('لا توجد سلع سريعة مسجلة حالياً'))
                      : ReorderableListView.builder(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _items.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                            });
                            _saveOrder();
                            SoundService.playTabSwitch();
                          },
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.teal.shade200),
                                  ),
                                  child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                                ),
                                title: Row(
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    if (item.shortCode.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: Text('كود: ${item.shortCode}', style: TextStyle(fontSize: 10, color: Colors.indigo.shade900, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  'السعر: ${item.price.toStringAsFixed(2)} د.ج • التكلفة: ${item.costPrice.toStringAsFixed(2)} د.ج • الباركود: ${item.barcode}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Move Up
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.indigo),
                                      tooltip: 'نقل للأعلى',
                                      onPressed: index > 0 ? () => _moveUp(index) : null,
                                    ),
                                    // Move Down
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward_rounded, size: 20, color: Colors.indigo),
                                      tooltip: 'نقل للأسفل',
                                      onPressed: index < _items.length - 1 ? () => _moveDown(index) : null,
                                    ),
                                    const VerticalDivider(width: 16),
                                    // Edit
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.teal),
                                      tooltip: 'تعديل السعر والبيانات',
                                      onPressed: () => _showAddEditModal(existingItem: item),
                                    ),
                                    // Delete
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'حذف',
                                      onPressed: () => _deleteItem(item),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

