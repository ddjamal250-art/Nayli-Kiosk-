import 'package:flutter/material.dart';
import '../widgets/product_image_picker_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_units_editor_widget.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _baseUnitNameCtrl;
  late TextEditingController _pluCodeCtrl;

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

  // --- العروض الخاصة والتخفيض الذكي ---
  bool _hasSpecialOffer = false;
  UnitTier _offerTier = UnitTier.small;
  late TextEditingController _offerQtyCtrl;
  late TextEditingController _offerPriceCtrl;

  late String _selectedCategory;
  List<String> _availableCategories = [];
  bool _isSaving = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasCarton && _hasPack) {
        final cCap = double.tryParse(_cartonCapacityCtrl.text) ?? 24.0;
        final pCap = double.tryParse(_packCapacityCtrl.text) ?? 6.0;
        if (pCap > 0) {
          _cartonCapacityCtrl.text = (cCap / pCap).toStringAsFixed(0);
        }
      }
    });
    _availableCategories = CategoryTaxonomy.getDropdownCategories();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p.barcode);
    _nameCtrl = TextEditingController(text: p.name);
    _priceCtrl = TextEditingController(text: p.price > 0 ? p.price.toStringAsFixed(0) : '');
    _costPriceCtrl = TextEditingController(text: p.costPrice > 0 ? p.costPrice.toStringAsFixed(0) : '');
    _stockCtrl = TextEditingController(text: p.stock.toStringAsFixed(0));
    _baseUnitNameCtrl = TextEditingController(text: p.baseUnitName);
    _imageUrl = p.imageUrl;
    _pluCodeCtrl = TextEditingController(text: p.pluCode ?? '');
    _selectedCategory = _availableCategories.contains(p.category) ? p.category : 'عام';

    // تحميل إعدادات الكرتونة إن وجدت
    final cartonUnit = p.units.where((u) => u.tier == UnitTier.large || u.name.contains('كرتون')).firstOrNull;
    if (cartonUnit != null) {
      _hasCarton = cartonUnit.isEnabled;
      _cartonBarcodeCtrl = TextEditingController(text: cartonUnit.barcode ?? '');
      _cartonCapacityCtrl = TextEditingController(text: cartonUnit.multiplier.toStringAsFixed(0));
      _cartonCostCtrl = TextEditingController(text: cartonUnit.cost > 0 ? cartonUnit.cost.toStringAsFixed(0) : '');
      _cartonPriceCtrl = TextEditingController(text: cartonUnit.price > 0 ? cartonUnit.price.toStringAsFixed(0) : '');
    } else {
      _hasCarton = false;
      _cartonBarcodeCtrl = TextEditingController();
      _cartonCapacityCtrl = TextEditingController(text: '24');
      _cartonCostCtrl = TextEditingController();
      _cartonPriceCtrl = TextEditingController();
    }

    // تحميل إعدادات العلبة إن وجدت
    final packUnit = p.units.where((u) => u.tier == UnitTier.medium || u.name.contains('علب')).firstOrNull;
    if (packUnit != null) {
      _hasPack = packUnit.isEnabled;
      _packBarcodeCtrl = TextEditingController(text: packUnit.barcode ?? '');
      _packCapacityCtrl = TextEditingController(text: packUnit.multiplier.toStringAsFixed(0));
      _packCostCtrl = TextEditingController(text: packUnit.cost > 0 ? packUnit.cost.toStringAsFixed(0) : '');
      _packPriceCtrl = TextEditingController(text: packUnit.price > 0 ? packUnit.price.toStringAsFixed(0) : '');
    } else {
      _hasPack = false;
      _packBarcodeCtrl = TextEditingController();
      _packCapacityCtrl = TextEditingController(text: '6');
      _packCostCtrl = TextEditingController();
      _packPriceCtrl = TextEditingController();
    }

    // تحميل العروض الخاصة والتخفيضات إن وجدت
    if (p.specialOffer != null && p.specialOffer!.isValid) {
      _hasSpecialOffer = p.specialOffer!.isEnabled;
      _offerTier = p.specialOffer!.targetTier;
      _offerQtyCtrl = TextEditingController(text: p.specialOffer!.quantity.toStringAsFixed(0));
      _offerPriceCtrl = TextEditingController(text: p.specialOffer!.offerPrice.toStringAsFixed(0));
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

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final plu = _pluCodeCtrl.text.trim();

    // بناء وحدات البيع (كرتونة، علبة، حبة)
    final List<ProductUnit> units = [];
    if (_hasCarton) {
      final cartonCapUI = double.tryParse(_cartonCapacityCtrl.text.trim()) ?? 24.0;
      final packCapUI = double.tryParse(_packCapacityCtrl.text.trim()) ?? 6.0;
      final cartonMultiplier = _hasPack ? (cartonCapUI * packCapUI) : cartonCapUI;

      final pr = double.tryParse(_cartonPriceCtrl.text.trim()) ?? 0.0;
      final cst = double.tryParse(_cartonCostCtrl.text.trim()) ?? 0.0;
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
      final cap = double.tryParse(_packCapacityCtrl.text.trim()) ?? 6.0;
      final pr = double.tryParse(_packPriceCtrl.text.trim()) ?? 0.0;
      final cst = double.tryParse(_packCostCtrl.text.trim()) ?? 0.0;
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
    SpecialOffer? offer;
    if (_hasSpecialOffer) {
      final q = double.tryParse(_offerQtyCtrl.text.trim()) ?? 0.0;
      final p = double.tryParse(_offerPriceCtrl.text.trim()) ?? 0.0;
      if (q > 1 && p > 0) {
        offer = SpecialOffer(
          targetTier: _offerTier,
          quantity: q,
          offerPrice: p,
          isEnabled: true,
        );
      }
    }

    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      stock: double.tryParse(_stockCtrl.text.trim()) ?? 0.0,
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة',
      units: units,
      specialOffer: offer,
      pluCode: plu.isNotEmpty ? plu : null,
    );

    context.read<ProductBloc>().add(UpdateProduct(updatedProduct));

    if (mounted) {
      SnackbarHelper.showSuccess(context, 'تم تعديل المنتج بنجاح');
      context.pop();
    }
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
                TextFormField(controller: _barcodeCtrl),
                const SizedBox(height: 12),
                const InputLabel(text: 'كود PLU للميزان التجاري (اختياري)'),
                TextFormField(
                  controller: _pluCodeCtrl,
                  keyboardType: TextInputType.number,
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
            // --- المخزون الحالي ---
            _SectionCard(
              title: 'المخزون الحالي',
              icon: Icons.inventory_2_outlined,
              children: [
                const InputLabel(text: 'الكمية المتوفرة بالمخزون حالياً (بالحبة)'),
                TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number),
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


