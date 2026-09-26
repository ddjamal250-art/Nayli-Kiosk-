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
import '../../../../core/widgets/product_image_display.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../widgets/quick_receive_modal.dart';
import '../widgets/coffee_recipe_modal.dart';

class ProductListPage extends StatefulWidget {
  ProductListPage({super.key});

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
    {'key': 'all', 'ar': 'Ø§Ù„ÙƒÙ„', 'fr': 'Tous', 'en': 'All'},
    {'key': 'coffee_ready', 'ar': 'â˜• Ø§Ù„Ù‚Ù‡ÙˆØ© Ø§Ù„Ø¬Ø§Ù‡Ø²Ø©', 'fr': 'â˜• CafÃ© PrÃªt', 'en': 'â˜• Ready Coffee'},
    {'key': 'scale', 'ar': 'âš–ï¸ Ù…ÙˆØ§Ø¯ Ø§Ù„Ù…ÙŠØ²Ø§Ù†', 'fr': 'âš–ï¸ Vrac & Balance', 'en': 'âš–ï¸ Scale & Bulk'},
    {'key': 'stationery', 'ar': 'ðŸ“š Ø£Ø¯ÙˆØ§Øª Ù…Ø¯Ø±Ø³ÙŠØ©', 'fr': 'ðŸ“š Papeterie', 'en': 'ðŸ“š Stationery'},
    {'key': 'tobacco', 'ar': 'ðŸš¬ ØªØ¨Øº ÙˆØ³Ø¬Ø§Ø¦Ø±', 'fr': 'ðŸš¬ Tabac', 'en': 'ðŸš¬ Tobacco'},
    {'key': 'food', 'ar': 'Ù…ÙˆØ§Ø¯ ØºØ°Ø§Ø¦ÙŠØ©', 'fr': 'Alimentation', 'en': 'Groceries'},
    {'key': 'dairy', 'ar': 'Ø­Ù„ÙŠØ¨ ÙˆÙ…Ø´ØªÙ‚Ø§ØªÙ‡', 'fr': 'Produits Laitiers', 'en': 'Dairy'},
    {'key': 'bakery', 'ar': 'Ù…Ø®Ø¨ÙˆØ²Ø§Øª ÙˆØ¹Ø¬Ø§Ø¦Ù†', 'fr': 'Boulangerie & PÃ¢tes', 'en': 'Bakery & Pasta'},
    {'key': 'beverages', 'ar': 'Ù…Ø´Ø±ÙˆØ¨Ø§Øª ÙˆÙ…ÙŠØ§Ù‡', 'fr': 'Boissons & Eaux', 'en': 'Beverages & Water'},
    {'key': 'cleaning', 'ar': 'Ù†Ø¸Ø§ÙØ© ÙˆØªØ¬Ù…ÙŠÙ„', 'fr': 'Entretien & HygiÃ¨ne', 'en': 'Cleaning & Hygiene'},
    {'key': 'sweets', 'ar': 'Ø­Ù„ÙˆÙŠØ§Øª ÙˆØ³ÙƒØ§ÙƒØ±', 'fr': 'Confiserie & Biscuits', 'en': 'Sweets & Biscuits'},
    {'key': 'fruits', 'ar': 'Ø®Ø¶Ø± ÙˆÙÙˆØ§ÙƒÙ‡', 'fr': 'Fruits & LÃ©gumes', 'en': 'Fruits & Veg'},
    {'key': 'other', 'ar': 'Ø£Ø®Ø±Ù‰', 'fr': 'Autres', 'en': 'Other'},
  ];

  List<String> get _categoryTabs => _categoryTabsDef.map((c) => c['ar']!).toList();
  String get _selectedCategoryFilter =>
      _selectedCategoryIndex < _categoryTabsDef.length ? _categoryTabsDef[_selectedCategoryIndex]['ar']! : 'Ø§Ù„ÙƒÙ„';

  bool _productMatchesTab(Product p, int tabIdx) {
    if (tabIdx == 0) return true;
    if (tabIdx >= _categoryTabsDef.length) return false;
    final catDef = _categoryTabsDef[tabIdx];
    final key = catDef['key'];
    final pCat = p.category.toLowerCase();
    final pName = p.name.toLowerCase();

    if (key == 'coffee_ready') {
      return p.isCoffeeMachineProduct || pCat.contains('Ù‚Ù‡ÙˆØ©') || pCat.contains('Ø´Ø§ÙŠ') || pCat.contains('ÙƒØ§ÙÙŠØªÙŠØ±ÙŠØ§');
    }
    if (key == 'scale') {
      return p.isWeighted || p.barcode.startsWith('SCALE_') || pName.contains('Ù…ÙŠØ²Ø§Ù†') || pName.contains('ÙƒØº');
    }
    if (key == 'stationery') {
      return pCat.contains('Ù…Ø¯Ø±Ø³') || pCat.contains('Ù…ÙƒØªØ¨') || pCat.contains('ÙˆØ±Ù‚') || pCat.contains('ÙƒØ±Ø§Ø³') || pCat.contains('Ù‚Ù„Ù…') || pCat.contains('papeterie');
    }
    if (key == 'tobacco') {
      return p.isTobacco || pCat.contains('ØªØ¨Øº') || pCat.contains('Ø³Ø¬Ø§Ø¦Ø±') || pCat.contains('Ø´Ù…Ø©') || pCat.contains('Ù…Ø¹Ø³Ù„');
    }
    if (key == 'beverages') {
      final isDrink = p.isBeverage || pCat.contains('Ù…Ø´Ø±ÙˆØ¨') || pCat.contains('Ù…Ø§Ø¡') || pCat.contains('Ø¹ØµÙŠØ±') || pCat.contains('ØºØ§Ø²ÙŠ');
      return isDrink && !p.isCoffeeMachineProduct && !pCat.contains('Ù‚Ù‡ÙˆØ©') && !pCat.contains('Ø´Ø§ÙŠ');
    }

    final arName = (catDef['ar'] ?? '').toLowerCase();
    final frName = (catDef['fr'] ?? '').toLowerCase();
    return pCat.contains(arName) || pCat.contains(frName);
  }

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
    final auth = await SecurityPinHelper.authenticate(context, title: 'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø­Ø°Ù Ø§Ù„Ø¬Ù…Ø§Ø¹ÙŠ');
    if (!auth || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Ø­Ø°Ù $count Ø³Ù„Ø¹ Ù…Ø­Ø¯Ø¯Ø©ØŸ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø±ØºØ¨ØªÙƒ ÙÙŠ Ø­Ø°Ù $count Ø³Ù„Ø¹ Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ Ù…Ù† Ø§Ù„Ù…Ø®Ø²ÙˆÙ†ØŸ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù† Ù‡Ø°Ù‡ Ø§Ù„Ø¹Ù…Ù„ÙŠØ©.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('yes_delete_all'), style: TextStyle(fontWeight: FontWeight.bold)),
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
      context.showAppSnackBar('ðŸ—‘ï¸ ØªÙ… Ø­Ø°Ù $count Ø³Ù„Ø¹ Ø¨Ù†Ø¬Ø§Ø­ Ù…Ù† Ø§Ù„Ù…Ø®Ø²Ù†!', backgroundColor: Colors.red[800]!);
      _clearSelection();
    }
  }

  /// Batch Move Category
  Future<void> _batchMoveCategory(BuildContext context, List<Product> allProducts) async {
    if (_selectedProductIds.isEmpty) return;
    final count = _selectedProductIds.length;
    String targetCat = 'Ù…ÙˆØ§Ø¯ ØºØ°Ø§Ø¦ÙŠØ© ÙˆÙ…Ø¹Ù„Ø¨Ø§Øª';

    final selectedCat = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.drive_file_move_rounded, color: AppTheme.primaryColor, size: 24),
              SizedBox(width: 8),
              Text('Ù†Ù‚Ù„ $count Ø³Ù„Ø¹ Ù„Ù‚Ø³Ù… Ø¢Ø®Ø± ðŸ“‚', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ø§Ø®ØªØ± Ø§Ù„Ù‚Ø³Ù… Ø§Ù„Ù…Ø³ØªÙ‡Ø¯Ù Ù„Ù†Ù‚Ù„ Ø§Ù„Ø³Ù„Ø¹ Ø§Ù„Ù…Ø­Ø¯Ø¯Ø© Ø¥Ù„ÙŠÙ‡:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: targetCat,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _categoryTabs.where((c) => c != 'Ø§Ù„ÙƒÙ„' && c != 'âš–ï¸ Ù…ÙˆØ§Ø¯ Ø§Ù„Ù…ÙŠØ²Ø§Ù†').map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetCat = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, targetCat),
              child: Text(context.tr('transfer_items_now'), style: TextStyle(fontWeight: FontWeight.bold)),
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
          expiryDate: p.expiryDate,
        );
        bloc.add(UpdateProduct(updated));
      }
      SoundService.playSaveSuccess();
      context.showAppSnackBar('âœ… ØªÙ… Ù†Ù‚Ù„ $count Ø³Ù„Ø¹ Ø¥Ù„Ù‰ Ù‚Ø³Ù… ($selectedCat) Ø¨Ù†Ø¬Ø§Ø­!');
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
              Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Ø§Ø³ØªÙ„Ø§Ù… Ø´Ø­Ù†Ø© Ù„Ù€ $count Ø³Ù„Ø¹ ðŸ“¦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ø§Ø®ØªØ± Ø§Ù„ÙƒÙ…ÙŠØ© Ø§Ù„Ù…Ø¶Ø§ÙØ© Ù„ÙƒÙ„ Ø³Ù„Ø¹Ø© Ù…Ù† Ø§Ù„Ø³Ù„Ø¹ Ø§Ù„Ù…Ø­Ø¯Ø¯Ø©:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: Icon(Icons.remove),
                    onPressed: addQty > 1 ? () => setDialogState(() => addQty--) : null,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('+$addQty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  IconButton.filledTonal(
                    icon: Icon(Icons.add),
                    onPressed: () => setDialogState(() => addQty++),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [5, 10, 24, 50, 100].map((amt) {
                  return ActionChip(
                    label: Text('+$amt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    backgroundColor: addQty == amt ? Colors.green.withOpacity(0.2) : Colors.grey[100],
                    onPressed: () => setDialogState(() => addQty = amt),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, addQty),
              child: Text('Ø¥Ø¶Ø§ÙØ© +$addQty Ù„Ù„ÙƒÙ„ ðŸš€', style: TextStyle(fontWeight: FontWeight.bold)),
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
          expiryDate: p.expiryDate,
        );
        bloc.add(UpdateProduct(updated));
      }
      SoundService.playRestockSound();
      context.showAppSnackBar('âœ… ØªÙ… Ø§Ø³ØªÙ„Ø§Ù… Ø§Ù„Ø´Ø­Ù†Ø© (+ $selectedQty) Ù„Ù€ $count Ø³Ù„Ø¹ Ø¨Ù†Ø¬Ø§Ø­!');
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
      context.showAppSnackBar('Ø§Ù„Ù…Ø®Ø²ÙˆÙ† ÙØ§Ø±Øº Ù„Ø§ ØªÙˆØ¬Ø¯ Ø³Ù„Ø¹ Ù„ØªØµØ¯ÙŠØ±Ù‡Ø§!', backgroundColor: Colors.orange[800]!);
      return;
    }

    setState(() => _isExporting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Ø¬Ø§Ø±ÙŠ ØªØ¬Ù‡ÙŠØ² ÙˆØªØµØ¯ÙŠØ± Ù…Ù„Ù Ø§Ù„Ø¥ÙƒØ³Ù„ ÙˆØ­ÙØ¸Ù‡... â³',
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
        text: 'ðŸ“Š ØªÙ‚Ø±ÙŠØ± Ù…Ø®Ø²ÙˆÙ† Ù†Ø§ÙŠÙ„Ù€ÙŠ Ù…Ø§Ø±ÙƒØª - $dateStr (${products.length} Ø³Ù„Ø¹Ø©)',
      );

      if (context.mounted) {
        context.showAppSnackBar(
          'âœ… ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ ÙˆØ­ÙØ¸ Ù…Ù„Ù Ø§Ù„Ø¥ÙƒØ³Ù„ Ø¨Ù†Ø¬Ø§Ø­ ($fileName)',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        context.showAppSnackBar('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ ØªØµØ¯ÙŠØ± Ø§Ù„Ù…Ù„Ù: $e', backgroundColor: Colors.red[800]!);
      }
      setState(() => _isExporting = false);
    }
  }

  /// Advanced Weighable Restock Modal (Ø§Ø³ØªÙ„Ø§Ù… Ø³Ù„Ø¹ Ø§Ù„Ù…ÙŠØ²Ø§Ù† Ø¨Ø§Ù„ÙƒØº ÙˆØ§Ù„Ø£ÙƒÙŠØ§Ø³ ÙˆØ§Ù„ÙØ§Ù‚Ø¯)
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
                      Row(
                        children: [
                          Icon(Icons.scale_rounded, color: Colors.teal, size: 24),
                          SizedBox(width: 8),
                          Text('Ø§Ø³ØªÙ„Ø§Ù… Ø´Ø­Ù†Ø© Ø¨Ø§Ù„Ù…ÙŠØ²Ø§Ù† âš–ï¸ðŸ“¦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Ø§Ù„Ù…Ø®Ø²ÙˆÙ† Ø§Ù„Ø­Ø§Ù„ÙŠ: ${product.stock} ÙƒØº â€¢ Ø³Ø¹Ø± Ø§Ù„Ø¨ÙŠØ¹: ${product.price.toStringAsFixed(0)} Ø¯Ø¬/ÙƒØº',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                  SizedBox(height: 14),

                  // Gross Weight Input & Presets
                  Text('Ø§Ù„ÙˆØ²Ù† Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø³ØªÙ„Ù… (Ø¨Ø§Ù„ÙƒÙŠÙ„ÙˆØºØ±Ø§Ù…):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: grossWeightCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      suffixText: 'ÙƒØº (Kg)',
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [2.5, 5.0, 10.0, 25.0, 50.0].map((amt) {
                      return ActionChip(
                        label: Text('+$amt ÙƒØº', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  SizedBox(height: 14),

                  // Cost & Tare Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ø³Ø¹Ø± ØªÙƒÙ„ÙØ© Ø§Ù„ÙƒÙŠÙ„Ùˆ (Achat):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            SizedBox(height: 4),
                            TextFormField(
                              controller: costCtrl,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(hintText: '0', suffixText: 'Ø¯Ø¬/ÙƒØº'),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ù†Ø³Ø¨Ø© Ø§Ù„ÙØ§Ù‚Ø¯/Ø§Ù„Ø±Ø·ÙˆØ¨Ø© (Tare):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                            SizedBox(height: 4),
                            TextFormField(
                              controller: tareCtrl,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(hintText: '0', suffixText: '%'),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  // Financial Breakdown Card
                  Container(
                    padding: EdgeInsets.all(12),
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
                            Text('Ø§Ù„ÙˆØ²Ù† Ø§Ù„ØµØ§ÙÙŠ Ø§Ù„Ù…Ø¶Ø§Ù Ù„Ù„Ø³ØªÙˆÙƒ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('${netWeight.toStringAsFixed(2)} ÙƒØº',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ø¥Ø¬Ù…Ø§Ù„ÙŠ ØªÙƒÙ„ÙØ© Ø§Ù„Ø´Ø­Ù†Ø©:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${totalBatchCost.toStringAsFixed(0)} Ø¯Ø¬',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ø§Ù„Ø±Ø¨Ø­ Ø§Ù„ØµØ§ÙÙŠ Ø§Ù„Ù…ØªÙˆÙ‚Ø¹:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            Text('+${estimatedProfit.toStringAsFixed(0)} Ø¯Ø¬',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('ØªØ£ÙƒÙŠØ¯ Ø§Ø³ØªÙ„Ø§Ù… ${netWeight.toStringAsFixed(1)} ÙƒØº (Ø§Ù„Ù…Ø¬Ù…ÙˆØ¹: ${(product.stock + netWeight).toStringAsFixed(1)} ÙƒØº)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                        expiryDate: product.expiryDate,
                      );
                      context.read<ProductBloc>().add(UpdateProduct(updated));
                      SoundService.playRestockSound();
                      context.showAppSnackBar('âœ… ØªÙ… Ø§Ø³ØªÙ„Ø§Ù… Ø´Ø­Ù†Ø© Ø§Ù„Ù…ÙŠØ²Ø§Ù† ÙˆØªØ­Ø¯ÙŠØ« Ø§Ù„Ù…Ø®Ø²ÙˆÙ† Ø¨Ø¯Ù‚Ø©!');
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
    if (product.isWeighted || product.barcode.startsWith('SCALE_') || product.name.contains('ميزان') || product.name.contains('وزن')) {
      _showWeighableRestockModal(product);
      return;
    }
    QuickReceiveModal.show(context, product);
  }

  void _pinToQuickSale(BuildContext context, Product product) async {
    final box = HiveDatabase.quickItemsBox;
    final id = 'quick_${product.id}';
    final item = {
      'id': id,
      'name': product.name,
      'price': product.price,
      'costPrice': product.costPrice,
      'icon': 'ðŸ›ï¸',
      'linkedProductId': product.id,
    };
    await box.put(id, item);
    SoundService.playScanBeep();
    if (context.mounted) {
      context.showAppSnackBar(
        'âš¡ ØªÙ… ØªØ«Ø¨ÙŠØª (${product.name}) ÙÙŠ Ø´Ø±ÙŠØ· Ø§Ù„Ø¨ÙŠØ¹ Ø§Ù„Ø³Ø±ÙŠØ¹ Ø¨Ù†Ø¬Ø§Ø­!',
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
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: _clearSelection,
              ),
              title: Text(
                'Ø§Ù„Ù…Ø­Ø¯Ø¯: ${_selectedProductIds.length}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              actions: [
                BlocBuilder<ProductBloc, ProductState>(
                  builder: (context, state) {
                    final query = _searchQuery.trim().toLowerCase();
                    final filtered = state.products.where((p) {
                      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query) || p.barcode.contains(query);
                      if (!matchesQuery) return false;
                      return _productMatchesTab(p, _selectedCategoryIndex);
                    }).toList();

                    return TextButton(
                      onPressed: () => _selectAllFiltered(filtered),
                      child: Text('ØªØ­Ø¯ÙŠØ¯ Ø§Ù„ÙƒÙ„', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(Icons.checklist_rounded, color: AppTheme.primaryColor),
                  tooltip: context.tr('multi_select_tooltip'),
                  onPressed: () => setState(() => _isMultiSelectMode = true),
                ),
                IconButton(
                  icon: Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),
                  tooltip: context.tr('export_excel_tooltip'),
                  onPressed: () {
                    final productState = context.read<ProductBloc>().state;
                    _exportAndSaveExcel(context, productState.products);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                  tooltip: 'ÙƒØªØ§Ù„ÙˆØ¬ Ø§Ù„Ø³Ù„Ø¹ Ø§Ù„Ø¬Ø²Ø§Ø¦Ø±ÙŠØ© (15,500+)',
                  onPressed: () => context.push('/products/catalog'),
                ),
              ],
            ),
      body: Column(
        children: [
          // Quick Tools Row (Shelf Price Tags, Inventory Audit & Invoices)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/inventory-audit'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_rounded, size: 15, color: Colors.teal),
                          SizedBox(width: 4),
                          Text('Ø§Ù„Ø¬Ø±Ø¯ ÙˆØ±Ø£Ø³ Ø§Ù„Ù…Ø§Ù„ ðŸ“‹', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/shelf-labels'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.label_important_outline, size: 15, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('Ù…Ù„ØµÙ‚Ø§Øª Ø§Ù„Ø±ÙÙˆÙ ðŸ·ï¸', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/supplier-invoices'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 15, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ù…ÙˆØ±Ø¯ÙŠÙ† ðŸšš', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            hintText: context.tr('search_name_or_barcode'),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: EdgeInsets.all(12),
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
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categoryTabsDef.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final catDef = _categoryTabsDef[idx];
                    final isSelected = _selectedCategoryIndex == idx;
                    final langCode = Localizations.localeOf(context).languageCode;
                    final label = catDef[langCode] ?? catDef['ar'] ?? '';

                    // Calculate count for this tab
                    final count = state.products.where((p) => _productMatchesTab(p, idx)).length;

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
                      selectedColor: idx == 1 ? Colors.brown : (idx == 2 ? Colors.teal : AppTheme.primaryColor),
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
                if (state.status == ProductStatus.error &&
                    state.message != null &&
                    (ModalRoute.of(context)?.isCurrent ?? false)) {
                  context.showAppSnackBar(state.message!, isError: true);
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return Center(
                      child: Text('No products found. Add some!'));
                }

                final filteredProducts = state.products.where((product) {
                  final matchesSearch = product.name.toLowerCase().contains(_searchQuery) ||
                      product.barcode.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;
                  return _productMatchesTab(product, _selectedCategoryIndex);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø³Ù„Ø¹ ÙÙŠ Ù‚Ø³Ù… "$_selectedCategoryFilter"', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.only(
                      left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isWeighable = product.isWeighted || product.barcode.startsWith('SCALE_') || product.name.contains('Ù…ÙŠØ²Ø§Ù†') || product.name.contains('ÙƒØº');
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
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        padding: EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isMultiSelectMode) ...[
                              Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (_) => _toggleProductSelection(product.id),
                              ),
                              SizedBox(width: 4),
                            ],
                            ProductImageDisplay(
                              imageUrl: product.imageUrl,
                              width: 48,
                              height: 48,
                              borderRadius: 8,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5),
                                        ),
                                      ),
                                      if (isWeighable) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                          ),
                                          child: Text('âš–ï¸ Ù…ÙŠØ²Ø§Ù†', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                        ),
                                        SizedBox(width: 4),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: AppTheme.primaryColor),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                              ? '${product.stock} ÙƒØº'
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
                                      if (product.category.isNotEmpty && product.category != 'Ø¹Ø§Ù…') ...[
                                        SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(product.category, style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Modern Options Dropdown Menu (Arrow / More Button)
                            PopupMenuButton<String>(
                              tooltip: 'Ø®ÙŠØ§Ø±Ø§Øª ÙˆØ¥Ø¯Ø§Ø±Ø© Ø§Ù„Ø³Ù„Ø¹Ø©',
                              icon: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
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
                                    title: context.tr('edit_product_and_prices'),
                                  );
                                  if (auth && context.mounted) {
                                    context.push('/products/edit/${product.id}', extra: product);
                                  }
                                } else if (action == 'delete') {
                                  _confirmDelete(context, product);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'restock',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 20),
                                      SizedBox(width: 10),
                                      Text(context.tr('quick_restock_menu'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 20),
                                      SizedBox(width: 10),
                                      Text(context.tr('edit_product_menu'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'label',
                                  child: Row(
                                    children: [
                                      Icon(Icons.label_important_outline, color: Colors.amber, size: 20),
                                      SizedBox(width: 10),
                                      Text(context.tr('shelf_label_menu'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'pin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, color: Colors.teal, size: 20),
                                      SizedBox(width: 10),
                                      Text(context.tr('pin_to_quick_menu'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      SizedBox(width: 10),
                                      Text(context.tr('delete_product_menu'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.red)),
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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: Offset(0, -4),
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
                              '${context.tr('batch_actions_title')} ($selectedCount):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            TextButton(
                              onPressed: _clearSelection,
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: Text(context.tr('clear_selection'), style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
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
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: Icon(Icons.add_shopping_cart, size: 16),
                                label: Text(context.tr('receive_shipment'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => _batchRestock(context, state.products),
                              ),
                              SizedBox(width: 8),

                              // Batch Move Category
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: Icon(Icons.drive_file_move_outlined, size: 16),
                                label: Text(context.tr('move_to_category'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => _batchMoveCategory(context, state.products),
                              ),
                              SizedBox(width: 8),

                              // Batch Shelf Labels
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: Icon(Icons.label_outline, size: 16),
                                label: Text(context.tr('print_labels'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                onPressed: () => context.push('/products/shelf-labels'),
                              ),
                              SizedBox(width: 8),

                              // Batch Delete
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: Icon(Icons.delete_forever, size: 16),
                                label: Text('Ø­Ø°Ù ($selectedCount) ðŸ—‘ï¸', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
      floatingActionButton: _selectedCategoryIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => CoffeeRecipeModal.show(context),
              icon: const Icon(Icons.coffee),
              label: const Text('إضافة وصفة', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            )
          : FloatingActionButton(
              onPressed: () async {
          final auth = await SecurityPinHelper.authenticate(
            context,
            title: context.tr('add_new_product'),
          );
          if (auth && context.mounted) {
            context.push('/products/add');
          }
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        child: Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) async {
    final auth = await SecurityPinHelper.authenticate(
      context,
      title: context.tr('delete_product_permanently'),
    );
    if (!auth || !context.mounted) return;

    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: Text(context.tr('delete_product')),
          content: Text('Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù ${product.name} Ù†Ù‡Ø§Ø¦ÙŠØ§Ù‹ØŸ'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                final pName = product.name;
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
                SoundService.playDeleteSound();
                context.showAppSnackBar('ðŸ—‘ï¸ ØªÙ… Ø­Ø°Ù "$pName" Ø¨Ù†Ø¬Ø§Ø­', backgroundColor: Colors.red[800]!);
              },
              child: Text(context.tr('delete'), style: TextStyle(color: Colors.red)),
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
            currencySymbol: 'Ø¯Ø¬',
            shopName: shopName,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.label_important_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Ø·Ø¨Ø§Ø¹Ø© Ù…Ù„ØµÙ‚ ÙˆØ¨Ø§Ø±ÙƒÙˆØ¯ Ø§Ù„Ø³Ù„Ø¹Ø© ðŸ·ï¸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live Tag Preview Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        Text('ðŸª $shopName', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        SizedBox(height: 2),
                        Text(product.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        SizedBox(height: 4),
                        Text(
                          '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        if (product.barcode.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ÙƒÙˆØ¯: ${product.barcode}',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Template Selection
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(context.tr('template_label'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(context.tr('shelf_tag'), style: TextStyle(fontSize: 10.5)),
                          selected: selectedTemplate == ShelfLabelTemplate.shelfTag,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.shelfTag);
                          },
                        ),
                        SizedBox(width: 4),
                        ChoiceChip(
                          label: Text(context.tr('barcode_sticker'), style: TextStyle(fontSize: 10.5)),
                          selected: selectedTemplate == ShelfLabelTemplate.productSticker,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.productSticker);
                          },
                        ),
                        if (product.isWeighted || product.barcode.startsWith('SCALE_')) ...[
                          SizedBox(width: 4),
                          ChoiceChip(
                            label: Text(context.tr('scale_sticker'), style: TextStyle(fontSize: 10.5)),
                            selected: selectedTemplate == ShelfLabelTemplate.scaleWeight,
                            onSelected: (v) {
                              if (v) setDialogState(() => selectedTemplate = ShelfLabelTemplate.scaleWeight);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 10),

                  // Size Selection
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(context.tr('size_label'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  SizedBox(height: 4),
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
                                  ? '50Ã—30 Ù…Ù…'
                                  : sz == ShelfLabelSize.compact40x30
                                      ? '40Ã—30 Ù…Ù…'
                                      : sz == ShelfLabelSize.mini38x25
                                          ? '38Ã—25 Ù…Ù…'
                                          : 'Ø±ÙˆÙ„ 80 Ù…Ù…',
                              style: TextStyle(fontSize: 10.5),
                            ),
                            selected: selectedSize == sz,
                            onSelected: (v) {
                              if (v) setDialogState(() => selectedSize = sz);
                            },
                          ),
                          SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // Quantity Selector Row
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(context.tr('copies_count_label'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final count in [1, 2, 3, 5, 10]) ...[
                        ChoiceChip(
                          label: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          selected: copies == count,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          onSelected: (v) {
                            if (v) setDialogState(() => copies = count);
                          },
                        ),
                        SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: Icon(Icons.bluetooth_connected, size: 16),
                label: Text('Ø¨Ù„ÙˆØªÙˆØ« ($copies)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  bool isConnected = false;
                  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
                    isConnected = await PrintBluetoothThermal.connectionStatus;
                  }
                  
                  if (!isConnected) {
                    if (context.mounted) {
                      context.showAppSnackBar(
                        'âš ï¸ Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© Ø§Ù„Ø­Ø±Ø§Ø±ÙŠØ© ØºÙŠØ± Ù…ØªØµÙ„Ø©! ÙŠØ±Ø¬Ù‰ ØªØ´ØºÙŠÙ„ Ø§Ù„Ø¨Ù„ÙˆØªÙˆØ« ÙˆØªÙˆØµÙŠÙ„Ù‡Ø§ ÙÙŠ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø£Ùˆ Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø·Ø¨Ø§Ø¹Ø© ÙˆÙŠÙ†Ø¯ÙˆØ²/PDF.',
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
                    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
                      await PrintBluetoothThermal.writeBytes(bytes);
                    }
                    SoundService.playCheckoutSuccess();
                    if (context.mounted) {
                      context.showAppSnackBar(
                        'âœ… ØªÙ… Ø¥Ø±Ø³Ø§Ù„ $copies Ù…Ù„ØµÙ‚ Ù„Ù€ (${product.name}) Ø¥Ù„Ù‰ Ø§Ù„Ø·Ø§Ø¨Ø¹Ø© Ø§Ù„Ø­Ø±Ø§Ø±ÙŠØ© Ø¨Ù†Ø¬Ø§Ø­!',
                        backgroundColor: Colors.green[800]!,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      context.showAppSnackBar('Ø­Ø¯Ø« Ø®Ø·Ø£ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø·Ø¨Ø§Ø¹Ø©: $e', backgroundColor: Colors.red[800]!);
                    }
                  }
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: Icon(Icons.print_rounded, size: 16),
                label: Text('ÙˆÙŠÙ†Ø¯ÙˆØ²/PDF ($copies)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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



