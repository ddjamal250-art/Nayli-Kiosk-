import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_unit.dart';
import '../../../product/data/models/product_unit_model.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';
import '../bloc/billing_event.dart';

class QuickItemData {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final String icon;
  final String barcode;
  final String shortCode;
  final double stock;
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
    this.stock = 0.0,
    this.linkedProductId,
    this.orderIndex = 0,
  });

  QuickItemData copyWith({
    String? id,
    String? name,
    double? price,
    double? costPrice,
    String? icon,
    String? barcode,
    String? shortCode,
    double? stock,
    String? linkedProductId,
    int? orderIndex,
  }) => QuickItemData(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    costPrice: costPrice ?? this.costPrice,
    icon: icon ?? this.icon,
    barcode: barcode ?? this.barcode,
    shortCode: shortCode ?? this.shortCode,
    stock: stock ?? this.stock,
    linkedProductId: linkedProductId ?? this.linkedProductId,
    orderIndex: orderIndex ?? this.orderIndex,
  );

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
    stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
    linkedProductId: map['linkedProductId']?.toString(),
    orderIndex: (map['orderIndex'] as num?)?.toInt() ?? index,
  );
}

class QuickItemAddEditDialog extends StatefulWidget {
  final QuickItemData? existingItem;
  final bool addToCartOnSave;
  final Function(QuickItemData item, ProductModel productModel)? onSaved;

  const QuickItemAddEditDialog({
    super.key,
    this.existingItem,
    this.addToCartOnSave = false,
    this.onSaved,
  });

  @override
  State<QuickItemAddEditDialog> createState() => _QuickItemAddEditDialogState();
}

class _QuickItemAddEditDialogState extends State<QuickItemAddEditDialog> {
  static const List<String> popularEmojis = [
    '💧', '🥛', '🫓', '🍲', '🥚', '🥐', '🥖', '☕', '🟤', '🍵', '🛍️',
    '🥪', '🍰', '🧀', '🥤', '🥩', '🍗', '🍉', '🍎',
    '🍟', '🍕', '🍯', '🧈', '🧂', '🍬', '🍫', '🏷️',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _shortCodeController;
  late String _selectedEmoji;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(text: item != null && item.price > 0 ? item.price.toStringAsFixed(2) : '');
    _costController = TextEditingController(text: item != null && item.costPrice > 0 ? item.costPrice.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: item != null ? item.stock.toString() : '50');
    _barcodeController = TextEditingController(text: item?.barcode ?? BarcodeGeneratorHelper.generateUniqueInStoreEan13());
    _shortCodeController = TextEditingController(text: item?.shortCode ?? BarcodeGeneratorHelper.generateNextShortSku());
    _selectedEmoji = item?.icon ?? '🥖';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _shortCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final stock = double.tryParse(_stockController.text.trim()) ?? 0.0;
    final barcode = _barcodeController.text.trim();
    final shortCode = _shortCodeController.text.trim();

    if (name.isEmpty || price <= 0 || barcode.isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى إدخال اسم السلعة وسعر بيع صحيح');
      return;
    }

    final existingItem = widget.existingItem;
    final newItem = QuickItemData(
      id: existingItem?.id ?? 'quick_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      price: price,
      costPrice: cost,
      icon: _selectedEmoji,
      barcode: barcode,
      shortCode: shortCode,
      stock: stock,
      linkedProductId: existingItem?.linkedProductId,
      orderIndex: existingItem?.orderIndex ?? HiveDatabase.quickItemsBox.length,
    );

    // 1. Save in Quick Items Box
    final qBox = HiveDatabase.quickItemsBox;
    await qBox.put(newItem.id, newItem.toMap());

    // 2. Save & Link in Inventory (productBox)
    final productBox = HiveDatabase.productBox;
    final existing = newItem.linkedProductId != null && newItem.linkedProductId!.isNotEmpty
        ? (productBox.get(newItem.linkedProductId) ?? productBox.values.where((p) => p.barcode == newItem.barcode || p.id == newItem.id).firstOrNull)
        : productBox.values.where((p) => p.barcode == newItem.barcode || p.id == newItem.id).firstOrNull;

    final isCoffee = newItem.name.toLowerCase().contains('قهوة') ||
        newItem.name.toLowerCase().contains('شاي') ||
        newItem.name.toLowerCase().contains('كبسول') ||
        newItem.name.toLowerCase().contains('express');

    ProductModel productModel;
    if (existing != null) {
      productModel = existing.copyWith(
        name: newItem.name,
        barcode: newItem.barcode,
        price: newItem.price,
        costPrice: newItem.costPrice > 0 ? newItem.costPrice : existing.costPrice,
        stock: newItem.stock > 0 ? newItem.stock : existing.stock,
      );
    } else {
      final unit = ProductUnitModel(
        tierIndex: UnitTier.small.index,
        name: isCoffee ? 'كأس' : 'حبة',
        multiplier: 1.0,
        price: newItem.price,
        cost: newItem.costPrice,
        isEnabled: true,
      );

      final batch = PurchaseBatchModel(
        batchId: 'BATCH_${newItem.barcode}',
        costPrice: newItem.costPrice,
        remainingQuantity: newItem.stock,
        dateAdded: DateTime.now(),
      );

      productModel = ProductModel(
        id: newItem.linkedProductId ?? newItem.id,
        name: newItem.name,
        barcode: newItem.barcode,
        price: newItem.price,
        costPrice: newItem.costPrice,
        stock: newItem.stock,
        category: isCoffee ? 'القهوة الجاهزة' : 'سلعة حرة',
        wholesalePrice: newItem.price,
        units: [unit],
        stockBatchesModels: [batch],
      );
    }

    await productBox.put(productModel.id, productModel);

    // 3. Silent catalog harvest
    CatalogCrowdsourceHelper.silentHarvest(
      productModel.toEntity(),
      category: isCoffee ? 'القهوة الجاهزة' : 'سلعة حرة',
      unit: isCoffee ? 'كأس' : 'حبة',
    );

    // 4. Update ProductBloc so inventory is refreshed across the application
    try {
      context.read<ProductBloc>().add(LoadProducts());
    } catch (_) {}

    // 5. If called from POS during checkout, add item to active cart immediately
    if (widget.addToCartOnSave) {
      try {
        context.read<BillingBloc>().add(AddProductToCartEvent(productModel));
      } catch (_) {}
    }

    // 6. Callback
    if (widget.onSaved != null) {
      widget.onSaved!(newItem, productModel);
    }

    SoundService.playSaveSuccess();
    if (mounted) {
      SnackbarHelper.showSuccess(
        context,
        widget.addToCartOnSave
            ? 'تم حفظ "$name" في المخزون وإضافته للسلة!'
            : 'تم حفظ "$name" ومزامنته مع المخزون العام!',
      );
      Navigator.pop(context, productModel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingItem = widget.existingItem;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            existingItem != null ? Icons.edit_note_rounded : Icons.add_circle_outline,
            color: Colors.teal,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            existingItem != null ? 'تعديل منتج البيع السريع' : 'إضافة منتج بيع سريع جديد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
              const Text(
                'اختر أيقونة السلعة (الإيموجي):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: popularEmojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final em = popularEmojis[i];
                    final isSelected = _selectedEmoji == em;
                    return InkWell(
                      onTap: () => setState(() => _selectedEmoji = em),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.teal.shade900 : Colors.teal.shade100)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.teal : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            width: isSelected ? 2 : 1,
                          ),
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
                controller: _nameController,
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
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      controller: _stockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      controller: _shortCodeController,
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
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'الباركود الداخلي المولد (EAN-13)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'توليد باركود داخلي جديد',
                    icon: const Icon(Icons.refresh, color: Colors.teal),
                    onPressed: () {
                      setState(() {
                        _barcodeController.text = BarcodeGeneratorHelper.generateUniqueInStoreEan13();
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text(
            'حفظ وربط بالمخزون',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
