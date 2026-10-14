import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/widgets/liquid_bottle_indicator.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/liquid_decant_config.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/billing_bloc.dart';

class LiquidDecantDialog extends StatefulWidget {
  final Product product;
  final CartItem? existingCartItem;

  const LiquidDecantDialog({
    super.key,
    required this.product,
    this.existingCartItem,
  });

  static Future<void> show(
    BuildContext context,
    Product product, {
    CartItem? existingCartItem,
  }) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LiquidDecantDialog(
        product: product,
        existingCartItem: existingCartItem,
      ),
    );
  }

  @override
  State<LiquidDecantDialog> createState() => _LiquidDecantDialogState();
}

class _LiquidDecantDialogState extends State<LiquidDecantDialog> {
  late LiquidDecantConfig _config;

  // Selected Bottle Format or Custom Mode
  LiquidBottleFormat? _selectedFormat;
  bool _isCustomVolume = false;

  // Custom Volume & Dispensing
  late TextEditingController _customVolumeCtrl;
  late TextEditingController _customPriceCtrl;
  late TextEditingController _customBottleCostCtrl;
  bool _includeEmptyBottle = true;

  // Quantity of bottles to dispense
  int _bottlesCount = 1;

  @override
  void initState() {
    super.initState();
    _config = widget.product.liquidConfig ??
        LiquidDecantConfig.defaultPerfumeConfig().copyWith(
          containerCost: widget.product.costPrice > 0 ? widget.product.costPrice : 15000,
        );

    // Default selection: middle enabled format (e.g. 30ml)
    final enabledFormats = _config.formats.where((f) => f.isEnabled).toList();
    if (enabledFormats.isNotEmpty) {
      final preferred = enabledFormats.firstWhere(
        (f) => f.volumeMl == 30,
        orElse: () => enabledFormats.first,
      );
      _selectedFormat = preferred;
      _isCustomVolume = false;
    } else {
      _isCustomVolume = true;
    }

    _customVolumeCtrl = TextEditingController(text: '30');
    _customPriceCtrl = TextEditingController(
      text: _config.defaultPricePerMl > 0
          ? (_config.defaultPricePerMl * 30 + _config.defaultEmptyBottleCost).toInt().toString()
          : '3000',
    );
    _customBottleCostCtrl = TextEditingController(
      text: _config.defaultEmptyBottleCost.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _customVolumeCtrl.dispose();
    _customPriceCtrl.dispose();
    _customBottleCostCtrl.dispose();
    super.dispose();
  }

  double get _currentVolume {
    if (!_isCustomVolume && _selectedFormat != null) {
      return _selectedFormat!.volumeMl;
    }
    return double.tryParse(_customVolumeCtrl.text.trim()) ?? 30.0;
  }

  double get _currentBottleCost {
    if (!_isCustomVolume && _selectedFormat != null) {
      return _selectedFormat!.bottleCost;
    }
    if (!_includeEmptyBottle) return 0.0;
    return double.tryParse(_customBottleCostCtrl.text.trim()) ?? _config.defaultEmptyBottleCost;
  }

  double get _currentUnitPrice {
    if (!_isCustomVolume && _selectedFormat != null) {
      return _selectedFormat!.sellingPrice;
    }
    return double.tryParse(_customPriceCtrl.text.trim()) ?? 0.0;
  }

  double get _liquidCostPerUnit => _currentVolume * _config.costPerMl;
  double get _totalCostPerUnit => _liquidCostPerUnit + _currentBottleCost;
  double get _profitPerUnit => _currentUnitPrice - _totalCostPerUnit;
  double get _marginPercent =>
      (_currentUnitPrice > 0) ? ((_profitPerUnit / _currentUnitPrice) * 100) : 0.0;

  LiquidType get _liquidType {
    final cat = widget.product.category.toLowerCase();
    final name = widget.product.name.toLowerCase();
    if (name.contains('زيت') || cat.contains('زيت')) return LiquidType.oilPerfume;
    if (name.contains('عطر') || cat.contains('عطر') || cat.contains('parfum')) return LiquidType.perfume;
    if (name.contains('كيراتين') || name.contains('بروتين') || name.contains('شامبو') || cat.contains('شعر')) return LiquidType.hairCare;
    if (cat.contains('تجميل') || cat.contains('مستحضر')) return LiquidType.cosmetics;
    return LiquidType.generic;
  }

  void _onCustomVolumeChanged(double newVol) {
    setState(() {
      _customVolumeCtrl.text = newVol == newVol.roundToDouble()
          ? newVol.toInt().toString()
          : newVol.toString();

      final pPerMl = _config.defaultPricePerMl > 0
          ? _config.defaultPricePerMl
          : (_config.costPerMl * 1.5);
      final bottleCost = _includeEmptyBottle
          ? (double.tryParse(_customBottleCostCtrl.text.trim()) ?? _config.defaultEmptyBottleCost)
          : 0.0;
      final calculatedPrice = (newVol * pPerMl) + bottleCost;
      _customPriceCtrl.text = calculatedPrice.round().toString();
    });
  }

  Future<void> _confirmAndAddToCart() async {
    final vol = _currentVolume;
    final unitPrice = _currentUnitPrice;
    final totalCost = _totalCostPerUnit;
    final unitName = _config.unitName;

    if (vol <= 0 || unitPrice <= 0) {
      return;
    }

    // حماية من البيع بالخسارة: تنبيه المحاسب إذا كانت التكلفة تفوق سعر البيع
    if (_profitPerUnit < 0 && _config.costPerMl > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('⚠️ تنبيه: بيع بخسارة!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'سعر البيع النهائي (${unitPrice.toInt()} دج) أقل من التكلفة الحقيقية للقارورة (${totalCost.toInt()} دج).\n'
            'صافي الخسارة: ${_profitPerUnit.abs().toInt()} دج لكل قارورة.\n\n'
            'هل أنت متأكد من رغبتك في إتمام البيع؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة وإضافة للسلة'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final hasBottle = _isCustomVolume ? _includeEmptyBottle : (_selectedFormat?.bottleCost ?? 0) > 0;
    final formatName = _isCustomVolume
        ? 'تعبئة ${vol == vol.roundToDouble() ? vol.toInt() : vol} $unitName${hasBottle ? ' + قارورة' : ''}'
        : 'تقسيم ${_selectedFormat!.volumeMl == _selectedFormat!.volumeMl.roundToDouble() ? _selectedFormat!.volumeMl.toInt() : _selectedFormat!.volumeMl} $unitName';

    // مفتاح فريد لكل مقاس لمنع دمج المقاسات المختلفة بالسعر الخاطئ في السلة
    final String uniqueUnitLevel = 'liquid_${vol.toStringAsFixed(1)}ml';

    // Dispatch to BillingBloc
    context.read<BillingBloc>().add(
          AddProductToCartEvent(
            widget.product,
            quantity: _bottlesCount.toDouble(),
            unitLevel: uniqueUnitLevel,
            customUnitName: formatName,
            customPrice: unitPrice,
            customUnitCost: totalCost,
            customMultiplier: vol, // In ml, decrements directly from bulk stock
          ),
        );

    SoundService.playSaveSuccess();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final enabledFormats = _config.formats.where((f) => f.isEnabled).toList();
    final stockAvailable = widget.product.stock;
    final costPerMl = _config.costPerMl;
    final isStockLow = stockAvailable < (_currentVolume * _bottlesCount);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Product Info & Bulk Stock
            _buildDialogHeader(stockAvailable, costPerMl),
            const Divider(height: 24),

            // Body: Scrollable Formats & Custom Dispensing
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Predefined Bottle Format Cards (1-Click)
                    const Text(
                      '1. اختر مقاس القارورة الجاهزة:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF004D40),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...enabledFormats.map((fmt) => _buildFormatCard(fmt)),
                        _buildCustomModeButton(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Custom Dispensing Options (if selected)
                    if (_isCustomVolume) _buildCustomDispensingSection(),

                    // 3. Bottles Quantity Counter
                    const SizedBox(height: 12),
                    _buildQuantityCounter(),

                    // 4. Mathematical Breakdown & Profit Summary Card
                    const SizedBox(height: 16),
                    _buildProfitBreakdownCard(),

                    if (isStockLow) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تنبيه: الكمية المطلوبة (${_currentVolume * _bottlesCount} ${_config.unitName}) تتجاوز المخزون المتوفر ($stockAvailable ${_config.unitName})',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions: Cancel & Confirm Button
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(double stockAvailable, double costPerMl) {
    return Row(
      children: [
        LiquidBottleIndicator(
          fillRatio: _config.fillRatio(stockAvailable),
          stockMl: stockAvailable,
          unitName: _config.unitName,
          liquidType: _liquidType,
          animate: true,
          size: 78.0,
          showLabel: false,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF004D40),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      'المخزون المتوفر: ${stockAvailable.toStringAsFixed(1)} ${_config.unitName}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stockAvailable > 0 ? Colors.teal.shade900 : Colors.red,
                      ),
                    ),
                  ),
                  Text(
                    'تكلفة المليلتر: ${costPerMl > 0 ? costPerMl.toStringAsFixed(1) : "0.0"} دج',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (costPerMl == 0.0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    '⚠️ التكلفة غير محددة — الأرباح المعروضة تقديرية',
                    style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildFormatCard(LiquidBottleFormat fmt) {
    final isSelected = !_isCustomVolume && _selectedFormat == fmt;
    final totalCost = fmt.totalCost(_config.costPerMl);
    final profit = fmt.profit(_config.costPerMl);

    return InkWell(
      onTap: () {
        setState(() {
          _isCustomVolume = false;
          _selectedFormat = fmt;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 135,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${fmt.volumeMl.toInt()} ${_config.unitName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isSelected ? Colors.teal.shade900 : Colors.black87,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: Colors.teal),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${fmt.sellingPrice.toInt()} دج',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.teal.shade800 : Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'تكلفة: ${totalCost.toInt()} دج',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            Text(
              '+${profit.toInt()} دج ربح',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomModeButton() {
    final isSelected = _isCustomVolume;

    return InkWell(
      onTap: () {
        setState(() {
          _isCustomVolume = true;
          _selectedFormat = null;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 135,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
            width: isSelected ? 2.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '➕ حجم مخصص',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 16, color: Colors.teal),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'تعبئة بالطلب',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              'حسب رغبة الزبون',
              style: TextStyle(fontSize: 10, color: Colors.teal.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDispensingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تحديد الحجم وسعر البيع بالطلب:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _customVolumeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الحجم المطلوب (${_config.unitName}) *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final v = double.tryParse(val) ?? 0.0;
                    _onCustomVolumeChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _customPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع النهائي (دج) *',
                    suffixText: 'دج',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick volume adjustment chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 50.0, 100.0].map((v) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text('${v.toInt()} ${_config.unitName}'),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.teal.shade200),
                    onPressed: () => _onCustomVolumeChanged(v),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Empty bottle toggle & cost
          Row(
            children: [
              Checkbox(
                value: _includeEmptyBottle,
                activeColor: Colors.teal,
                onChanged: (val) {
                  setState(() {
                    _includeEmptyBottle = val ?? true;
                    _onCustomVolumeChanged(_currentVolume);
                  });
                },
              ),
              Expanded(
                child: Text(
                  'إضافة قارورة فارغة من المحل (+${_config.defaultEmptyBottleCost.toInt()} دج)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_includeEmptyBottle)
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _customBottleCostCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر القارورة',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCounter() {
    return Row(
      children: [
        const Text(
          'عدد القوارير المطلوبة:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.teal),
          onPressed: _bottlesCount > 1
              ? () => setState(() => _bottlesCount--)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Text(
            '$_bottlesCount',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
          onPressed: (_currentVolume * (_bottlesCount + 1)) <= widget.product.stock
              ? () => setState(() => _bottlesCount++)
              : null,
        ),
      ],
    );
  }

  Widget _buildProfitBreakdownCard() {
    final totalVol = _currentVolume * _bottlesCount;
    final totalSelling = _currentUnitPrice * _bottlesCount;
    final totalLiquidCost = _liquidCostPerUnit * _bottlesCount;
    final totalBottleCost = _currentBottleCost * _bottlesCount;
    final totalCost = _totalCostPerUnit * _bottlesCount;
    final totalProfit = _profitPerUnit * _bottlesCount;
    final isProfitable = totalProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الكمية المقتطعة من المخزون: $totalVol ${_config.unitName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isProfitable ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_marginPercent.toStringAsFixed(0)}% هامش ربح',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isProfitable ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'سائل: ${totalLiquidCost.toStringAsFixed(0)} دج',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
              const Text(' + ', style: TextStyle(fontSize: 11)),
              Text(
                'قوارير: ${totalBottleCost.toStringAsFixed(0)} دج',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Text(
                'التكلفة الإجمالية: ${totalCost.toStringAsFixed(0)} دج',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صافي الربح: ${totalProfit >= 0 ? "+" : ""}${totalProfit.toStringAsFixed(0)} دج',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              Text(
                'المجموع للزبون: ${totalSelling.toStringAsFixed(0)} دج',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF004D40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final totalSelling = _currentUnitPrice * _bottlesCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(
            'تأكيد وإضافة للسلة 🛍️ (${totalSelling.toStringAsFixed(0)} دج)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: (widget.product.stock <= 0 || _currentUnitPrice <= 0)
              ? null
              : _confirmAndAddToCart,
        ),
      ],
    );
  }
}
