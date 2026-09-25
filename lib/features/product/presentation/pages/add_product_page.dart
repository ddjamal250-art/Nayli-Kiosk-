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
  final _baseUnitNameCtrl = TextEditingController(text: 'Ø­Ø¨Ø©');
  final _pluCodeCtrl = TextEditingController();

  String _selectedCategory = 'Ø¹Ø§Ù…';
  String? _imageUrl;
  bool _isSaving = false;
  List<ProductUnit> _dynamicUnits = [];
  List<String> _availableCategories = [];

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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Ø¥Ø¶Ø§ÙØ© ÙˆØ­Ø¯Ø© Ø¬Ø¯ÙŠØ¯Ø©' : 'ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„ÙˆØ­Ø¯Ø©'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ø§Ø³Ù… Ø§Ù„ÙˆØ­Ø¯Ø© (ÙƒØ±ØªÙˆÙ†Ø©ØŒ ÙƒØº...)')),
                const SizedBox(height: 8),
                TextField(controller: multiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ø¹Ø¯Ø¯ Ø§Ù„Ø­Ø¨Ø§Øª / Ø§Ù„Ù…Ø¹Ø§Ù…Ù„')),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isWeighable ? 'Ø³Ø¹Ø± Ø§Ù„Ø¨ÙŠØ¹ / ÙƒØº (Ø¯Ø¬)' : 'Ø³Ø¹Ø± Ø§Ù„Ø¨ÙŠØ¹'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: isWeighable ? 'Ø³Ø¹Ø± Ø§Ù„Ø´Ø±Ø§Ø¡ / ÙƒØº (Ø¯Ø¬)' : 'Ø³Ø¹Ø± Ø§Ù„Ø´Ø±Ø§Ø¡'),
                ),
                const SizedBox(height: 8),
                TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Ø¨Ø§Ø±ÙƒÙˆØ¯ Ø§Ù„ÙˆØ­Ø¯Ø© (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)')),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Ù…ÙÙØ¹ÙŽÙ‘Ù„Ø© ÙÙŠ Ø§Ù„ÙƒØ§Ø´ÙŠØ±'),
                  subtitle: const Text('Ø£ÙˆÙ‚ÙÙ‡Ø§ Ù„Ø¥Ø®ÙØ§Ø¦Ù‡Ø§ Ù…Ø¤Ù‚ØªØ§Ù‹'),
                  value: isEnabled,
                  onChanged: (v) => setDlg(() => isEnabled = v),
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text('âš–ï¸ ÙˆØ­Ø¯Ø© Ù…ÙŠØ²Ø§Ù†'),
                  subtitle: const Text('Ø§Ù„Ø³Ø¹Ø± Ø¨Ø§Ù„ÙƒØº â€” ÙŠØ­ØªØ§Ø¬ Ù…ÙŠØ²Ø§Ù† ØªØ¬Ø§Ø±ÙŠ'),
                  value: isWeighable,
                  onChanged: (v) => setDlg(() => isWeighable = v),
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Ø¥Ù„ØºØ§Ø¡')),
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
              child: const Text('Ø­ÙØ¸'),
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
        title: const Text('ØªØµÙ†ÙŠÙ Ø¬Ø¯ÙŠØ¯'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Ø§Ø³Ù… Ø§Ù„ØªØµÙ†ÙŠÙ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ø¥Ù„ØºØ§Ø¡')),
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
            child: const Text('Ø¥Ø¶Ø§ÙØ©'),
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
      stock: int.tryParse(_stockCtrl.text.trim()) ?? 10,
      category: _selectedCategory,
      imageUrl: _imageUrl,
      baseUnitName: _baseUnitNameCtrl.text.trim().isNotEmpty ? _baseUnitNameCtrl.text.trim() : 'Ø­Ø¨Ø©',
      units: _dynamicUnits,
      pluCode: plu.isNotEmpty ? plu : null,
    );

    context.read<ProductBloc>().add(AddProduct(product));

    if (mounted) {
      SnackbarHelper.showSuccess(context, 'ØªÙ… Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ù…Ù†ØªØ¬ Ø¨Ù†Ø¬Ø§Ø­');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ø¥Ø¶Ø§ÙØ© Ù…Ù†ØªØ¬ Ø¬Ø¯ÙŠØ¯'),
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
            // --- Ø§Ù„Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ© ---
            _SectionCard(
              title: 'Ø§Ù„Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ©',
              icon: Icons.info_outline,
              children: [
                const InputLabel(text: 'Ø§Ø³Ù… Ø§Ù„Ù…Ù†ØªØ¬'),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ù‡Ø°Ø§ Ø§Ù„Ø­Ù‚Ù„ Ù…Ø·Ù„ÙˆØ¨' : null,
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'Ø§Ù„Ø¨Ø§Ø±ÙƒÙˆØ¯'),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _barcodeCtrl)),
                    IconButton(icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor), onPressed: _scanBarcode),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'ÙƒÙˆØ¯ PLU Ù„Ù„Ù…ÙŠØ²Ø§Ù† Ø§Ù„ØªØ¬Ø§Ø±ÙŠ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)'),
                TextFormField(
                  controller: _pluCodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ù…Ø«Ø§Ù„: 1ØŒ 42...',
                    prefixIcon: Icon(Icons.scale, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const InputLabel(text: 'Ø§Ù„ØªØµÙ†ÙŠÙ'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addCustomCategoryDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('ØªØµÙ†ÙŠÙ Ø¬Ø¯ÙŠØ¯'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: _availableCategories.contains(_selectedCategory) ? _selectedCategory : 'Ø¹Ø§Ù…',
                  isExpanded: true,
                  items: _availableCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedCategory = v); },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Ø§Ù„ØªØ³Ø¹ÙŠØ± ÙˆØ§Ù„Ù…Ø®Ø²ÙˆÙ† ---
            _SectionCard(
              title: 'Ø§Ù„ØªØ³Ø¹ÙŠØ± ÙˆØ§Ù„Ù…Ø®Ø²ÙˆÙ†',
              icon: Icons.attach_money,
              children: [
                const InputLabel(text: 'Ø§Ø³Ù… Ø§Ù„ÙˆØ­Ø¯Ø© Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ© (Ø­Ø¨Ø©ØŒ ÙƒØº...)'),
                TextFormField(controller: _baseUnitNameCtrl),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'Ø³Ø¹Ø± Ø§Ù„Ø¨ÙŠØ¹'),
                      TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const InputLabel(text: 'Ø³Ø¹Ø± Ø§Ù„Ø´Ø±Ø§Ø¡'),
                      TextFormField(controller: _costPriceCtrl, keyboardType: TextInputType.number),
                    ])),
                  ],
                ),
                const SizedBox(height: 12),
                const InputLabel(text: 'Ø§Ù„Ù…Ø®Ø²ÙˆÙ† Ø§Ù„Ø­Ø§Ù„ÙŠ'),
                TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number),
              ],
            ),
            const SizedBox(height: 16),
            // --- Ø§Ù„ÙˆØ­Ø¯Ø§Øª Ø§Ù„ÙØ±Ø¹ÙŠØ© ---
            _SectionCard(
              title: 'Ø§Ù„ÙˆØ­Ø¯Ø§Øª Ø§Ù„ÙØ±Ø¹ÙŠØ©',
              icon: Icons.layers,
              borderColor: Colors.teal.shade200,
              trailing: TextButton.icon(
                onPressed: () => _addOrEditUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ø¥Ø¶Ø§ÙØ© ÙˆØ­Ø¯Ø©'),
              ),
              children: [
                if (_dynamicUnits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ ÙˆØ­Ø¯Ø§Øª ÙØ±Ø¹ÙŠØ© â€” Ø³ÙŠÙØ¨Ø§Ø¹ Ø§Ù„Ù…Ù†ØªØ¬ Ø¨Ø§Ù„ÙˆØ­Ø¯Ø© Ø§Ù„Ø£Ø³Ø§Ø³ÙŠØ© ÙÙ‚Ø·.', style: TextStyle(color: Colors.grey)),
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
                          '${unit.name}  Ã—${unit.multiplier}  â€” ${unit.price} Ø¯Ø¬${unit.isWeighable ? '/ÙƒØº' : ''}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: unit.isEnabled ? null : Colors.grey),
                        ),
                        subtitle: Wrap(
                          spacing: 4,
                          children: [
                            if (!unit.isEnabled) const Chip(label: Text('Ù…ÙØ¹Ø·ÙŽÙ‘Ù„Ø©', style: TextStyle(fontSize: 11)), backgroundColor: Colors.orange, padding: EdgeInsets.zero),
                            if (unit.isWeighable) const Chip(label: Text('âš–ï¸ Ù…ÙŠØ²Ø§Ù†', style: TextStyle(fontSize: 11)), backgroundColor: Color(0xFFE0F2F1), padding: EdgeInsets.zero),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(unit.isEnabled ? Icons.toggle_on : Icons.toggle_off, color: unit.isEnabled ? Colors.green : Colors.grey, size: 28),
                              tooltip: unit.isEnabled ? 'ØªØ¹Ø·ÙŠÙ„' : 'ØªÙØ¹ÙŠÙ„',
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
              child: const Text('Ø­ÙØ¸ Ø§Ù„Ù…Ù†ØªØ¬', style: TextStyle(fontSize: 18, color: Colors.white)),
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

