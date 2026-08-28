import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/data/hive_database.dart';
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

  List<String> _categories = [];

  static const List<String> _defaultCategories = [
    'سلعة عامة',
    'حلويات وسكاكر 🍬',
    'مخبوزات 🥖',
    'أجبان وتجزئة 🧀',
    'خضر وفواكه 🍎',
    'توابل وبقوليات 🌾',
    'ساندويتش ومأكولات 🥪',
    'مشروبات ومرطبات 🥤',
  ];

  final List<double> _quickPresets = [5, 10, 15, 20, 50, 100, 150, 200, 300, 500];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final box = HiveDatabase.settingsBox;
    final saved = box.get('custom_quick_categories');
    if (saved is List) {
      setState(() {
        _categories = List<String>.from(saved);
      });
    } else {
      setState(() {
        _categories = List<String>.from(_defaultCategories);
      });
    }
  }

  Future<void> _saveCategories() async {
    final box = HiveDatabase.settingsBox;
    await box.put('custom_quick_categories', _categories);
  }

  void _showAddCategoryDialog({String? catToEdit, int? index}) {
    final ctrl = TextEditingController(text: catToEdit ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          catToEdit == null ? '➕ إضافة تصنيف جديد' : '✏️ تعديل التصنيف',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'اسم التصنيف (مثال: أواني ومنظفات 🧼)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (catToEdit != null && index != null && index > 0)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                setState(() {
                  _categories.removeAt(index);
                  if (_selectedCategory == catToEdit) {
                    _selectedCategory = _categories.first;
                  }
                });
                await _saveCategories();
                Navigator.pop(ctx);
              },
              child: const Text('حذف'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () async {
              final newCat = ctrl.text.trim();
              if (newCat.isEmpty) return;

              setState(() {
                if (index != null) {
                  _categories[index] = newCat;
                } else {
                  _categories.add(newCat);
                }
                _selectedCategory = newCat;
              });
              await _saveCategories();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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

    final cost = (amount * 0.8).roundToDouble(); // estimate 20% margin for free price if cost unspecified

    context.read<BillingBloc>().add(AddCustomItemEvent(
      name: '$_selectedCategory (${amount.toStringAsFixed(0)} دج)',
      price: amount,
      costPrice: cost,
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

          // Category Chips with + Add Category button
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: Colors.purple),
                  label: const Text('إضافة تصنيف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                  onPressed: () => _showAddCategoryDialog(),
                ),
                const SizedBox(width: 6),
                ...List.generate(_categories.length, (index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onLongPress: () => _showAddCategoryDialog(catToEdit: cat, index: index),
                      child: ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: Colors.purple,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = cat);
                        },
                      ),
                    ),
                  );
                }),
              ],
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