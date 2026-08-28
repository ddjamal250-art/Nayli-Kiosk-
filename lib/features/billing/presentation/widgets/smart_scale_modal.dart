import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final _weightController = TextEditingController(text: '500'); // grams
  final _amountController = TextEditingController();
  
  bool _isByWeight = true; // true = by weight, false = by fixed amount (e.g. 100 DZD)

  final List<Map<String, dynamic>> _quickPresets = [
    {'name': 'عدس', 'pricePerKg': 260.0},
    {'name': 'حمص', 'pricePerKg': 280.0},
    {'name': 'لوبيا بيضاء', 'pricePerKg': 340.0},
    {'name': 'فريك شوربة', 'pricePerKg': 450.0},
    {'name': 'حلوة الترك بالميزان', 'pricePerKg': 600.0},
    {'name': 'زيتون أخضر مقطع', 'pricePerKg': 350.0},
    {'name': 'كاشير بالميزان', 'pricePerKg': 400.0},
    {'name': 'جبن أحمر / كودة', 'pricePerKg': 1200.0},
  ];

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

            // Quick Preset Chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickPresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final preset = _quickPresets[index];
                  final isSelected = _nameController.text == preset['name'];
                  return ChoiceChip(
                    label: Text('${preset['name']}', style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryColor,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _nameController.text = preset['name'];
                          _pricePerKgController.text = (preset['pricePerKg'] as double).toStringAsFixed(0);
                        });
                      }
                    },
                  );
                },
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

                final name = _nameController.text.trim();
                final grams = _calculatedGrams.toStringAsFixed(0);
                final displayName = '$name ($grams غ)';

                context.read<BillingBloc>().add(AddCustomItemEvent(
                  name: displayName,
                  price: total,
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