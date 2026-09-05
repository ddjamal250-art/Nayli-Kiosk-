import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/shelf_label_generator.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/adaptive_modal_helper.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  bool _isExporting = false;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedProductIds = {};

  static const List<Map<String, String>> _categoryTabsDef = [
    {'key': 'all', 'ar': 'الكل', 'fr': 'Tous', 'en': 'All'},
    {'key': 'scale', 'ar': '⚖️ مواد الميزان', 'fr': '⚖️ Vrac & Balance', 'en': '⚖️ Scale & Bulk'},
    {'key': 'food', 'ar': 'مواد غذائية', 'fr': 'Alimentation', 'en': 'Groceries'},
    {'key': 'dairy', 'ar': 'حليب ومشتقاته', 'fr': 'Produits Laitiers', 'en': 'Dairy'},
    {'key': 'bakery', 'ar': 'مخبوزات وعجائن', 'fr': 'Boulangerie & Pâtes', 'en': 'Bakery & Pasta'},
    {'key': 'beverages', 'ar': 'مشروبات ومياه', 'fr': 'Boissons & Eaux', 'en': 'Beverages & Water'},
    {'key': 'cleaning', 'ar': 'نظافة وتجميل', 'fr': 'Entretien & Hygiène', 'en': 'Cleaning & Hygiene'},
    {'key': 'sweets', 'ar': 'حلويات وسكاكر', 'fr': 'Confiserie & Biscuits', 'en': 'Sweets & Biscuits'},
    {'key': 'fruits', 'ar': 'خضر وفواكه', 'fr': 'Fruits & Légumes', 'en': 'Fruits & Veg'},
    {'key': 'other', 'ar': 'أخرى', 'fr': 'Autres', 'en': 'Other'},
  ];

  List<String> get _categoryTabs => _categoryTabsDef.map((c) => c['ar']!).toList();
  String get _selectedCategoryFilter =>
      _selectedCategoryIndex < _categoryTabsDef.length ? _categoryTabsDef[_selectedCategoryIndex]['ar']! : 'الكل';

  void _toggleProductSelection(String id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
        if (_selectedProductIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedProductIds.add(id);
        _isMultiSelectMode = true;
      }
    });
    SoundService.playTabSwitch();
  }

  void _selectAllFiltered(List<Product> products) {
    setState(() {
      _isMultiSelectMode = true;
      for (final p in products) {
        _selectedProductIds.add(p.id);
      }
    });
    SoundService.playTabSwitch();
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _isMultiSelectMode = false;
    });
    SoundService.playTabSwitch();
  }

  /// Batch Delete
  Future<void> _batchDelete(BuildContext context) async {
    if (_selectedProductIds.isEmpty) return;
    final count = _selectedProductIds.length;
    final auth = await SecurityPinHelper.authenticate(context, title: 'تأكيد الحذف الجماعي');
    if (!auth || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('حذف $count سلع محددة؟', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('هل أنت متأكد من رغبتك في حذف $count سلع نهائياً من المخزون؟ لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، حذف الكل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final bloc = context.read<ProductBloc>();
      for (final id in _selectedProductIds) {
        bloc.add(DeleteProduct(id));
      }
      SoundService.playDeleteSound();
      context.showAppSnackBar('🗑️ تم حذف $count سلع بنجاح من المخزن!', backgroundColor: Colors.red[800]!);
      _clearSelection();
    }
  }

  /// Batch Move Category
  Future<void> _batchMoveCategory(BuildContext context, List<Product> allProducts) async {
    if (_selectedProductIds.isEmpty) return;
    final count = _selectedProductIds.length;
    String targetCat = 'مواد غذائية ومعلبات';

    final selectedCat = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.drive_file_move_rounded, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text('نقل $count سلع لقسم آخر 📂', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('اختر القسم المستهدف لنقل السلع المحددة إليه:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetCat,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _categoryTabs.where((c) => c != 'الكل' && c != '⚖️ مواد الميزان').map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetCat = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, targetCat),
              child: const Text('نقل السلع الآن 💾', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (selectedCat != null && context.mounted) {
      final bloc = context.read<ProductBloc>();
      for (final id in _selectedProductIds) {
        final p = allProducts.firstWhere((item) => item.id == id, orElse: () => allProducts.first);
        final updated = Product(
          id: p.id,
          name: p.name,
          barcode: p.barcode,
          price: p.price,
          costPrice: p.costPrice,
          wholesalePrice: p.wholesalePrice,
          stock: p.stock,
          category: selectedCat,
          isWeighted: p.isWeighted,
          expiryDate: p.expiryDate,
        );
        bloc.add(UpdateProduct(updated));
      }
      SoundService.playSaveSuccess();
      context.showAppSnackBar('✅ تم نقل $count سلع إلى قسم ($selectedCat) بنجاح!');
      _clearSelection();
    }
  }

  /// Batch Restock (Arrivage for selected items)
  Future<void> _batchRestock(BuildContext context, List<Product> allProducts) async {
    if (_selectedProductIds.isEmpty) return;
    final count = _selectedProductIds.length;
    int addQty = 10;

    final selectedQty = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text('استلام شحنة لـ $count سلع 📦', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر الكمية المضافة لكل سلعة من السلع المحددة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: addQty > 1 ? () => setDialogState(() => addQty--) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+$addQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => setDialogState(() => addQty++),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [5, 10, 24, 50, 100].map((amt) {
                  return ActionChip(
                    label: Text('+$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    backgroundColor: addQty == amt ? Colors.green.withOpacity(0.2) : Colors.grey[100],
                    onPressed: () => setDialogState(() => addQty = amt),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, addQty),
              child: Text('إضافة +$addQty للكل 🚀', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (selectedQty != null && context.mounted) {
      final bloc = context.read<ProductBloc>();
      for (final id in _selectedProductIds) {
        final p = allProducts.firstWhere((item) => item.id == id, orElse: () => allProducts.first);
        final updated = Product(
          id: p.id,
          name: p.name,
          barcode: p.barcode,
          price: p.price,
          costPrice: p.costPrice,
          wholesalePrice: p.wholesalePrice,
          stock: p.stock + selectedQty,
          category: p.category,
          isWeighted: p.isWeighted,
          expiryDate: p.expiryDate,
        );
        bloc.add(UpdateProduct(updated));
      }
      SoundService.playRestockSound();
      context.showAppSnackBar('✅ تم استلام الشحنة (+ $selectedQty) لـ $count سلع بنجاح!');
      _clearSelection();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode.trim() == barcode.trim()).firstOrNull;
      if (matchedProduct != null) {
        _searchController.text = matchedProduct.name;
        if (mounted) {
          context.push('/products/edit/${matchedProduct.id}', extra: matchedProduct);
        }
      } else {
        _searchController.text = barcode;
      }
    }
  }

  /// Real Excel / CSV Export saving directly to disk with loading indicator
  Future<void> _exportAndSaveExcel(BuildContext context, List<Product> products) async {
    if (products.isEmpty) {
      context.showAppSnackBar('المخزون فارغ لا توجد سلع لتصديرها!', backgroundColor: Colors.orange[800]!);
      return;
    }

    setState(() => _isExporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'جاري تجهيز وتصدير ملف الإكسل وحفظه... ⏳',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final buffer = StringBuffer();
      // UTF-8 BOM for Microsoft Excel compatibility with Arabic characters
      buffer.write('\uFEFF');
      buffer.writeln('Code-Barres,Nom Produit,Categorie,Prix Vente (DA),Prix Achat (DA),Prix Gros (DA),Stock,Vendu Au Poids');

      for (final p in products) {
        final isWeightStr = (p.isWeighted || p.barcode.startsWith('SCALE_')) ? 'Oui (Poids)' : 'Non (Piece)';
        buffer.writeln('"${p.barcode}","${p.name}","${p.category}",${p.price},${p.costPrice},${p.wholesalePrice},${p.stock},"$isWeightStr"');
      }

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Stock_Nayli_Market_$dateStr.csv';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      setState(() => _isExporting = false);
      SoundService.playCheckoutSuccess();

      // Trigger Android native share/save to storage dialog
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: fileName)],
        text: '📊 تقرير مخزون نايلـي ماركت - $dateStr (${products.length} سلعة)',
      );

      if (context.mounted) {
        context.showAppSnackBar(
          '✅ تم إنشاء وحفظ ملف الإكسل بنجاح ($fileName)',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        context.showAppSnackBar('حدث خطأ أثناء تصدير الملف: $e', backgroundColor: Colors.red[800]!);
      }
      setState(() => _isExporting = false);
    }
  }

  /// Advanced Weighable Restock Modal (استلام سلع الميزان بالكغ والأكياس والفاقد)
  void _showWeighableRestockModal(Product product) {
    double grossWeight = 10.0;
    double tareLossPercent = 0.0;
    double costPerKg = product.costPrice > 0 ? product.costPrice : (product.price * 0.75);
    final TextEditingController grossWeightCtrl = TextEditingController(text: '10.0');
    final TextEditingController costCtrl = TextEditingController(text: costPerKg.toStringAsFixed(0));
    final TextEditingController tareCtrl = TextEditingController(text: '0');

    AdaptiveModalHelper.showAdaptiveModal(
      context: context,
      desktopMaxWidth: 560,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final double parsedGross = double.tryParse(grossWeightCtrl.text.trim()) ?? grossWeight;
          final double parsedTare = double.tryParse(tareCtrl.text.trim()) ?? tareLossPercent;
          final double parsedCost = double.tryParse(costCtrl.text.trim()) ?? costPerKg;
          final double netWeight = (parsedGross * (1.0 - (parsedTare / 100.0))).clamp(0.0, 999999.0);
          final double totalBatchCost = netWeight * parsedCost;
          final double totalBatchSale = netWeight * product.price;
          final double estimatedProfit = totalBatchSale - totalBatchCost;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.scale_rounded, color: Colors.teal, size: 24),
                          SizedBox(width: 8),
                          Text('استلام شحنة بالميزان ⚖️📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('المخزون الحالي: ${product.stock} كغ • سعر البيع: ${product.price.toStringAsFixed(0)} دج/كغ',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  const SizedBox(height: 14),

                  // Gross Weight Input & Presets
                  const Text('الوزن الإجمالي المستلم (بالكيلوغرام):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: grossWeightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.0',
                      suffixText: 'كغ (Kg)',
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [2.5, 5.0, 10.0, 25.0, 50.0].map((amt) {
                      return ActionChip(
                        label: Text('+$amt كغ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                        onPressed: () {
                          setModalState(() {
                            grossWeightCtrl.text = amt.toStringAsFixed(1);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Cost & Tare Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سعر تكلفة الكيلو (Achat):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: costCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '0', suffixText: 'دج/كغ'),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('نسبة الفاقد/الرطوبة (Tare):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: tareCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '0', suffixText: '%'),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Financial Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الوزن الصافي المضاف للستوك:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${netWeight.toStringAsFixed(2)} كغ',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي تكلفة الشحنة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${totalBatchCost.toStringAsFixed(0)} دج',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الربح الصافي المتوقع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('+${estimatedProfit.toStringAsFixed(0)} دج',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('تأكيد استلام ${netWeight.toStringAsFixed(1)} كغ (المجموع: ${(product.stock + netWeight).toStringAsFixed(1)} كغ)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final updated = Product(
                        id: product.id,
                        name: product.name,
                        barcode: product.barcode,
                        price: product.price,
                        costPrice: parsedCost,
                        wholesalePrice: product.wholesalePrice,
                        stock: (product.stock + netWeight.round()).toInt(),
                        category: product.category,
                        isWeighted: true,
                        expiryDate: product.expiryDate,
                      );
                      context.read<ProductBloc>().add(UpdateProduct(updated));
                      SoundService.playRestockSound();
                      context.showAppSnackBar('✅ تم استلام شحنة الميزان وتحديث المخزون بدقة!');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickRestockModal(Product product) {
    if (product.isWeighted || product.barcode.startsWith('SCALE_') || product.name.contains('ميزان') || product.name.contains('كغ')) {
      _showWeighableRestockModal(product);
      return;
    }

    int addQty = 10;
    AdaptiveModalHelper.showAdaptiveModal(
      context: context,
      desktopMaxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text('استلام شحنة جديدة 📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('المخزون الحالي: ${product.stock} قطعة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('اختر الكمية المضافة للشحنة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: addQty > 1 ? () => setModalState(() => addQty--) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+$addQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => setModalState(() => addQty++),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [5, 10, 24, 50, 100].map((amt) {
                  return ActionChip(
                    label: Text('+$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    backgroundColor: addQty == amt ? Colors.green.withOpacity(0.2) : Colors.grey[100],
                    onPressed: () => setModalState(() => addQty = amt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text('تأكيد إضافة +$addQty إلى المخزن (المجموع: ${product.stock + addQty})', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  final updated = Product(
                    id: product.id,
                    name: product.name,
                    barcode: product.barcode,
                    price: product.price,
                    costPrice: product.costPrice,
                    wholesalePrice: product.wholesalePrice,
                    stock: product.stock + addQty,
                    category: product.category,
                    isWeighted: product.isWeighted,
                    expiryDate: product.expiryDate,
                  );
                  context.read<ProductBloc>().add(UpdateProduct(updated));
                  SoundService.playRestockSound();
                  context.showAppSnackBar('✅ تم استلام الشحنة وتحديث المخزون بنجاح!');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pinToQuickSale(BuildContext context, Product product) async {
    final box = HiveDatabase.quickItemsBox;
    final id = 'quick_${product.id}';
    final item = {
      'id': id,
      'name': product.name,
      'price': product.price,
      'costPrice': product.costPrice,
      'icon': '🛍️',
      'linkedProductId': product.id,
    };
    await box.put(id, item);
    SoundService.playScanBeep();
    if (context.mounted) {
      context.showAppSnackBar(
        '⚡ تم تثبيت (${product.name}) في شريط البيع السريع بنجاح!',
        backgroundColor: Colors.teal[800]!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey[100]!;

    return Scaffold(
      appBar: _isMultiSelectMode
          ? AppBar(
              backgroundColor: AppTheme.primaryColor,
              elevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _clearSelection,
              ),
              title: Text(
                'المحدد: ${_selectedProductIds.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              actions: [
                BlocBuilder<ProductBloc, ProductState>(
                  builder: (context, state) {
                    final query = _searchQuery.trim().toLowerCase();
                    final filtered = state.products.where((p) {
                      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query) || p.barcode.contains(query);
                      if (!matchesQuery) return false;
                      if (_selectedCategoryIndex == 0) return true;
                      if (_selectedCategoryIndex == 1) {
                        return p.isWeighted || p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ');
                      }
                      final catDef = _categoryTabsDef[_selectedCategoryIndex];
                      final pCat = p.category.toLowerCase();
                      return pCat.contains((catDef['ar'] ?? '').toLowerCase()) || pCat.contains((catDef['fr'] ?? '').toLowerCase());
                    }).toList();

                    return TextButton(
                      onPressed: () => _selectAllFiltered(filtered),
                      child: const Text('تحديد الكل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    );
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.chevron_left,
                    size: 28, color: Theme.of(context).primaryColor),
                onPressed: () => context.pop(),
              ),
              title: Text(context.tr('products_management'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded, color: AppTheme.primaryColor),
                  tooltip: 'تحديد متعدد للسلع ☑️',
                  onPressed: () => setState(() => _isMultiSelectMode = true),
                ),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),
                  tooltip: 'تصدير وحفظ ملف Excel 📊',
                  onPressed: () {
                    final productState = context.read<ProductBloc>().state;
                    _exportAndSaveExcel(context, productState.products);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                  tooltip: 'كتالوج السلع الجزائرية (15,500+)',
                  onPressed: () => context.push('/products/catalog'),
                ),
              ],
            ),
      body: Column(
        children: [
          // Master Catalog Quick Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              onTap: () => context.push('/products/catalog'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor.withOpacity(0.12), AppTheme.primaryColor.withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مكتبة السلع الجزائرية (15,500+ منتج)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                          Text('استورد السلع الجاهزة وأسعارها لمخزونك بدون مسح فردي',
                              style: TextStyle(fontSize: 10, color: Colors.black87)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
          ),

          // Quick Tools Row (Shelf Price Tags, Inventory Audit & Invoices)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/inventory-audit'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_rounded, size: 15, color: Colors.teal),
                          SizedBox(width: 4),
                          Text('الجرد ورأس المال 📋', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/shelf-labels'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.label_important_outline, size: 15, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('ملصقات الرفوف 🏷️', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/supplier-invoices'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 15, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('فواتير الموردين 🚚', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم أو الباركود...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),

          // Categories & Scale Items Horizontal Filter Ribbon
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              return Container(
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categoryTabsDef.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final catDef = _categoryTabsDef[idx];
                    final isSelected = _selectedCategoryIndex == idx;
                    final langCode = Localizations.localeOf(context).languageCode;
                    final label = catDef[langCode] ?? catDef['ar'] ?? '';

                    // Calculate count for this tab
                    int count = 0;
                    if (idx == 0) {
                      count = state.products.length;
                    } else if (idx == 1) {
                      count = state.products.where((p) => p.isWeighted || p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ')).length;
                    } else {
                      final arName = (catDef['ar'] ?? '').toLowerCase();
                      final frName = (catDef['fr'] ?? '').toLowerCase();
                      count = state.products.where((p) {
                        final pCat = p.category.toLowerCase();
                        return pCat.contains(arName) || pCat.contains(frName);
                      }).length;
                    }

                    return FilterChip(
                      label: Text(
                        '$label ($count)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: idx == 1 ? Colors.teal : AppTheme.primaryColor,
                      backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryIndex = idx;
                        });
                        SoundService.playScanBeep();
                      },
                    );
                  },
                ),
              );
            },
          ),

          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.status == ProductStatus.success &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.green),
                  );
                } else if (state.status == ProductStatus.error &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return const Center(
                      child: Text('No products found. Add some!'));
                }

                final filteredProducts = state.products.where((product) {
                  final matchesSearch = product.name.toLowerCase().contains(_searchQuery) ||
                      product.barcode.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;

                  if (_selectedCategoryIndex == 0) return true;
                  if (_selectedCategoryIndex == 1) {
                    return product.isWeighted ||
                        product.barcode.startsWith('SCALE_') ||
                        product.name.contains('ميزان') ||
                        product.name.contains('كغ');
                  }
                  final catDef = _categoryTabsDef[_selectedCategoryIndex];
                  final pCat = product.category.toLowerCase();
                  return pCat.contains((catDef['ar'] ?? '').toLowerCase()) || pCat.contains((catDef['fr'] ?? '').toLowerCase());
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('لا توجد سلع في قسم "$_selectedCategoryFilter"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isWeighable = product.isWeighted || product.barcode.startsWith('SCALE_') || product.name.contains('ميزان') || product.name.contains('كغ');
                    final isSelected = _selectedProductIds.contains(product.id);

                    return InkWell(
                      onTap: () {
                        if (_isMultiSelectMode) {
                          _toggleProductSelection(product.id);
                        } else {
                          context.push('/products/edit/${product.id}', extra: product);
                        }
                      },
                      onLongPress: () {
                        _toggleProductSelection(product.id);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withOpacity(0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : borderColor,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isMultiSelectMode) ...[
                              Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (_) => _toggleProductSelection(product.id),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5),
                                        ),
                                      ),
                                      if (isWeighable) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                          ),
                                          child: const Text('⚖️ ميزان', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: AppTheme.primaryColor),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: product.stock > 5
                                              ? Colors.green.withOpacity(0.1)
                                              : (product.stock > 0
                                                  ? Colors.orange.withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isWeighable
                                              ? '${product.stock} كغ'
                                              : '${product.stock} ${context.tr('in_stock')}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: product.stock > 5
                                                ? Colors.green[800]
                                                : (product.stock > 0
                                                    ? Colors.orange[800]
                                                    : Colors.red[800]),
                                          ),
                                        ),
                                      ),
                                      if (product.category.isNotEmpty && product.category != 'عام') ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(product.category, style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Modern Options Dropdown Menu (Arrow / More Button)
                            PopupMenuButton<String>(
                              tooltip: 'خيارات وإدارة السلعة',
                              icon: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF1E293B)),
                                    SizedBox(width: 2),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.grey),
                                  ],
                                ),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (action) async {
                                if (action == 'restock') {
                                  _showQuickRestockModal(product);
                                } else if (action == 'label') {
                                  _printSingleShelfLabel(context, product);
                                } else if (action == 'pin') {
                                  _pinToQuickSale(context, product);
                                } else if (action == 'edit') {
                                  final auth = await SecurityPinHelper.authenticate(
                                    context,
                                    title: 'تعديل السلعة والأسعار',
                                  );
                                  if (auth && context.mounted) {
                                    context.push('/products/edit/${product.id}', extra: product);
                                  }
                                } else if (action == 'delete') {
                                  _confirmDelete(context, product);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'restock',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 20),
                                      SizedBox(width: 10),
                                      Text('استلام شحنة جديدة 📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 20),
                                      SizedBox(width: 10),
                                      Text('تعديل السلعة والأسعار ✏️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'label',
                                  child: Row(
                                    children: [
                                      Icon(Icons.label_important_outline, color: Colors.amber, size: 20),
                                      SizedBox(width: 10),
                                      Text('طباعة ملصق السعر 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'pin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, color: Colors.teal, size: 20),
                                      SizedBox(width: 10),
                                      Text('تثبيت في البيع السريع ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      SizedBox(width: 10),
                                      Text('حذف من المخزون 🗑️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: (_isMultiSelectMode && _selectedProductIds.isNotEmpty)
          ? BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                final selectedCount = _selectedProductIds.length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إجراءات مجمعة ($selectedCount سلع محددة):',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            TextButton(
                              onPressed: _clearSelection,
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('إلغاء التحديد ✖', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Batch Restock
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text('استلام شحنة 📦', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => _batchRestock(context, state.products),
                              ),
                              const SizedBox(width: 8),

                              // Batch Move Category
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                                label: const Text('نقل لقسم 📂', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => _batchMoveCategory(context, state.products),
                              ),
                              const SizedBox(width: 8),

                              // Batch Shelf Labels
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.label_outline, size: 16),
                                label: const Text('طباعة ملصقات 🏷️', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => context.push('/products/shelf-labels'),
                              ),
                              const SizedBox(width: 8),

                              // Batch Delete
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.delete_forever, size: 16),
                                label: Text('حذف ($selectedCount) 🗑️', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => _batchDelete(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final auth = await SecurityPinHelper.authenticate(
            context,
            title: 'إضافة سلعة جديدة',
          );
          if (auth && context.mounted) {
            context.push('/products/add');
          }
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) async {
    final auth = await SecurityPinHelper.authenticate(
      context,
      title: 'حذف السلعة نهائياً',
    );
    if (!auth || !context.mounted) return;

    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('حذف السلعة'),
          content: Text('هل أنت متأكد من حذف ${product.name} نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printSingleShelfLabel(BuildContext context, Product product) async {
    int copies = 1;
    ShelfLabelSize selectedSize = ShelfLabelSize.standard50x30;
    ShelfLabelTemplate selectedTemplate = product.isWeighted || product.barcode.startsWith('SCALE_')
        ? ShelfLabelTemplate.scaleWeight
        : ShelfLabelTemplate.shelfTag;

    final shopName = ShelfLabelGenerator.getEffectiveShopName();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final config = ShelfLabelConfig(
            size: selectedSize,
            template: selectedTemplate,
            includeShopName: true,
            includeDate: true,
            includeBarcode: true,
            showHriDigits: true,
            currencySymbol: 'دج',
            shopName: shopName,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.label_important_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('طباعة ملصق وباركود السلعة 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live Tag Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        Text('🏪 $shopName', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(
                          '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        if (product.barcode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'كود: ${product.barcode}',
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Template Selection
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('النموذج:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('بطاقة رف', style: TextStyle(fontSize: 10.5)),
                          selected: selectedTemplate == ShelfLabelTemplate.shelfTag,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.shelfTag);
                          },
                        ),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          label: const Text('لاصقة باركود', style: TextStyle(fontSize: 10.5)),
                          selected: selectedTemplate == ShelfLabelTemplate.productSticker,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.productSticker);
                          },
                        ),
                        if (product.isWeighted || product.barcode.startsWith('SCALE_')) ...[
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('ملصق ميزان', style: TextStyle(fontSize: 10.5)),
                            selected: selectedTemplate == ShelfLabelTemplate.scaleWeight,
                            onSelected: (v) {
                              if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.scaleWeight);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Size Selection
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('المقاس:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final sz in [
                          ShelfLabelSize.standard50x30,
                          ShelfLabelSize.compact40x30,
                          ShelfLabelSize.mini38x25,
                          ShelfLabelSize.roll80mm,
                        ]) ...[
                          ChoiceChip(
                            label: Text(
                              sz == ShelfLabelSize.standard50x30
                                  ? '50×30 مم'
                                  : sz == ShelfLabelSize.compact40x30
                                      ? '40×30 مم'
                                      : sz == ShelfLabelSize.mini38x25
                                          ? '38×25 مم'
                                          : 'رول 80 مم',
                              style: const TextStyle(fontSize: 10.5),
                            ),
                            selected: selectedSize == sz,
                            onSelected: (v) {
                              if (v) setDialogState(() => selectedSize = sz);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity Selector Row
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('عدد النسخ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final count in [1, 2, 3, 5, 10]) ...[
                        ChoiceChip(
                          label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          selected: copies == count,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          onSelected: (v) {
                            if (v) setDialogState(() => copies = count);
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.bluetooth_connected, size: 16),
                label: Text('بلوتوث ($copies)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final isConnected = await PrintBluetoothThermal.connectionStatus;
                  if (!isConnected) {
                    if (context.mounted) {
                      context.showAppSnackBar(
                        '⚠️ الطابعة الحرارية غير متصلة! يرجى تشغيل البلوتوث وتوصيلها في الإعدادات أو استخدام طباعة ويندوز/PDF.',
                        backgroundColor: Colors.orange[800]!,
                      );
                    }
                    return;
                  }

                  try {
                    final bytes = ShelfLabelGenerator.generateEscPosBytes(
                      itemsWithCopies: [MapEntry(product, copies)],
                      config: config,
                    );
                    await PrintBluetoothThermal.writeBytes(bytes);
                    SoundService.playCheckoutSuccess();
                    if (context.mounted) {
                      context.showAppSnackBar(
                        '✅ تم إرسال $copies ملصق لـ (${product.name}) إلى الطابعة الحرارية بنجاح!',
                        backgroundColor: Colors.green[800]!,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
                    }
                  }
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: Text('ويندوز/PDF ($copies)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Printing.layoutPdf(
                    name: 'label_${product.barcode}_$copies',
                    format: config.size.pageFormat,
                    onLayout: (format) async {
                      return await ShelfLabelGenerator.generateLabelsPdf(
                        itemsWithCopies: [MapEntry(product, copies)],
                        config: config,
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}


