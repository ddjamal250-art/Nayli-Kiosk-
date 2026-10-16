import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/sound_service.dart';
import '../../domain/entities/product_option.dart';

class ProductOptionsConfigModal extends StatefulWidget {
  final String? initialOptionsJson;

  const ProductOptionsConfigModal({
    super.key,
    this.initialOptionsJson,
  });

  static Future<String?> show(BuildContext context, {String? initialOptionsJson}) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductOptionsConfigModal(initialOptionsJson: initialOptionsJson),
    );
  }

  @override
  State<ProductOptionsConfigModal> createState() => _ProductOptionsConfigModalState();
}

class _OptionChoiceItem {
  String id;
  TextEditingController nameCtrl;
  TextEditingController priceDeltaCtrl;

  _OptionChoiceItem({
    required this.id,
    required String name,
    required double priceDelta,
  })  : nameCtrl = TextEditingController(text: name),
        priceDeltaCtrl = TextEditingController(
          text: priceDelta == 0.0 ? '0' : (priceDelta == priceDelta.toInt() ? priceDelta.toInt().toString() : priceDelta.toStringAsFixed(2)),
        );

  void dispose() {
    nameCtrl.dispose();
    priceDeltaCtrl.dispose();
  }
}

class _OptionGroupItem {
  String id;
  TextEditingController nameCtrl;
  bool isRequired;
  bool isMultiSelect;
  List<_OptionChoiceItem> choices;

  _OptionGroupItem({
    required this.id,
    required String name,
    this.isRequired = false,
    this.isMultiSelect = false,
    List<_OptionChoiceItem>? choices,
  })  : nameCtrl = TextEditingController(text: name),
        choices = choices ?? [];

  void dispose() {
    nameCtrl.dispose();
    for (var c in choices) {
      c.dispose();
    }
  }
}

class _ProductOptionsConfigModalState extends State<ProductOptionsConfigModal> {
  final List<_OptionGroupItem> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  void _loadInitial() {
    final parsed = ProductOptionGroup.parseJsonList(widget.initialOptionsJson);
    for (final g in parsed) {
      _groups.add(
        _OptionGroupItem(
          id: g.id.isNotEmpty ? g.id : const Uuid().v4(),
          name: g.name,
          isRequired: g.isRequired,
          isMultiSelect: g.isMultiSelect,
          choices: g.choices
              .map(
                (c) => _OptionChoiceItem(
                  id: c.id.isNotEmpty ? c.id : const Uuid().v4(),
                  name: c.name,
                  priceDelta: c.priceDelta,
                ),
              )
              .toList(),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _addNewGroup({String name = '', bool isRequired = false, bool isMultiSelect = false, List<Map<String, dynamic>>? initialChoices}) {
    final group = _OptionGroupItem(
      id: const Uuid().v4(),
      name: name,
      isRequired: isRequired,
      isMultiSelect: isMultiSelect,
      choices: (initialChoices ?? [
        {'name': 'خيار 1', 'priceDelta': 0.0},
        {'name': 'خيار 2', 'priceDelta': 50.0},
      ]).map((c) => _OptionChoiceItem(
        id: const Uuid().v4(),
        name: c['name'] as String,
        priceDelta: (c['priceDelta'] as num).toDouble(),
      )).toList(),
    );

    setState(() {
      _groups.add(group);
    });
    SoundService.playTabSwitch();
  }

  void _addChoiceToGroup(_OptionGroupItem group) {
    setState(() {
      group.choices.add(
        _OptionChoiceItem(
          id: const Uuid().v4(),
          name: 'خيار جديد',
          priceDelta: 0.0,
        ),
      );
    });
    SoundService.playTabSwitch();
  }

  void _removeChoice(_OptionGroupItem group, int index) {
    setState(() {
      final item = group.choices.removeAt(index);
      item.dispose();
    });
  }

  void _removeGroup(int index) {
    setState(() {
      final g = _groups.removeAt(index);
      g.dispose();
    });
    SoundService.playDeleteSound();
  }

  void _applyTemplate(String type) {
    if (type == 'sizes') {
      _addNewGroup(
        name: 'الحجم',
        isRequired: true,
        isMultiSelect: false,
        initialChoices: [
          {'name': 'صغير (Petit)', 'priceDelta': 0.0},
          {'name': 'متوسط (Moyen)', 'priceDelta': 50.0},
          {'name': 'كبير (Grand)', 'priceDelta': 100.0},
        ],
      );
    } else if (type == 'sugar') {
      _addNewGroup(
        name: 'درجة السكر',
        isRequired: false,
        isMultiSelect: false,
        initialChoices: [
          {'name': 'سكر عادي', 'priceDelta': 0.0},
          {'name': 'سكر زيادة', 'priceDelta': 0.0},
          {'name': 'بدون سكر (Sams)', 'priceDelta': 0.0},
        ],
      );
    } else if (type == 'addons') {
      _addNewGroup(
        name: 'إضافات مميزة',
        isRequired: false,
        isMultiSelect: true,
        initialChoices: [
          {'name': 'حليب لوز', 'priceDelta': 50.0},
          {'name': 'سيروب كراميل', 'priceDelta': 40.0},
          {'name': 'شوكولاتة إضافية', 'priceDelta': 50.0},
          {'name': 'كريمة مخفوقة Chantilly', 'priceDelta': 60.0},
        ],
      );
    } else if (type == 'food') {
      _addNewGroup(
        name: 'إضافات الوجبة',
        isRequired: false,
        isMultiSelect: true,
        initialChoices: [
          {'name': 'جبن شيدر إضافي', 'priceDelta': 60.0},
          {'name': 'بطاطا مقلية Frites', 'priceDelta': 100.0},
          {'name': 'صوص جزائري حار', 'priceDelta': 20.0},
        ],
      );
    }
  }

  void _saveAndClose() {
    final validGroups = <ProductOptionGroup>[];

    for (final g in _groups) {
      final gName = g.nameCtrl.text.trim();
      if (gName.isEmpty) continue;

      final validChoices = <ProductOptionChoice>[];
      for (final c in g.choices) {
        final cName = c.nameCtrl.text.trim();
        if (cName.isEmpty) continue;
        final delta = double.tryParse(c.priceDeltaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
        validChoices.add(ProductOptionChoice(
          id: c.id,
          name: cName,
          priceDelta: delta,
        ));
      }

      if (validChoices.isNotEmpty) {
        validGroups.add(ProductOptionGroup(
          id: g.id,
          name: gName,
          isRequired: g.isRequired,
          isMultiSelect: g.isMultiSelect,
          choices: validChoices,
        ));
      }
    }

    if (validGroups.isEmpty) {
      Navigator.pop(context, null);
    } else {
      final jsonStr = jsonEncode(validGroups.map((g) => g.toMap()).toList());
      SoundService.playSaveSuccess();
      Navigator.pop(context, jsonStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعداد خيارات وتعديلات المنتج (Options & Modifiers)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'قم بتعريف الأحجام، الإضافات، أو الخيارات التي يسأل عنها الكاشير عند بيع المنتج',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'إغلاق',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Template Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Text('قوالب جاهزة سريعة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTemplateChip('☕ أحجام المشروبات', () => _applyTemplate('sizes')),
                          const SizedBox(width: 6),
                          _buildTemplateChip('🧂 خيارات السكر', () => _applyTemplate('sugar')),
                          const SizedBox(width: 6),
                          _buildTemplateChip('🥛 إضافات ونكهات', () => _applyTemplate('addons')),
                          const SizedBox(width: 6),
                          _buildTemplateChip('🍔 إضافات الوجبات', () => _applyTemplate('food')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Group List or Empty State
            Expanded(
              child: _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ballot_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد خيارات أو إضافات معرّفة لهذا المنتج بعد',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يمكنك استخدام أحد القوالب الجاهزة أعلاه أو النقر على زر "إضافة مجموعة" أدناه',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('إضافة أول مجموعة خيارات'),
                            onPressed: () => _addNewGroup(name: 'الحجم'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, gIdx) {
                        final group = _groups[gIdx];
                        return _buildGroupCard(group, gIdx);
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions Bar
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('إضافة مجموعة أخرى'),
                  onPressed: () => _addNewGroup(),
                ),
                const Spacer(),
                if (_groups.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('مسح جميع الخيارات'),
                    onPressed: () {
                      setState(() {
                        for (var g in _groups) {
                          g.dispose();
                        }
                        _groups.clear();
                      });
                    },
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('حفظ واعتماد الخيارات'),
                  onPressed: _saveAndClose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChip(String label, VoidCallback onTap) {
    return ActionChip(
      avatar: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.amber),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: onTap,
    );
  }

  Widget _buildGroupCard(_OptionGroupItem group, int gIdx) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Group Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'المجموعة #${gIdx + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: group.nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المجموعة (مثال: الحجم، الإضافات، درجة السكر)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'حذف المجموعة',
                onPressed: () => _removeGroup(gIdx),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Group Rules: Required & MultiSelect
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('اختيار إلزامي؟', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('يجب على الكاشير اختيار بند قبل إضافة السلعة للسلة', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: group.isRequired,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => group.isRequired = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('اختيارات متعددة؟', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: const Text('السماح للزبون باختيار أكثر من بند في نفس الوقت', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: group.isMultiSelect,
                  activeColor: Colors.teal,
                  onChanged: (val) => setState(() => group.isMultiSelect = val),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Choices List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الاختيارات المتاحة وفارق السعر (+/- دج):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة خيار', style: TextStyle(fontSize: 11)),
                onPressed: () => _addChoiceToGroup(group),
              ),
            ],
          ),
          const SizedBox(height: 6),

          ...List.generate(group.choices.length, (cIdx) {
            final choice = group.choices[cIdx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: choice.nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'اسم الخيار (مثال: كبير، كراميل)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: choice.priceDeltaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: 'الفارق في السعر',
                        suffixText: 'دج',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (group.choices.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _removeChoice(group, cIdx),
                      tooltip: 'حذف الخيار',
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
