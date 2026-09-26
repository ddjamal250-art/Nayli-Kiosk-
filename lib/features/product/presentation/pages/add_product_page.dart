import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/product_unit.dart' show UnitTier;
import '../../domain/entities/product_unit.dart';
import '../../domain/entities/product_unit.dart' show UnitTier;
import '../bloc/product_bloc.dart';

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
  final _baseUnitNameCtrl = TextEditingController(text: 'Ã˜Â­Ã˜Â¨Ã˜Â©');
  final _pluCodeCtrl = TextEditingController();

  String _selectedCategory = 'Ã˜Â¹Ã˜Â§Ã™â€¦';
  String? _imageUrl;
  bool _isSaving = false;
  List<ProductUnit> _dynamicUnits = [];
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
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() => _barcodeCtrl.text = result);
      SoundService.playScanBeep();
    }
  }

  void _addOrEditUnitDialog({ProductUnit? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final multiCtrl = TextEditingController(text: existing?.multiplier.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '');
    final costCtrl = TextEditingController(text: existing?.cost.toString() ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    bool isEnabled = existing?.isEnabled ?? true;
    bool isWeighable = existing?.isWeighable ?? false;
    UnitTier _tier = existing?.tier ?? UnitTier.small;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Ã˜Â¥Ã˜Â¶Ã˜Â§Ã™ÂÃ˜Â© Ã™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯Ã˜Â©' : 'Ã˜ÂªÃ˜Â¹Ã˜Â¯Ã™Å Ã™â€ž Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â©'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ã˜Â§Ã˜Â³Ã™â€¦ Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© (Ã™Æ’Ã˜Â±Ã˜ÂªÃ™Ë†Ã™â€ Ã˜Â©Ã˜Å’ Ã™Æ’Ã˜Âº...)')),
                const SizedBox(height: 8),
                TextField(controller: multiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ã˜Â¹Ã˜Â¯Ã˜Â¯ Ã˜Â§Ã™â€žÃ˜Â­Ã˜Â¨Ã˜Â§Ã˜Âª / Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â¹Ã˜Â§Ã™â€¦Ã™â€ž')),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isWeighable ? 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â¨Ã™Å Ã˜Â¹ / Ã™Æ’Ã˜Âº (Ã˜Â¯Ã˜Â¬)' : 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â¨Ã™Å Ã˜Â¹'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isWeighable ? 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â´Ã˜Â±Ã˜Â§Ã˜Â¡ / Ã™Æ’Ã˜Âº (Ã˜Â¯Ã˜Â¬)' : 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â´Ã˜Â±Ã˜Â§Ã˜Â¡'),
                ),
                const SizedBox(height: 8),
                TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Ã˜Â¨Ã˜Â§Ã˜Â±Ã™Æ’Ã™Ë†Ã˜Â¯ Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© (Ã˜Â§Ã˜Â®Ã˜ÂªÃ™Å Ã˜Â§Ã˜Â±Ã™Å )')),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Ã™â€¦Ã™ÂÃ™ÂÃ˜Â¹Ã™Å½Ã™â€˜Ã™â€žÃ˜Â© Ã™ÂÃ™Å  Ã˜Â§Ã™â€žÃ™Æ’Ã˜Â§Ã˜Â´Ã™Å Ã˜Â±'),
                  subtitle: const Text('Ã˜Â£Ã™Ë†Ã™â€šÃ™ÂÃ™â€¡Ã˜Â§ Ã™â€žÃ˜Â¥Ã˜Â®Ã™ÂÃ˜Â§Ã˜Â¦Ã™â€¡Ã˜Â§ Ã™â€¦Ã˜Â¤Ã™â€šÃ˜ÂªÃ˜Â§Ã™â€¹'),
                  value: isEnabled,
                  onChanged: (v) => setDlg(() => isEnabled = v),
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text('Ã¢Å¡â€“Ã¯Â¸Â Ã™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© Ã™â€¦Ã™Å Ã˜Â²Ã˜Â§Ã™â€ '),
                  subtitle: const Text('Ã˜Â§Ã™â€žÃ˜Â³Ã˜Â¹Ã˜Â± Ã˜Â¨Ã˜Â§Ã™â€žÃ™Æ’Ã˜Âº Ã¢â‚¬â€ Ã™Å Ã˜Â­Ã˜ÂªÃ˜Â§Ã˜Â¬ Ã™â€¦Ã™Å Ã˜Â²Ã˜Â§Ã™â€  Ã˜ÂªÃ˜Â¬Ã˜Â§Ã˜Â±Ã™Å '),
                  value: isWeighable,
                  onChanged: (v) => setDlg(() => isWeighable = v),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Ã˜Â¥Ã™â€žÃ˜ÂºÃ˜Â§Ã˜Â¡')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final unit = ProductUnit(
                  name: name,
                  multiplier: double.tryParse(multiCtrl.text.trim()) ?? 1.0,
                  price: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                  cost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                  barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                  isEnabled: isEnabled,
                  isWeighable: isWeighable,
                  tier: _tier,
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
              child: const Text('Ã˜Â­Ã™ÂÃ˜Â¸'),
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
        title: const Text('Ã˜ÂªÃ˜ÂµÃ™â€ Ã™Å Ã™Â Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Ã˜Â§Ã˜Â³Ã™â€¦ Ã˜Â§Ã™â€žÃ˜ÂªÃ˜ÂµÃ™â€ Ã™Å Ã™Â')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ã˜Â¥Ã™â€žÃ˜ÂºÃ˜Â§Ã˜Â¡')),
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
            child: const Text('Ã˜Â¥Ã˜Â¶Ã˜Â§Ã™ÂÃ˜Â©'),
          ),
        ],
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final barcode = _barcodeCtrl.text.trim();
    final plu = _pluCodeCtrl.text.trim();
    final product = Product(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      barcode: barcode.isNotEmpty ? barcode : 'NO_BARCODE_${DateTime.now().millisecondsSinceEpoch}',
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
      wholesalePrice: 0.0,
      stock: double.tryParse(_stockCtrl.text.trim()) ?? 10.0,
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'Ã˜Â­Ã˜Â¨Ã˜Â©',
      units: _dynamicUnits,
      pluCode: plu.isNotEmpty ? plu : null,
      unitSystemType: _unitSystemType,
    );

    context.read<ProductBloc>().add(AddProduct(product));

    if (mounted) {
      SnackbarHelper.showSuccess(context, 'Ã˜ÂªÃ™â€¦ Ã˜Â¥Ã˜Â¶Ã˜Â§Ã™ÂÃ˜Â© Ã˜Â§Ã™â€žÃ™â€¦Ã™â€ Ã˜ÂªÃ˜Â¬ Ã˜Â¨Ã™â€ Ã˜Â¬Ã˜Â§Ã˜Â­');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ã˜Â¥Ã˜Â¶Ã˜Â§Ã™ÂÃ˜Â© Ã™â€¦Ã™â€ Ã˜ÂªÃ˜Â¬ Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯'),
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
            // --- Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â¹Ã™â€žÃ™Ë†Ã™â€¦Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ˜Â£Ã˜Â³Ã˜Â§Ã˜Â³Ã™Å Ã˜Â© ---
            _SectionCard(
              title: 'Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â¹Ã™â€žÃ™Ë†Ã™â€¦Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ˜Â£Ã˜Â³Ã˜Â§Ã˜Â³Ã™Å Ã˜Â©',
              icon: Icons.info_outline,
              children: [
                const InputLabel(text: 'Ã˜Â§Ã˜Â³Ã™â€¦ Ã˜Â§Ã™â€žÃ™â€¦Ã™â€ Ã˜ÂªÃ˜Â¬'),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ã™â€¡Ã˜Â°Ã˜Â§ Ã˜Â§Ã™â€žÃ˜Â­Ã™â€šÃ™â€ž Ã™â€¦Ã˜Â·Ã™â€žÃ™Ë†Ã˜Â¨' : null,
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'Ã˜Â§Ã™â€žÃ˜Â¨Ã˜Â§Ã˜Â±Ã™Æ’Ã™Ë†Ã˜Â¯'),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _barcodeCtrl)),
                    IconButton(icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor), onPressed: _scanBarcode),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'Ã™Æ’Ã™Ë†Ã˜Â¯ PLU Ã™â€žÃ™â€žÃ™â€¦Ã™Å Ã˜Â²Ã˜Â§Ã™â€  Ã˜Â§Ã™â€žÃ˜ÂªÃ˜Â¬Ã˜Â§Ã˜Â±Ã™Å  (Ã˜Â§Ã˜Â®Ã˜ÂªÃ™Å Ã˜Â§Ã˜Â±Ã™Å )'),
                TextFormField(
                  controller: _pluCodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ã™â€¦Ã˜Â«Ã˜Â§Ã™â€ž: 1Ã˜Å’ 42...',
                    prefixIcon: Icon(Icons.scale, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const InputLabel(text: 'Ã˜Â§Ã™â€žÃ˜ÂªÃ˜ÂµÃ™â€ Ã™Å Ã™Â'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomCategoryDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ã˜ÂªÃ˜ÂµÃ™â€ Ã™Å Ã™Â Ã˜Â¬Ã˜Â¯Ã™Å Ã˜Â¯'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _availableCategories.contains(_selectedCategory) ? _selectedCategory : 'Ã˜Â¹Ã˜Â§Ã™â€¦',
                  isExpanded: true,
                  items: _availableCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Ã˜Â§Ã™â€žÃ˜ÂªÃ˜Â³Ã˜Â¹Ã™Å Ã˜Â± Ã™Ë†Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â®Ã˜Â²Ã™Ë†Ã™â€  ---
            _SectionCard(
              title: 'Ã˜Â§Ã™â€žÃ˜ÂªÃ˜Â³Ã˜Â¹Ã™Å Ã˜Â± Ã™Ë†Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â®Ã˜Â²Ã™Ë†Ã™â€ ',
              icon: Icons.attach_money,
              children: [
                const InputLabel(text: 'Ã˜Â§Ã˜Â³Ã™â€¦ Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© Ã˜Â§Ã™â€žÃ˜Â£Ã˜Â³Ã˜Â§Ã˜Â³Ã™Å Ã˜Â© (Ã˜Â­Ã˜Â¨Ã˜Â©Ã˜Å’ Ã™Æ’Ã˜Âº...)'),
                TextFormField(controller: _baseUnitNameCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â¨Ã™Å Ã˜Â¹'),
                      TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'Ã˜Â³Ã˜Â¹Ã˜Â± Ã˜Â§Ã™â€žÃ˜Â´Ã˜Â±Ã˜Â§Ã˜Â¡'),
                      TextFormField(controller: _costPriceCtrl, keyboardType: TextInputType.number),
                    ])),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'Ã˜Â§Ã™â€žÃ™â€¦Ã˜Â®Ã˜Â²Ã™Ë†Ã™â€  Ã˜Â§Ã™â€žÃ˜Â­Ã˜Â§Ã™â€žÃ™Å '),
                TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number),
              ],
            ),
            const SizedBox(height: 16),
            // --- Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ™ÂÃ˜Â±Ã˜Â¹Ã™Å Ã˜Â© ---
            _SectionCard(
              title: 'Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â§Ã˜Âª Ã˜Â§Ã™â€žÃ™ÂÃ˜Â±Ã˜Â¹Ã™Å Ã˜Â©',
              icon: Icons.layers,
              borderColor: Colors.teal.shade200,
              trailing: TextButton.icon(
                onPressed: () => _addOrEditUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ã˜Â¥Ã˜Â¶Ã˜Â§Ã™ÂÃ˜Â© Ã™Ë†Ã˜Â­Ã˜Â¯Ã˜Â©'),
              ),
              children: [
                if (_dynamicUnits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Ã™â€žÃ˜Â§ Ã˜ÂªÃ™Ë†Ã˜Â¬Ã˜Â¯ Ã™Ë†Ã˜Â­Ã˜Â¯Ã˜Â§Ã˜Âª Ã™ÂÃ˜Â±Ã˜Â¹Ã™Å Ã˜Â© Ã¢â‚¬â€ Ã˜Â³Ã™Å Ã™ÂÃ˜Â¨Ã˜Â§Ã˜Â¹ Ã˜Â§Ã™â€žÃ™â€¦Ã™â€ Ã˜ÂªÃ˜Â¬ Ã˜Â¨Ã˜Â§Ã™â€žÃ™Ë†Ã˜Â­Ã˜Â¯Ã˜Â© Ã˜Â§Ã™â€žÃ˜Â£Ã˜Â³Ã˜Â§Ã˜Â³Ã™Å Ã˜Â© Ã™ÂÃ™â€šÃ˜Â·.', style: TextStyle(color: Colors.grey)),
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
                          '${unit.name}  Ãƒâ€”${unit.multiplier}  Ã¢â‚¬â€ ${unit.price} Ã˜Â¯Ã˜Â¬${unit.isWeighable ? '/Ã™Æ’Ã˜Âº' : ''}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: unit.isEnabled ? null : Colors.grey),
                        ),
                        subtitle: Wrap(
                          spacing: 4,
                          children: [
                            if (!unit.isEnabled) const Chip(label: Text('Ã™â€¦Ã™ÂÃ˜Â¹Ã˜Â·Ã™Å½Ã™â€˜Ã™â€žÃ˜Â©', style: TextStyle(fontSize: 11)), backgroundColor: Colors.orange, padding: EdgeInsets.zero),
                            if (unit.isWeighable) const Chip(label: Text('Ã¢Å¡â€“Ã¯Â¸Â Ã™â€¦Ã™Å Ã˜Â²Ã˜Â§Ã™â€ ', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFE0F2F1), padding: EdgeInsets.zero),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(unit.isEnabled ? Icons.toggle_on : Icons.toggle_off, color: unit.isEnabled ? Colors.green : Colors.grey, size: 28),
                              tooltip: unit.isEnabled ? 'Ã˜ÂªÃ˜Â¹Ã˜Â·Ã™Å Ã™â€ž' : 'Ã˜ÂªÃ™ÂÃ˜Â¹Ã™Å Ã™â€ž',
                              onPressed: () => setState(() { _dynamicUnits[idx] = unit.copyWith(isEnabled: !unit.isEnabled); }),
                            ),
                            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _addOrEditUnitDialog(existing: unit, editIndex: idx)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => setState(() => _dynamicUnits.removeAt(idx))),
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
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppTheme.primaryColor),
              child: const Text('Ã˜Â­Ã™ÂÃ˜Â¸ Ã˜Â§Ã™â€žÃ™â€¦Ã™â€ Ã˜ÂªÃ˜Â¬', style: TextStyle(fontSize: 18, color: Colors.white)),
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


