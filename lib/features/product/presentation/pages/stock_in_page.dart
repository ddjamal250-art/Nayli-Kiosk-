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
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../documents/domain/entities/commercial_document.dart';
import '../../../documents/presentation/widgets/receipt_ocr_scanner_dialog.dart';
import '../../../../core/utils/receipt_ocr_parser.dart';
import '../widgets/product_image_picker_field.dart';

enum ArrivageUnitMode { cartons, vracSacs, singleUnits }

class StockInPage extends StatefulWidget {
  final ParsedReceiptResult? initialReceiptResult;
  const StockInPage({super.key, this.initialReceiptResult});

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

  // OCR Invoice Review Queue
  List<CommercialDocItem> _pendingOcrItems = [];
  int _activeOcrIndex = -1;
  String? _ocrSupplierName;
  String? _itemImageUrl;
  String _selectedCategory = 'مشروبات ومياه وعصائر';
  bool _isCategoryUserSelected = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (!_isCategoryUserSelected && _nameController.text.trim().isNotEmpty) {
        final detected = CategoryTaxonomy.smartDetect(_nameController.text.trim());
        if (mounted && _selectedCategory != detected.titleAr) {
          setState(() {
            _selectedCategory = detected.titleAr;
          });
        }
      }
    });

    _cartonCountController.addListener(_onCartonInputsChanged);
    _unitsPerCartonController.addListener(_onCartonInputsChanged);
    _cartonCostController.addListener(_onCartonCostChanged);

    _sacCountController.addListener(_onSacInputsChanged);
    _kgPerSacController.addListener(_onSacInputsChanged);
    _sacCostController.addListener(_onSacCostChanged);
    _costPerKgController.addListener(_onKgCostChanged);

    _costPriceController.addListener(_onUnitCostChanged);
    _priceController.addListener(() => setState(() {}));

    if (widget.initialReceiptResult != null && widget.initialReceiptResult!.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyOcrResult(widget.initialReceiptResult!);
      });
    }
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

  void _onUnitCostChanged() {
    if (_isUpdatingFromCalculation) return;
    final unitCost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    if (_unitMode == ArrivageUnitMode.cartons) {
      final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
      if (perCarton > 0 && unitCost > 0) {
        _isUpdatingFromCalculation = true;
        _cartonCostController.text = (unitCost * perCarton).toStringAsFixed(2);
        _isUpdatingFromCalculation = false;
      }
    } else if (_unitMode == ArrivageUnitMode.vracSacs) {
      final kgPerSac = double.tryParse(_kgPerSacController.text.trim()) ?? 0.0;
      if (kgPerSac > 0 && unitCost > 0) {
        _isUpdatingFromCalculation = true;
        _costPerKgController.text = unitCost.toStringAsFixed(2);
        _sacCostController.text = (unitCost * kgPerSac).toStringAsFixed(2);
        _isUpdatingFromCalculation = false;
      }
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
        _itemImageUrl = existing.imageUrl;
        _selectedCategory = existing.category.isNotEmpty ? existing.category : 'عام';
        _isCategoryUserSelected = true;
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
        _itemImageUrl = masterMatch.imageUrl;
        _selectedCategory = masterMatch.category.isNotEmpty ? masterMatch.category : CategoryTaxonomy.smartDetect(masterMatch.name).titleAr;
        _isCategoryUserSelected = true;
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
      _itemImageUrl = null;
      _isCategoryUserSelected = false;
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

    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    final existingProduct = _existingProductId != null
        ? products.where((p) => p.id == _existingProductId).firstOrNull
        : null;

    // Calculate PUMP (Prix Unitaire Moyen Pondéré) for existing products
    double effectiveCost = costPrice;
    if (_isExistingInShop && _currentStock > 0 && costPrice > 0) {
      final oldCost = (existingProduct != null && existingProduct.costPrice > 0)
          ? existingProduct.costPrice
          : costPrice;
      final totalValue = (_currentStock * oldCost) + (qty * costPrice);
      final totalStock = _currentStock + qty;
      effectiveCost = totalStock > 0 ? (totalValue / totalStock) : costPrice;
    }
    final masterMatch = MasterCatalogService.searchByBarcode(_activeBarcode) ??
        MasterCatalogService.instance.search(name).firstOrNull;

    final productImageUrl = _itemImageUrl ?? existingProduct?.imageUrl ?? masterMatch?.imageUrl;
    final isTobacco = existingProduct?.isTobacco ?? masterMatch?.isTobacco ?? false;
    final piecesPerPack = existingProduct?.piecesPerPack ?? masterMatch?.piecesPerPack ?? 20;
    final packsPerCarton = existingProduct?.packsPerCarton ?? masterMatch?.packsPerCarton ?? 10;
    final singlePiecePrice = existingProduct?.singlePiecePrice ?? masterMatch?.singlePiecePrice ?? 0.0;
    final cartonPrice = existingProduct?.cartonPrice ?? masterMatch?.cartonPrice ?? 0.0;
    final wholesaleCartonPrice = existingProduct?.wholesaleCartonPrice ?? masterMatch?.wholesaleCartonPrice ?? 0.0;
    final wholesalePackPrice = existingProduct?.wholesalePackPrice ?? masterMatch?.wholesalePackPrice ?? 0.0;
    final cartonCostPrice = existingProduct?.cartonCostPrice ?? masterMatch?.cartonCostPrice ?? 0.0;
    final unitType = existingProduct?.unitType ?? masterMatch?.unitType ?? 'unit';

    final effectiveCategory = _selectedCategory.trim().isNotEmpty
        ? _selectedCategory.trim()
        : (existingProduct?.category ?? masterMatch?.category ?? 'عام');

    if (_isExistingInShop && _existingProductId != null) {
      final updatedProduct = (existingProduct ?? Product(
        id: _existingProductId!,
        name: name,
        barcode: _activeBarcode,
        price: price,
      )).copyWith(
        name: name,
        barcode: _activeBarcode,
        category: effectiveCategory,
        price: price,
        costPrice: effectiveCost,
        stock: _currentStock + qty,
        isWeighted: isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
        imageUrl: productImageUrl,
      );
      productBloc.add(UpdateProduct(updatedProduct));
      CatalogCrowdsourceHelper.silentHarvest(
        updatedProduct,
        category: effectiveCategory,
        unit: _unitMode == ArrivageUnitMode.vracSacs ? 'كغ' : (_unitMode == ArrivageUnitMode.cartons ? 'كرتونة' : 'حبة'),
      );
    } else {
      final newProduct = Product(
        id: const Uuid().v4(),
        name: name,
        barcode: _activeBarcode,
        category: effectiveCategory,
        price: price,
        costPrice: effectiveCost,
        stock: qty,
        isWeighted: isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
        imageUrl: productImageUrl,
        isTobacco: isTobacco,
        piecesPerPack: piecesPerPack,
        packsPerCarton: packsPerCarton,
        singlePiecePrice: singlePiecePrice,
        cartonPrice: cartonPrice,
        wholesaleCartonPrice: wholesaleCartonPrice,
        wholesalePackPrice: wholesalePackPrice,
        cartonCostPrice: cartonCostPrice,
        unitType: unitType,
      );
      productBloc.add(AddProduct(newProduct));
      CatalogCrowdsourceHelper.silentHarvest(
        newProduct,
        category: effectiveCategory,
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
      _itemImageUrl = null;
    });

    SoundService.playSaveSuccess();

    // Check if we are processing a pending OCR item
    if (_activeOcrIndex >= 0 && _activeOcrIndex < _pendingOcrItems.length) {
      _pendingOcrItems.removeAt(_activeOcrIndex);
      if (_pendingOcrItems.isNotEmpty) {
        final nextIdx = _activeOcrIndex < _pendingOcrItems.length ? _activeOcrIndex : 0;
        _selectPendingOcrItem(nextIdx);
        SnackbarHelper.showSuccess(
          context,
          '✅ تم حفظ واستلام "$name" بنجاح! تم تحميل السلعة التالية (${_pendingOcrItems.length} سلع متبقية)',
        );
        return;
      } else {
        _activeOcrIndex = -1;
        SnackbarHelper.showSuccess(
          context,
          '🎉 رائع جداً! تم استلام وتأكيد جميع سلع الفاتورة بنجاح في المخزون!',
        );
        return;
      }
    }

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

  void _applyOcrResult(ParsedReceiptResult result) {
    if (result.items.isEmpty) return;
    setState(() {
      _pendingOcrItems = List.from(result.items);
      _ocrSupplierName = result.entityName;
      if (result.entityName.isNotEmpty) {
        _supplierNameController.text = result.entityName;
      }
    });
    _selectPendingOcrItem(0);
    SnackbarHelper.showSuccess(
      context,
      '📄 تم استخراج ${result.items.length} سلع من الفاتورة. اضغط على أي سلعة لمراجعة تفاصيلها وتأكيدها.',
    );
  }

  void _selectPendingOcrItem(int index) {
    if (index < 0 || index >= _pendingOcrItems.length) return;
    final item = _pendingOcrItems[index];

    setState(() {
      _activeOcrIndex = index;
      _unitMode = ArrivageUnitMode.singleUnits;
      _nameController.text = item.designation;
      _qtyController.text = item.quantity.toInt().toString();
      _costPriceController.text = item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(2) : '';

      final products = context.read<ProductBloc>().state.products;
      final existing = products.where((p) =>
        p.name.trim().toLowerCase() == item.designation.trim().toLowerCase() ||
        (item.reference.isNotEmpty && p.barcode == item.reference)
      ).firstOrNull;

      if (existing != null) {
        _isExistingInShop = true;
        _existingProductId = existing.id;
        _activeBarcode = existing.barcode;
        _priceController.text = existing.price.toStringAsFixed(2);
        _currentStock = existing.stock;
        _itemImageUrl = existing.imageUrl;
        _selectedCategory = existing.category.isNotEmpty ? existing.category : 'عام';
        _isCategoryUserSelected = true;
      } else {
        final masterMatch = MasterCatalogService.instance.search(item.designation).firstOrNull ??
            (item.reference.isNotEmpty ? MasterCatalogService.searchByBarcode(item.reference) : null);
        if (masterMatch != null) {
          _isExistingInShop = false;
          _existingProductId = null;
          _activeBarcode = masterMatch.barcode;
          _priceController.text = masterMatch.defaultPrice > 0
              ? masterMatch.defaultPrice.toStringAsFixed(2)
              : (item.unitPrice > 0 ? (item.unitPrice * 1.25).toStringAsFixed(2) : '');
          _currentStock = 0;
          _itemImageUrl = masterMatch.imageUrl;
          _selectedCategory = masterMatch.category.isNotEmpty ? masterMatch.category : CategoryTaxonomy.smartDetect(masterMatch.name).titleAr;
          _isCategoryUserSelected = true;
        } else {
          _isExistingInShop = false;
          _existingProductId = null;
          _activeBarcode = item.reference.isNotEmpty ? item.reference : BarcodeGeneratorHelper.generateUniqueInStoreEan13();
          _priceController.text = item.unitPrice > 0 ? (item.unitPrice * 1.25).toStringAsFixed(2) : '';
          _currentStock = 0;
          _itemImageUrl = null;
          _selectedCategory = CategoryTaxonomy.smartDetect(item.designation).titleAr;
          _isCategoryUserSelected = false;
        }
      }
    });
    SoundService.playScanBeep();
  }

  Future<void> _receiveAllPendingOcrItems() async {
    if (_pendingOcrItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('استلام جميع السلع دفعة واحدة ⚡'),
          ],
        ),
        content: Text(
          'سيتم إدخال جميع السلع المتبقية (${_pendingOcrItems.length} سلعة) إلى المخزون بهامش ربح تلقائي (25%) وبسعر الشراء المستخرج من الفاتورة.\n\nهل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الاستلام الشامل 🚀'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    int addedCount = 0;

    for (final item in _pendingOcrItems) {
      final existing = products.where((p) =>
        p.name.trim().toLowerCase() == item.designation.trim().toLowerCase() ||
        (item.reference.isNotEmpty && p.barcode == item.reference)
      ).firstOrNull;

      final qty = item.quantity.toInt();
      final costPrice = item.unitPrice;

      if (existing != null) {
        final updatedProduct = existing.copyWith(
          stock: existing.stock + qty,
          costPrice: costPrice > 0 ? costPrice : existing.costPrice,
        );
        productBloc.add(UpdateProduct(updatedProduct));
      } else {
        final masterMatch = MasterCatalogService.instance.search(item.designation).firstOrNull;
        final barcode = masterMatch?.barcode ?? (item.reference.isNotEmpty ? item.reference : BarcodeGeneratorHelper.generateUniqueInStoreEan13());
        final price = masterMatch != null && masterMatch.defaultPrice > 0
            ? masterMatch.defaultPrice
            : (costPrice > 0 ? costPrice * 1.25 : 100.0);

        final ocrCat = (masterMatch?.category != null && masterMatch!.category.isNotEmpty)
            ? masterMatch.category
            : CategoryTaxonomy.smartDetect(item.designation).titleAr;

        final newProduct = Product(
          id: const Uuid().v4(),
          name: item.designation,
          barcode: barcode,
          category: ocrCat,
          price: price,
          costPrice: costPrice,
          stock: qty,
          imageUrl: masterMatch?.imageUrl,
          isTobacco: masterMatch?.isTobacco ?? false,
          cartonPrice: masterMatch?.cartonPrice ?? 0.0,
          wholesalePrice: masterMatch?.wholesalePrice ?? 0.0,
          wholesaleCartonPrice: masterMatch?.wholesaleCartonPrice ?? 0.0,
          wholesalePackPrice: masterMatch?.wholesalePackPrice ?? 0.0,
          singlePiecePrice: masterMatch?.singlePiecePrice ?? 0.0,
          piecesPerPack: masterMatch?.piecesPerPack ?? 20,
          packsPerCarton: masterMatch?.packsPerCarton ?? 10,
          unitType: masterMatch?.unitType ?? 'unit',
        );
        productBloc.add(AddProduct(newProduct));
        CatalogCrowdsourceHelper.silentHarvest(newProduct, category: ocrCat, unit: item.unit);
      }

      _sessionStockIns.insert(0, {
        'name': item.designation,
        'barcode': item.reference,
        'qty': qty,
        'unitMode': 'singleUnits',
        'price': costPrice * 1.25,
        'costPrice': costPrice,
        'supplier': _supplierNameController.text.trim(),
        'receiptDate': _receiptDate,
        'condition': '✅ ممتازة / سليمة',
      });
      addedCount++;
    }

    setState(() {
      _pendingOcrItems.clear();
      _activeOcrIndex = -1;
      _nameController.clear();
      _priceController.clear();
      _costPriceController.clear();
      _activeBarcode = '';
    });

    SoundService.playSaveSuccess();
    SnackbarHelper.showSuccess(context, '🎉 تم استلام $addedCount سلع بنجاح وإضافتها للمخزن!');
  }

  Future<void> _scanSupplierPaperInvoice() async {
    final result = await ReceiptOcrScannerDialog.show(context);
    if (result != null && result.items.isNotEmpty) {
      _applyOcrResult(result);
    }
  }

  Widget _buildOcrQueueBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فاتورة الشراء الممسوحة (${_pendingOcrItems.length} سلع معلقة)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                    ),
                    if (_ocrSupplierName != null && _ocrSupplierName!.isNotEmpty)
                      Text(
                        'المورد: $_ocrSupplierName',
                        style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('استلام الكل ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _receiveAllPendingOcrItems,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                tooltip: 'إلغاء قائمة الفاتورة',
                onPressed: () {
                  setState(() {
                    _pendingOcrItems.clear();
                    _activeOcrIndex = -1;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على أي سلعة لتعبئة بياناتها، ضبط سعر البيع والصلاحية، ثم اضغط "تأكيد واستلام":',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingOcrItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _pendingOcrItems[index];
                final isSelected = index == _activeOcrIndex;
                return InkWell(
                  onTap: () => _selectPendingOcrItem(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.indigo.shade800 : Colors.indigo.shade100,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}. ${item.designation}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.indigo.shade700 : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'x${item.quantity.toInt()} | ${item.unitPrice.toStringAsFixed(0)} دج',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.amberAccent : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

            if (_pendingOcrItems.isNotEmpty) _buildOcrQueueBanner(),

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

                  // Product Image Picker (Web search + camera + gallery)
                  ProductImagePickerField(
                    initialImageUrl: _itemImageUrl,
                    barcode: _activeBarcode,
                    productName: _nameController.text,
                    onImageChanged: (path) => setState(() => _itemImageUrl = path),
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
                  const SizedBox(height: 12),

                  // Architectural Category Selector
                  _buildCategorySelector(),
                  const SizedBox(height: 12),

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
                  // Live Profit & Expected Margin Card
                  Builder(
                    builder: (context) {
                      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
                      final cost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
                      final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
                      if (price <= 0 || cost <= 0) return const SizedBox.shrink();

                      final unitProfit = price - cost;
                      final marginPct = cost > 0 ? ((unitProfit / cost) * 100).toStringAsFixed(1) : '0';
                      final totalProfit = unitProfit * qty;
                      final isPos = unitProfit > 0;

                      // Cartons extra info
                      double? cartonProfit;
                      if (_unitMode == ArrivageUnitMode.cartons) {
                        final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
                        final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
                        if (perCarton > 0 && cartonCost > 0) {
                          cartonProfit = (price * perCarton) - cartonCost;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPos ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isPos ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isPos ? Icons.insights_rounded : Icons.trending_down,
                                    size: 16, color: isPos ? const Color(0xFF16A34A) : Colors.red),
                                const SizedBox(width: 6),
                                Text(
                                  'أرباح متوقعة: ${unitProfit >= 0 ? "+" : ""}${unitProfit.toStringAsFixed(2)} DA / وحدة (هامش $marginPct%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isPos ? const Color(0xFF166534) : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                            if (qty > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '💰 إجمالي صافي أرباح هذه الشحنة بالكامل ($qty وحدة): ${totalProfit >= 0 ? "+" : ""}${totalProfit.toStringAsFixed(2)} DA',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: isPos ? const Color(0xFF0F766E) : Colors.red.shade700,
                                ),
                              ),
                            ],
                            if (cartonProfit != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '📦 صافي ربح الكرتونة الواحدة: ${cartonProfit >= 0 ? "+" : ""}${cartonProfit.toStringAsFixed(2)} DA',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF0D9488)),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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

  Widget _buildCategorySelector() {
    final domain = CategoryTaxonomy.resolveDomain(_selectedCategory);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              domain.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'التصنيف المعماري للمنتج:',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    if (!_isCategoryUserSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'اكتشاف ذكي ⚡',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedCategory,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'تغيير تصنيف السلعة',
            icon: const Icon(Icons.tune, color: AppTheme.primaryColor),
            onSelected: (String cat) {
              setState(() {
                _selectedCategory = cat;
                _isCategoryUserSelected = true;
              });
            },
            itemBuilder: (BuildContext context) {
              final List<PopupMenuEntry<String>> items = [];
              for (final d in CategoryTaxonomy.allDomains) {
                items.add(
                  PopupMenuItem<String>(
                    value: d.titleAr,
                    child: Row(
                      children: [
                        Text(d.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(d.titleAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
                for (final sub in d.subCategories) {
                  items.add(
                    PopupMenuItem<String>(
                      value: sub.titleAr,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Row(
                          children: [
                            Text(sub.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(sub.titleAr, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                items.add(const PopupMenuDivider());
              }
              if (items.isNotEmpty) items.removeLast();
              return items;
            },
          ),
        ],
      ),
    );
  }
}