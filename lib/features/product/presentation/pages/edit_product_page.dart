import 'dart:io';
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
import '../../../../core/utils/catalog_crowdsource_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

import '../widgets/product_image_picker_field.dart';

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

  // New Tobacco & Unit controllers
  late TextEditingController _cartonPriceCtrl;
  late TextEditingController _wholesaleCartonPriceCtrl;
  late TextEditingController _wholesalePackPriceCtrl;
  late TextEditingController _singlePiecePriceCtrl;
  late TextEditingController _packsPerCartonCtrl;
  late TextEditingController _piecesPerPackCtrl;

  late String _selectedCategory;
  String? _imageUrl;
  late bool _isTobacco;
  late String _unitType; // 'piece', 'meter', 'ml'
  late bool _isWeighted;
  DateTime? _expiryDate;

  static const List<String> categories = [
    'عام',
    'أدوات مدرسية ومكتبية',
    'تبغ وسجائر',
    'شمة وتبغ تقليدي',
    'ورق لف وفلاتر',
    'معسل وشيشة',
    'ولاعات وغاز',
    'عطور زيتية وبالمتر',
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

    _imageUrl = widget.product.imageUrl;
    _isTobacco = widget.product.isTobacco || widget.product.category.contains('تبغ') || widget.product.category.contains('شمة') || widget.product.category.contains('معسل');
    _unitType = widget.product.unitType.isNotEmpty ? widget.product.unitType : 'piece';
    _cartonPriceCtrl = TextEditingController(text: widget.product.cartonPrice > 0 ? widget.product.cartonPrice.toStringAsFixed(0) : '');
    _wholesaleCartonPriceCtrl = TextEditingController(text: widget.product.wholesaleCartonPrice > 0 ? widget.product.wholesaleCartonPrice.toStringAsFixed(0) : '');
    _wholesalePackPriceCtrl = TextEditingController(text: widget.product.wholesalePackPrice > 0 ? widget.product.wholesalePackPrice.toStringAsFixed(0) : '');
    _singlePiecePriceCtrl = TextEditingController(text: widget.product.singlePiecePrice > 0 ? widget.product.singlePiecePrice.toStringAsFixed(0) : '');
    _packsPerCartonCtrl = TextEditingController(text: widget.product.packsPerCarton.toString());
    _piecesPerPackCtrl = TextEditingController(text: widget.product.piecesPerPack.toString());

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
    _cartonPriceCtrl.dispose();
    _wholesaleCartonPriceCtrl.dispose();
    _wholesalePackPriceCtrl.dispose();
    _singlePiecePriceCtrl.dispose();
    _packsPerCartonCtrl.dispose();
    _piecesPerPackCtrl.dispose();
    super.dispose();
  }

  bool _isAutoCalculating = false;

  void _onCartonPriceChanged(String val) {
    if (_isAutoCalculating) return;
    final carton = double.tryParse(val.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;
    if (carton > 0 && packs > 0) {
      _isAutoCalculating = true;
      final packPrice = carton / packs;
      _priceCtrl.text = packPrice % 1 == 0 ? packPrice.toInt().toString() : packPrice.toStringAsFixed(2);
      if (pieces > 0) {
        final piecePrice = (packPrice / pieces).ceilToDouble();
        _singlePiecePriceCtrl.text = piecePrice % 1 == 0 ? piecePrice.toInt().toString() : piecePrice.toStringAsFixed(2);
      }
      _isAutoCalculating = false;
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _onPackPriceChanged(String val) {
    if (_isAutoCalculating) return;
    final pack = double.tryParse(val.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;
    if (pack > 0 && packs > 0) {
      _isAutoCalculating = true;
      final carton = pack * packs;
      _cartonPriceCtrl.text = carton % 1 == 0 ? carton.toInt().toString() : carton.toStringAsFixed(2);
      if (pieces > 0) {
        final piecePrice = (pack / pieces).ceilToDouble();
        _singlePiecePriceCtrl.text = piecePrice % 1 == 0 ? piecePrice.toInt().toString() : piecePrice.toStringAsFixed(2);
      }
      _isAutoCalculating = false;
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _onWholesaleCartonPriceChanged(String val) {
    if (_isAutoCalculating) return;
    final wCarton = double.tryParse(val.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    if (wCarton > 0 && packs > 0) {
      _isAutoCalculating = true;
      final wPack = wCarton / packs;
      final text = wPack % 1 == 0 ? wPack.toInt().toString() : wPack.toStringAsFixed(2);
      _wholesalePackPriceCtrl.text = text;
      _wholesalePriceCtrl.text = text;
      _isAutoCalculating = false;
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _onWholesalePackPriceChanged(String val) {
    if (_isAutoCalculating) return;
    final wPack = double.tryParse(val.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    if (wPack > 0 && packs > 0) {
      _isAutoCalculating = true;
      final wCarton = wPack * packs;
      _wholesaleCartonPriceCtrl.text = wCarton % 1 == 0 ? wCarton.toInt().toString() : wCarton.toStringAsFixed(2);
      _wholesalePriceCtrl.text = val.trim();
      _isAutoCalculating = false;
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _onSinglePiecePriceChanged(String val) {
    if (_isAutoCalculating) return;
    final piece = double.tryParse(val.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;
    if (piece > 0 && pieces > 0) {
      _isAutoCalculating = true;
      final pack = piece * pieces;
      final carton = pack * (packs > 0 ? packs : 10);
      _priceCtrl.text = pack % 1 == 0 ? pack.toInt().toString() : pack.toStringAsFixed(2);
      _cartonPriceCtrl.text = carton % 1 == 0 ? carton.toInt().toString() : carton.toStringAsFixed(2);
      _isAutoCalculating = false;
      setState(() {});
    } else {
      setState(() {});
    }
  }

  Widget _buildTobaccoProfitCard() {
    final cartonPrice = double.tryParse(_cartonPriceCtrl.text.trim()) ?? 0.0;
    final packPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final piecePrice = double.tryParse(_singlePiecePriceCtrl.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;

    final packCost = costPrice;
    final cartonCost = packCost * packs;
    final pieceCost = (pieces > 0 && packCost > 0) ? (packCost / pieces) : 0.0;

    final cartonProfit = (cartonPrice > 0 && cartonCost > 0) ? (cartonPrice - cartonCost) : 0.0;
    final packProfit = (packPrice > 0 && packCost > 0) ? (packPrice - packCost) : 0.0;
    final pieceProfit = (piecePrice > 0 && pieceCost > 0) ? (piecePrice - pieceCost) : 0.0;

    final cartonProfitPercent = cartonCost > 0 ? ((cartonProfit / cartonCost) * 100).toStringAsFixed(1) : '0';
    final packProfitPercent = packCost > 0 ? ((packProfit / packCost) * 100).toStringAsFixed(1) : '0';
    final pieceProfitPercent = pieceCost > 0 ? ((pieceProfit / pieceCost) * 100).toStringAsFixed(1) : '0';

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.query_stats_rounded, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 6),
              Text(
                'حساب دقيق للأرباح الصافية المتوقعة 📊',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildProfitPill(
                  title: 'ربح الكرطوشة',
                  profit: cartonProfit,
                  percent: cartonProfitPercent,
                  color: const Color(0xFF0D9488),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProfitPill(
                  title: 'ربح العلبة',
                  profit: packProfit,
                  percent: packProfitPercent,
                  color: const Color(0xFF2563EB),
                  icon: Icons.crop_portrait_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProfitPill(
                  title: 'ربح السيجارة (الحبة)',
                  profit: pieceProfit,
                  percent: pieceProfitPercent,
                  color: const Color(0xFFD97706),
                  icon: Icons.smoking_rooms_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitPill({
    required String title,
    required double profit,
    required String percent,
    required Color color,
    required IconData icon,
  }) {
    final isPos = profit > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${profit >= 0 ? "+" : ""}${profit.toStringAsFixed(1)} دج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isPos ? color : Colors.red,
            ),
          ),
          Text(
            'هامش: $percent%',
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
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

  bool _isSaving = false;

  void _submit() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? widget.product.price,
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? widget.product.costPrice,
        wholesalePrice: double.tryParse(_wholesalePriceCtrl.text.trim()) ?? (double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? widget.product.wholesalePrice),
        stock: int.tryParse(_stockCtrl.text.trim()) ?? widget.product.stock,
        category: _selectedCategory,
        isWeighted: _isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
        imageUrl: _imageUrl,
        isTobacco: _isTobacco,
        cartonPrice: double.tryParse(_cartonPriceCtrl.text.trim()) ?? widget.product.cartonPrice,
        wholesaleCartonPrice: double.tryParse(_wholesaleCartonPriceCtrl.text.trim()) ?? widget.product.wholesaleCartonPrice,
        wholesalePackPrice: double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? widget.product.wholesalePackPrice,
        singlePiecePrice: double.tryParse(_singlePiecePriceCtrl.text.trim()) ?? widget.product.singlePiecePrice,
        piecesPerPack: int.tryParse(_piecesPerPackCtrl.text.trim()) ?? widget.product.piecesPerPack,
        packsPerCarton: int.tryParse(_packsPerCartonCtrl.text.trim()) ?? widget.product.packsPerCarton,
        unitType: _unitType,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      CatalogCrowdsourceHelper.silentHarvest(
        updatedProduct,
        category: _selectedCategory,
        unit: _isWeighted ? 'كغ' : 'حبة',
      );
      SoundService.playCheckoutSuccess();
      context.showAppSnackBar('✅ تم تحديث وتعديل بيانات السلعة بنجاح!');
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) context.pop();
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
    bool isConnected = false;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      isConnected = await PrintBluetoothThermal.connectionStatus;
    }
    
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

      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        await PrintBluetoothThermal.writeBytes(bytes);
      }
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
        title: Text(context.tr('edit_product_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.label_important_rounded, color: Colors.amber),
            tooltip: context.tr('shelf_tag_btn'),
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
                // Product Image Picker (Web search + camera + gallery)
                InputLabel(text: context.tr('product_image')),
                ProductImagePickerField(
                  initialImageUrl: _imageUrl,
                  barcode: _barcodeCtrl.text.trim(),
                  productName: _nameCtrl.text.trim(),
                  onImageChanged: (path) => setState(() => _imageUrl = path),
                ),
                const SizedBox(height: 16),

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
                            Text(context.tr('barcode_editable_hint'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _barcodeCtrl,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 15),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText: context.tr('barcode_editable_hint'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
                        tooltip: context.tr('scan_camera'),
                        onPressed: _scanBarcode,
                      ),
                    ],
                  ),
                ),

                // Product Name
                InputLabel(text: context.tr('product_name_label')),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(hintText: context.tr('product_name_label')),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required(context.tr('required')),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                InputLabel(text: context.tr('category_label')),
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
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        if (val.contains('تبغ') || val.contains('شمة') || val.contains('معسل') || val.contains('ولاع') || val.contains('ورق لف')) {
                          _isTobacco = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Unit Type Selection (قطعة، متر، مليلتر)
                InputLabel(text: context.tr('unit_label')),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'piece', label: Text(context.tr('unit_piece'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'meter', label: Text(context.tr('unit_meter'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'ml', label: Text(context.tr('unit_ml'), style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {_unitType},
                  onSelectionChanged: (set) {
                    setState(() => _unitType = set.first);
                  },
                ),
                if (_unitType == 'meter')
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 4),
                    child: Text('ℹ️ مخصص للأكشاك التي تبيع الحبال والمطاط بالمتر. في شاشة البيع ستتمكن من إدخال الطول بالمتر مباشرة.', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ),
                if (_unitType == 'ml')
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 4),
                    child: Text('ℹ️ مخصص للعطور الزيتية المركزة وسوائل الفيب والشيشة. في شاشة البيع ستظهر أزرار سريعة (30ml, 50ml, 100ml).', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ),
                const SizedBox(height: 16),

                // Tobacco & Kiosk Special pricing card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isTobacco ? Colors.brown.withOpacity(0.06) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _isTobacco ? Colors.brown : Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2, color: _isTobacco ? Colors.brown : Colors.grey),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('multipack_title'),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isTobacco ? Colors.brown[800] : Colors.black87)),
                                  Text(context.tr('multipack_subtitle'), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _isTobacco,
                            activeColor: Colors.brown,
                            onChanged: (v) => setState(() {
                              _isTobacco = v;
                            }),
                          ),
                        ],
                      ),
                      if (_isTobacco) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('carton_retail_price')),
                                  TextFormField(
                                    controller: _cartonPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(hintText: '4100', suffixText: 'دج'),
                                    onChanged: _onCartonPriceChanged,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('carton_wholesale_price')),
                                  TextFormField(
                                    controller: _wholesaleCartonPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(hintText: '3950', suffixText: 'دج'),
                                    onChanged: _onWholesaleCartonPriceChanged,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('pack_wholesale_price')),
                                  TextFormField(
                                    controller: _wholesalePackPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(hintText: '400', suffixText: 'دج'),
                                    onChanged: _onWholesalePackPriceChanged,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('single_piece_price')),
                                  TextFormField(
                                    controller: _singlePiecePriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(hintText: '25', suffixText: 'دج'),
                                    onChanged: _onSinglePiecePriceChanged,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('pieces_per_pack')),
                                  TextFormField(
                                    controller: _piecesPerPackCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: '20'),
                                    onChanged: (v) {
                                      if (_cartonPriceCtrl.text.isNotEmpty) {
                                        _onCartonPriceChanged(_cartonPriceCtrl.text);
                                      } else if (_priceCtrl.text.isNotEmpty) {
                                        _onPackPriceChanged(_priceCtrl.text);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InputLabel(text: context.tr('packs_per_carton')),
                                  TextFormField(
                                    controller: _packsPerCartonCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: '10'),
                                    onChanged: (v) {
                                      if (_cartonPriceCtrl.text.isNotEmpty) {
                                        _onCartonPriceChanged(_cartonPriceCtrl.text);
                                      } else if (_priceCtrl.text.isNotEmpty) {
                                        _onPackPriceChanged(_priceCtrl.text);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        _buildTobaccoProfitCard(),
                      ],
                    ],
                  ),
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
                              Text(context.tr('sold_by_weight_title'),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isWeighted ? Colors.teal[800] : Colors.black87)),
                              Text(context.tr('sold_by_weight_hint'), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
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
                          InputLabel(text: context.tr('cost_price_input')),
                          TextFormField(
                            controller: _costPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputLabel(text: context.tr('retail_price_input')),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                            validator: AppValidators.price,
                            onChanged: (v) {
                              if (_isTobacco) {
                                _onPackPriceChanged(v);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InputLabel(text: context.tr('wholesale_price_input')),
                          TextFormField(
                            controller: _wholesalePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: '0', suffixText: 'دج'),
                            onChanged: (v) {
                              if (_isTobacco) {
                                _onWholesalePackPriceChanged(v);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isTobacco &&
                    (double.tryParse(_priceCtrl.text) ?? 0) > 0 &&
                    (double.tryParse(_costPriceCtrl.text) ?? 0) > 0) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final p = double.tryParse(_priceCtrl.text) ?? 0;
                      final c = double.tryParse(_costPriceCtrl.text) ?? 0;
                      final diff = p - c;
                      final pct = c > 0 ? ((diff / c) * 100).toStringAsFixed(1) : '0';
                      final isPos = diff > 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPos ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isPos ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Icon(isPos ? Icons.trending_up : Icons.trending_down,
                                size: 16, color: isPos ? const Color(0xFF16A34A) : Colors.red),
                            const SizedBox(width: 6),
                            Text(
                              'صافي الربح للقطعة: ${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(2)} دج (نسبة الربح: $pct%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPos ? const Color(0xFF166534) : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Stock Quantity & Quick Batch Arrivage Addition Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${context.tr('stock_quantity_label')} (${_isWeighted ? "كغ" : "قطعة"}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                    Text(context.tr('quick_arrivage_label'), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
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
                                Text(context.tr('expiry_date_label'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : context.tr('no_expiry_date'),
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
              : const Icon(Icons.save),
          label: Text(
            _isSaving ? '...' : context.tr('save_changes_btn'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          onPressed: _isSaving ? null : _submit,
        ),
      ),
    );
  }
}
