import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';

class SmartScaleModal extends StatefulWidget {
  const SmartScaleModal({super.key});

  @override
  State<SmartScaleModal> createState() => _SmartScaleModalState();
}

class _SmartScaleModalState extends State<SmartScaleModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pricePerKgController = TextEditingController();
  final TextEditingController _costPerKgController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(); // in grams
  final TextEditingController _amountController = TextEditingController(); // in DZD

  bool _isByWeight = true; // true = by weight, false = by fixed amount (e.g. 100 DZD)
  String? _selectedProductId;
  double _currentStockKg = 50.0;
  String _selectedCategory = 'الكل';

  List<Map<String, dynamic>> _scaleProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  List<String> get _categories {
    final cats = <String>['الكل'];
    final seen = <String>{'الكل'};
    for (final p in _scaleProducts) {
      final c = p['category']?.toString().trim();
      if (c != null && c.isNotEmpty && !seen.contains(c)) {
        seen.add(c);
        cats.add(c);
      }
    }
    return cats;
  }

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

    for (final p in pBox.values) {
      if (p.isWeighted == true || p.unitSystemTypeIndex == 1 || p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ')) {
        list.add({
          'id': p.id,
          'name': p.name,
          'pricePerKg': p.price,
          'costPerKg': p.costPrice,
          'stockKg': p.stock.toDouble(),
          'barcode': p.barcode,
          'category': p.category,
        });
      }
    }

    setState(() {
      _scaleProducts = list;
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'الكل';
      }
      _filteredProducts = List.from(list);
    });
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  void _onSearchChanged() {
    final rawQuery = _searchController.text.trim();
    final query = _normalizeArabic(rawQuery);

    setState(() {
      _filteredProducts = _scaleProducts.where((p) {
        final matchesCat = _selectedCategory == 'الكل' || p['category'] == _selectedCategory;
        if (!matchesCat) return false;

        if (query.isEmpty) return true;
        final name = _normalizeArabic(p['name']?.toString() ?? '');
        final barcode = p['barcode']?.toString().toLowerCase() ?? '';
        return name.contains(query) || barcode.contains(query);
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _onSearchChanged();
  }

  void _selectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProductId = product['id']?.toString() ?? product['barcode']?.toString();
      _nameController.text = product['name'] ?? '';
      _pricePerKgController.text = (product['pricePerKg'] as num?)?.toStringAsFixed(0) ?? '0';
      _costPerKgController.text = (product['costPerKg'] as num?)?.toStringAsFixed(0) ?? '0';
      _currentStockKg = (product['stockKg'] as num?)?.toDouble() ?? 50.0;
    });
    SoundService.playScanBeep();
  }

  void _showAddScaleProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final directKgCtrl = TextEditingController(text: '50');
    final bagsCountCtrl = TextEditingController(text: '2');
    final bagWeightCtrl = TextEditingController(text: '25');
    final supplierCtrl = TextEditingController();
    bool isBagsMode = false;
    final availableCats = <String>{};
    for (final p in HiveDatabase.productBox.values) {
      final c = p.category.trim();
      if (c.isNotEmpty && c != 'الكل') availableCats.add(c);
    }
    if (availableCats.isEmpty) {
      availableCats.addAll(['ميزان', 'مواد غذائية', 'خضر وفواكه', 'بقوليات', 'توابل']);
    }
    final catList = availableCats.toList()..sort();
    String selectedCat = catList.contains('ميزان') ? 'ميزان' : catList.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(context.tr('إضافة مادة ميزان جديدة وتفاصيل المخزون'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.tr('item_name'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: InputDecoration(
                    labelText: context.tr('category'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: catList.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedCat = val);
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('selling_price_per_kg'),
                          suffixText: AppConstants.currencySymbol,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('cost_price'),
                          suffixText: AppConstants.currencySymbol,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                      label: Text(context.tr('by_bags_sacks'), style: const TextStyle(fontSize: 11)),
                      selected: isBagsMode,
                      onSelected: (v) => setDialogState(() => isBagsMode = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(context.tr('by_direct_kg'), style: const TextStyle(fontSize: 11)),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.tr('sacks_count'),
                            suffixText: 'شكارة',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bagWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: context.tr('sack_weight'),
                            suffixText: 'كغ',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          '📦 إجمالي المخزون: $total كغ ($bags شكارة × $weight كغ)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: directKgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('direct_total_stock_kg'),
                      suffixText: 'كغ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextField(
                  controller: supplierCtrl,
                  decoration: InputDecoration(
                    labelText: context.tr('supplier_optional'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
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
                  category: selectedCat,
                  price: price,
                  costPrice: cost,
                  stock: totalStock.toDouble(),
                  isWeighted: true,
                  unit: 'كغ',
                );

                context.read<ProductBloc>().add(AddProduct(newProd));

                final itemMap = {
                  'id': newProdId,
                  'name': name,
                  'category': selectedCat,
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
                SoundService.playCheckoutSuccess();
                context.showAppSnackBar(
                  '✅ تم حفظ مادة الميزان ($name) بمخزون $totalStock كغ!',
                  backgroundColor: Colors.green[800]!,
                );
              },
              child: Text(context.tr('save_and_insert'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      context.showAppSnackBar('يرجى تحديد وزن أو مبلغ صحيح!', backgroundColor: Colors.red[800]!);
      return;
    }

    final String weightLabel = grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} كغ' : '${grams.toInt()} غ';
    final customItemName = '$name ($weightLabel)';
    final rawBarcode = 'SCALE_${DateTime.now().millisecondsSinceEpoch}';

    final pBox = HiveDatabase.productBox;
    final matching = pBox.values.where((p) => p.name.trim() == name.trim() || p.id == _selectedProductId).firstOrNull;

    if (matching != null) {
      context.read<BillingBloc>().add(AddProductToCartEvent(
        matching,
        weightKg: weightKg,
        customPrice: finalTotal,
      ));
    } else {
      context.read<BillingBloc>().add(AddCustomItemEvent(
        name: customItemName,
        price: finalTotal,
        costPrice: (costPerKg * weightKg).roundToDouble(),
        quantity: 1,
        barcode: rawBarcode,
      ));
    }

    Navigator.pop(context);
    SoundService.playScanBeep();
    context.showAppSnackBar(
      '✅ تمت إضافة $customItemName بمبلغ $finalTotal ${AppConstants.currencySymbol}!',
      backgroundColor: Colors.teal[800]!,
      icon: Icons.scale_rounded,
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
                  child: Icon(Icons.scale_rounded, color: AppTheme.primaryColor, size: 24),
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
                      hintText: context.tr('search_scale_item_hint'),
                      prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.primaryColor),
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
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('add_item_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _showAddScaleProductDialog,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Category Filter Chips (Only shown when products exist in multiple categories)
            if (_scaleProducts.isNotEmpty && _categories.length > 2) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                      onSelected: (_) => _onCategorySelected(cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            // SCALE PRODUCTS HORIZONTAL LIST / GRID
            if (_scaleProducts.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا توجد منتجات ميزان مسجلة في المخزون بعد. يرجى إضافة منتجات ميزان وتفعيل خيار (يباع بالوزن) أولاً.',
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 72,
                child: _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد مواد تطابق "${_searchController.text}"',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = _filteredProducts[index];
                        final isSelected = _nameController.text.trim() == item['name'].toString().trim();
                        final price = (item['pricePerKg'] as num?)?.toDouble() ?? 0.0;

                        return InkWell(
                          onTap: () => _selectProduct(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${price.toStringAsFixed(0)} ${AppConstants.currencySymbol}/كغ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // PRODUCT DETAILS FORM (Name & Price/Kg)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('selected_item'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _pricePerKgController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('price_per_kg'),
                      suffixText: AppConstants.currencySymbol,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mode Selector: By Weight (grams) vs By Amount (DZD)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.tr('sell_by_weight_kg'))),
                    selected: _isByWeight,
                    onSelected: (val) {
                      setState(() {
                        _isByWeight = true;
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.tr('sell_by_amount_money'))),
                    selected: !_isByWeight,
                    onSelected: (val) {
                      setState(() {
                        _isByWeight = false;
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Input Fields depending on Mode
            if (_isByWeight) ...[
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr('weight_in_grams'),
                  hintText: 'مثال: 500 للرطل، 1000 للكيلو، 250 للربع...',
                  suffixText: 'غرام',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Preset Weight Buttons (250g, 500g, 1kg, 2kg, 5kg)
              Wrap(
                spacing: 6,
                children: [
                  _buildQuickWeightChip('100 غ', 100),
                  _buildQuickWeightChip('250 غ (ربع)', 250),
                  _buildQuickWeightChip('500 غ (رطل)', 500),
                  _buildQuickWeightChip('1 كغ', 1000),
                  _buildQuickWeightChip('2 كغ', 2000),
                  _buildQuickWeightChip('5 كغ', 5000),
                ],
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${context.tr("amount")} (${context.tr("currency_symbol")})',
                  hintText: 'مثال: اعطيني قيس 100 دج أو 200 دج...',
                  suffixText: AppConstants.currencySymbol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Preset Amount Buttons (50 DA, 100 DA, 200 DA, 500 DA, 1000 DA)
              Wrap(
                spacing: 6,
                children: [
                  _buildQuickAmountChip('50 دج', 50),
                  _buildQuickAmountChip('100 دج', 100),
                  _buildQuickAmountChip('200 دج', 200),
                  _buildQuickAmountChip('500 دج', 500),
                  _buildQuickAmountChip('1000 دج', 1000),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // LIVE CALCULATION RESULT CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('calculated_weight_label'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        grams >= 1000 ? '${(grams / 1000).toStringAsFixed(2)} كغ' : '${grams.toInt()} غرام',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.tr('total_amount_label'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '${total.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ADD TO CART BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_shopping_cart, size: 20),
              label: Text(
                'إضافة إلى السلة (${total.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _onAddToCart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickWeightChip(String label, int grams) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _weightController.text = grams.toString();
        });
      },
    );
  }

  Widget _buildQuickAmountChip(String label, int amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _amountController.text = amount.toString();
        });
      },
    );
  }
}
