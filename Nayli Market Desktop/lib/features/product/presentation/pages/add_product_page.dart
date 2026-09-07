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
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/widgets/input_label.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

import '../widgets/product_image_picker_field.dart';

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

  // New Tobacco & Unit controllers
  final TextEditingController _cartonPriceCtrl = TextEditingController();
  final TextEditingController _wholesaleCartonPriceCtrl = TextEditingController();
  final TextEditingController _wholesalePackPriceCtrl = TextEditingController();
  final TextEditingController _singlePiecePriceCtrl = TextEditingController();
  final TextEditingController _packsPerCartonCtrl = TextEditingController(text: '10');
  final TextEditingController _piecesPerPackCtrl = TextEditingController(text: '20');
  final TextEditingController _packBarcodeCtrl = TextEditingController();
  final TextEditingController _packNameCtrl = TextEditingController();

  String _selectedCategory = 'عام';
  bool _isCategoryUserSelected = false;
  String? _imageUrl;
  bool _isTobacco = false;
  String _unitType = 'piece'; // 'piece', 'meter', 'ml'
  bool _isWeighted = false;
  DateTime? _expiryDate;
  bool _isSaving = false;

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
    _nameCtrl.addListener(() {
      if (!_isCategoryUserSelected && _nameCtrl.text.trim().isNotEmpty) {
        final detected = CategoryTaxonomy.smartDetect(_nameCtrl.text.trim());
        if (mounted && _selectedCategory != detected.titleAr) {
          setState(() {
            _selectedCategory = categories.contains(detected.titleAr) ? detected.titleAr : 'عام';
            if (_selectedCategory.contains('تبغ') || _selectedCategory.contains('شمة') || _selectedCategory.contains('معسل')) {
              _isTobacco = true;
            }
          });
        }
      }
    });
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
    _packBarcodeCtrl.dispose();
    _packNameCtrl.dispose();
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

  void _applyMultiUnitPreset(String type) {
    SoundService.playTabSwitch();
    setState(() {
      _isTobacco = true;
      if (type == 'tobacco') {
        _piecesPerPackCtrl.text = '20';
        _packsPerCartonCtrl.text = '10';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'cheese') {
        _piecesPerPackCtrl.text = '16';
        _packsPerCartonCtrl.text = '12';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'water') {
        _piecesPerPackCtrl.text = '0';
        _packsPerCartonCtrl.text = '6';
        _packNameCtrl.text = 'قارورة';
      } else if (type == 'gum') {
        _piecesPerPackCtrl.text = '20';
        _packsPerCartonCtrl.text = '24';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'eggs') {
        _piecesPerPackCtrl.text = '30';
        _packsPerCartonCtrl.text = '12';
        _packNameCtrl.text = 'بلاطو 30';
      }
    });

    if (_priceCtrl.text.isNotEmpty) {
      _onPackPriceChanged(_priceCtrl.text);
    }
  }

  Widget _buildPresetChip(String label, String type) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.teal.shade50,
      side: BorderSide(color: Colors.teal.shade200),
      onPressed: () => _applyMultiUnitPreset(type),
    );
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
        wholesalePrice: double.tryParse(_wholesalePriceCtrl.text.trim()) ?? (double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? 0.0),
        stock: int.tryParse(_stockCtrl.text.trim()) ?? 10,
        category: _selectedCategory,
        isWeighted: _isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
        imageUrl: _imageUrl,
        isTobacco: _isTobacco,
        cartonPrice: double.tryParse(_cartonPriceCtrl.text.trim()) ?? 0.0,
        wholesaleCartonPrice: double.tryParse(_wholesaleCartonPriceCtrl.text.trim()) ?? 0.0,
        wholesalePackPrice: double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? 0.0,
        singlePiecePrice: double.tryParse(_singlePiecePriceCtrl.text.trim()) ?? 0.0,
        piecesPerPack: int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20,
        packsPerCarton: int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10,
        packBarcode: _packBarcodeCtrl.text.trim().isNotEmpty ? _packBarcodeCtrl.text.trim() : null,
        packName: _packNameCtrl.text.trim().isNotEmpty ? _packNameCtrl.text.trim() : null,
        unitType: _unitType,
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
                // Product Image Picker (Web search + camera + gallery)
                const InputLabel(text: 'صورة المنتج 📸 (تظهر بالتطبيق ولا تطبع على الوصل)'),
                ProductImagePickerField(
                  initialImageUrl: _imageUrl,
                  barcode: _barcodeCtrl.text.trim(),
                  productName: _nameCtrl.text.trim(),
                  onImageChanged: (path) => setState(() => _imageUrl = path),
                ),
                const SizedBox(height: 16),

                // Barcode input with camera scanner button
                const InputLabel(text: 'رمز الباركود'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: InputDecoration(
                          hintText: context.tr('scan_or_type_barcode'),
                          prefixIcon: const Icon(Icons.qr_code),
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
                  decoration: InputDecoration(hintText: context.tr('item_name')),
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
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        _isCategoryUserSelected = true;
                        if (val.contains('تبغ') || val.contains('شمة') || val.contains('معسل') || val.contains('ولاع') || val.contains('ورق لف')) {
                          _isTobacco = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Unit Type Selection (قطعة، متر، مليلتر)
                const InputLabel(text: 'وحدة البيع والقياس 📏📦'),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'piece', label: Text(context.tr('unit_piece_box'), style: const TextStyle(fontSize: 12))),
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

                // Universal Multi-Unit Packaging Card (Piece / Pack / Carton)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isTobacco ? Colors.teal.withOpacity(0.06) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _isTobacco ? Colors.teal : Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.layers_rounded, color: _isTobacco ? Colors.teal : Colors.grey),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('multi_unit_packaging_system'),
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isTobacco ? Colors.teal[900] : Colors.black87)),
                                  const Text('للسجائر، قوارير وفاردو الماء، مثلثات الجبن، العلك، البيض، إلخ', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _isTobacco,
                            activeColor: Colors.teal,
                            onChanged: (v) => setState(() {
                              _isTobacco = v;
                            }),
                          ),
                        ],
                      ),
                      if (_isTobacco) ...[
                        const Divider(height: 18),
                        const Text('قوالب سريعة للأصناف الشائعة ⚡:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPresetChip('🚬 سجائر وتبغ', 'tobacco'),
                              const SizedBox(width: 6),
                              _buildPresetChip('🧀 جبن ومثلثات', 'cheese'),
                              const SizedBox(width: 6),
                              _buildPresetChip('💧 ماء وعصائر', 'water'),
                              const SizedBox(width: 6),
                              _buildPresetChip('🍬 علك وحلويات', 'gum'),
                              const SizedBox(width: 6),
                              _buildPresetChip('🥚 بيض وبلاطو', 'eggs'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const InputLabel(text: 'سعر بيع الكرطوشة (تجزئة)'),
                                  TextFormField(
                                    controller: _cartonPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(hintText: '4100', suffixText: context.tr('currency_symbol')),
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
                                  const InputLabel(text: 'سعر بيع الكرطوشة (جملة)'),
                                  TextFormField(
                                    controller: _wholesaleCartonPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(hintText: '3950', suffixText: context.tr('currency_symbol')),
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
                                  const InputLabel(text: 'سعر بيع العلبة (جملة)'),
                                  TextFormField(
                                    controller: _wholesalePackPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(hintText: '400', suffixText: context.tr('currency_symbol')),
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
                                  const InputLabel(text: 'سعر بيع السيجارة بالحبة (دج)'),
                                  TextFormField(
                                    controller: _singlePiecePriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(hintText: '25', suffixText: context.tr('currency_symbol')),
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
                                  const InputLabel(text: 'سجائر في العلبة'),
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
                                  const InputLabel(text: 'علب في الكرطوشة'),
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const InputLabel(text: 'اسم العبوة الأساسية (علبة/قارورة/بلاطو)'),
                                  TextFormField(
                                    controller: _packNameCtrl,
                                    decoration: InputDecoration(hintText: context.tr('box_bottle_pack')),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const InputLabel(text: 'باركود الكرتونة / الفاردو (اختياري)'),
                                  TextFormField(
                                    controller: _packBarcodeCtrl,
                                    decoration: InputDecoration(hintText: context.tr('scan_carton_barcode')),
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
                              Text(context.tr('sold_by_scale_kg'),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isWeighted ? Colors.teal[800] : Colors.black87)),
                              Text(context.tr('calc_price_by_weight'), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
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
                            decoration: InputDecoration(hintText: '0', suffixText: context.tr('currency_symbol')),
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
                          const InputLabel(text: 'سعر البيع (Détail) *'),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(hintText: '0', suffixText: context.tr('currency_symbol')),
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
                          const InputLabel(text: 'سعر الجملة (Gros)'),
                          TextFormField(
                            controller: _wholesalePriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(hintText: '0', suffixText: context.tr('currency_symbol')),
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
                                Text(context.tr('expiry_date_optional'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
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


