import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class StockInPage extends StatefulWidget {
  const StockInPage({super.key});

  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  String _activeBarcode = '';
  String _productName = '';
  double _price = 0.0;
  int _quantityToAdd = 12;
  int _currentStock = 0;
  bool _isExistingInShop = false;
  String? _existingProductId;
  DateTime? _lastScanTime;
  String? _lastScannedBarcode;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '12');

  final List<Map<String, dynamic>> _sessionStockIns = [];

  @override
  void dispose() {
    _scannerController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedBarcode == barcode && _lastScanTime != null) {
      if (now.difference(_lastScanTime!).inMilliseconds < 1200) {
        return;
      }
    }
    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    final hasVib = await Vibration.hasVibrator();
    if (hasVib == true) Vibration.vibrate(duration: 50);

    _processScannedBarcode(barcode.trim());
  }

  void _processScannedBarcode(String barcode) {
    setState(() {
      _activeBarcode = barcode;
    });

    final productState = context.read<ProductBloc>().state;
    final existingShopProduct = productState.products
        .where((p) => p.barcode.trim() == barcode.trim())
        .firstOrNull;

    if (existingShopProduct != null) {
      setState(() {
        _isExistingInShop = true;
        _existingProductId = existingShopProduct.id;
        _productName = existingShopProduct.name;
        _price = existingShopProduct.price;
        _currentStock = existingShopProduct.stock;

        _nameController.text = _productName;
        _priceController.text = _price.toStringAsFixed(2);
      });
    } else {
      final masterItem = MasterCatalogSeed.lookup(barcode);
      setState(() {
        _isExistingInShop = false;
        _existingProductId = null;
        _currentStock = 0;
        _productName = masterItem?.name ?? '';
        _price = masterItem?.defaultPrice ?? 0.0;

        _nameController.text = _productName;
        _priceController.text = _price > 0 ? _price.toStringAsFixed(2) : '';
      });
    }
  }

  void _saveStockIn() {
    if (_activeBarcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('stock_in_hint')), backgroundColor: Colors.orange),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('required')), backgroundColor: Colors.red),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final qty = int.tryParse(_qtyController.text.trim()) ?? _quantityToAdd;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('required')), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isExistingInShop && _existingProductId != null) {
      context.read<ProductBloc>().add(AdjustProductStock(
        productId: _existingProductId!,
        quantityDelta: qty,
        newPrice: price > 0 ? price : null,
      ));
    } else {
      final newProduct = Product(
        id: const Uuid().v4(),
        name: name,
        barcode: _activeBarcode,
        price: price,
        stock: qty,
      );
      context.read<ProductBloc>().add(AddProduct(newProduct));
    }

    setState(() {
      _sessionStockIns.insert(0, {
        'name': name,
        'barcode': _activeBarcode,
        'qty': qty,
        'price': price,
        'time': DateTime.now(),
      });

      _activeBarcode = '';
      _lastScannedBarcode = null;
      _productName = '';
      _nameController.clear();
      _priceController.clear();
      _qtyController.text = '12';
      _quantityToAdd = 12;
      _isExistingInShop = false;
      _existingProductId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.tr('stock_added_msg')} : $name (+$qty)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('stock_in_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flashlight_on : Icons.flashlight_off),
            onPressed: () {
              setState(() => _isFlashOn = !_isFlashOn);
              _scannerController.toggleTorch();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Top Scanner Area
          SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: Container(
                    width: 220,
                    height: 110,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Text(
                    _activeBarcode.isEmpty ? context.tr('stock_in_hint') : '${context.tr('barcode_label')}: $_activeBarcode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                )
              ],
            ),
          ),

          // Middle Form Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_activeBarcode.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isExistingInShop ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isExistingInShop ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(_isExistingInShop ? Icons.inventory_2 : Icons.auto_awesome, color: _isExistingInShop ? Colors.blue : Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isExistingInShop
                                      ? '${context.tr('existing_in_shop')} (${context.tr('current_stock')}: $_currentStock)'
                                      : context.tr('master_recognized'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _isExistingInShop ? Colors.blue[900] : Colors.green[900],
                                  ),
                                ),
                                Text('${context.tr('barcode_label')}: $_activeBarcode',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Product Name Input
                  Text(context.tr('product_name'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: context.tr('product_name'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity Selector with quick chips
                  Text(context.tr('received_qty'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '12',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickQtyChip(6),
                      const SizedBox(width: 4),
                      _buildQuickQtyChip(12),
                      const SizedBox(width: 4),
                      _buildQuickQtyChip(24),
                      const SizedBox(width: 4),
                      _buildQuickQtyChip(48),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selling Price
                  Text(context.tr('selling_price'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '${AppConstants.currencySymbol} ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Button
                  PrimaryButton(
                    onPressed: _saveStockIn,
                    icon: Icons.add_shopping_cart,
                    label: context.tr('save_stock'),
                  ),

                  const SizedBox(height: 20),

                  // Session History
                  if (_sessionStockIns.isNotEmpty) ...[
                    const Divider(),
                    Text(context.tr('session_stock_ins'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._sessionStockIns.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${context.tr('barcode_label')}: ${item['barcode']}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Text('+${item['qty']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickQtyChip(int qty) {
    return InkWell(
      onTap: () {
        setState(() {
          _quantityToAdd = qty;
          _qtyController.text = qty.toString();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('+$qty', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12)),
      ),
    );
  }
}

