import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _costPriceCtrl = TextEditingController();
  final TextEditingController _wholesalePriceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController(text: '10');
  String _selectedCategory = 'عام';
  bool _isWeighted = false;
  DateTime? _expiryDate;
  bool _isSaving = false;

  static const List<String> categories = [
    'عام',
    'مواد غذائية ومعلبات',
    'حليب ومشتقاته',
    'مخبوزات وعجائن',
    'مشروبات ومياه',
    'نظافة وتجميل',
    'حلويات وسكاكر',
    'خضر وفواكه',
    'أخرى',
  ];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcodeCtrl.text = result;
      });
      SoundService.playScanBeep();
    }
  }

  void _addStockBatch(int amount) {
    final current = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final updated = (current + amount).clamp(0, 999999);
    setState(() {
      _stockCtrl.text = updated.toString();
    });
    SoundService.playScanBeep();
  }

  void _submit() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final barcode = _barcodeCtrl.text.trim();
      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == barcode).firstOrNull;

      if (existingProduct != null && barcode.isNotEmpty) {
        context.showAppSnackBar('⚠️ هذا الباركود ($barcode) مسجل مسبقاً لسلعة أخرى!', backgroundColor: Colors.red[800]!);
        setState(() => _isSaving = false);
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        barcode: barcode.isNotEmpty ? barcode : 'NO_BARCODE_${DateTime.now().millisecondsSinceEpoch}',
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0,
        wholesalePrice: double.tryParse(_wholesalePriceCtrl.text.trim()) ?? 0.0,
        stock: int.tryParse(_stockCtrl.text.trim()) ?? 10,
        category: _selectedCategory,
        isWeighted: _isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      CatalogCrowdsourceHelper.silentHarvest(
        product,
        category: _selectedCategory,
        unit: _isWeighted ? 'كغ' : 'حبة',
      );
      SoundService.playCheckoutSuccess();
      context.showAppSnackBar('✅ تم إضافة واستلام السلعة (${product.name}) بنجاح!');
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Theme.of(context).primaryColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
        ),
        title: const Text('إضافة واستلام سلعة جديدة 📦✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barcode input with camera scanner button
                const InputLabel(text: 'رمز الباركود'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'امسح بالكاميرا أو اكتب الباركود...',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                      onPressed: _scanBarcode,
                      padding: const EdgeInsets.all(12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Product Name
                const InputLabel(text: 'اسم السلعة / المنتج *'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'اسم السلعة'),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required(context.tr('required')),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                const InputLabel(text: 'قسم / صنف السلعة 📂'),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: categories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),

                // Weighted Item Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isWeighted ? Colors.teal.withOpacity(0.08) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isWeighted ? Colors.teal : Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.scale, color: _isWeighted ? Colors.teal : Colors.grey),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تباع بالميزان (بالكيلوغرام) ⚖️',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isWeighted ? Colors.teal[800] : Colors.black87)),
                              const Text('احتساب السعر حسب الوزن والكسور', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isWeighted,
                        activeColor: Colors.teal,
                        onChanged: (v) => setState(() => _isWeighted = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Pricing Row: Cost Price, Retail Price, Wholesale Price
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InputLabel(text: 'سعر التكلفة (Achat)'),
                          TextFormField(
                            controller: _costPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InputLabel(text: 'سعر البيع (Détail) *'),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                            validator: AppValidators.price,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InputLabel(text: 'سعر الجملة (Gros)'),
                          TextFormField(
                            controller: _wholesalePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stock Quantity & Quick Batch Arrivage Addition Chips
                InputLabel(text: 'الكمية المستلمة في المخزون (${_isWeighted ? "كغ" : "قطعة"})'),
                TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '10',
                    suffixText: _isWeighted ? 'كغ' : 'قطعة',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Batch Addition (Arrivage) Chips
                Row(
                  children: [
                    const Text('استلام شحنة سريعة:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [5, 10, 24, 50, 100].map((amt) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text('+$amt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.green.withOpacity(0.1),
                                side: BorderSide(color: Colors.green.withOpacity(0.3)),
                                onPressed: () => _addStockBatch(amt),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Expiry Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _expiryDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_outlined, color: Colors.deepOrange, size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاريخ انتهاء الصلاحية (اختياري):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : 'غير محدد (انقر لتحديد التاريخ)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _expiryDate != null ? Colors.black87 : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_expiryDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _expiryDate = null),
                          )
                        else
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSaving ? Colors.grey[600] : AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.add_circle),
          label: Text(
            _isSaving ? 'جاري الإضافة... ⏳' : 'إضافة السلعة للمخزون 📦✨',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: _isSaving ? null : _submit,
        ),
      ),
    );
  }
}


