import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_option.dart';

class ProductOptionsResult {
  final List<SelectedProductOption> selectedOptions;
  final String? itemNote;

  const ProductOptionsResult({
    required this.selectedOptions,
    this.itemNote,
  });
}

class ProductOptionsModal {
  static Future<ProductOptionsResult?> show(
    BuildContext context, {
    required Product product,
    double quantity = 1.0,
    double basePrice = 0.0,
  }) async {
    SoundService.playTabSwitch();
    final groups = product.optionGroups;
    if (groups.isEmpty) {
      return const ProductOptionsResult(selectedOptions: []);
    }

    final double effectiveBasePrice = basePrice > 0 ? basePrice : product.price;

    return await showDialog<ProductOptionsResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return _ProductOptionsDialog(
          product: product,
          groups: groups,
          quantity: quantity,
          basePrice: effectiveBasePrice,
        );
      },
    );
  }
}

class _ProductOptionsDialog extends StatefulWidget {
  final Product product;
  final List<ProductOptionGroup> groups;
  final double quantity;
  final double basePrice;

  const _ProductOptionsDialog({
    required this.product,
    required this.groups,
    required this.quantity,
    required this.basePrice,
  });

  @override
  State<_ProductOptionsDialog> createState() => _ProductOptionsDialogState();
}

class _ProductOptionsDialogState extends State<_ProductOptionsDialog> {
  late final Map<String, Set<String>> _selectedChoiceIds;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedChoiceIds = {};
    for (final group in widget.groups) {
      _selectedChoiceIds[group.id] = <String>{};
      // Pre-select default if available, or first if required and not multi-select
      final defaultChoice = group.choices.where((c) => c.isDefault).firstOrNull;
      if (defaultChoice != null) {
        _selectedChoiceIds[group.id]!.add(defaultChoice.id);
      } else if (group.isRequired && !group.isMultiSelect && group.choices.isNotEmpty) {
        _selectedChoiceIds[group.id]!.add(group.choices.first.id);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _optionsDelta {
    double delta = 0.0;
    for (final group in widget.groups) {
      final selectedIds = _selectedChoiceIds[group.id] ?? {};
      for (final choice in group.choices) {
        if (selectedIds.contains(choice.id)) {
          delta += choice.priceDelta;
        }
      }
    }
    return delta;
  }

  double get _unitPrice => widget.basePrice + _optionsDelta;
  double get _totalPrice => _unitPrice * widget.quantity;

  bool get _isValid {
    for (final group in widget.groups) {
      if (group.isRequired) {
        final selected = _selectedChoiceIds[group.id] ?? {};
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  List<SelectedProductOption> _buildSelectedList() {
    final List<SelectedProductOption> result = [];
    for (final group in widget.groups) {
      final selectedIds = _selectedChoiceIds[group.id] ?? {};
      for (final choice in group.choices) {
        if (selectedIds.contains(choice.id)) {
          result.add(SelectedProductOption(
            groupId: group.id,
            groupName: group.name,
            choiceId: choice.id,
            choiceName: choice.name,
            priceDelta: choice.priceDelta,
          ));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.teal, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'تخصيص الخيارات والإضافات (${widget.basePrice.toStringAsFixed(2)} DA)',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Options Groups List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    ...widget.groups.map((group) => _buildGroupSection(group)),
                    const SizedBox(height: 8),

                    // Preparation / Kitchen Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: Colors.blueGrey.shade700),
                              const SizedBox(width: 6),
                              const Text(
                                'ملاحظة خاصة بالبند (للمطبخ / التحضير):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'مثال: بدون سكر، ساخن جداً، زيادة صوص...',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer: Price preview & Confirm
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'السعر الإجمالي: ${_totalPrice.toStringAsFixed(2)} DA',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.teal),
                      ),
                      if (_optionsDelta > 0)
                        Text(
                          'إضافات: +${(_optionsDelta * widget.quantity).toStringAsFixed(2)} DA',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isValid ? Colors.teal : Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                        label: const Text(
                          'تأكيد وإضافة للسلة',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isValid
                            ? () {
                                SoundService.playScanBeep();
                                final note = _noteController.text.trim();
                                Navigator.pop(
                                  context,
                                  ProductOptionsResult(
                                    selectedOptions: _buildSelectedList(),
                                    itemNote: note.isNotEmpty ? note : null,
                                  ),
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSection(ProductOptionGroup group) {
    final selectedSet = _selectedChoiceIds[group.id] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: group.isRequired && selectedSet.isEmpty ? Colors.amber.shade400 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text('إجباري', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              if (group.isMultiSelect)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('(اختيار متعدد)', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.choices.map((choice) {
              final isChosen = selectedSet.contains(choice.id);
              final priceText = choice.priceDelta > 0
                  ? '+${choice.priceDelta.toStringAsFixed(0)} DA'
                  : (choice.priceDelta < 0 ? '${choice.priceDelta.toStringAsFixed(0)} DA' : 'مجاني');

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    if (group.isMultiSelect) {
                      if (isChosen) {
                        selectedSet.remove(choice.id);
                      } else {
                        selectedSet.add(choice.id);
                      }
                    } else {
                      selectedSet.clear();
                      selectedSet.add(choice.id);
                    }
                  });
                  SoundService.playTabSwitch();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChosen ? Colors.teal.shade700 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChosen ? Colors.teal.shade700 : Colors.grey.shade300,
                      width: isChosen ? 1.5 : 1.0,
                    ),
                    boxShadow: isChosen
                        ? [BoxShadow(color: Colors.teal.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        group.isMultiSelect
                            ? (isChosen ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                            : (isChosen ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        size: 16,
                        color: isChosen ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        choice.name,
                        style: TextStyle(
                          color: isChosen ? Colors.white : Colors.black87,
                          fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isChosen ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priceText,
                          style: TextStyle(
                            color: isChosen ? Colors.white : (choice.priceDelta > 0 ? Colors.green.shade700 : Colors.grey.shade600),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
