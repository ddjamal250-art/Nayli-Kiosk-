import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/product_image_picker_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/utils/category_taxonomy.dart';
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
import '../widgets/coffee_recipe_modal.dart';
import '../../domain/entities/liquid_decant_config.dart';
import '../widgets/liquid_decant_calculator_card.dart';
import '../../../../core/widgets/liquid_bottle_indicator.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {

  String _formatDouble(double val) {
    if (val == val.toInt()) return val.toInt().toString();
    String s = val.toStringAsFixed(3);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _baseUnitNameCtrl;
  late TextEditingController _pluCodeCtrl;

  // --- تركيبة ووصفة القهوة الجاهزة ---
  String? _coffeeRecipeJson;

  // --- إعدادات الميزان والوزن ---
  bool _isWeighted = false;

  // --- إعدادات تجزئة وتقسيم السوائل والعطور ---
  String? _liquidConfigJson;

  // --- إعدادات الكرتونة (Large) ---
  bool _hasCarton = false;
  late TextEditingController _cartonBarcodeCtrl;
  late TextEditingController _cartonCapacityCtrl;
  late TextEditingController _cartonCostCtrl;
  late TextEditingController _cartonPriceCtrl;

  // --- إعدادات العلبة (Medium) ---
  bool _hasPack = false;
  late TextEditingController _packBarcodeCtrl;
  late TextEditingController _packCapacityCtrl;
  late TextEditingController _packCostCtrl;
  late TextEditingController _packPriceCtrl;

  // --- العروض الخاصة والتخفيضات الذكي ---
  bool _hasSpecialOffer = false;
  UnitTier _offerTier = UnitTier.small;
  late TextEditingController _offerQtyCtrl;
  late TextEditingController _offerPriceCtrl;
  List<SpecialOffer> _specialOffers = [];

  late String _selectedCategory;
  List<String> _availableCategories = [];
  bool _isSaving = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _availableCategories = CategoryTaxonomy.getDropdownCategories();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p.barcode);
    _nameCtrl = TextEditingController(text: p.name);
    _priceCtrl = TextEditingController(text: p.price > 0 ? _formatDouble(p.price) : '');
    final initialCost = p.costPrice > 0 ? p.costPrice : p.effectiveCostPrice;
    _costPriceCtrl = TextEditingController(text: initialCost > 0 ? _formatDouble(initialCost) : '');
    _stockCtrl = TextEditingController(text: _formatDouble(p.stock));
    _baseUnitNameCtrl = TextEditingController(text: p.baseUnitName);
    _imageUrl = p.imageUrl;
    _pluCodeCtrl = TextEditingController(text: p.pluCode ?? '');
    _selectedCategory = _availableCategories.contains(p.category) ? p.category : 'عام';
    _coffeeRecipeJson = p.coffeeRecipeJson;
    _liquidConfigJson = p.liquidConfigJson;
    _isWeighted = p.isWeighted ||
                  p.unitSystemType == UnitSystemType.weight ||
                  p.barcode.startsWith('SCALE_') ||
                  p.name.contains('كغ') ||
                  p.name.contains('ميزان') ||
                  p.baseUnitName.trim() == 'كغ' ||
                  (p.pluCode != null && p.pluCode!.isNotEmpty);

    // 1. تحميل إعدادات العلبة أولاً لتحديد مضاعف العلبة
    final packUnit = p.units.where((u) => u.tier == UnitTier.medium || u.name.contains('علب')).firstOrNull;
    if (packUnit != null) {
      _hasPack = packUnit.isEnabled;
      _packBarcodeCtrl = TextEditingController(text: packUnit.barcode ?? '');
      _packCapacityCtrl = TextEditingController(text: _formatDouble(packUnit.multiplier));
      _packCostCtrl = TextEditingController(text: packUnit.cost > 0 ? _formatDouble(packUnit.cost) : '');
      _packPriceCtrl = TextEditingController(text: packUnit.price > 0 ? _formatDouble(packUnit.price) : '');
    } else {
      _hasPack = false;
      _packBarcodeCtrl = TextEditingController();
      _packCapacityCtrl = TextEditingController(text: '6');
      _packCostCtrl = TextEditingController();
      _packPriceCtrl = TextEditingController();
    }

    // 2. تحميل إعدادات الكرتونة (حساب السعة بالنسبة للواجهة بدون مضاعفة متكررة)
    final cartonUnit = p.units.where((u) => u.tier == UnitTier.large || u.name.contains('كرتون')).firstOrNull;
    if (cartonUnit != null) {
      _hasCarton = cartonUnit.isEnabled;
      _cartonBarcodeCtrl = TextEditingController(text: cartonUnit.barcode ?? '');
      // إذا كانت العلبة مفعلة، فإن الحقل في الواجهة يطلب (كم علبة في الكرتونة؟)، لذا نقسم على سعة العلبة
      final double cartonUIVal = cartonUnit.multiplier;
      _cartonCapacityCtrl = TextEditingController(text: _formatDouble(cartonUIVal));
      _cartonCostCtrl = TextEditingController(text: cartonUnit.cost > 0 ? _formatDouble(cartonUnit.cost) : '');
      _cartonPriceCtrl = TextEditingController(text: cartonUnit.price > 0 ? _formatDouble(cartonUnit.price) : '');
    } else {
      _hasCarton = false;
      _cartonBarcodeCtrl = TextEditingController();
      _cartonCapacityCtrl = TextEditingController(text: '24');
      _cartonCostCtrl = TextEditingController();
      _cartonPriceCtrl = TextEditingController();
    }

    // تحميل العروض الخاصة والتخفيضات إن وجدت
    _specialOffers = List<SpecialOffer>.from(p.specialOffers);
    if (_specialOffers.isEmpty && p.specialOffer != null && p.specialOffer!.isValid) {
      _specialOffers = [p.specialOffer!];
    }
    if (_specialOffers.isNotEmpty) {
      _hasSpecialOffer = _specialOffers.any((o) => o.isEnabled);
      final first = _specialOffers.first;
      _offerTier = first.targetTier;
      _offerQtyCtrl = TextEditingController(text: _formatDouble(first.quantity));
      _offerPriceCtrl = TextEditingController(text: _formatDouble(first.offerPrice));
    } else {
      _hasSpecialOffer = false;
      _offerTier = UnitTier.small;
      _offerQtyCtrl = TextEditingController(text: '3');
      _offerPriceCtrl = TextEditingController();
    }
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
      // Note: We deliberately do NOT overwrite the category during edit 
      // so the product does not jump to a different tab and seem to 'disappear'.
      
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
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
        ),
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

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final plu = _pluCodeCtrl.text.trim();

    final cartonCapUI = _parsePrice(_cartonCapacityCtrl.text);
    final packCapUI = _parsePrice(_packCapacityCtrl.text);
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
            : (_hasPack && packCapUI > 0 && packCost > 0 ? (packCost / packCapUI) : widget.product.effectiveCostPrice));

    final rawBc = _barcodeCtrl.text.trim();
    final validBc = (rawBc.isEmpty || rawBc.startsWith('NO_BARCODE_'))
        ? BarcodeGeneratorHelper.generateUniqueInStoreEan13()
        : rawBc;

    final effectiveBaseUnit = _isWeighted && (_baseUnitNameCtrl.text.isEmpty || _baseUnitNameCtrl.text == 'قطعة' || _baseUnitNameCtrl.text == 'حبة')
        ? 'كغ'
        : baseName;

    // إضافة وحدة القطعة/الحبة أو الكيلوغرام الأساسية (Small Tier) لضمان اتساق الحسابات
    units.add(ProductUnit(
      name: effectiveBaseUnit,
      tier: UnitTier.small,
      multiplier: 1.0,
      price: _parsePrice(_priceCtrl.text),
      cost: effectiveCost,
      barcode: validBc,
      isWeighable: _isWeighted,
    ));

    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      barcode: validBc,
      price: _parsePrice(_priceCtrl.text),
      costPrice: effectiveCost,
      stock: _parsePrice(_stockCtrl.text),
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: effectiveBaseUnit,
      units: units,
      specialOffers: resolvedOffers,
      pluCode: plu.isNotEmpty ? plu : null,
      isWeighted: _isWeighted,
      unitSystemType: _isWeighted ? UnitSystemType.weight : (_liquidConfigJson != null ? UnitSystemType.volume : widget.product.unitSystemType),
      coffeeRecipeJson: _coffeeRecipeJson,
      liquidConfigJson: _liquidConfigJson,
      isCoffeeMachineProduct: widget.product.isCoffeeMachineProduct || _coffeeRecipeJson != null || _selectedCategory.contains('قهوة'),
      packMultiplier: _hasPack && packCapUI > 0 ? packCapUI.toInt() : 1,
      packsPerCarton: cartonCapUI > 0 ? cartonCapUI.toInt() : 10,
      hasMultiUnit: _hasCarton || _hasPack,
    );

    // الحفظ المباشر والفوري في قاعدة بيانات Hive لمنع أي تأخير أو تزامن غير مكتمل
    final model = ProductModel.fromEntity(updatedProduct);
    await HiveDatabase.productBox.put(model.id, model);

    if (mounted) {
      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      SnackbarHelper.showSuccess(context, 'تم تعديل المنتج بنجاح');
      context.pop();
    }
  }

  void _openLiquidDecantEditor() {
    final currentCfg = LiquidDecantConfig.tryParse(_liquidConfigJson) ??
        LiquidDecantConfig.defaultPerfumeConfig().copyWith(
          containerCost: _parsePrice(_costPriceCtrl.text) > 0 ? _parsePrice(_costPriceCtrl.text) : 12000,
          containerVolume: _parsePrice(_stockCtrl.text) > 0 ? _parsePrice(_stockCtrl.text) : 100,
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🧴', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      'إعدادات تجزئة وتقسيم السوائل والعطور',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: LiquidDecantCalculatorCard(
                  initialConfig: currentCfg,
                  onChanged: (cfg) {
                    setState(() {
                      _liquidConfigJson = cfg.toJsonString();
                      if (cfg.costPerMl > 0) {
                        _costPriceCtrl.text = _formatDouble(cfg.costPerMl);
                      }
                      if (cfg.defaultPricePerMl > 0) {
                        _priceCtrl.text = _formatDouble(cfg.defaultPricePerMl);
                      }
                      _baseUnitNameCtrl.text = cfg.unitName;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حفظ الإعدادات والتأكيد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المنتج'),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isWeighted ? Colors.teal.withOpacity(0.07) : Colors.grey.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isWeighted ? Colors.teal : Colors.grey.shade300,
                      width: _isWeighted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _isWeighted,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.scale_rounded, color: _isWeighted ? Colors.teal : Colors.grey),
                            const SizedBox(width: 8),
                            const Text('سلعة ميزان (تباع بالوزن / كغ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        subtitle: Text(
                          _isWeighted 
                            ? 'مفعلة: ستظهر السلعة تلقائياً في قسم الميزان وشاشة الميزان الافتراضي (F8) وتدعم الوزن والجرامات.' 
                            : 'غير مفعلة: تباع السلعة بالقطعة أو الحبة العادية.',
                          style: TextStyle(fontSize: 12, color: _isWeighted ? Colors.teal.shade800 : Colors.grey),
                        ),
                        activeColor: Colors.teal,
                        onChanged: (val) {
                          setState(() {
                            _isWeighted = val;
                            if (_isWeighted) {
                              if (_baseUnitNameCtrl.text.isEmpty || _baseUnitNameCtrl.text == 'قطعة' || _baseUnitNameCtrl.text == 'حبة') {
                                _baseUnitNameCtrl.text = 'كغ';
                              }
                            }
                          });
                        },
                      ),
                      if (_isWeighted) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const InputLabel(text: 'كود PLU للميزان التجاري (اختياري)'),
                                  TextFormField(
                                    controller: _pluCodeCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: 'مثال: 1، 42...',
                                      prefixIcon: const Icon(Icons.pin, size: 18, color: Colors.teal),
                                      suffixIcon: _pluCodeCtrl.text.isNotEmpty 
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 16), 
                                              onPressed: () => setState(() => _pluCodeCtrl.clear()),
                                            ) 
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal,
                                  side: const BorderSide(color: Colors.teal),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                icon: const Icon(Icons.qr_code, size: 18),
                                label: const Text('توليد كود ميزان', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setState(() {
                                    _barcodeCtrl.text = 'SCALE_${DateTime.now().millisecondsSinceEpoch % 100000}';
                                  });
                                  SoundService.playScanBeep();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
            // --- المخزون الحالي ---
            _SectionCard(
              title: 'المخزون الحالي',
              icon: Icons.inventory_2_outlined,
              children: [
                InputLabel(text: _isWeighted ? 'الكمية المتوفرة بالمخزون حالياً (بالكيلوغرام كغ)' : 'الكمية المتوفرة بالمخزون حالياً (بالحبة)'),
                TextFormField(controller: _stockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            const SizedBox(height: 16),

            // --- تركيبة ووصفة القهوة الجاهزة ---
            if (_coffeeRecipeJson != null || _selectedCategory.contains('قهوة') || widget.product.isCoffeeMachineProduct) ...[
              _SectionCard(
                title: 'تركيبة ووصفة القهوة الجاهزة ☕',
                icon: Icons.coffee_rounded,
                children: [
                  Builder(
                    builder: (ctx) {
                      List<dynamic> recipeItems = [];
                      if (_coffeeRecipeJson != null) {
                        try {
                          recipeItems = jsonDecode(_coffeeRecipeJson!);
                        } catch (_) {}
                      }

                      if (recipeItems.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.brown.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.brown.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'هذا المنتج مصنف كمشروب قهوة ولكن لا يملك تركيبة استهلاك مواد خام محددة بعد.',
                                style: TextStyle(fontSize: 12.5, color: Colors.brown),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.brown,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: const Text('إعداد وربط وصفة القهوة والمواد الخام الآن ☕',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () async {
                                  final res = await CoffeeRecipeModal.show(context, existingProduct: widget.product);
                                  if (res != null && mounted) {
                                    setState(() {
                                      _coffeeRecipeJson = res.coffeeRecipeJson;
                                      if (res.costPrice > 0) {
                                        _costPriceCtrl.text = _formatDouble(res.costPrice);
                                      }
                                      if (res.price > 0 && (_priceCtrl.text.isEmpty || _priceCtrl.text == '0')) {
                                        _priceCtrl.text = _formatDouble(res.price);
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD7CCC8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'المواد الخام المستهلكة في الكوب الواحد:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${recipeItems.length} مكونات',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...recipeItems.map((item) {
                              final name = item['rawProductName'] ?? 'مادة خام';
                              final qty = item['qty'] ?? '';
                              final unit = item['unit'] == 'g' ? 'غرام' : (item['unit'] == 'ml' ? 'مل' : 'حبة');
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 14, color: Colors.brown),
                                    const SizedBox(width: 6),
                                    Text('$name:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text('$qty $unit', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.brown,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('تعديل الوصفة والمكونات ⚙️',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () async {
                                      final res = await CoffeeRecipeModal.show(context, existingProduct: widget.product.copyWith(
                                        coffeeRecipeJson: _coffeeRecipeJson,
                                        price: double.tryParse(_priceCtrl.text) ?? widget.product.price,
                                      ));
                                      if (res != null && mounted) {
                                        setState(() {
                                          _coffeeRecipeJson = res.coffeeRecipeJson;
                                          if (res.costPrice > 0) {
                                            _costPriceCtrl.text = _formatDouble(res.costPrice);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text('إلغاء الوصفة', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setState(() {
                                      _coffeeRecipeJson = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // --- إعدادات تقسيم وتعبئة السوائل والعطور ومستحضرات التجميل ---
            Builder(
              builder: (context) {
                final cfg = LiquidDecantConfig.tryParse(_liquidConfigJson);
                final hasConfig = cfg != null;
                final isLiquidCandidate = hasConfig ||
                    _selectedCategory.contains('عطور') ||
                    _selectedCategory.contains('تجميل') ||
                    _baseUnitNameCtrl.text.contains('مل') ||
                    _baseUnitNameCtrl.text.contains('غرام');

                if (!isLiquidCandidate && !hasConfig) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.water_drop_outlined, color: Colors.teal),
                      label: const Text('تفعيل ميزة تقسيم وتعبئة السوائل والعطور 🧴', style: TextStyle(color: Colors.teal)),
                      onPressed: _openLiquidDecantEditor,
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('🧴', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text(
                                'تجزئة وتقسيم السوائل والعطور ومستحضرات التجميل:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40)),
                              ),
                            ],
                          ),
                          if (hasConfig)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${cfg.formats.where((f) => f.isEnabled).length} مقاسات قوارير',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (hasConfig) ...[
                        Row(
                          children: [
                            LiquidBottleIndicator(
                              fillRatio: cfg.fillRatio(widget.product.stock),
                              stockMl: widget.product.stock,
                              unitName: cfg.unitName,
                              animate: true,
                              size: 70,
                              showLabel: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تكلفة المليلتر: ${cfg.costPerMl.toStringAsFixed(2)} دج',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'سعة العبوة الأم: ${cfg.containerVolume.toInt()} ${cfg.unitName} (هدر: ${cfg.spillageLossPercent}%)',
                                    style: TextStyle(fontSize: 11.5, color: Colors.teal.shade800),
                                  ),
                                  if (cfg.defaultPricePerMl > 0)
                                    Text(
                                      'سعر التعبئة الحرة: ${cfg.defaultPricePerMl.toStringAsFixed(1)} دج/${cfg.unitName}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('تعديل جدول القوارير وهوامش الربح 🧴⚙️', style: TextStyle(fontSize: 12)),
                                onPressed: _openLiquidDecantEditor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('إلغاء التقسيم', style: TextStyle(fontSize: 11)),
                              onPressed: () => setState(() => _liquidConfigJson = null),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'يمكنك ضبط أحجام قوارير البيع (10ml, 30ml, 50ml...) وحساب تكلفة القوارير الفارغة وأرباح كل حجم تلقائياً.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF00695C)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('تهيئة جدول القوارير وهوامش الربح الآن 🧴✨', style: TextStyle(fontSize: 12)),
                          onPressed: _openLiquidDecantEditor,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // --- تفاصيل الوحدات العمودية الثلاث والعروض الخاصة ---
            ProductUnitsEditorWidget(
              hasCarton: _hasCarton,
              onHasCartonChange: (v) => setState(() => _hasCarton = v),
              cartonBarcodeCtrl: _cartonBarcodeCtrl,
              cartonCapacityCtrl: _cartonCapacityCtrl,
              cartonCostCtrl: _cartonCostCtrl,
              cartonPriceCtrl: _cartonPriceCtrl,

              hasPack: _hasPack,
              onHasPackChange: (v) {
                setState(() {
                  _hasPack = v;
                });
              },
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
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
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.borderColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor ?? Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}


