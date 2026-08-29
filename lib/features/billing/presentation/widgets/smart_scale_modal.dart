import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';

class SmartScaleModal extends StatefulWidget {
  const SmartScaleModal({super.key});

  @override
  State<SmartScaleModal> createState() => _SmartScaleModalState();
}

class _SmartScaleModalState extends State<SmartScaleModal> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController(text: 'عدس');
  final _pricePerKgController = TextEditingController(text: '260');
  final _costPerKgController = TextEditingController(text: '200');
  final _weightController = TextEditingController(text: '500'); // grams
  final _amountController = TextEditingController();

  bool _isByWeight = true; // true = by weight, false = by fixed amount (e.g. 100 DZD)
  String? _selectedProductId;
  double _currentStockKg = 50.0;

  List<Map<String, dynamic>> _scaleProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  static const List<Map<String, dynamic>> _defaultPresets = [
    {'name': 'عدس', 'pricePerKg': 260.0, 'costPerKg': 200.0, 'stockKg': 50.0, 'barcode': 'SCALE_LENTIL'},
    {'name': 'حمص', 'pricePerKg': 280.0, 'costPerKg': 220.0, 'stockKg': 40.0, 'barcode': 'SCALE_CHICKPEA'},
    {'name': 'لوبيا بيضاء', 'pricePerKg': 340.0, 'costPerKg': 280.0, 'stockKg': 30.0, 'barcode': 'SCALE_BEAN'},
    {'name': 'فريك شوربة', 'pricePerKg': 450.0, 'costPerKg': 360.0, 'stockKg': 25.0, 'barcode': 'SCALE_FRIK'},
    {'name': 'حلوة الترك بالميزان', 'pricePerKg': 600.0, 'costPerKg': 450.0, 'stockKg': 15.0, 'barcode': 'SCALE_HALWA'},
    {'name': 'زيتون أخضر مقطع', 'pricePerKg': 350.0, 'costPerKg': 270.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_G'},
    {'name': 'زيتون أسود بالميزان', 'pricePerKg': 450.0, 'costPerKg': 350.0, 'stockKg': 20.0, 'barcode': 'SCALE_OLIVE_B'},
    {'name': 'كاشير بالميزان', 'pricePerKg': 400.0, 'costPerKg': 300.0, 'stockKg': 15.0, 'barcode': 'SCALE_CACHIR'},
    {'name': 'جبن أحمر / كودة', 'pricePerKg': 1200.0, 'costPerKg': 950.0, 'stockKg': 10.0, 'barcode': 'SCALE_CHEESE'},
    {'name': 'سميد ممتاز بالميزان', 'pricePerKg': 110.0, 'costPerKg': 85.0, 'stockKg': 100.0, 'barcode': 'SCALE_SEMOLINA'},
    {'name': 'سكر بالميزان', 'pricePerKg': 100.0, 'costPerKg': 80.0, 'stockKg': 150.0, 'barcode': 'SCALE_SUGAR'},
    {'name': 'طماطم بالميزان', 'pricePerKg': 120.0, 'costPerKg': 90.0, 'stockKg': 30.0, 'barcode': 'SCALE_TOMATO'},
    {'name': 'بطاطا بالميزان', 'pricePerKg': 80.0, 'costPerKg': 60.0, 'stockKg': 80.0, 'barcode': 'SCALE_POTATO'},
  ];

  @override
  void initState() {
    super.initState();
    _loadScaleProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _pricePerKgController.dispose();
    _costPerKgController.dispose();
    _weightController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _loadScaleProducts() {
    final List<Map<String, dynamic>> list = [];
    final pBox = HiveDatabase.productBox;

    // Load from products database
    for (final p in pBox.values) {
      if (p.isWeighable || p.barcode.startsWith('SCALE_') || p.unit == 'kg') {
        list.add({
          'id': p.id,
          'name': p.name,
          'pricePerKg': p.price,
          'costPerKg': p.costPrice,
          'stockKg': p.stock.toDouble(),
          'barcode': p.barcode,
        });
      }
    }

    // Merge default presets if not in database
    for (final def in _defaultPresets) {
      if (!list.any((e) => e['name'].toString().trim() == def['name'].toString().trim())) {
        list.add(Map<String, dynamic>.from(def));
      }
    }

    setState(() {
      _scaleProducts = list;
      _filteredProducts = List.from(list);
    });
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll(RegExp(r'[ةه]'), 'ه')
        .replaceAll(RegExp(r'[ىي]'), 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // remove tashkeel
        .toLowerCase()
        .trim();
  }

  void _onSearchChanged() {
    final query = _normalizeArabic(_searchController.text);
    if (query.isEmpty) {
      setState(() => _filteredProducts = List.from(_scaleProducts));
      return;
    }

    setState(() {
      _filteredProducts = _scaleProducts.where((p) {
        final normName = _normalizeArabic(p['name'].toString());
        return normName.contains(query);
      }).toList();
    });
  }

  void _selectProduct(Map<String, dynamic> prod) {
    setState(() {
      _selectedProductId = prod['id']?.toString();
      _nameController.text = prod['name'].toString();
      _pricePerKgController.text = (prod['pricePerKg'] as num).toStringAsFixed(0);
      _costPerKgController.text = ((prod['costPerKg'] as num?) ?? ((prod['pricePerKg'] as num) * 0.8)).toStringAsFixed(0);
      _currentStockKg = (prod['stockKg'] as num?)?.toDouble() ?? 50.0;
      _searchController.clear();
      _filteredProducts = List.from(_scaleProducts);
    });
  }

  void _showAddDetailedWeighableProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final bagsCountCtrl = TextEditingController(text: '2');
    final bagWeightCtrl = TextEditingController(text: '25');
    final directKgCtrl = TextEditingController(text: '50');
    final supplierCtrl = TextEditingController();
    bool isBagsMode = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.scale_rounded, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('➕ إضافة سلعة ميزان جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة / السلعة',
                    hintText: 'مثال: سميد ممتاز، عدس بني، زيتون...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'سعر البيع (دج/كغ)',
                          suffixText: 'دج',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'سعر التكلفة (دج/كغ)',
                          suffixText: 'دج',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Supply Method (Bags / Direct Kg)
                const Text('طريقة احتساب وتوريد المخزون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('بالأكياس / الشكاير 🌾', style: TextStyle(fontSize: 11)),
                      selected: isBagsMode,
                      onSelected: (v) => setDialogState(() => isBagsMode = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('بالكيلوغرام المباشر ⚖️', style: TextStyle(fontSize: 11)),
                      selected: !isBagsMode,
                      onSelected: (v) => setDialogState(() => isBagsMode = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (isBagsMode) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bagsCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الشكاير',
                            suffixText: 'شكارة',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bagWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'وزن الشكارة',
                            suffixText: 'كغ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (_) {
                      final bags = int.tryParse(bagsCountCtrl.text.trim()) ?? 0;
                      final weight = double.tryParse(bagWeightCtrl.text.trim()) ?? 0.0;
                      final total = bags * weight;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          '📦 إجمالي المخزون المحسوب: $total كغ ($bags شكارة × $weight كغ)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: directKgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المخزون الإجمالي المباشر (كغ)',
                      suffixText: 'كغ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المورد / شركة التوزيع (اختياري)',
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
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ?? (price * 0.8);
                if (name.isEmpty || price <= 0) return;

                double totalStock = 0.0;
                if (isBagsMode) {
                  final bags = int.tryParse(bagsCountCtrl.text.trim()) ?? 0;
                  final bWeight = double.tryParse(bagWeightCtrl.text.trim()) ?? 25.0;
                  totalStock = bags * bWeight;
                } else {
                  totalStock = double.tryParse(directKgCtrl.text.trim()) ?? 50.0;
                }

                final newProdId = const Uuid().v4();
                final rawBarcode = 'SCALE_${DateTime.now().millisecondsSinceEpoch}';

                final newProd = Product(
                  id: newProdId,
                  name: name,
                  barcode: rawBarcode,
                  price: price,
                  costPrice: cost,
                  stock: totalStock.toInt(),
                  isWeighable: true,
                  unit: 'kg',
                  unitsPerCarton: isBagsMode ? (int.tryParse(bagsCountCtrl.text.trim()) ?? 1) : 1,
                  cartonCostPrice: isBagsMode ? (cost * (double.tryParse(bagWeightCtrl.text.trim()) ?? 25.0)) : cost,
                );

                context.read<ProductBloc>().add(AddProduct(newProd));

                final itemMap = {
                  'id': newProdId,
                  'name': name,
                  'pricePerKg': price,
                  'costPerKg': cost,
                  'stockKg': totalStock,
                  'barcode': rawBarcode,
                };

                setState(() {
                  _scaleProducts.insert(0, itemMap);
                  _selectProduct(itemMap);
                });

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم حفظ مادة الميزان ($name) بمخزون $totalStock كغ!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
              child: const Text('حفظ وإدراج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  double get _calculatedTotal {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (_isByWeight) {
      final grams = double.tryParse(_weightController.text.trim()) ?? 0.0;
      return (pricePerKg * (grams / 1000.0)).roundToDouble();
    } else {
      return double.tryParse(_amountController.text.trim()) ?? 0.0;
    }
  }

  double get _calculatedGrams {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (pricePerKg <= 0) return 0.0;
    if (_isByWeight) {
      return double.tryParse(_weightController.text.trim()) ?? 0.0;
    } else {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      return ((amount / pricePerKg) * 1000.0).roundToDouble();
    }
  }

  void _onAddToCart() {
    final name = _nameController.text.trim().isEmpty ? 'سلعة ميزان' : _nameController.text.trim();
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    final costPerKg = double.tryParse(_costPerKgController.text.trim()) ?? (pricePerKg * 0.8);
    final finalTotal = _calculatedTotal;
    final grams = _calculatedGrams;
    final weightKg = grams / 1000.0;

    if (finalTotal <= 0 || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد وزن أو مبلغ صحيح!'), backgroundColor: Colors.red),
      );
      return;
    }

    final String weightLabel = grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} كغ' : '${grams.toInt()} غ';
    final customItemName = '$name ($weightLabel)';
    final rawBarcode = 'SCALE_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Add to cart
    context.read<BillingBloc>().add(AddCustomItemEvent(
      name: customItemName,
      price: finalTotal,
      costPrice: (costPerKg * weightKg).roundToDouble(),
      quantity: 1,
      barcode: rawBarcode,
    ));

    // 2. Deduct from product stock if registered in ProductBox
    final pBox = HiveDatabase.productBox;
    final matching = pBox.values.where((p) => p.name.trim() == name.trim() || p.id == _selectedProductId).firstOrNull;
    if (matching != null) {
      final current = matching.stock;
      final newStock = (current - weightKg).clamp(0.0, double.infinity).toInt();
      final updated = Product(
        id: matching.id,
        name: matching.name,
        barcode: matching.barcode,
        price: matching.price,
        costPrice: matching.costPrice,
        stock: newStock,
        unit: matching.unit,
        isWeighable: true,
        unitsPerCarton: matching.unitsPerCarton,
        cartonCostPrice: matching.cartonCostPrice,
      );
      context.read<ProductBloc>().add(UpdateProduct(updated));
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تمت إضافة $customItemName بمبلغ $finalTotal دج!'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grams = _calculatedGrams;
    final total = _calculatedTotal;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.scale_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'حاسبة سلع الميزان والتجزئة (Vrac) ⚖️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),

            // SEARCH BAR & ADD PRODUCT ROW
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مادة ميزان (بالأحرف أو الاسم)... 🔍',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text('إضافة سلعة', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showAddDetailedWeighableProductDialog,
                ),
              ],
            ),

            // LIVE SEARCH RESULTS DROPDOWN / CHIPS
            if (_filteredProducts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 6),
                  itemBuilder: (ctx, idx) {
                    final prod = _filteredProducts[idx];
                    final isSelected = _nameController.text == prod['name'];
                    final stock = (prod['stockKg'] as num?)?.toDouble() ?? 0.0;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
                      title: Row(
                        children: [
                          Text(prod['name'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                          const Spacer(),
                          Text('${(prod['pricePerKg'] as num).toStringAsFixed(0)} دج/كغ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor)),
                        ],
                      ),
                      subtitle: Text('📦 المخزون: ${stock.toStringAsFixed(1)} كغ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      onTap: () => _selectProduct(prod),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),

            // SELECTED PRODUCT CARD & EDITABLE FIELDS
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم السلعة المحددة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pricePerKgController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'سعر الكيلو (دج)',
                        suffixText: 'دج',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Toggle Mode: Weight vs Amount
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isByWeight = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isByWeight ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '⚖️ البيع بالوزن (غرام)',
                          style: TextStyle(
                            color: _isByWeight ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isByWeight = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isByWeight ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '💵 البيع بالمبلغ (دج)',
                          style: TextStyle(
                            color: !_isByWeight ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Weight or Amount Input
            if (_isByWeight) ...[
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الوزن (غرام)',
                  suffixText: 'غرام',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              // Preset Weight Buttons (100g, 250g, 500g, 1kg, 2kg)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildWeightChip('100 غ', '100'),
                  _buildWeightChip('250 غ', '250'),
                  _buildWeightChip('500 غ', '500'),
                  _buildWeightChip('1.0 كغ', '1000'),
                  _buildWeightChip('2.0 كغ', '2000'),
                  _buildWeightChip('5.0 كغ', '5000'),
                ],
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المطلوب (مثال: أعطيني 200 دج عدس)',
                  suffixText: 'دج',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildAmountChip('50 دج', '50'),
                  _buildAmountChip('100 دج', '100'),
                  _buildAmountChip('150 دج', '150'),
                  _buildAmountChip('200 دج', '200'),
                  _buildAmountChip('300 دج', '300'),
                  _buildAmountChip('500 دج', '500'),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Calculation Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('${total.toStringAsFixed(2)} دج', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800])),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('الوزن المحسوب:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        grams >= 1000 ? '${(grams / 1000.0).toStringAsFixed(2)} كغ' : '${grams.toInt()} غرام',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Add to Cart CTA
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text('إضافة للفاتورة الآن 🛒', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: _onAddToCart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChip(String label, String value) {
    final isSelected = _weightController.text == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _weightController.text = value;
          });
        }
      },
    );
  }

  Widget _buildAmountChip(String label, String value) {
    final isSelected = _amountController.text == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _amountController.text = value;
          });
        }
      },
    );
  }
}
