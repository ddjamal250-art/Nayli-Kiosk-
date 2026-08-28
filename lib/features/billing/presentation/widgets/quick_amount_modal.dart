import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/billing_bloc.dart';

class QuickAmountModal extends StatefulWidget {
  const QuickAmountModal({super.key});

  @override
  State<QuickAmountModal> createState() => _QuickAmountModalState();
}

class _QuickAmountModalState extends State<QuickAmountModal> {
  String _amountStr = '';
  String _selectedCategory = 'سلعة عامة';

  final List<String> _categories = [
    'سلعة عامة',
    'حلويات وسكاكر 🍬',
    'مخبوزات 🥖',
    'أجبان وتجزئة 🧀',
    'خضر وفواكه 🍎',
    'توابل وبقوليات 🌾',
  ];

  final List<double> _quickPresets = [5, 10, 15, 20, 50, 100, 150, 200, 300, 500];

  void _onKeyPress(String key) {
    if (key == 'C') {
      setState(() => _amountStr = '');
    } else if (key == 'DEL') {
      if (_amountStr.isNotEmpty) {
        setState(() => _amountStr = _amountStr.substring(0, _amountStr.length - 1));
      }
    } else {
      if (_amountStr.length < 6) {
        setState(() => _amountStr += key);
      }
    }
  }

  void _submit() {
    final amount = double.tryParse(_amountStr) ?? 0.0;
    if (amount <= 0) return;

    context.read<BillingBloc>().add(AddCustomItemEvent(
      name: '$_selectedCategory (${amount.toStringAsFixed(0)} دج)',
      price: amount,
      barcode: 'DIRECT_${DateTime.now().millisecondsSinceEpoch}',
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentAmount = double.tryParse(_amountStr) ?? 0.0;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calculate_rounded, color: Colors.purple, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text('إضافة مبلغ مباشر / سعر حر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),

          // Category Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.purple,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Display Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600),
                ),
                Text(
                  _amountStr.isEmpty ? '0.00 دج' : '$_amountStr دج',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Presets Grid
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _quickPresets.map((val) {
              return ActionChip(
                label: Text('${val.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.purple[50],
                side: BorderSide(color: Colors.purple[100]!),
                onPressed: () {
                  setState(() => _amountStr = val.toStringAsFixed(0));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Numeric Numpad
          Column(
            children: [
              _buildNumpadRow(['1', '2', '3']),
              const SizedBox(height: 6),
              _buildNumpadRow(['4', '5', '6']),
              const SizedBox(height: 6),
              _buildNumpadRow(['7', '8', '9']),
              const SizedBox(height: 6),
              _buildNumpadRow(['C', '0', 'DEL']),
            ],
          ),
          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: currentAmount > 0 ? _submit : null,
            child: Text(
              'إضافة للفاتورة (${currentAmount.toStringAsFixed(0)} دج)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final isAction = key == 'C' || key == 'DEL';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => _onKeyPress(key),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isAction ? Colors.grey[200] : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                alignment: Alignment.center,
                child: isAction && key == 'DEL'
                    ? const Icon(Icons.backspace_outlined, size: 18, color: Colors.red)
                    : Text(
                        key,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isAction ? (key == 'C' ? Colors.red : Colors.black87) : Colors.black87,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}