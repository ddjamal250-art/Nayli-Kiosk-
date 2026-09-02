import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/barcode_generator_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/data/master_catalog_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../documents/presentation/widgets/receipt_ocr_scanner_dialog.dart';

enum ArrivageUnitMode { cartons, vracSacs, singleUnits }

class StockInPage extends StatefulWidget {
  const StockInPage({super.key});

  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isCameraOn = false;
  bool _isFlashOn = false;
  String _activeBarcode = '';
  int _currentStock = 0;
  bool _isExistingInShop = false;
  String? _existingProductId;
  DateTime? _lastScanTime;
  String? _lastScannedBarcode;

  // Arrivage Mode (Cartons vs Vrac Sacs vs Single Units)
  ArrivageUnitMode _unitMode = ArrivageUnitMode.cartons;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '24');
  
  // Cartons controllers
  final TextEditingController _cartonCountController = TextEditingController(text: '1');
  final TextEditingController _unitsPerCartonController = TextEditingController(text: '24');
  final TextEditingController _cartonCostController = TextEditingController();

  // Vrac & Sacs controllers (Coffee, Sugar, Semolina, Spices)
  final TextEditingController _sacCountController = TextEditingController(text: '1');
  final TextEditingController _kgPerSacController = TextEditingController(text: '25');
  final TextEditingController _sacCostController = TextEditingController();
  final TextEditingController _pricePerKgController = TextEditingController();
  final TextEditingController _costPerKgController = TextEditingController();

  // Supplier & Traceability
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

  bool _isUpdatingFromCalculation = false;

  @override
  void initState() {
    super.initState();
    _cartonCountController.addListener(_onCartonInputsChanged);
    _unitsPerCartonController.addListener(_onCartonInputsChanged);
    _cartonCostController.addListener(_onCartonCostChanged);

    _sacCountController.addListener(_onSacInputsChanged);
    _kgPerSacController.addListener(_onSacInputsChanged);
    _sacCostController.addListener(_onSacCostChanged);
    _costPerKgController.addListener(_onKgCostChanged);

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
    _sacCountController.dispose();
    _kgPerSacController.dispose();
    _sacCostController.dispose();
    _pricePerKgController.dispose();
    _costPerKgController.dispose();
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  void _onCartonInputsChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final totalUnits = cartons * perCarton;
    _qtyController.text = totalUnits.toString();

    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCalculation = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _onCartonCostChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCalculation = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _onSacInputsChanged() {
    if (_unitMode != ArrivageUnitMode.vracSacs || _isUpdatingFromCalculation) return;
    final sacs = int.tryParse(_sacCountController.text.trim()) ?? 0;
    final kgPerSac = double.tryParse(_kgPerSacController.text.trim()) ?? 0.0;
    final totalKg = (sacs * kgPerSac).toInt();
    _qtyController.text = totalKg.toString();

    final sacCost = double.tryParse(_sacCostController.text.trim()) ?? 0.0;
    if (kgPerSac > 0 && sacCost > 0) {
      final costPerKg = sacCost / kgPerSac;
      _isUpdatingFromCalculation = true;
      _costPerKgController.text = costPerKg.toStringAsFixed(2);
      _costPriceController.text = costPerKg.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _onSacCostChanged() {
    if (_unitMode != ArrivageUnitMode.vracSacs || _isUpdatingFromCalculation) return;
    final kgPerSac = double.tryParse(_kgPerSacController.text.trim()) ?? 0.0;
    final sacCost = double.tryParse(_sacCostController.text.trim()) ?? 0.0;
    if (kgPerSac > 0 && sacCost > 0) {
      final costPerKg = sacCost / kgPerSac;
      _isUpdatingFromCalculation = true;
      _costPerKgController.text = costPerKg.toStringAsFixed(2);
      _costPriceController.text = costPerKg.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _onKgCostChanged() {
    if (_unitMode != ArrivageUnitMode.vracSacs || _isUpdatingFromCalculation) return;
    final kgPerSac = double.tryParse(_kgPerSacController.text.trim()) ?? 0.0;
    final costPerKg = double.tryParse(_costPerKgController.text.trim()) ?? 0.0;
    if (kgPerSac > 0 && costPerKg > 0) {
      final sacCost = costPerKg * kgPerSac;
      _isUpdatingFromCalculation = true;
      _sacCostController.text = sacCost.toStringAsFixed(2);
      _costPriceController.text = costPerKg.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _generateGreyProductBarcode() {
    final ean13 = BarcodeGeneratorHelper.generateUniqueInStoreEan13();
    setState(() {
      _activeBarcode = ean13;
    });
    SoundService.playSaveSuccess();
    SnackbarHelper.showSuccess(context, '🏷️ تم توليد باركود داخلي قياسي (EAN-13): $ean13');
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

    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    final existing = products.where((p) => p.barcode == barcode).firstOrNull;

    if (existing != null) {
      setState(() {
        _isExistingInShop = true;
        _existingProductId = existing.id;
        _nameController.text = existing.name;
        _priceController.text = existing.price.toStringAsFixed(2);
        _costPriceController.text = existing.costPrice.toStringAsFixed(2);
        _currentStock = existing.stock;
        if (existing.isWeighted || existing.name.contains('كغ') || existing.name.contains('ميزان') || existing.name.contains('قهوة') || existing.name.contains('سكر') || existing.name.contains('سميد')) {
          _unitMode = ArrivageUnitMode.vracSacs;
        }
      });
      SoundService.playScanBeep();
      return;
    }

    // Try Master Catalog 59,297 items
    final masterMatch = MasterCatalogService.searchByBarcode(barcode);
    if (masterMatch != null) {
      setState(() {
        _isExistingInShop = false;
        _existingProductId = null;
        _nameController.text = masterMatch.name;
        _priceController.text = masterMatch.defaultPrice.toStringAsFixed(2);
        _costPriceController.text = masterMatch.defaultCost.toStringAsFixed(2);
        _currentStock = 0;
      });
      SoundService.playScanBeep();
      return;
    }

    setState(() {
      _isExistingInShop = false;
      _existingProductId = null;
      _nameController.clear();
      _priceController.clear();
      _costPriceController.clear();
      _currentStock = 0;
    });
    SoundService.playScanBeep();
  }

  void _saveStockIn() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;

    if (name.isEmpty) {
      SnackbarHelper.showWarning(context, 'يرجى إدخال اسم السلعة');
      return;
    }
    if (_activeBarcode.isEmpty) {
      _generateGreyProductBarcode();
    }
    if (qty <= 0) {
      SnackbarHelper.showWarning(context, 'يرجى تحديد كمية استلام صحيحة');
      return;
    }

    final isWeighted = _unitMode == ArrivageUnitMode.vracSacs;

    // Calculate PUMP (Prix Unitaire Moyen Pondéré) for existing products
    double effectiveCost = costPrice;
    if (_isExistingInShop && _currentStock > 0 && costPrice > 0) {
      final oldCost = double.tryParse(_costPriceController.text.trim()) ?? costPrice;
      final totalValue = (_currentStock * oldCost) + (qty * costPrice);
      final totalStock = _currentStock + qty;
      effectiveCost = totalStock > 0 ? (totalValue / totalStock) : costPrice;
    }

    if (_isExistingInShop && _existingProductId != null) {
      final updatedProduct = Product(
        id: _existingProductId!,
        name: name,
        barcode: _activeBarcode,
        price: price,
        costPrice: effectiveCost,
        stock: _currentStock + qty,
        isWeighted: isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );
      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      CatalogCrowdsourceHelper.silentHarvest(
        updatedProduct,
        category: 'أريفاج ومخزن',
        unit: _unitMode == ArrivageUnitMode.vracSacs ? 'كغ' : (_unitMode == ArrivageUnitMode.cartons ? 'كرتونة' : 'حبة'),
      );
    } else {
      final newProduct = Product(
        id: const Uuid().v4(),
        name: name,
        barcode: _activeBarcode,
        price: price,
        costPrice: effectiveCost,
        stock: qty,
        isWeighted: isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );
      context.read<ProductBloc>().add(AddProduct(newProduct));
      CatalogCrowdsourceHelper.silentHarvest(
        newProduct,
        category: 'أريفاج ومخزن',
        unit: _unitMode == ArrivageUnitMode.vracSacs ? 'كغ' : (_unitMode == ArrivageUnitMode.cartons ? 'كرتونة' : 'حبة'),
      );
    }

    setState(() {
      _sessionStockIns.insert(0, {
        'name': name,
        'barcode': _activeBarcode,
        'qty': qty,
        'unitMode': _unitMode.name,
        'price': price,
        'costPrice': effectiveCost,
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
      _sacCostController.clear();
      _pricePerKgController.clear();
      _costPerKgController.clear();
      _qtyController.text = '24';
      _isExistingInShop = false;
      _existingProductId = null;
      _expiryDate = null;
    });

    SoundService.playSaveSuccess();
    SnackbarHelper.showSuccess(context, '✅ تم تسجيل أريفاج "$name" (+$qty ${_unitMode == ArrivageUnitMode.vracSacs ? "كغ" : "حبة"}) بنجاح!');
  }

  Future<void> _pickReceiptDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _receiptDate = picked);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _scanSupplierPaperInvoice() async {
    final result = await ReceiptOcrScannerDialog.show(context);
    if (result != null && result.items.isNotEmpty) {
      final productBloc = context.read<ProductBloc>();
      final products = productBloc.state.products;

      int addedCount = 0;
      for (final item in result.items) {
        final existing = products.where((p) => p.name.trim().toLowerCase() == item.designation.trim().toLowerCase()).firstOrNull;

        if (existing != null) {
          final updatedProduct = existing.copyWith(
            stock: existing.stock + item.quantity.toInt(),
            costPrice: item.unitPrice > 0 ? item.unitPrice : existing.costPrice,
          );
          productBloc.add(UpdateProduct(updatedProduct));
        } else {
          final newProduct = Product(
            id: const Uuid().v4(),
            name: item.designation,
            barcode: BarcodeGeneratorHelper.generateUniqueInStoreEan13(),
            price: item.unitPrice > 0 ? (item.unitPrice * 1.25) : 100.0,
            costPrice: item.unitPrice,
            stock: item.quantity.toInt(),
          );
          productBloc.add(AddProduct(newProduct));
          CatalogCrowdsourceHelper.silentHarvest(newProduct, category: 'أريفاج ورقي', unit: item.unit);
        }

        _sessionStockIns.insert(0, {
          'name': item.designation,
          'barcode': '',
          'qty': item.quantity.toInt(),
          'unitMode': 'singleUnits',
          'price': item.unitPrice * 1.25,
          'costPrice': item.unitPrice,
          'supplier': result.entityName.isNotEmpty ? result.entityName : _supplierNameController.text.trim(),
          'receiptDate': DateTime.now(),
          'condition': '✅ ممتازة / سليمة',
        });
        addedCount++;
      }

      setState(() {
        if (result.entityName.isNotEmpty && _supplierNameController.text.isEmpty) {
          _supplierNameController.text = result.entityName;
        }
      });

      SoundService.playSaveSuccess();
      if (mounted) {
        SnackbarHelper.showSuccess(context, '🎉 تم استيراد $addedCount سلع من فاتورة المورد الورقية وإدخالها في المخزون بنجاح!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('استلام السلع (أريفاج) 📦',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'مسح وصل المورد (OCR) 📸',
            icon: const Icon(Icons.document_scanner_rounded, color: Colors.indigo),
            onPressed: _scanSupplierPaperInvoice,
          ),
          IconButton(
            tooltip: 'توليد باركود داخلي للسلع الرمادية',
            icon: const Icon(Icons.qr_code_2_rounded, color: Colors.teal),
            onPressed: _generateGreyProductBarcode,
          ),
          IconButton(
            tooltip: _isCameraOn ? 'إيقاف الكاميرا' : 'تشغيل الكاميرا',
            icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off, color: Colors.indigo),
            onPressed: () => setState(() => _isCameraOn = !_isCameraOn),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            if (_isCameraOn)
              Container(
                height: 180,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(controller: _scannerController, onDetect: _onDetect),
                    Container(
                      width: 220,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Barcode Row with Grey Products Button
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.barcode_reader, color: Colors.teal, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الباركود المسجل أو المولد:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                _activeBarcode.isEmpty ? 'امسح الباركود أو اضغط لتوليد باركود محلي' : _activeBarcode,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _activeBarcode.isEmpty ? Colors.grey.shade400 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Colors.white),
                          label: const Text('توليد EAN-13', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _generateGreyProductBarcode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Item Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم السلعة (مثلاً: زيت عافية 5L / شكارة قهوة 25kg) *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      suffixIcon: _isExistingInShop
                          ? Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                              child: Text('بالمخزون: $_currentStock', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Arrivage Mode 3-Way Selector
                  const Text('اختر طريقة ووحدة الاستلام:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildModeTab('📦 كراتين وصناديق', ArrivageUnitMode.cartons),
                        _buildModeTab('🛍️ شكاير وميزان (قهوة، سكر...)', ArrivageUnitMode.vracSacs),
                        _buildModeTab('🏷️ حبة منفردة', ArrivageUnitMode.singleUnits),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode Specific Form
                  if (_unitMode == ArrivageUnitMode.cartons) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cartonCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'عدد الكراتين', suffixText: 'كرتونة', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _unitsPerCartonController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'سعة الكرتونة (حبة)', suffixText: 'حبة/كرتونة', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cartonCostController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر شراء الكرتونة الواحدة', suffixText: 'DA/كرتونة', border: OutlineInputBorder()),
                    ),
                  ] else if (_unitMode == ArrivageUnitMode.vracSacs) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sacCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'عدد الشكاير / الأكياس', suffixText: 'شكارة', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _kgPerSacController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'وزن الشكارة (كغ)', suffixText: 'كغ/شكارة', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sacCostController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'سعر شراء الشكارة (DA)', suffixText: 'DA/شكارة', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _costPerKgController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'تكلفة الكيلوغرام (DA)', suffixText: 'DA/كغ', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية المستلمة (بالحبة)', suffixText: 'حبة', border: OutlineInputBorder()),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Selling Price & Unit Cost Price
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _unitMode == ArrivageUnitMode.vracSacs ? 'سعر بيع الكيلوغرام *' : 'سعر بيع الحبة *',
                            suffixText: 'DA',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _costPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _unitMode == ArrivageUnitMode.vracSacs ? 'تكلفة الكيلوغرام (PUMP)' : 'سعر تكلفة الحبة (PUMP)',
                            suffixText: 'DA',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Supplier & Phone Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _supplierNameController,
                          decoration: const InputDecoration(labelText: 'اسم الموزع / المورد (Fournisseur)', prefixIcon: Icon(Icons.local_shipping_outlined), border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _supplierPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم هاتف الموزع', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dates: Receipt Date & Expiry Date
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickReceiptDate,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📅 تاريخ الاستلام', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(dateFormat.format(_receiptDate), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _expiryDate != null ? Colors.red.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _expiryDate != null ? Colors.red.shade200 : Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⏳ نهاية الصلاحية (DDM/DLC)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(_expiryDate != null ? dateFormat.format(_expiryDate!) : 'تحديد التاريخ (اختياري)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _expiryDate != null ? Colors.red.shade900 : Colors.black87)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Condition Row
                  DropdownButtonFormField<String>(
                    value: _itemCondition,
                    decoration: const InputDecoration(labelText: 'حالة الشحنة / السلعة', border: OutlineInputBorder()),
                    items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _itemCondition = val!),
                  ),
                  const SizedBox(height: 18),

                  // Submit Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                    label: Text(
                      _isExistingInShop ? 'تحديث وتزويد المخزون (+${_qtyController.text})' : 'حفظ وتسجيل المنتج الجديد في المخزون',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _saveStockIn,
                  ),
                  const SizedBox(height: 24),

                  // Recent Stock In Session History
                  if (_sessionStockIns.isNotEmpty) ...[
                    const Text('شحنات جلسة الاستلام الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessionStockIns.length,
                      itemBuilder: (context, i) {
                        final entry = _sessionStockIns[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.inventory, color: Colors.white, size: 18)),
                            title: Text(entry['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('الكمية: +${entry['qty']} • التكلفة: ${entry['costPrice'].toStringAsFixed(2)} DA • المورد: ${entry['supplier'].isEmpty ? "غير محدد" : entry['supplier']}',
                                style: const TextStyle(fontSize: 11)),
                            trailing: Text('${(entry['price'] as double).toStringAsFixed(2)} DA', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
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

  Widget _buildModeTab(String label, ArrivageUnitMode mode) {
    final isSelected = _unitMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _unitMode = mode;
          });
          SoundService.playTabSwitch();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 3)] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.teal : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}