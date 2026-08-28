import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/data/master_catalog_service.dart';
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
  int _currentStock = 0;
  bool _isExistingInShop = false;
  String? _existingProductId;
  DateTime? _lastScanTime;
  String? _lastScannedBarcode;

  // Arrivage Mode (Carton vs Units)
  bool _isCartonMode = true;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '24');
  final TextEditingController _cartonCountController = TextEditingController(text: '1');
  final TextEditingController _unitsPerCartonController = TextEditingController(text: '24');
  final TextEditingController _cartonCostController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _supplierPhoneController = TextEditingController();

  // Receipt Date & Expiry Date
  DateTime _receiptDate = DateTime.now();
  DateTime? _expiryDate;

  // Item Condition
  String _itemCondition = '✅ ممتازة / سليمة';
  final List<String> _conditions = [
    '✅ ممتازة / سليمة',
    '⚠️ كراتين مبعثرة / متضررة',
    '📦 عينة تجريبية',
  ];

  final List<Map<String, dynamic>> _sessionStockIns = [];

  bool _isUpdatingFromCarton = false;
  bool _isUpdatingFromUnit = false;

  @override
  void initState() {
    super.initState();
    _cartonCountController.addListener(_onCartonInputsChanged);
    _unitsPerCartonController.addListener(_onCartonInputsChanged);
    _cartonCostController.addListener(_onCartonCostChanged);
    _costPriceController.addListener(_onUnitCostChanged);
    _priceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _qtyController.dispose();
    _cartonCountController.dispose();
    _unitsPerCartonController.dispose();
    _cartonCostController.dispose();
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  void _onCartonInputsChanged() {
    if (!_isCartonMode) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final totalUnits = cartons * perCarton;
    _qtyController.text = totalUnits.toString();

    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCarton = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCarton = false;
    }
    setState(() {});
  }

  void _onCartonCostChanged() {
    if (!_isCartonMode || _isUpdatingFromUnit) return;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCarton = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCarton = false;
    }
    setState(() {});
  }

  void _onUnitCostChanged() {
    if (!_isCartonMode || _isUpdatingFromCarton) return;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final unitCost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    if (perCarton > 0 && unitCost > 0) {
      final cartonCost = unitCost * perCarton;
      _isUpdatingFromUnit = true;
      _cartonCostController.text = cartonCost.toStringAsFixed(2);
      _isUpdatingFromUnit = false;
    }
    setState(() {});
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
        _nameController.text = existingShopProduct.name;
        _priceController.text = existingShopProduct.price.toStringAsFixed(2);
        _costPriceController.text = existingShopProduct.costPrice.toStringAsFixed(2);
        _currentStock = existingShopProduct.stock;
      });
      return;
    }

    _isExistingInShop = false;
    _existingProductId = null;
    _currentStock = 0;

    final masterProduct = MasterCatalogService.instance.lookup(barcode);
    if (masterProduct != null) {
      setState(() {
        _nameController.text = masterProduct.name;
        _priceController.text = masterProduct.defaultPrice.toStringAsFixed(2);
        _costPriceController.text = masterProduct.defaultCost.toStringAsFixed(2);
      });
    } else {
      setState(() {
        _nameController.text = '';
        _priceController.text = '';
        _costPriceController.text = '';
      });
    }
  }

  Future<void> _pickReceiptDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _receiptDate = picked);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _submitStockIn() {
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
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد كمية مستلمة صحيحة'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isExistingInShop && _existingProductId != null) {
      final existing = context
          .read<ProductBloc>()
          .state
          .products
          .firstWhere((p) => p.id == _existingProductId);

      final updated = Product(
        id: existing.id,
        name: name,
        barcode: existing.barcode,
        price: price > 0 ? price : existing.price,
        costPrice: costPrice > 0 ? costPrice : existing.costPrice,
        stock: existing.stock + qty,
      );
      context.read<ProductBloc>().add(UpdateProduct(updated));
    } else {
      final newProduct = Product(
        id: const Uuid().v4(),
        name: name,
        barcode: _activeBarcode,
        price: price,
        costPrice: costPrice,
        stock: qty,
      );
      context.read<ProductBloc>().add(AddProduct(newProduct));
    }

    final cartons = _isCartonMode ? (int.tryParse(_cartonCountController.text.trim()) ?? 1) : 0;
    final unitsPer = _isCartonMode ? (int.tryParse(_unitsPerCartonController.text.trim()) ?? qty) : qty;

    setState(() {
      _sessionStockIns.insert(0, {
        'name': name,
        'barcode': _activeBarcode,
        'qty': qty,
        'cartons': cartons,
        'unitsPerCarton': unitsPer,
        'isCarton': _isCartonMode,
        'price': price,
        'costPrice': costPrice,
        'supplier': _supplierNameController.text.trim(),
        'supplierPhone': _supplierPhoneController.text.trim(),
        'receiptDate': _receiptDate,
        'expiryDate': _expiryDate,
        'condition': _itemCondition,
      });

      _activeBarcode = '';
      _lastScannedBarcode = null;
      _nameController.clear();
      _priceController.clear();
      _costPriceController.clear();
      _cartonCostController.clear();
      _cartonCountController.text = '1';
      _unitsPerCartonController.text = '24';
      _qtyController.text = '24';
      _isExistingInShop = false;
      _existingProductId = null;
      _expiryDate = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم تسجيل استلام: \$name (+\$qty وحدة)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('استلام السلع / أريفاج Pro',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
          ),
          IconButton(
            icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off),
            onPressed: () {
              setState(() => _isCameraOn = !_isCameraOn);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Scanner Section
            if (_isCameraOn)
              Container(
                height: 180,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                    Container(
                      width: 220,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _activeBarcode.isNotEmpty
                              ? 'باركود: \$_activeBarcode'
                              : 'وجّه الكاميرا نحو باركود السلعة المستلمة',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Form Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barcode / Recognition Banner
                  if (_activeBarcode.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isExistingInShop ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
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
                                      ? 'منتج موجود في المحل (المخزون الحالي: \$_currentStock)'
                                      : 'منتج جديد تم التعرف عليه من المكتبة الجزائرية',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _isExistingInShop ? Colors.blue[900] : Colors.green[900],
                                  ),
                                ),
                                Text('الباركود: \$_activeBarcode',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Manual Barcode Entry option
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'الباركود (مسح أو كتابة يدوية)',
                              hintText: 'مثال: 613000000000',
                              prefixIcon: Icon(Icons.qr_code),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (val) {
                              if (val.trim().length >= 4) {
                                _processScannedBarcode(val.trim());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Product Name
                  const Text('اسم المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'مثال: حليب كونديا 1L أو زيت إيليو 5L...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Carton vs Units Mode Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isCartonMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isCartonMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _isCartonMode ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 16, color: _isCartonMode ? AppTheme.primaryColor : Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '📦 استلام بالكرتونة / الباك',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isCartonMode ? AppTheme.primaryColor : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isCartonMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isCartonMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !_isCartonMode ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tag, size: 16, color: !_isCartonMode ? AppTheme.primaryColor : Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '🏷️ استلام بالحبة الفردية',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !_isCartonMode ? AppTheme.primaryColor : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Carton Details (If Carton Mode)
                  if (_isCartonMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('عدد الكراتين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _cartonCountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '1',
                                  suffixText: 'كرتونة',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('سعة الكرتونة (حبة/باك)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _unitsPerCartonController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '24',
                                  suffixText: 'حبة/كرتونة',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Carton Cost
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('سعر شراء الكرتونة الواحدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _cartonCostController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'مثال: 1000',
                                  suffixText: 'دج/كرتونة',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    // Single Units Quantity
                    const Text('الكمية المستلمة (بالحبة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '24',
                        suffixText: 'حبة',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Selling Price & Unit Cost Price
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سعر بيع الحبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                suffixText: 'دج',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سعر تكلفة الحبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _costPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                suffixText: 'دج',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Smart Calculation & Profit Summary Card
                  Builder(
                    builder: (context) {
                      final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
                      final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
                      final totalUnits = _isCartonMode ? (cartons * perCarton) : (int.tryParse(_qtyController.text.trim()) ?? 0);
                      final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
                      final unitCost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
                      final unitSell = double.tryParse(_priceController.text.trim()) ?? 0.0;
                      final totalInvoiceCost = _isCartonMode ? (cartons * cartonCost) : (totalUnits * unitCost);
                      final profitPerUnit = unitSell > unitCost ? (unitSell - unitCost) : 0.0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('📦 إجمالي الحبات للمخزون:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                Text('$totalUnits حبة', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                            if (_isCartonMode && cartonCost > 0) ...[
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('💵 إجمالي فاتورة الشراء:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                                  Text('${totalInvoiceCost.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                            if (profitPerUnit > 0) ...[
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('📈 فائدة الحبة الواحدة:', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  Text(
                                    '+${profitPerUnit.toStringAsFixed(1)} دج (${((profitPerUnit / (unitCost > 0 ? unitCost : 1)) * 100).toStringAsFixed(0)}%)',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Dates: Receipt Date & Expiry Date
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickReceiptDate,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📅 تاريخ الاستلام', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(dateFormat.format(_receiptDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickExpiryDate,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _expiryDate != null ? Colors.orange[50] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _expiryDate != null ? Colors.orange[300]! : Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⌛ نهاية الصلاحية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  _expiryDate != null ? dateFormat.format(_expiryDate!) : 'اختياري',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _expiryDate != null ? Colors.orange[900] : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Condition of Goods
                  const Text('حالة السلعة المستلمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _conditions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final cond = _conditions[index];
                        final isSel = cond == _itemCondition;
                        return ChoiceChip(
                          label: Text(cond, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.black87)),
                          selected: isSel,
                          selectedColor: AppTheme.primaryColor,
                          onSelected: (selected) {
                            if (selected) setState(() => _itemCondition = cond);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Supplier / Distributor Details (Optional)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 18, color: Colors.blueGrey),
                            SizedBox(width: 6),
                            Text('بيانات الموزع أو الشركة (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _supplierNameController,
                                decoration: const InputDecoration(
                                  hintText: 'اسم الموزع (مثال: صومام، حمود...)',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _supplierPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  hintText: 'رقم الهاتف',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: const Text(
                      'تأكيد استلام السلعة وإضافتها للمخزون',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _submitStockIn,
                  ),

                  // Session Arrivage History
                  if (_sessionStockIns.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سجل استلامات الجلسة (\${_sessionStockIns.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'إجمالي الحبات: \${_sessionStockIns.fold<int>(0, (s, i) => s + (i[\'qty\'] as int))}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessionStockIns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = _sessionStockIns[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['isCarton'] == true
                                        ? '\${item[\'cartons\']} كرتونة × \${item[\'unitsPerCarton\']} حبة = \${item[\'qty\']} حبة'
                                        : '\${item[\'qty\']} حبة فردية',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  if (item['supplier'] != null && item['supplier'].toString().isNotEmpty)
                                    Text(
                                      'الموزع: \${item[\'supplier\']}',
                                      style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+\${item[\'qty\']} حبة',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                  ),
                                  Text(
                                    '\${item[\'price\']} \${AppConstants.currencySymbol}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}