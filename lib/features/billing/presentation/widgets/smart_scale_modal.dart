import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/billing_bloc.dart';

class SmartScaleModal extends StatefulWidget {
  const SmartScaleModal({super.key});

  @override
  State<SmartScaleModal> createState() => _SmartScaleModalState();
}

class _SmartScaleModalState extends State<SmartScaleModal> {
  final _nameController = TextEditingController(text: 'عدس');
  final _pricePerKgController = TextEditingController(text: '260');
  final _costPerKgController = TextEditingController(text: '200');
  final _weightController = TextEditingController(text: '500'); // grams
  final _amountController = TextEditingController();
  
  bool _isByWeight = true; // true = by weight, false = by fixed amount (e.g. 100 DZD)

  List<Map<String, dynamic>> _quickPresets = [];

  static const List<Map<String, dynamic>> _defaultPresets = [
    {'name': 'عدس', 'pricePerKg': 260.0, 'costPerKg': 200.0},
    {'name': 'حمص', 'pricePerKg': 280.0, 'costPerKg': 220.0},
    {'name': 'لوبيا بيضاء', 'pricePerKg': 340.0, 'costPerKg': 280.0},
    {'name': 'فريك شوربة', 'pricePerKg': 450.0, 'costPerKg': 360.0},
    {'name': 'حلوة الترك بالميزان', 'pricePerKg': 600.0, 'costPerKg': 450.0},
    {'name': 'زيتون أخضر مقطع', 'pricePerKg': 350.0, 'costPerKg': 270.0},
    {'name': 'كاشير بالميزان', 'pricePerKg': 400.0, 'costPerKg': 300.0},
    {'name': 'جبن أحمر / كودة', 'pricePerKg': 1200.0, 'costPerKg': 950.0},
  ];

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  void _loadPresets() {
    final box = HiveDatabase.settingsBox;
    final saved = box.get('custom_scale_presets');
    if (saved is List) {
      setState(() {
        _quickPresets = saved.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } else {
      setState(() {
        _quickPresets = List.from(_defaultPresets);
      });
    }
  }

  Future<void> _savePresets() async {
    final box = HiveDatabase.settingsBox;
    await box.put('custom_scale_presets', _quickPresets);
  }

  void _showAddEditPresetDialog({Map<String, dynamic>? itemToEdit, int? index}) {
    final nameCtrl = TextEditingController(text: itemToEdit?['name'] ?? '');
    final priceCtrl = TextEditingController(text: itemToEdit != null ? (itemToEdit['pricePerKg'] as num).toString() : '');
    final costCtrl = TextEditingController(text: itemToEdit != null ? ((itemToEdit['costPerKg'] as num?)?.toString() ?? '') : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          itemToEdit == null ? '➕ إضافة سلعة ميزان جديدة' : '✏️ تعديل سلعة الميزان',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم السلعة (مثال: زيتون أسود)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر البيع للكيلو (دج)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر التكلفة للكيلو (اختياري)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          if (itemToEdit != null && index != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                setState(() {
                  _quickPresets.removeAt(index);
                });
                await _savePresets();
                Navigator.pop(ctx);
              },
              child: const Text('حذف السلعة'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final cost = double.tryParse(costCtrl.text.trim()) ?? (price * 0.8);
              if (name.isEmpty || price <= 0) return;

              final itemData = {'name': name, 'pricePerKg': price, 'costPerKg': cost};
              setState(() {
                if (index != null) {
                  _quickPresets[index] = itemData;
                } else {
                  _quickPresets.add(itemData);
                }
                _nameController.text = name;
                _pricePerKgController.text = price.toStringAsFixed(0);
                _costPerKgController.text = cost.toStringAsFixed(0);
              });
              await _savePresets();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  double get _calculatedTotal {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (_isByWeight) {
      final grams = double.tryParse(_weightController.text.trim()) ?? 0.0;
      return (pricePerKg * (grams / 1000.0)).roundToDouble();
    } else {
      return double.tryParse(_amountController.text.trim()) ?? 0.0;
    }
  }

  double get _calculatedGrams {
    final pricePerKg = double.tryParse(_pricePerKgController.text.trim()) ?? 0.0;
    if (pricePerKg <= 0) return 0.0;
    if (_isByWeight) {
      return double.tryParse(_weightController.text.trim()) ?? 0.0;
    } else {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      return ((amount / pricePerKg) * 1000.0).roundToDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.scale_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'حاسبة سلع الميزان والتجزئة (Vrac)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Quick Preset Chips + Add Button
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: Colors.teal),
                    label: const Text('إضافة سلعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                    onPressed: () => _showAddEditPresetDialog(),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(_quickPresets.length, (index) {
                    final preset = _quickPresets[index];
                    final isSelected = _nameController.text == preset['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onLongPress: () => _showAddEditPresetDialog(itemToEdit: preset, index: index),
                        child: ChoiceChip(
                          label: Text(
                            '${preset['name']} (${(preset['pricePerKg'] as num).toStringAsFixed(0)}دج)',
                            style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _nameController.text = preset['name'];
                                _pricePerKgController.text = (preset['pricePerKg'] as num).toStringAsFixed(0);
                                _costPerKgController.text = ((preset['costPerKg'] as num?) ?? (preset['pricePerKg'] as num) * 0.8).toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item Name & Price Per KG
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم السلعة',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _pricePerKgController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'سعر الكيلو (دج)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle Mode: Weight vs Amount
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isByWeight = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isByWeight ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '⚖️ البيع بالوزن (غرام)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isByWeight ? Colors.white : Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isByWeight = false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isByWeight ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '💵 البيع بالمبلغ (دج)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isByWeight ? Colors.white : Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_isByWeight) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'الوزن (غرام)',
                        hintText: 'مثال: 500 للرطل',
                        border: OutlineInputBorder(),
                        suffixText: 'غرام',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fast weight chips (100g, 250g, 500g, 1000g, 2000g)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [100, 250, 500, 1000, 2000].map((g) {
                  return ActionChip(
                    label: Text('${g >= 1000 ? '${g / 1000} كغ' : '$g غ'}', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _weightController.text = g.toString();
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المطلوب من الزبون (دج)',
                  hintText: 'مثال: 50 دج أو 100 دج',
                  border: OutlineInputBorder(),
                  suffixText: 'دج',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Fast amount chips (50, 100, 150, 200, 500 DA)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [50, 100, 150, 200, 500].map((da) {
                  return ActionChip(
                    label: Text('$da دج', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setState(() {
                        _amountController.text = da.toString();
                      });
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // Summary Calculation Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الوزن المقدر: ${_calculatedGrams.toStringAsFixed(0)} غرام',
                        style: TextStyle(fontSize: 12, color: Colors.teal[900]),
                      ),
                      Text(
                        '(${(_calculatedGrams / 1000).toStringAsFixed(2)} كغ)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '${_calculatedTotal.toStringAsFixed(2)} دج',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal[800]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final total = _calculatedTotal;
                if (total <= 0) return;

                final costPerKg = double.tryParse(_costPerKgController.text.trim()) ?? (double.tryParse(_pricePerKgController.text.trim()) ?? 0.0) * 0.8;
                final totalCost = (costPerKg * (_calculatedGrams / 1000.0)).roundToDouble();

                context.read<BillingBloc>().add(AddCustomItemEvent(
                  name: displayName,
                  price: total,
                  costPrice: totalCost,
                  barcode: 'SCALE_${DateTime.now().millisecondsSinceEpoch}',
                ));

                Navigator.pop(context);
              },
              child: const Text(
                'إضافة للفاتورة الآن',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}