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
  late TextEditingController _packBarcodeCtrl;
  late TextEditingController _packNameCtrl;

  late String _selectedCategory;
  String? _imageUrl;
  late bool _isTobacco;
  late bool _hasCartonLevel;
  late bool _hasPackLevel;
  late bool _hasPieceLevel;
  late bool _allowPieceSale;
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
    'ماكينة القهوة والشاي',
    'عطور زيتية وبالمتر',
    'مواد غذائية ومعلبات',
    'حليب ومشتقاته',
    'أجبان ومشتقات الحليب',
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
    _isTobacco = widget.product.isTobacco ||
        widget.product.category.contains('تبغ') ||
        widget.product.category.contains('شمة') ||
        widget.product.category.contains('معسل') ||
        widget.product.hasMultiUnit;
    _hasCartonLevel = widget.product.hasCarton || widget.product.cartonPrice > 0 || widget.product.packsPerCarton > 1;
    _hasPieceLevel = widget.product.hasSubUnit || widget.product.singlePiecePrice > 0 || (widget.product.piecesPerPack > 1 && !widget.product.isBeverage);
    _hasPackLevel = true;
    _unitType = widget.product.unitType.isNotEmpty ? widget.product.unitType : 'piece';
    _allowPieceSale = widget.product.singlePiecePrice > 0 || _hasPieceLevel;
    _cartonPriceCtrl = TextEditingController(text: widget.product.cartonPrice > 0 ? widget.product.cartonPrice.toStringAsFixed(0) : '');
    _wholesaleCartonPriceCtrl = TextEditingController(text: widget.product.wholesaleCartonPrice > 0 ? widget.product.wholesaleCartonPrice.toStringAsFixed(0) : '');
    _wholesalePackPriceCtrl = TextEditingController(text: widget.product.wholesalePackPrice > 0 ? widget.product.wholesalePackPrice.toStringAsFixed(0) : '');
    _singlePiecePriceCtrl = TextEditingController(text: widget.product.singlePiecePrice > 0 ? widget.product.singlePiecePrice.toStringAsFixed(0) : '');
    _packsPerCartonCtrl = TextEditingController(text: widget.product.packsPerCarton.toString());
    _piecesPerPackCtrl = TextEditingController(text: widget.product.piecesPerPack.toString());
    _packBarcodeCtrl = TextEditingController(text: widget.product.packBarcode ?? '');
    _packNameCtrl = TextEditingController(text: widget.product.packName ?? '');

    _selectedCategory = widget.product.category.isNotEmpty ? widget.product.category : 'عام';
    _isWeighted = widget.product.isWeighted || widget.product.barcode.startsWith('SCALE_') || widget.product.name.contains('ميزان') || widget.product.name.contains('كغ');
    if (widget.product.expiryDate != null && widget.product.expiryDate!.isNotEmpty) {
      _expiryDate = DateTime.tryParse(widget.product.expiryDate!);
    }
  }

  void _applyCategoryConfig(String cat, {bool userOverride = false}) {
    final lower = cat.toLowerCase();
    final isTob = lower.contains('تبغ') || lower.contains('سجائر') || lower.contains('شمة') || lower.contains('معسل') || lower.contains('ولاع') || lower.contains('ورق لف');
    final isCheese = lower.contains('جبن') || lower.contains('حليب') || lower.contains('مشتقات') || lower.contains('fromage');
    final isDrink = lower.contains('مشروب') || lower.contains('ماء') || lower.contains('عصير') || lower.contains('boisson') || lower.contains('soda');
    final isCoffee = lower.contains('ماكينة') || lower.contains('قهوة') || lower.contains('شاي') || lower.contains('cafe') || lower.contains('tea');
    final isProduce = lower.contains('خضر') || lower.contains('فواكه') || lower.contains('ميزان') || lower.contains('legume') || lower.contains('fruit');

    setState(() {
      _isTobacco = isTob;
      if (isTob) {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _isWeighted = false;
        _packsPerCartonCtrl.text = '10';
        _piecesPerPackCtrl.text = '20';
        _packNameCtrl.text = 'علبة';
      } else if (isCheese) {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _packsPerCartonCtrl.text = '12';
        _piecesPerPackCtrl.text = '16';
        _packNameCtrl.text = 'علبة';
      } else if (isDrink) {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = false;
        _allowPieceSale = false;
        _isWeighted = false;
        _packsPerCartonCtrl.text = '6';
        _piecesPerPackCtrl.text = '1';
        _packNameCtrl.text = 'قارورة';
      } else if (isCoffee) {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _isWeighted = false;
        _packsPerCartonCtrl.text = '10';
        _piecesPerPackCtrl.text = '100'; // 100 cups yield per kg
        _packNameCtrl.text = 'كيس 1 كغ بن';
      } else if (isProduce) {
        _isWeighted = true;
        _hasCartonLevel = false;
        _hasPackLevel = false;
        _hasPieceLevel = false;
        _allowPieceSale = false;
      }
    });

    if (_priceCtrl.text.isNotEmpty) {
      _onPackPriceChanged(_priceCtrl.text);
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
    _packBarcodeCtrl.dispose();
    _packNameCtrl.dispose();
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
      if (pieces > 0 && _allowPieceSale) {
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


  Widget _buildBreakCaseCard() {
    final barcode = widget.product.barcode;
    final looseCount = (HiveDatabase.loosePiecesBox.get(barcode, defaultValue: 0) as num).toInt();
    final packStock = int.tryParse(_stockCtrl.text.trim()) ?? widget.product.stock;
    final piecesPerPack = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? widget.product.piecesPerPack;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut_rounded, color: Color(0xFF334155), size: 18),
              const SizedBox(width: 8),
              const Text(
                'إدارة كسر العلب (Break-Case & Loose Pieces)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text('علب مقفلة بالرف', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('$packStock علبة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text('حبات فردية مفتوحة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('$looseCount حبة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepOrange)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Colors.deepOrange),
                  ),
                  onPressed: packStock > 0
                      ? () {
                          final newStock = packStock - 1;
                          final newLoose = looseCount + piecesPerPack;
                          HiveDatabase.loosePiecesBox.put(barcode, newLoose);
                          setState(() {
                            _stockCtrl.text = newStock.toString();
                          });
                          SoundService.playKeyTap();
                          context.showAppSnackBar('✂️ تم فتح علبة وإضافة $piecesPerPack حبة إلى المخزون المفتوح!');
                        }
                      : null,
                  icon: const Icon(Icons.content_cut, size: 16, color: Colors.deepOrange),
                  label: const Text('فتح علبة لحبات', style: TextStyle(fontSize: 11.5, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Colors.teal),
                  ),
                  onPressed: looseCount >= piecesPerPack
                      ? () {
                          final newLoose = looseCount - piecesPerPack;
                          final newStock = packStock + 1;
                          HiveDatabase.loosePiecesBox.put(barcode, newLoose);
                          setState(() {
                            _stockCtrl.text = newStock.toString();
                          });
                          SoundService.playSaveSuccess();
                          context.showAppSnackBar('📦 تم تجميع $piecesPerPack حبة في علبة مقفلة جديدة!');
                        }
                      : null,
                  icon: const Icon(Icons.inventory_rounded, size: 16, color: Colors.teal),
                  label: const Text('تجميع لعلبة', style: TextStyle(fontSize: 11.5, color: Colors.teal, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildPieceSaleToggle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _allowPieceSale ? Colors.deepOrange.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _allowPieceSale ? Colors.deepOrange.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: _allowPieceSale ? Colors.deepOrange : Colors.grey, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفعيل البيع بالحبة (Vente à la pièce)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: _allowPieceSale ? Colors.deepOrange.shade900 : Colors.black87),
                  ),
                  const Text('حساب سعر الحبة تلقائياً وتمكين بيعها بالكاشير', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
          Switch(
            value: _allowPieceSale,
            activeColor: Colors.deepOrange,
            onChanged: (val) {
              setState(() {
                _allowPieceSale = val;
                if (val) {
                  final pack = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
                  final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;
                  if (pack > 0 && pieces > 0) {
                    final calc = (pack / pieces).ceilToDouble();
                    _singlePiecePriceCtrl.text = calc % 1 == 0 ? calc.toInt().toString() : calc.toStringAsFixed(0);
                  }
                } else {
                  _singlePiecePriceCtrl.text = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiUnitProfitCard() {
    final cartonPrice = double.tryParse(_cartonPriceCtrl.text.trim()) ?? 0.0;
    final packPrice = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final piecePrice = double.tryParse(_singlePiecePriceCtrl.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0;
    final packs = int.tryParse(_packsPerCartonCtrl.text.trim()) ?? 10;
    final pieces = int.tryParse(_piecesPerPackCtrl.text.trim()) ?? 20;

    final packCost = costPrice;
    final cartonCost = packCost * packs;
    final pieceCost = (pieces > 0 && packCost > 0) ? (packCost / pieces) : 0.0;

    final cartonProfit = (_hasCartonLevel && cartonPrice > 0 && cartonCost > 0) ? (cartonPrice - cartonCost) : 0.0;
    final packProfit = (_hasPackLevel && packPrice > 0 && packCost > 0) ? (packPrice - packCost) : 0.0;
    final pieceProfit = (_hasPieceLevel && piecePrice > 0 && pieceCost > 0) ? (piecePrice - pieceCost) : 0.0;

    final cartonProfitPercent = cartonCost > 0 ? ((cartonProfit / cartonCost) * 100).toStringAsFixed(1) : '0';
    final packProfitPercent = packCost > 0 ? ((packProfit / packCost) * 100).toStringAsFixed(1) : '0';
    final pieceProfitPercent = pieceCost > 0 ? ((pieceProfit / pieceCost) * 100).toStringAsFixed(1) : '0';

    final isCoffee = _selectedCategory.contains('ماكينة') || _selectedCategory.contains('قهوة') || _selectedCategory.contains('شاي');
    final pieceTitle = isCoffee ? 'ربح الكوب / الفنجان' : (_selectedCategory.contains('تبغ') ? 'ربح السيجارة' : 'ربح الحبة / القطعة');

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
              if (_hasCartonLevel)
                Expanded(
                  child: _buildProfitPill(
                    title: 'ربح الكرتونة',
                    profit: cartonProfit,
                    percent: cartonProfitPercent,
                    color: const Color(0xFF0D9488),
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
              if (_hasCartonLevel && (_hasPackLevel || _hasPieceLevel)) const SizedBox(width: 8),
              if (_hasPackLevel)
                Expanded(
                  child: _buildProfitPill(
                    title: 'ربح العلبة / الوحدة',
                    profit: packProfit,
                    percent: packProfitPercent,
                    color: const Color(0xFF2563EB),
                    icon: Icons.crop_portrait_rounded,
                  ),
                ),
              if (_hasPackLevel && _hasPieceLevel) const SizedBox(width: 8),
              if (_hasPieceLevel)
                Expanded(
                  child: _buildProfitPill(
                    title: pieceTitle,
                    profit: pieceProfit,
                    percent: pieceProfitPercent,
                    color: const Color(0xFFD97706),
                    icon: isCoffee ? Icons.coffee_rounded : Icons.pie_chart_rounded,
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
      _isTobacco = type == 'tobacco';
      if (type == 'tobacco') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _piecesPerPackCtrl.text = '20';
        _packsPerCartonCtrl.text = '10';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'cheese') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _piecesPerPackCtrl.text = '16';
        _packsPerCartonCtrl.text = '12';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'coffee') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _piecesPerPackCtrl.text = '100';
        _packsPerCartonCtrl.text = '10';
        _packNameCtrl.text = 'كيس 1 كغ بن';
      } else if (type == 'water') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = false;
        _allowPieceSale = false;
        _piecesPerPackCtrl.text = '1';
        _packsPerCartonCtrl.text = '6';
        _packNameCtrl.text = 'قارورة';
      } else if (type == 'gum') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
        _piecesPerPackCtrl.text = '20';
        _packsPerCartonCtrl.text = '24';
        _packNameCtrl.text = 'علبة';
      } else if (type == 'eggs') {
        _hasCartonLevel = true;
        _hasPackLevel = true;
        _hasPieceLevel = true;
        _allowPieceSale = true;
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
      double retailPrice = double.tryParse(_priceCtrl.text.trim()) ?? widget.product.price;
      double singlePiecePrice = _hasPieceLevel ? (double.tryParse(_singlePiecePriceCtrl.text.trim()) ?? widget.product.singlePiecePrice) : 0.0;
      // Loose pieces handling: if user disabled pack level and is selling loose pieces only
      if (!_hasPackLevel && _hasPieceLevel) {
        if (retailPrice == 0.0 && singlePiecePrice > 0.0) {
          retailPrice = singlePiecePrice;
        }
        if (singlePiecePrice == 0.0 && retailPrice > 0.0) {
          singlePiecePrice = retailPrice;
        }
      }

      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim(),
        price: retailPrice,
        costPrice: double.tryParse(_costPriceCtrl.text.trim()) ?? widget.product.costPrice,
        wholesalePrice: _hasPackLevel ? (double.tryParse(_wholesalePriceCtrl.text.trim()) ?? (double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? widget.product.wholesalePrice)) : 0.0,
        stock: int.tryParse(_stockCtrl.text.trim()) ?? widget.product.stock,
        category: _selectedCategory,
        isWeighted: _isWeighted,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
        imageUrl: _imageUrl,
        isTobacco: _isTobacco || _selectedCategory.contains('تبغ') || _selectedCategory.contains('سجائر') || _selectedCategory.contains('شمة') || _selectedCategory.contains('معسل'),
        cartonPrice: _hasCartonLevel ? (double.tryParse(_cartonPriceCtrl.text.trim()) ?? widget.product.cartonPrice) : 0.0,
        wholesaleCartonPrice: _hasCartonLevel ? (double.tryParse(_wholesaleCartonPriceCtrl.text.trim()) ?? widget.product.wholesaleCartonPrice) : 0.0,
        wholesalePackPrice: _hasPackLevel ? (double.tryParse(_wholesalePackPriceCtrl.text.trim()) ?? widget.product.wholesalePackPrice) : 0.0,
        singlePiecePrice: singlePiecePrice,
        piecesPerPack: _hasPieceLevel ? (int.tryParse(_piecesPerPackCtrl.text.trim()) ?? widget.product.piecesPerPack) : 1,
        packsPerCarton: _hasCartonLevel ? (int.tryParse(_packsPerCartonCtrl.text.trim()) ?? widget.product.packsPerCarton) : 1,
        packBarcode: (_hasCartonLevel && _packBarcodeCtrl.text.trim().isNotEmpty) ? _packBarcodeCtrl.text.trim() : null,
        packName: _hasPackLevel && _packNameCtrl.text.trim().isNotEmpty ? _packNameCtrl.text.trim() : null,
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
          title: Row(
            children: [
              const Icon(Icons.label_important_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Text(ctx.tr('print_price_sticker'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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
                    child: Text('$labelCopies', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
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
                        icon: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
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
                      });
                      _applyCategoryConfig(val, userOverride: true);
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

                // Universal Multi-Unit Packaging Card (Independent Levels Architecture)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.layers_rounded, color: Colors.teal, size: 22),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('نظام التعبئة والتجزئة متعدد المستويات 📦📏',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87)),
                                  Text('أزرار تفعيل/تعطيل مستقلة لكل مستوى: كرتونة، علبة، وحبة/كوب', style: TextStyle(fontSize: 10.5, color: Colors.blueGrey)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
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
                            _buildPresetChip('☕ ماكينة قهوة وشاي', 'coffee'),
                            const SizedBox(width: 6),
                            _buildPresetChip('💧 ماء وعصائر', 'water'),
                            const SizedBox(width: 6),
                            _buildPresetChip('🍬 علك وحلويات', 'gum'),
                            const SizedBox(width: 6),
                            _buildPresetChip('🥚 بيض وبلاطو', 'eggs'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // LEVEL 1: CARTON / FARDEAU
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasCartonLevel ? Colors.teal.withOpacity(0.06) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _hasCartonLevel ? Colors.teal.shade400 : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, color: _hasCartonLevel ? Colors.teal : Colors.grey, size: 18),
                                    const SizedBox(width: 6),
                                    Text('مستوى 1: الكرتونة أو الفاردو / الكرطوشة',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _hasCartonLevel ? Colors.teal.shade900 : Colors.grey.shade700)),
                                  ],
                                ),
                                Switch(
                                  value: _hasCartonLevel,
                                  activeColor: Colors.teal,
                                  onChanged: (v) => setState(() {
                                    _hasCartonLevel = v;
                                    if (!v) {
                                      _cartonPriceCtrl.clear();
                                      _wholesaleCartonPriceCtrl.clear();
                                      _packsPerCartonCtrl.text = '1';
                                    } else {
                                      if (_packsPerCartonCtrl.text == '1' || _packsPerCartonCtrl.text.isEmpty) {
                                        _packsPerCartonCtrl.text = '10';
                                      }
                                      if (_priceCtrl.text.isNotEmpty) {
                                        _onPackPriceChanged(_priceCtrl.text);
                                      }
                                    }
                                  }),
                                ),
                              ],
                            ),
                            if (_hasCartonLevel) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const InputLabel(text: 'عدد العلب في الكرتونة / الفاردو *'),
                                        TextFormField(
                                          controller: _packsPerCartonCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(hintText: '10', prefixIcon: Icon(Icons.numbers, size: 18)),
                                          onChanged: (v) {
                                            if (_priceCtrl.text.isNotEmpty) _onPackPriceChanged(_priceCtrl.text);
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
                                        const InputLabel(text: 'باركود الكرتونة (اختياري)'),
                                        TextFormField(
                                          controller: _packBarcodeCtrl,
                                          decoration: const InputDecoration(hintText: 'امسح باركود الكرتونة', prefixIcon: Icon(Icons.qr_code, size: 18)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const InputLabel(text: 'سعر بيع الكرتونة (تجزئة)'),
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
                                        const InputLabel(text: 'سعر بيع الكرتونة (جملة)'),
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
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // LEVEL 2: PACK / UNIT
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasPackLevel ? Colors.indigo.withOpacity(0.05) : Colors.amber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _hasPackLevel ? Colors.indigo.shade300 : Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.crop_portrait_rounded, color: _hasPackLevel ? Colors.indigo : Colors.amber.shade800, size: 18),
                                    const SizedBox(width: 6),
                                    Text('مستوى 2: العلبة / الوحدة الأساسية (Pack)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _hasPackLevel ? Colors.indigo.shade900 : Colors.amber.shade900)),
                                  ],
                                ),
                                Switch(
                                  value: _hasPackLevel,
                                  activeColor: Colors.indigo,
                                  onChanged: (v) => setState(() {
                                    _hasPackLevel = v;
                                    if (!v) {
                                      _hasPieceLevel = true;
                                      _allowPieceSale = true;
                                    }
                                  }),
                                ),
                              ],
                            ),
                            if (_hasPackLevel) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const InputLabel(text: 'اسم العبوة الأساسية'),
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
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.brown),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'تم تعطيل مستوى العلبة: يتم بيع وتتبع السلعة كحبات فردية مستوردة أو حبات مباشرة.',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // LEVEL 3: PIECE / SUB-UNIT / CUP
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasPieceLevel ? Colors.deepOrange.withOpacity(0.06) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _hasPieceLevel ? Colors.deepOrange.shade300 : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedCategory.contains('ماكينة') || _selectedCategory.contains('قهوة')
                                          ? Icons.coffee_rounded
                                          : Icons.pie_chart_rounded,
                                      color: _hasPieceLevel ? Colors.deepOrange : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCategory.contains('ماكينة') || _selectedCategory.contains('قهوة')
                                          ? 'مستوى 3: تحضير وبيع الكؤوس (إنتاجية الأكواب ☕)'
                                          : 'مستوى 3: البيع بالحبة / المثلث / القطعة الفردية',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _hasPieceLevel ? Colors.deepOrange.shade900 : Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _hasPieceLevel,
                                  activeColor: Colors.deepOrange,
                                  onChanged: (v) => setState(() {
                                    _hasPieceLevel = v;
                                    _allowPieceSale = v;
                                    if (!v) {
                                      _singlePiecePriceCtrl.clear();
                                      _piecesPerPackCtrl.text = '1';
                                    } else {
                                      if (_piecesPerPackCtrl.text == '1' || _piecesPerPackCtrl.text.isEmpty) {
                                        _piecesPerPackCtrl.text = _selectedCategory.contains('قهوة') ? '100' : '20';
                                      }
                                      if (_priceCtrl.text.isNotEmpty) {
                                        _onPackPriceChanged(_priceCtrl.text);
                                      }
                                    }
                                  }),
                                ),
                              ],
                            ),
                            if (_hasPieceLevel) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InputLabel(
                                          text: _selectedCategory.contains('ماكينة') || _selectedCategory.contains('قهوة')
                                              ? 'إنتاجية الكؤوس للكيس/الكغ *'
                                              : (_selectedCategory.contains('جبن') ? 'مثلثات/قطع في العلبة *' : 'حبات/سجائر في العلبة *'),
                                        ),
                                        TextFormField(
                                          controller: _piecesPerPackCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: _selectedCategory.contains('قهوة') ? '100' : '20',
                                            prefixIcon: const Icon(Icons.layers, size: 18),
                                          ),
                                          onChanged: (v) {
                                            if (_priceCtrl.text.isNotEmpty) _onPackPriceChanged(_priceCtrl.text);
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
                                        InputLabel(
                                          text: _selectedCategory.contains('ماكينة') || _selectedCategory.contains('قهوة')
                                              ? 'سعر بيع الكأس/الفنجان (دج)'
                                              : 'سعر بيع الحبة للعموم (دج)',
                                        ),
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
                            ],
                          ],
                        ),
                      ),

                      // BREAK CASE CARD (If item has piece/loose management)
                      if (_hasPieceLevel || _isTobacco) _buildBreakCaseCard(),

                      // PROFIT ANALYTICS CARD
                      _buildMultiUnitProfitCard(),
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
                          InputLabel(text: context.tr('retail_price_input')),
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
                          InputLabel(text: context.tr('wholesale_price_input')),
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
