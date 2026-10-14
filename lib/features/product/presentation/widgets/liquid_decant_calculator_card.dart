import 'package:flutter/material.dart';
import '../../domain/entities/liquid_decant_config.dart';

class LiquidDecantCalculatorCard extends StatefulWidget {
  final LiquidDecantConfig initialConfig;
  final ValueChanged<LiquidDecantConfig> onChanged;

  const LiquidDecantCalculatorCard({
    super.key,
    required this.initialConfig,
    required this.onChanged,
  });

  @override
  State<LiquidDecantCalculatorCard> createState() => _LiquidDecantCalculatorCardState();
}

class _LiquidDecantCalculatorCardState extends State<LiquidDecantCalculatorCard> {
  late LiquidDecantConfig _config;

  late TextEditingController _containerVolumeCtrl;
  late TextEditingController _containerCostCtrl;
  late TextEditingController _spillagePercentCtrl;
  late TextEditingController _defaultBottleCostCtrl;
  late TextEditingController _defaultPricePerMlCtrl;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;

    _containerVolumeCtrl = TextEditingController(
      text: _formatNum(_config.containerVolume),
    );
    _containerCostCtrl = TextEditingController(
      text: _formatNum(_config.containerCost),
    );
    _spillagePercentCtrl = TextEditingController(
      text: _formatNum(_config.spillageLossPercent),
    );
    _defaultBottleCostCtrl = TextEditingController(
      text: _formatNum(_config.defaultEmptyBottleCost),
    );
    _defaultPricePerMlCtrl = TextEditingController(
      text: _formatNum(_config.defaultPricePerMl),
    );
  }

  @override
  void dispose() {
    _containerVolumeCtrl.dispose();
    _containerCostCtrl.dispose();
    _spillagePercentCtrl.dispose();
    _defaultBottleCostCtrl.dispose();
    _defaultPricePerMlCtrl.dispose();
    super.dispose();
  }

  String _formatNum(double val) {
    if (val == 0) return '';
    return val == val.roundToDouble() ? val.toInt().toString() : val.toString();
  }

  void _notify() {
    widget.onChanged(_config);
    setState(() {});
  }

  void _applyPreset(String presetType) {
    LiquidDecantConfig newConfig;
    switch (presetType) {
      case 'original_perfume':
        // عطور أصلية فاخرة (تقسيم عطور نيش أو أصلية 100 مل)
        newConfig = LiquidDecantConfig(
          containerVolume: 100,
          containerCost: 15000,
          unitName: 'مل',
          spillageLossPercent: 2.0,
          defaultEmptyBottleCost: 150,
          defaultPricePerMl: 220,
          formats: [
            LiquidBottleFormat(volumeMl: 5, bottleCost: 100, sellingPrice: 1200),
            LiquidBottleFormat(volumeMl: 10, bottleCost: 120, sellingPrice: 2300),
            LiquidBottleFormat(volumeMl: 20, bottleCost: 150, sellingPrice: 4400),
            LiquidBottleFormat(volumeMl: 30, bottleCost: 180, sellingPrice: 6500),
            LiquidBottleFormat(volumeMl: 50, bottleCost: 250, sellingPrice: 10500),
          ],
        );
        break;

      case 'oil_perfume':
        // عطور زيتية ومركزة (عبوة 500 مل)
        newConfig = LiquidDecantConfig(
          containerVolume: 500,
          containerCost: 12000,
          unitName: 'مل',
          spillageLossPercent: 1.0,
          defaultEmptyBottleCost: 80,
          defaultPricePerMl: 40,
          formats: [
            LiquidBottleFormat(volumeMl: 3, bottleCost: 50, sellingPrice: 180),
            LiquidBottleFormat(volumeMl: 6, bottleCost: 60, sellingPrice: 320),
            LiquidBottleFormat(volumeMl: 12, bottleCost: 80, sellingPrice: 600),
            LiquidBottleFormat(volumeMl: 30, bottleCost: 120, sellingPrice: 1400),
            LiquidBottleFormat(volumeMl: 50, bottleCost: 160, sellingPrice: 2200),
          ],
        );
        break;

      case 'cosmetics_hair':
        // كيراتين / بروتين / شامبو وبلسم (عبوة 1000 مل)
        newConfig = LiquidDecantConfig(
          containerVolume: 1000,
          containerCost: 8000,
          unitName: 'مل',
          spillageLossPercent: 1.5,
          defaultEmptyBottleCost: 100,
          defaultPricePerMl: 15,
          formats: [
            LiquidBottleFormat(volumeMl: 50, bottleCost: 80, sellingPrice: 850),
            LiquidBottleFormat(volumeMl: 100, bottleCost: 100, sellingPrice: 1600),
            LiquidBottleFormat(volumeMl: 150, bottleCost: 120, sellingPrice: 2350),
            LiquidBottleFormat(volumeMl: 200, bottleCost: 140, sellingPrice: 3100),
            LiquidBottleFormat(volumeMl: 500, bottleCost: 200, sellingPrice: 7500),
          ],
        );
        break;

      default:
        newConfig = LiquidDecantConfig.defaultPerfumeConfig();
    }

    _config = newConfig;
    _containerVolumeCtrl.text = _formatNum(_config.containerVolume);
    _containerCostCtrl.text = _formatNum(_config.containerCost);
    _spillagePercentCtrl.text = _formatNum(_config.spillageLossPercent);
    _defaultBottleCostCtrl.text = _formatNum(_config.defaultEmptyBottleCost);
    _defaultPricePerMlCtrl.text = _formatNum(_config.defaultPricePerMl);
    _notify();
  }

  void _showAddFormatDialog() {
    final volCtrl = TextEditingController();
    final bottleCostCtrl = TextEditingController(
      text: _formatNum(_config.defaultEmptyBottleCost),
    );
    final sellPriceCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.teal),
            SizedBox(width: 8),
            Text('إضافة مقاس قارورة بيع جديد'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: volCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'حجم القارورة (${_config.unitName}) *',
                  hintText: 'مثال: 15 أو 25 أو 75',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bottleCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'تكلفة القارورة الفارغة + الرشاش (دج)',
                  hintText: 'مثال: 150',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sellPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'سعر البيع النهائي للزبون (دج) *',
                  hintText: 'مثال: 3500',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'باركود القارورة (اختياري للبيع المباشر)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final vol = double.tryParse(volCtrl.text.trim()) ?? 0.0;
              final bCost = double.tryParse(bottleCostCtrl.text.trim()) ?? _config.defaultEmptyBottleCost;
              final sPrice = double.tryParse(sellPriceCtrl.text.trim()) ?? 0.0;
              final bCode = barcodeCtrl.text.trim();

              if (vol > 0 && sPrice > 0) {
                final newFormats = List<LiquidBottleFormat>.from(_config.formats)
                  ..add(LiquidBottleFormat(
                    id: 'fmt_${vol.toInt()}ml_${DateTime.now().millisecondsSinceEpoch}',
                    name: 'قارورة ${vol == vol.roundToDouble() ? vol.toInt() : vol} ${_config.unitName}',
                    volumeMl: vol,
                    bottleCost: bCost,
                    sellingPrice: sPrice,
                    barcode: bCode.isNotEmpty ? bCode : null,
                  ));
                newFormats.sort((a, b) => a.volumeMl.compareTo(b.volumeMl));
                _config = _config.copyWith(formats: newFormats);
                Navigator.pop(ctx);
                _notify();
              }
            },
            child: const Text('إضافة المقاس'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costPerMl = _config.costPerMl;
    final effectiveSellableVolume = _config.effectiveSellableVolume;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🧴', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'نظام تقسيم وتعبئة السوائل والعطور ومستحضرات التجميل 🧴✨',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF004D40),
                      ),
                    ),
                    Text(
                      'حساب دقيق لتكلفة المليلتر، قوارير التعبئة، نسب الهدر، وهوامش الربح الرياضية لكل مقاس',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00695C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFB2DFDB)),

          // 1. Presets Selector
          const Text(
            '1. نماذج وقوالب جاهزة سريعة:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('✨ عطور أصلية (تقسيم)', 'original_perfume'),
                const SizedBox(width: 8),
                _buildPresetChip('🌿 عطور زيتية ومركزة', 'oil_perfume'),
                const SizedBox(width: 8),
                _buildPresetChip('💆‍♀️ بروتين / كيراتين / شامبو', 'cosmetics_hair'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Base Container Specifications
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'العبوة الأصلية (الأم) وسعر الشراء:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF004D40),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Text(
                        'تكلفة المليلتر الصافي: ${costPerMl.toStringAsFixed(2)} دج / ${_config.unitName}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _containerVolumeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final v = double.tryParse(val) ?? 0.0;
                          _config = _config.copyWith(containerVolume: v);
                          _notify();
                        },
                        decoration: InputDecoration(
                          labelText: 'سعة العبوة الأم (${_config.unitName}) *',
                          hintText: '100, 250, 500, 1000...',
                          prefixIcon: const Icon(Icons.water_drop_outlined, color: Colors.teal),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _containerCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final c = double.tryParse(val) ?? 0.0;
                          _config = _config.copyWith(containerCost: c);
                          _notify();
                        },
                        decoration: const InputDecoration(
                          labelText: 'تكلفة شراء العبوة الأم (دج) *',
                          hintText: 'مثال: 12000',
                          prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.teal),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _spillagePercentCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final s = double.tryParse(val) ?? 0.0;
                          _config = _config.copyWith(spillageLossPercent: s);
                          _notify();
                        },
                        decoration: const InputDecoration(
                          labelText: 'الهدر والفاقد (%)',
                          hintText: '0 أو 2',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_config.spillageLossPercent > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ملاحظة: مع احتساب فاقد ${_config.spillageLossPercent}%، الحجم الفعلي القابل للبيع هو ${effectiveSellableVolume.toStringAsFixed(1)} ${_config.unitName}',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Packaging & Dispensing Defaults
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _defaultBottleCostCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final b = double.tryParse(val) ?? 0.0;
                      _config = _config.copyWith(defaultEmptyBottleCost: b);
                      _notify();
                    },
                    decoration: InputDecoration(
                      labelText: 'تكلفة القارورة الفارغة الافتراضية (دج)',
                      hintText: '150',
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _defaultPricePerMlCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final p = double.tryParse(val) ?? 0.0;
                      _config = _config.copyWith(defaultPricePerMl: p);
                      _notify();
                    },
                    decoration: InputDecoration(
                      labelText: 'سعر البيع بالمليلتر (دج/${_config.unitName})',
                      hintText: '200',
                      prefixIcon: const Icon(Icons.sell_outlined, color: Colors.teal),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Formats Table & Profit Margins
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '2. أحجام قوارير البيع وهوامش الربح الحقيقية:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF004D40),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة مقاس'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade800,
                  side: BorderSide(color: Colors.teal.shade400),
                ),
                onPressed: _showAddFormatDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Formats Cards
          if (_config.formats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'لم يتم تحديد مقاسات بعد، اضغط "إضافة مقاس" أو اختر قالباً جاهزاً أعلاه.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            )
          else
            ...List.generate(_config.formats.length, (index) {
              final fmt = _config.formats[index];
              return _buildFormatCard(fmt, index, costPerMl);
            }),

          const SizedBox(height: 16),

          // 5. Total Batch Yield & Simulation Preview
          _buildYieldSimulationCard(costPerMl, effectiveSellableVolume),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String presetType) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.teal.shade200),
      onPressed: () => _applyPreset(presetType),
    );
  }

  Widget _buildFormatCard(LiquidBottleFormat fmt, int index, double costPerMl) {
    final liquidCost = fmt.liquidCost(costPerMl);
    final totalCost = fmt.totalCost(costPerMl);
    final profit = fmt.profit(costPerMl);
    final margin = fmt.marginPercent(costPerMl);
    final isProfitable = profit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fmt.isEnabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fmt.isEnabled ? Colors.teal.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Checkbox / Toggle
              Checkbox(
                value: fmt.isEnabled,
                activeColor: Colors.teal,
                onChanged: (val) {
                  final updatedFormats = List<LiquidBottleFormat>.from(_config.formats);
                  updatedFormats[index] = fmt.copyWith(isEnabled: val ?? true);
                  _config = _config.copyWith(formats: updatedFormats);
                  _notify();
                },
              ),

              // Volume Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Text(
                  '${_formatNum(fmt.volumeMl)} ${_config.unitName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Costs Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'سائل: ${liquidCost.toStringAsFixed(1)} دج',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        const Text(' + ', style: TextStyle(fontSize: 11)),
                        Text(
                          'قارورة: ${_formatNum(fmt.bottleCost)} دج',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Text(
                      'التكلفة الكلية: ${totalCost.toStringAsFixed(1)} دج',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // Selling Price Field (Editable)
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _formatNum(fmt.sellingPrice),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع',
                    suffixText: 'دج',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final sp = double.tryParse(val) ?? 0.0;
                    final updatedFormats = List<LiquidBottleFormat>.from(_config.formats);
                    updatedFormats[index] = fmt.copyWith(sellingPrice: sp);
                    _config = _config.copyWith(formats: updatedFormats);
                    _notify();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Profit & Margin Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isProfitable ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isProfitable ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)} دج',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isProfitable ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    Text(
                      '${margin.toStringAsFixed(0)}% ربح',
                      style: TextStyle(
                        fontSize: 10,
                        color: isProfitable ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete Format Button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                onPressed: () {
                  final updatedFormats = List<LiquidBottleFormat>.from(_config.formats)
                    ..removeAt(index);
                  _config = _config.copyWith(formats: updatedFormats);
                  _notify();
                },
              ),
            ],
          ),
          if (fmt.barcode != null && fmt.barcode!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.qr_code_2, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'الباركود: ${fmt.barcode}',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYieldSimulationCard(double costPerMl, double effectiveVolume) {
    if (_config.formats.isEmpty || effectiveVolume <= 0) return const SizedBox.shrink();

    // Calculate sample yield if sold in middle format (e.g. 30ml or 50ml)
    final activeFormats = _config.formats.where((f) => f.isEnabled).toList();
    if (activeFormats.isEmpty) return const SizedBox.shrink();

    final sampleFmt = activeFormats.length > 2
        ? activeFormats[activeFormats.length ~/ 2]
        : activeFormats.first;

    final bottlesCount = (effectiveVolume / sampleFmt.volumeMl).floor();
    final totalRevenue = bottlesCount * sampleFmt.sellingPrice;
    final soldVolumeMl = bottlesCount * sampleFmt.volumeMl;
    final totalCost = (soldVolumeMl * costPerMl) + (bottlesCount * sampleFmt.bottleCost);
    final totalNetProfit = totalRevenue - totalCost;
    final overallMargin = totalRevenue > 0 ? (totalNetProfit / totalRevenue) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, const Color(0xFF004D40)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_graph, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'محاكاة العائد والأرباح الإجمالية للعبوة:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'على مقاس ${_formatNum(sampleFmt.volumeMl)} ${_config.unitName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildYieldStat('عدد القوارير', '$bottlesCount قارورة'),
              _buildYieldStat('رقم الأعمال المتوقع', '${totalRevenue.toStringAsFixed(0)} دج'),
              _buildYieldStat('صافي الربح الكلي', '${totalNetProfit.toStringAsFixed(0)} دج', isGold: true),
              _buildYieldStat('نسبة العائد', '${overallMargin.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYieldStat(String label, String value, {bool isGold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.teal.shade100, fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isGold ? Colors.amberAccent : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
