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
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/special_offer.dart';
import '../bloc/product_bloc.dart';
import '../widgets/product_units_editor_widget.dart';
import '../widgets/coffee_recipe_modal.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {

  String _formatDouble(double val) {
    if (val == val.toInt()) return (val == val.roundToDouble() ? val.toInt().toString() : val.toString());
    return val.toString();
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
    _costPriceCtrl = TextEditingController(text: p.costPrice > 0 ? _formatDouble(p.costPrice) : '');
    _stockCtrl = TextEditingController(text: _formatDouble(p.stock));
    _baseUnitNameCtrl = TextEditingController(text: p.baseUnitName);
    _imageUrl = p.imageUrl;
    _pluCodeCtrl = TextEditingController(text: p.pluCode ?? '');
    _selectedCategory = _availableCategories.contains(p.category) ? p.category : 'عام';
    _coffeeRecipeJson = p.coffeeRecipeJson;

    // تحميل إعدادات الكرتونة إن وجدت
    final cartonUnit = p.units.where((u) => u.tier == UnitTier.large || u.name.contains('كرتون')).firstOrNull;
    if (cartonUnit != null) {
      _hasCarton = cartonUnit.isEnabled;
      _cartonBarcodeCtrl = TextEditingController(text: cartonUnit.barcode ?? '');
      _cartonCapacityCtrl = TextEditingController(text: _formatDouble(cartonUnit.multiplier));
      _cartonCostCtrl = TextEditingController(text: cartonUnit.cost > 0 ? _formatDouble(cartonUnit.cost) : '');
      _cartonPriceCtrl = TextEditingController(text: cartonUnit.price > 0 ? _formatDouble(cartonUnit.price) : '');
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
    List<SpecialOffer> resolvedOffers = [];
    if (_hasSpecialOffer) {
      if (_specialOffers.isNotEmpty) {
        resolvedOffers = _specialOffers.where((o) => o.isValid).toList();
      }
      if (resolvedOffers.isEmpty) {
        final q = double.tryParse(_offerQtyCtrl.text.trim()) ?? 0.0;
        final p = double.tryParse(_offerPriceCtrl.text.trim()) ?? 0.0;
        if (q > 1 && p > 0) {
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

    final rawBc = _barcodeCtrl.text.trim();
    final validBc = (rawBc.isEmpty || rawBc.startsWith('NO_BARCODE_'))
        ? BarcodeGeneratorHelper.generateUniqueInStoreEan13()
        : rawBc;

    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      barcode: validBc,
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      stock: double.tryParse(_stockCtrl.text.trim()) ?? 0.0,
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة',
      units: units,
      specialOffers: resolvedOffers,
      pluCode: plu.isNotEmpty ? plu : null,
      coffeeRecipeJson: _coffeeRecipeJson,
      isCoffeeMachineProduct: widget.product.isCoffeeMachineProduct || _coffeeRecipeJson != null || _selectedCategory.contains('قهوة'),
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
                  ],
                ),
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


