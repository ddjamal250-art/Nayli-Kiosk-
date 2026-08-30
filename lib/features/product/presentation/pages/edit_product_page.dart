import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/product.dart';
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
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _stockCtrl;
  late String _selectedCategory;
  late bool _isWeighted;
  DateTime? _expiryDate;

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
  void initState() {
    super.initState();
    _barcodeCtrl = TextEditingController(text: widget.product.barcode);
    _nameCtrl = TextEditingController(text: widget.product.name);
    _priceCtrl = TextEditingController(text: widget.product.price > 0 ? widget.product.price.toStringAsFixed(0) : '');
    _costPriceCtrl = TextEditingController(text: widget.product.costPrice > 0 ? widget.product.costPrice.toStringAsFixed(0) : '');
    _wholesalePriceCtrl = TextEditingController(text: widget.product.wholesalePrice > 0 ? widget.product.wholesalePrice.toStringAsFixed(0) : '');
    _stockCtrl = TextEditingController(text: widget.product.stock.toString());
    _selectedCategory = widget.product.category.isNotEmpty ? widget.product.category : 'عام';
    _isWeighted = widget.product.isWeighted || widget.product.barcode.startsWith('SCALE_') || widget.product.name.contains('ميزان') || widget.product.name.contains('كغ');
    if (widget.product.expiryDate != null && widget.product.expiryDate!.isNotEmpty) {
      _expiryDate = DateTime.tryParse(widget.product.expiryDate!);
    }
  }

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
    final current = int.tryParse(_stockCtrl.text.trim()) ?? widget.product.stock;
    final updated = (current + amount).clamp(0, 999999);
    setState(() {
      _stockCtrl.text = updated.toString();
    });
    SoundService.playScanBeep();
    context.showAppSnackBar('📦 تم تزويد المخزون بـ +$amount قطعة!');
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? widget.product.price,
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? widget.product.costPrice,
        wholesalePrice: double.tryParse(_wholesalePriceCtrl.text.trim()) ?? widget.product.wholesalePrice,
        stock: int.tryParse(_stockCtrl.text.trim()) ?? widget.product.stock,
        category: _selectedCategory,
        isWeighted: _isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      SoundService.playCheckoutSuccess();
      context.showAppSnackBar('✅ تم تحديث وتعديل بيانات السلعة بنجاح!');
      context.pop();
    }
  }

  void _showPrintLabelDialog() {
    int labelCopies = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.label_important_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('طباعة ملصق السعر 🏷️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Text(_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : widget.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('${_priceCtrl.text.trim()} ${AppConstants.currencySymbol}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('اختر عدد النسخ والملصقات المراد طباعتها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: labelCopies > 1 ? () => setDialogState(() => labelCopies--) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Text('$labelCopies', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => setDialogState(() => labelCopies++),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Preset chips: 1, 5, 10, 20, 50
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [1, 2, 5, 10, 20, 50].map((count) {
                  return ActionChip(
                    label: Text('$count', style: const TextStyle(fontSize: 11)),
                    backgroundColor: labelCopies == count ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey[100],
                    onPressed: () => setDialogState(() => labelCopies = count),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.print, size: 18),
              label: Text('طباعة $labelCopies ملصق', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                _executePrintShelfLabels(labelCopies);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executePrintShelfLabels(int copies) async {
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      if (mounted) {
        context.showAppSnackBar(
          '⚠️ الطابعة الحرارية غير متصلة! يرجى تشغيل البلوتوث وتوصيلها في الإعدادات.',
          backgroundColor: Colors.orange[800]!,
        );
      }
      return;
    }

    String shopName = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final pName = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : widget.product.name;
    final pPrice = _priceCtrl.text.trim().isNotEmpty ? _priceCtrl.text.trim() : widget.product.price.toStringAsFixed(0);
    final pBarcode = _barcodeCtrl.text.trim().isNotEmpty ? _barcodeCtrl.text.trim() : widget.product.barcode;

    try {
      final List<int> bytes = [];
      for (int c = 0; c < copies; c++) {
        bytes.addAll([27, 64]); // Initialize
        bytes.addAll([27, 97, 1]); // Center align
        bytes.addAll('$shopName\n'.codeUnits);
        bytes.addAll([27, 33, 16]); // Double height
        bytes.addAll('$pName\n'.codeUnits);
        bytes.addAll([27, 33, 48]); // Huge Price
        bytes.addAll('$pPrice DZD\n'.codeUnits);
        if (pBarcode.isNotEmpty) {
          bytes.addAll([27, 33, 0]);
          bytes.addAll('||||| $pBarcode |||||\n'.codeUnits);
        }
        bytes.addAll([27, 33, 0]);
        bytes.addAll('Date: $dateStr\n'.codeUnits);
        bytes.addAll('--------------------------------\n\n'.codeUnits);
        bytes.addAll([29, 86, 66, 0]); // Cut paper
      }

      await PrintBluetoothThermal.writeBytes(bytes);
      SoundService.playCheckoutSuccess();
      if (mounted) {
        context.showAppSnackBar(
          '✅ تم إرسال $copies ملصق لـ ($pName) إلى الطابعة بنجاح!',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        title: const Text('تعديل واستلام السلعة 📦✏️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.label_important_rounded, color: Colors.amber),
            tooltip: 'طباعة بطاقة الرف 🏷️',
            onPressed: _showPrintLabelDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editable Barcode Box with Camera Scanner
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رمز الباركود (قابل للتعديل أو المسح):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _barcodeCtrl,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 15),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'امسح أو اكتب الباركود...',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                        tooltip: 'مسح باركود جديد بالكاميرا',
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                ),

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
                  value: categories.contains(_selectedCategory) ? _selectedCategory : 'عام',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الكمية الحالية في المخزون (${_isWeighted ? "كغ" : "قطعة"}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    Text('إجمالي القيمة: ${((double.tryParse(_priceCtrl.text) ?? 0) * (int.tryParse(_stockCtrl.text) ?? 0)).toStringAsFixed(0)} دج',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0',
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
                                const Text('تاريخ انتهاء الصلاحية (Péremption):', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.save),
          label: const Text('حفظ التعديلات والاستلام 💾', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: _submit,
        ),
      ),
    );
  }
}


