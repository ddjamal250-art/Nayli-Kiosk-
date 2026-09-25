import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
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
  late TextEditingController _pluCodeCtrl;

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
    _pluCodeCtrl = TextEditingController(text: p.pluCode ?? '');
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
    _pluCodeCtrl.dispose();
    super.dispose();
  }

  void _addOrEditUnitDialog({ProductUnit? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final multiCtrl = TextEditingController(text: existing?.multiplier.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '');
    final costCtrl = TextEditingController(text: existing?.cost.toString() ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    bool isEnabled = existing?.isEnabled ?? true;
    bool isWeighable = existing?.isWeighable ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: Text(existing == null ? 'إضافة وحدة جديدة' : 'تعديل الوحدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الوحدة (كرتونة، كغ...)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: multiCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد الحبات / المعامل'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isWeighable ? 'سعر البيع / كغ (دج)' : 'سعر البيع',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isWeighable ? 'سعر الشراء / كغ (دج)' : 'سعر الشراء (التكلفة)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: barcodeCtrl,
                  decoration: const InputDecoration(labelText: 'باركود الوحدة (اختياري)'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('مُفعَّلة في الكاشير'),
                  subtitle: const Text('أوقفها لإخفائها مؤقتاً'),
                  value: isEnabled,
                  onChanged: (v) => setDlg(() => isEnabled = v),
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text('⚖️ وحدة ميزان'),
                  subtitle: const Text('السعر بالكغ — يحتاج ميزان تجاري'),
                  value: isWeighable,
                  onChanged: (v) => setDlg(() => isWeighable = v),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final unit = ProductUnit(
                  name: name,
                  multiplier: int.tryParse(multiCtrl.text.trim()) ?? 1,
                  price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                  cost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                  barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                  isEnabled: isEnabled,
                  isWeighable: isWeighable,
                );
                setState(() {
                  if (editIndex != null) {
                    _dynamicUnits[editIndex] = unit;
                  } else {
                    _dynamicUnits.add(unit);
                  }
                });
                Navigator.pop(ctx2);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
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
    final updatedProduct = widget.product.copyWith(
      name: _nameCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      stock: int.tryParse(_stockCtrl.text.trim()) ?? 0,
      category: _selectedCategory,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'حبة',
      units: _dynamicUnits,
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
            // --- التسعير والمخزون ---
            _SectionCard(
              title: 'التسعير والمخزون',
              icon: Icons.attach_money,
              children: [
                const InputLabel(text: 'اسم الوحدة الأساسية (حبة، كغ...)'),
                TextFormField(controller: _baseUnitNameCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'سعر البيع'),
                      TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'سعر الشراء'),
                      TextFormField(controller: _costPriceCtrl, keyboardType: TextInputType.number),
                    ])),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'المخزون الحالي'),
                TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number),
              ],
            ),
            const SizedBox(height: 16),
            // --- الوحدات الفرعية ---
            _SectionCard(
              title: 'الوحدات الفرعية',
              icon: Icons.layers,
              borderColor: Colors.teal.shade200,
              trailing: TextButton.icon(
                onPressed: () => _addOrEditUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة وحدة'),
              ),
              children: [
                if (_dynamicUnits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('لا توجد وحدات فرعية — سيُباع المنتج بالوحدة الأساسية فقط.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ..._dynamicUnits.asMap().entries.map((e) {
                    final idx = e.key;
                    final unit = e.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: unit.isEnabled ? Colors.white : Colors.grey.shade100,
                      child: ListTile(
                        leading: Icon(
                          unit.isWeighable ? Icons.scale : Icons.inventory_2_outlined,
                          color: unit.isEnabled ? Colors.teal : Colors.grey,
                        ),
                        title: Text(
                          '${unit.name}  ×${unit.multiplier}  — ${unit.price} دج${unit.isWeighable ? '/كغ' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unit.isEnabled ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (!unit.isEnabled)
                              const Chip(label: Text('مُعطَّلة', style: TextStyle(fontSize: 11)), backgroundColor: Colors.orange, padding: EdgeInsets.zero),
                            if (unit.isWeighable)
                              const Chip(label: Text('⚖️ ميزان', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFE0F2F1), padding: EdgeInsets.zero),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر تفعيل/تعطيل
                            IconButton(
                              icon: Icon(
                                unit.isEnabled ? Icons.toggle_on : Icons.toggle_off,
                                color: unit.isEnabled ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                              tooltip: unit.isEnabled ? 'تعطيل' : 'تفعيل',
                              onPressed: () => setState(() {
                                _dynamicUnits[idx] = unit.copyWith(isEnabled: !unit.isEnabled);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _addOrEditUnitDialog(existing: unit, editIndex: idx),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                              onPressed: () => setState(() => _dynamicUnits.removeAt(idx)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
                    TextFormField(controller: _nameCtrl, validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null),
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
