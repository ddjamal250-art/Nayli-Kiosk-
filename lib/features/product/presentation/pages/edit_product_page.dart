import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../bloc/product_bloc.dart';

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

  late String _selectedCategory;
  List<ProductUnit> _dynamicUnits = [];
  List<String> _availableCategories = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _availableCategories = CategoryTaxonomy.getDropdownCategories();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p.barcode);
    _nameCtrl = TextEditingController(text: p.name);
    _priceCtrl = TextEditingController(text: p.price.toString());
    _costPriceCtrl = TextEditingController(text: p.costPrice.toString());
    _stockCtrl = TextEditingController(text: p.stock.toString());
    _baseUnitNameCtrl = TextEditingController(text: p.baseUnitName);
    
    _selectedCategory = _availableCategories.contains(p.category) ? p.category : 'عام';
    _dynamicUnits = List.from(p.units);
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _baseUnitNameCtrl.dispose();
    super.dispose();
  }

  void _addUnitDialog() {
    final nameCtrl = TextEditingController();
    final multiCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة وحدة جديدة (مثال: كرتونة)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الوحدة (كرتونة, فاردو...)')),
              TextField(controller: multiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الحبات (المعامل)')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الوحدة')),
              TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'باركود الوحدة (اختياري)')),
            ],
          ),
        ),
        actions: [
          TextButton(onSelected: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && multiCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  _dynamicUnits.add(ProductUnit(
                    name: nameCtrl.text.trim(),
                    multiplier: int.tryParse(multiCtrl.text.trim()) ?? 1,
                    price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                    barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                  ));
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
    
    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      stock: int.tryParse(_stockCtrl.text.trim()) ?? 10,
      category: _selectedCategory,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة',
      units: _dynamicUnits,
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
            // Basic Info
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InputLabel(text: 'اسم المنتج'),
                    TextFormField(controller: _nameCtrl, validator: AppValidators.required),
                    const SizedBox(height: 12),
                    const InputLabel(text: 'الباركود'),
                    TextFormField(controller: _barcodeCtrl),
                    const SizedBox(height: 12),
                    const InputLabel(text: 'التصنيف'),
                    DropdownButtonFormField<String>(
                      value: _availableCategories.contains(_selectedCategory) ? _selectedCategory : 'عام',
                      items: _availableCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Pricing
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InputLabel(text: 'الوحدة الأساسية (مثال: حبة، كغ)'),
                    TextFormField(controller: _baseUnitNameCtrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const InputLabel(text: 'سعر البيع'),
                              TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const InputLabel(text: 'سعر الشراء (التكلفة)'),
                              TextFormField(controller: _costPriceCtrl, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const InputLabel(text: 'الكمية الحالية في المخزون (بالوحدة الأساسية)'),
                    TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Dynamic Units
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الوحدات الفرعية (كرتونة، فاردو...)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: _addUnitDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة وحدة'),
                        )
                      ],
                    ),
                    const Divider(),
                    if (_dynamicUnits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('لا توجد وحدات فرعية. سيتم بيع المنتج كحبة فقط.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ..._dynamicUnits.asMap().entries.map((e) {
                        final idx = e.key;
                        final unit = e.value;
                        return ListTile(
                          title: Text('${unit.name} (${unit.multiplier} ${_baseUnitNameCtrl.text})'),
                          subtitle: Text('السعر: ${unit.price} دج'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => _dynamicUnits.removeAt(idx)),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppTheme.primaryColor),
              child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
