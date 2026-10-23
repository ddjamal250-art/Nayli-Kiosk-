import 'package:flutter/material.dart';
import '../widgets/product_image_picker_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/master_catalog_service.dart';
import '../../../../core/utils/product_image_search_service.dart';
import '../../data/models/product_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_units_editor_widget.dart';
import '../widgets/product_options_config_modal.dart';
import '../../domain/entities/product_option.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '10');
  final _baseUnitNameCtrl = TextEditingController(text: 'حبة');
  final _pluCodeCtrl = TextEditingController();

  // --- إعدادات الكرتونة (Large) ---
  bool _hasCarton = false;
  final _cartonBarcodeCtrl = TextEditingController();
  final _cartonCapacityCtrl = TextEditingController(text: '24');
  final _cartonCostCtrl = TextEditingController();
  final _cartonPriceCtrl = TextEditingController();

  // --- إعدادات العلبة (Medium) ---
  bool _hasPack = false;
  final _packBarcodeCtrl = TextEditingController();
  final _packCapacityCtrl = TextEditingController(text: '6');
  final _packCostCtrl = TextEditingController();
  final _packPriceCtrl = TextEditingController();

  // --- العروض الخاصة والتخفيض الذكي ---
  bool _hasSpecialOffer = false;
  UnitTier _offerTier = UnitTier.small;
  final _offerQtyCtrl = TextEditingController(text: '3');
  final _offerPriceCtrl = TextEditingController();
  List<SpecialOffer> _specialOffers = [];

  String _selectedCategory = 'عام';
  String? _imageUrl;
  bool _isSaving = false;
  List<String> _availableCategories = [];
  final UnitSystemType _unitSystemType = UnitSystemType.discrete;
  String? _optionsConfigJson;

  @override
  void initState() {
    super.initState();
    _availableCategories = CategoryTaxonomy.getDropdownCategories();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _baseUnitNameCtrl.dispose();
    _pluCodeCtrl.dispose();
    _cartonBarcodeCtrl.dispose();
    _cartonCapacityCtrl.dispose();
    _cartonCostCtrl.dispose();
    _cartonPriceCtrl.dispose();
    _packBarcodeCtrl.dispose();
    _packCapacityCtrl.dispose();
    _packCostCtrl.dispose();
    _packPriceCtrl.dispose();
    _offerQtyCtrl.dispose();
    _offerPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryAutoFetchProductInfo(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    // 1. Instant check in Algerian Master Catalog
    final masterMatch = MasterCatalogService.searchByBarcode(cleanBarcode);
    if (masterMatch != null) {
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = masterMatch.name;
      }
      if (masterMatch.category != null && masterMatch.category!.isNotEmpty && _selectedCategory == _availableCategories.first) {
        if (_availableCategories.contains(masterMatch.category!)) {
          _selectedCategory = masterMatch.category!;
        }
      }
      if ((_imageUrl == null || _imageUrl!.isEmpty) &&
          masterMatch.imageUrl != null &&
          masterMatch.imageUrl!.isNotEmpty) {
        setState(() => _imageUrl = masterMatch.imageUrl);
        return;
      }
    }

    // 2. Auto-fetch image if empty
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      try {
        final localPath = await ProductImageSearchService.instance.autoFetchProductImage(
          barcode: cleanBarcode,
          name: _nameCtrl.text.trim(),
        );
        if (localPath != null && mounted) {
          setState(() => _imageUrl = localPath);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.bolt, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('تم جلب صورة المنتج تلقائياً وحفظها محلياً ⚡'),
                ],
              ),
              backgroundColor: Color(0xFF1B5E20),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeCtrl.text = result);
      SoundService.playScanBeep();
      _tryAutoFetchProductInfo(result);
    }
  }

  void _addCustomCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصنيف جديد'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم التصنيف')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                CategoryTaxonomy.addCustomCategory(name);
                setState(() {
                  _availableCategories = CategoryTaxonomy.getDropdownCategories();
                  _selectedCategory = name;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  double _parsePrice(String text) {
    final cleaned = text.trim().replaceAll(',', '.').replaceAll('،', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _formatDouble(double val) {
    if (val == val.toInt()) return val.toInt().toString();
    String s = val.toStringAsFixed(3);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void _showMultiUnitStockCalculator() {
    final totalStock = _parsePrice(_stockCtrl.text).floor();
    final cCap = _parsePrice(_cartonCapacityCtrl.text).floor();
    final pCap = _parsePrice(_packCapacityCtrl.text).floor();

    int rem = totalStock > 0 ? totalStock : 0;
    int initCartons = (_hasCarton && cCap > 0) ? (rem ~/ cCap) : 0;
    if (_hasCarton && cCap > 0) rem = rem % cCap;
    int initPacks = (_hasPack && pCap > 0) ? (rem ~/ pCap) : 0;
    if (_hasPack && pCap > 0) rem = rem % pCap;
    int initPieces = rem;

    final cCtrl = TextEditingController(text: initCartons.toString());
    final pCtrl = TextEditingController(text: initPacks.toString());
    final piCtrl = TextEditingController(text: initPieces.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cVal = int.tryParse(cCtrl.text.trim()) ?? 0;
          final pVal = int.tryParse(pCtrl.text.trim()) ?? 0;
          final piVal = int.tryParse(piCtrl.text.trim()) ?? 0;
          final calcTotal = (_hasCarton && cCap > 0 ? cVal * cCap : 0) +
              (_hasPack && pCap > 0 ? pVal * pCap : 0) +
              piVal;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.calculate_rounded, color: Colors.teal),
                SizedBox(width: 8),
                Text('حاسبة المخزون حسب الوحدات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasCarton && cCap > 0) ...[
                    TextField(
                      controller: cCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'عدد الكراتين (سعة الكرتونة: $cCap حبة)',
                        suffixText: 'كرتونة',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_hasPack && pCap > 0) ...[
                    TextField(
                      controller: pCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'عدد العلب المفردة (سعة العلبة: $pCap حبة)',
                        suffixText: 'علبة',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: piCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'عدد الحبات المفردة (الفرط)',
                      suffixText: 'حبة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      'الإجمالي المحسوب: $calcTotal ${_baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : "حبة"}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _stockCtrl.text = calcTotal.toString();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('اعتماد المخزون'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMultiUnitStockBreakdown() {
    if (!_hasCarton && !_hasPack) return const SizedBox.shrink();
    final totalStock = _parsePrice(_stockCtrl.text).floor();
    final cCap = _parsePrice(_cartonCapacityCtrl.text).floor();
    final pCap = _parsePrice(_packCapacityCtrl.text).floor();
    final baseName = _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة';

    int rem = totalStock > 0 ? totalStock : 0;
    final cartons = (_hasCarton && cCap > 0) ? (rem ~/ cCap) : 0;
    if (_hasCarton && cCap > 0) rem = rem % cCap;
    final packs = (_hasPack && pCap > 0) ? (rem ~/ pCap) : 0;
    if (_hasPack && pCap > 0) rem = rem % pCap;
    final loosePieces = rem;

    final parts = <String>[];
    if (_hasCarton && cCap > 0) parts.add('📦 $cartons كرتونة');
    if (_hasPack && pCap > 0) parts.add('🛍️ $packs علبة');
    parts.add('🍬 $loosePieces $baseName');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_rounded, size: 18, color: Colors.teal.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفصيل الكمية بالوحدات: ${parts.join(' + ')}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                  Text(
                    'الإجمالي بالوحدة الأساسية: $totalStock $baseName',
                    style: TextStyle(fontSize: 11, color: Colors.teal.shade700),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showMultiUnitStockCalculator,
              icon: const Icon(Icons.calculate_outlined, size: 16),
              label: const Text('إدخال بالكرتونة/العلبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final barcode = _barcodeCtrl.text.trim();
    final plu = _pluCodeCtrl.text.trim();

    final cartonCapUI = _parsePrice(_cartonCapacityCtrl.text);
    final packCapUI = _parsePrice(_packCapacityCtrl.text);
    // سعة الكرتونة في الواجهة هي دائماً إجمالي الحبات في الكرتونة الواحدة
    final cartonMultiplier = cartonCapUI > 0 ? cartonCapUI : 24.0;

    // بناء وحدات البيع (كرتونة، علبة، حبة)
    final List<ProductUnit> units = [];
    if (_hasCarton) {
      final pr = _parsePrice(_cartonPriceCtrl.text);
      final cst = _parsePrice(_cartonCostCtrl.text);
      final bc = _cartonBarcodeCtrl.text.trim();
      units.add(ProductUnit(
        name: 'كرتونة',
        tier: UnitTier.large,
        multiplier: cartonMultiplier,
        price: pr,
        cost: cst,
        barcode: bc.isNotEmpty ? bc : null,
      ));
    }

    if (_hasPack) {
      final cap = packCapUI > 0 ? packCapUI : 6.0;
      final pr = _parsePrice(_packPriceCtrl.text);
      final cst = _parsePrice(_packCostCtrl.text);
      final bc = _packBarcodeCtrl.text.trim();
      units.add(ProductUnit(
        name: 'علبة',
        tier: UnitTier.medium,
        multiplier: cap,
        price: pr,
        cost: cst,
        barcode: bc.isNotEmpty ? bc : null,
      ));
    }

    // بناء العرض الخاص والتخفيض
    List<SpecialOffer> resolvedOffers = [];
    if (_hasSpecialOffer) {
      if (_specialOffers.isNotEmpty) {
        resolvedOffers = _specialOffers.where((o) => o.isValid).toList();
      }
      if (resolvedOffers.isEmpty) {
        final q = _parsePrice(_offerQtyCtrl.text);
        final p = _parsePrice(_offerPriceCtrl.text);
        if (q > 0 && p > 0) {
          resolvedOffers = [
            SpecialOffer(
              targetTier: _offerTier,
              quantity: q,
              offerPrice: p,
              isEnabled: true,
            )
          ];
        }
      }
    }

    final enteredCost = _parsePrice(_costPriceCtrl.text);
    final cartonCost = _hasCarton ? _parsePrice(_cartonCostCtrl.text) : 0.0;
    final packCost = _hasPack ? _parsePrice(_packCostCtrl.text) : 0.0;
    final effectiveCost = enteredCost > 0
        ? enteredCost
        : (_hasCarton && cartonMultiplier > 0 && cartonCost > 0
            ? (cartonCost / cartonMultiplier)
            : (_hasPack && packCapUI > 0 && packCost > 0 ? (packCost / packCapUI) : 0.0));

    final cleanBarcode = barcode.trim();
    final validBarcode = (cleanBarcode.isEmpty || cleanBarcode.startsWith('NO_BARCODE_'))
        ? BarcodeGeneratorHelper.generateUniqueInStoreEan13()
        : cleanBarcode;

    final baseName = _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة';

    // إضافة وحدة القطعة/الحبة الأساسية (Small Tier) لضمان اتساق الحسابات
    units.add(ProductUnit(
      name: baseName,
      tier: UnitTier.small,
      multiplier: 1.0,
      price: _parsePrice(_priceCtrl.text),
      cost: effectiveCost,
      barcode: validBarcode,
    ));

    final product = Product(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      barcode: validBarcode,
      price: _parsePrice(_priceCtrl.text),
      costPrice: effectiveCost,
      wholesalePrice: 0.0,
      stock: _parsePrice(_stockCtrl.text),
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: baseName,
      units: units,
      specialOffers: resolvedOffers,
      pluCode: plu.isNotEmpty ? plu : null,
      unitSystemType: _unitSystemType,
      packMultiplier: _hasPack && packCapUI > 0 ? packCapUI.toInt() : 1,
      packsPerCarton: (_hasPack && packCapUI > 0 && cartonCapUI > 0)
          ? (cartonCapUI / packCapUI).round().clamp(1, 999999)
          : (cartonCapUI > 0 ? cartonCapUI.toInt() : 10),
      hasMultiUnit: _hasCarton || _hasPack,
      optionsConfigJson: _optionsConfigJson,
    );

    // الحفظ المباشر والفوري في قاعدة بيانات Hive لمنع أي تأخير
    final model = ProductModel.fromEntity(product);
    await HiveDatabase.productBox.put(model.id, model);

    if (mounted) {
      context.read<ProductBloc>().add(AddProduct(product));
      SnackbarHelper.showSuccess(context, 'تم إضافة المنتج بنجاح');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج جديد'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: CircularProgressIndicator(color: Colors.white)))
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveProduct),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- المعلومات الأساسية ---
            _SectionCard(
              title: 'المعلومات الأساسية',
              icon: Icons.info_outline,
              children: [
                ProductImagePickerField(
                  initialImagePath: _imageUrl,
                  barcode: _barcodeCtrl.text,
                  productName: _nameCtrl.text,
                  onImageChanged: (path) => setState(() => _imageUrl = path),
                ),
                const SizedBox(height: 16),
                const InputLabel(text: 'اسم المنتج'),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'الباركود أو رمز QR'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'امسح الباركود أو رمز QR أو اضغط للتوليد التلقائي',
                        ),
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (v) => _tryAutoFetchProductInfo(v),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                      tooltip: 'جلب صورة ومعلومات السلعة تلقائياً ⚡',
                      onPressed: () => _tryAutoFetchProductInfo(_barcodeCtrl.text),
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.teal),
                      tooltip: 'توليد باركود محلي EAN-13 حقيقي للمنتج',
                      onPressed: () {
                        setState(() {
                          _barcodeCtrl.text = BarcodeGeneratorHelper.generateUniqueInStoreEan13();
                        });
                        SoundService.playScanBeep();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                      tooltip: 'مسح الباركود أو رمز QR بالكاميرا',
                      onPressed: _scanBarcode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'كود PLU للميزان التجاري (اختياري)'),
                TextFormField(
                  controller: _pluCodeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'مثال: 1، 42...',
                    prefixIcon: Icon(Icons.scale, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const InputLabel(text: 'التصنيف'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomCategoryDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('تصنيف جديد'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _availableCategories.contains(_selectedCategory) ? _selectedCategory : 'عام',
                  isExpanded: true,
                  items: _availableCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- المخزون الأولي ---
            _SectionCard(
              title: 'المخزون الحالي',
              icon: Icons.inventory_2_outlined,
              children: [
                const InputLabel(text: 'الكمية الإجمالية المتوفرة بالمخزون حالياً (بالوحدة الأساسية / الحبة)'),
                TextFormField(
                  controller: _stockCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                _buildMultiUnitStockBreakdown(),
              ],
            ),
            const SizedBox(height: 16),

            // --- تفاصيل الوحدات العمودية الثلاث والعروض الخاصة ---
            ProductUnitsEditorWidget(
              onInputsChanged: () => setState(() {}),
              hasCarton: _hasCarton,
              onHasCartonChange: (v) => setState(() => _hasCarton = v),
              cartonBarcodeCtrl: _cartonBarcodeCtrl,
              cartonCapacityCtrl: _cartonCapacityCtrl,
              cartonCostCtrl: _cartonCostCtrl,
              cartonPriceCtrl: _cartonPriceCtrl,

              hasPack: _hasPack,
              onHasPackChange: (v) => setState(() => _hasPack = v),
              packBarcodeCtrl: _packBarcodeCtrl,
              packCapacityCtrl: _packCapacityCtrl,
              packCostCtrl: _packCostCtrl,
              packPriceCtrl: _packPriceCtrl,

              pieceBarcodeCtrl: _barcodeCtrl,
              pieceCostCtrl: _costPriceCtrl,
              piecePriceCtrl: _priceCtrl,
              baseUnitNameCtrl: _baseUnitNameCtrl,

              hasSpecialOffer: _hasSpecialOffer,
              onHasSpecialOfferChange: (v) => setState(() => _hasSpecialOffer = v),
              offerTier: _offerTier,
              onOfferTierChange: (tier) {
                if (tier != null) setState(() => _offerTier = tier);
              },
              offerQtyCtrl: _offerQtyCtrl,
              offerPriceCtrl: _offerPriceCtrl,
              specialOffers: _specialOffers,
              onSpecialOffersChange: (v) => setState(() => _specialOffers = v),
            ),
            const SizedBox(height: 16),

            // --- خيارات وتعديلات المنتج (Options & Modifiers) ---
            _SectionCard(
              title: 'خيارات وتعديلات المنتج (الأحجام، الإضافات، النكهات)',
              icon: Icons.tune_rounded,
              trailing: (_optionsConfigJson != null && _optionsConfigJson!.isNotEmpty)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'مفعّلة (${ProductOptionGroup.parseJsonList(_optionsConfigJson).length} مجموعات)',
                        style: TextStyle(color: Colors.teal.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
              children: [
                _buildProductOptionsSection(),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppTheme.primaryColor),
              child: const Text('حفظ المنتج', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductOptionsEditor() async {
    final result = await ProductOptionsConfigModal.show(
      context,
      initialOptionsJson: _optionsConfigJson,
    );
    if (!mounted) return;
    setState(() {
      _optionsConfigJson = result;
    });
  }

  Widget _buildProductOptionsSection() {
    final groups = ProductOptionGroup.parseJsonList(_optionsConfigJson);
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.teal.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أضف خيارات للمنتج تسأل عنها شاشة البيع تلقائياً (مثل: الحجم، الإضافات، السكر، النكهة، مع/بدون) مع تعديل السعر تلقائياً.',
              style: TextStyle(fontSize: 12.5, color: Colors.teal),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إعداد خيارات وتعديلات المنتج ✨'),
              onPressed: _openProductOptionsEditor,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...groups.map((group) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    if (group.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('إلزامي', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        group.isMultiSelect ? 'متعدد الاختيارات' : 'خيار وحيد',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: group.choices.map((c) {
                    final sign = c.priceDelta > 0 ? '+${c.priceDelta.toStringAsFixed(0)}' : (c.priceDelta < 0 ? c.priceDelta.toStringAsFixed(0) : '0');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${c.name} ($sign دج)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('تعديل الخيارات والإضافات'),
              onPressed: _openProductOptionsEditor,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('حذف الخيارات'),
              onPressed: () => setState(() => _optionsConfigJson = null),
            ),
          ],
        ),
      ],
    );
  }
}

// ===================== Helper Widget =====================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? borderColor;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.icon, required this.children, this.borderColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor ?? Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (trailing != null) ...[const Spacer(), trailing!],
            ]),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
