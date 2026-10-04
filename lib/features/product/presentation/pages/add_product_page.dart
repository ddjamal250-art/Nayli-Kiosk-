import 'package:flutter/material.dart';
import '../widgets/product_image_picker_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_units_editor_widget.dart';

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
  UnitSystemType _unitSystemType = UnitSystemType.discrete;

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

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeCtrl.text = result);
      SoundService.playScanBeep();
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

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final barcode = _barcodeCtrl.text.trim();
    final plu = _pluCodeCtrl.text.trim();

    final cartonCapUI = _parsePrice(_cartonCapacityCtrl.text);
    final packCapUI = _parsePrice(_packCapacityCtrl.text);
    final cartonMultiplier = _hasPack ? (cartonCapUI * packCapUI) : (cartonCapUI > 0 ? cartonCapUI : 24.0);

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
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة',
      units: units,
      specialOffers: resolvedOffers,
      pluCode: plu.isNotEmpty ? plu : null,
      unitSystemType: _unitSystemType,
    );

    context.read<ProductBloc>().add(AddProduct(product));

    if (mounted) {
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
                  onImageChanged: (path) => setState(() => _imageUrl = path),
                ),
                const SizedBox(height: 16),
                const InputLabel(text: 'اسم المنتج'),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'الباركود'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'امسح الباركود أو اضغط للتوليد التلقائي',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                      tooltip: 'مسح بالماسح الضوئي أو الكاميرا',
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
                const InputLabel(text: 'الكمية المتوفرة بالمخزون حالياً (بالحبة)'),
                TextFormField(controller: _stockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
            const SizedBox(height: 16),

            // --- تفاصيل الوحدات العمودية الثلاث والعروض الخاصة ---
            ProductUnitsEditorWidget(
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


