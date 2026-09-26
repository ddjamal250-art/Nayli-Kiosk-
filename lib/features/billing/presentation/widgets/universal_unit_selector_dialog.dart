import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../../../features/product/domain/entities/product_unit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/widgets/product_image_display.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/billing_bloc.dart';

class UniversalUnitSelectorDialog extends StatefulWidget {
  final Product product;
  final CartItem? cartItem;
  final String initialUnit;
  final double initialQuantity;

  const UniversalUnitSelectorDialog({
    super.key,
    required this.product,
    this.cartItem,
    this.initialUnit = 'pack',
    this.initialQuantity = 1.0,
  });

  static Future<void> showForCartItem(BuildContext context, CartItem item) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      builder: (ctx) => UniversalUnitSelectorDialog(
        product: item.product,
        cartItem: item,
        initialUnit: item.unitLevel,
        initialQuantity: item.quantity,
      ),
    );
  }

  static Future<void> showForProduct(
    BuildContext context,
    Product product, {
    String initialUnit = 'pack',
  }) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      builder: (ctx) => UniversalUnitSelectorDialog(
        product: product,
        initialUnit: initialUnit,
        initialQuantity: 1,
      ),
    );
  }

  @override
  State<UniversalUnitSelectorDialog> createState() => _UniversalUnitSelectorDialogState();
}

class _UniversalUnitSelectorDialogState extends State<UniversalUnitSelectorDialog> {
  late String _selectedUnit;
  late int _quantity;
  late final TextEditingController _qtyController;

  // Custom Quantity & Deal Controllers
  late final TextEditingController _customQtyController;
  late final TextEditingController _customPriceController;
  String _customBaseUnit = 'base'; 
  final FocusNode _keyboardFocusNode = FocusNode();

  // ⚖️ حقول الميزان
  final TextEditingController _weightKgController = TextEditingController();
  final TextEditingController _weightPriceController = TextEditingController();
  bool _weightByPrice = false; // false = أدخل وزن، true = أدخل سعر إجمالي

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.initialUnit;
    
    if (_selectedUnit != 'base' && _selectedUnit != 'custom') {
      final exists = p.units.any((u) => u.name == _selectedUnit);
      if (!exists) _selectedUnit = 'base';
    }

    _quantity = widget.initialQuantity;
    _qtyController = TextEditingController(text: _quantity.toString());

    final initialCustomQty = 3;
    final initialCustomPrice = p.price * initialCustomQty;

    _customBaseUnit = 'base';
    _customQtyController = TextEditingController(text: initialCustomQty.toString());
    _customPriceController = TextEditingController(text: initialCustomPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _customQtyController.dispose();
    _customPriceController.dispose();
    _keyboardFocusNode.dispose();
    _weightKgController.dispose();
    _weightPriceController.dispose();
    super.dispose();
  }

  Product get p => widget.product;

  ProductUnit? get _activeProductUnit {
    if (_selectedUnit == 'base' || _selectedUnit == 'custom') return null;
    return p.units.where((u) => u.name == _selectedUnit).firstOrNull;
  }

  double get _currentUnitPrice {
    if (_selectedUnit == 'custom') {
      final q = int.tryParse(_customQtyController.text.trim()) ?? 1;
      final pr = double.tryParse(_customPriceController.text.trim()) ?? 0.0;
      return q > 0 ? (pr / q) : 0.0;
    }
    return _activeProductUnit?.price ?? p.price;
  }

  String get _currentUnitName {
    if (_selectedUnit == 'custom') return 'سعر كمية مخصص';
    return _activeProductUnit?.name ?? p.baseUnitName;
  }

  double get _totalPrice {
    if (_selectedUnit == 'custom') {
      return double.tryParse(_customPriceController.text.trim()) ?? 0.0;
    }
    return _currentUnitPrice * _quantity;
  }

  void _setQuantity(int q) {
    final validQ = q.clamp(1, 9999);
    setState(() {
      _quantity = validQ;
      _qtyController.text = validQ.toString();
    });
  }

  void _selectUnit(String unit) {
    SoundService.playTabSwitch();
    setState(() {
      _selectedUnit = unit;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Fast Numeric Shortcuts (1: Base, 2: Unit1, 3: Unit2, 4: Custom Deal)
    if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
      _selectUnit('base');
    } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
      if (p.units.isNotEmpty) _selectUnit(p.units[0].name);
    } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
      if (p.units.length > 1) _selectUnit(p.units[1].name);
    } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.numpad4 ||
        event.logicalKey == LogicalKeyboardKey.keyB) {
      _selectUnit('custom');
    } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _applySelection();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _applySelection() {
    SoundService.playScanBeep();

    if (_selectedUnit == 'custom') {
      final qty = (int.tryParse(_customQtyController.text.trim()) ?? 1).clamp(1, 9999);
      final total = (double.tryParse(_customPriceController.text.trim()) ?? 0.0).clamp(0.0, 999999.0);
      final unitEffectivePrice = qty > 0 ? (total / qty) : 0.0;
      final baseUnitLabel = p.baseUnitName;
      final customName = '$qty $baseUnitLabel = ${total.toStringAsFixed(0)} دج';

      if (widget.cartItem != null) {
        context.read<BillingBloc>().add(
              SwitchCartItemUnitEvent(
                cartKey: widget.cartItem!.cartKey,
                targetUnit: 'custom',
                newQuantity: qty,
                customUnitPrice: unitEffectivePrice,
                customUnitName: customName,
              ),
            );
        SnackbarHelper.showSuccess(context, 'تم تعديل السعر المخصص: $customName');
      } else {
        context.read<BillingBloc>().add(
              AddProductToCartEvent(
                p,
                unitLevel: 'custom',
                quantity: qty,
                customPrice: unitEffectivePrice,
              ),
            );
        SnackbarHelper.showSuccess(context, 'تمت الإضافة بالسعر المخصص: $customName');
      }
      Navigator.pop(context);
      return;
    }

    final isWeighable = _activeProductUnit?.isWeighable == true;
    double? resolvedWeightKg;

    if (isWeighable) {
      if (_weightByPrice) {
        final total = double.tryParse(_weightPriceController.text.trim()) ?? 0.0;
        resolvedWeightKg = _currentUnitPrice > 0 ? (total / _currentUnitPrice) : 0.0;
      } else {
        resolvedWeightKg = double.tryParse(_weightKgController.text.trim()) ?? 0.0;
      }
      if (resolvedWeightKg == null || resolvedWeightKg <= 0) {
        SnackbarHelper.showError(context, 'الرجاء إدخال وزن أو سعر صحيح للميزان');
        return;
      }
    }

    if (widget.cartItem != null) {
      context.read<BillingBloc>().add(
            SwitchCartItemUnitEvent(
              cartKey: widget.cartItem!.cartKey,
              targetUnit: _selectedUnit,
              newQuantity: isWeighable ? 1 : _quantity,
              weightKg: resolvedWeightKg,
            ),
          );
      SnackbarHelper.showSuccess(
        context,
        '${context.tr("unit_switched_msg")}: "${p.name}" (${isWeighable ? '${(resolvedWeightKg! * 1000).toStringAsFixed(0)}غ' : '$posUnitLabel x$_quantity'})',
      );
    } else {
      context.read<BillingBloc>().add(
            AddProductToCartEvent(
              p,
              unitLevel: _selectedUnit,
              quantity: isWeighable ? 1 : _quantity,
              weightKg: resolvedWeightKg,
            ),
          );
      SnackbarHelper.showSuccess(
        context,
        '${context.tr("added_to_cart")}: ${isWeighable ? '${(resolvedWeightKg! * 1000).toStringAsFixed(0)}غ' : '$_quantity $posUnitLabel'} (${p.name})',
      );
    }
    Navigator.pop(context);
  }


  String get posUnitLabel => _currentUnitName;

  @override
  Widget build(BuildContext context) {
    final isEditingCart = widget.cartItem != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final List<Widget> unitCards = [];

    // 1. Base Unit Card (Key 1)
    unitCards.add(
      Expanded(
        child: _buildUnitOptionCard(
          unitKey: 'base',
          title: p.baseUnitName,
          subtitle: 'الوحدة الأساسية',
          price: p.price,
          iconData: Icons.check_box_outline_blank_rounded,
          accentColor: Colors.blue,
          shortcutKey: '1',
          isDark: isDark,
        ),
      ),
    );

    // 2. Additional Units — فلتر الوحدات المعطَّلة (isEnabled = false لا تظهر)
    int shortcut = 2;
    for (final unit in p.units.where((u) => u.isEnabled)) {
      if (shortcut > 4) break;
      final isScale = unit.isWeighable;
      unitCards.add(
        Expanded(
          child: _buildUnitOptionCard(
            unitKey: unit.name,
            title: unit.name,
            subtitle: isScale
                ? '⚖️ ${unit.price} دج/كغ'
                : 'x${unit.multiplier} ${p.baseUnitName}',
            price: unit.price,
            iconData: isScale ? Icons.scale : Icons.inventory_2_rounded,
            accentColor: isScale
                ? Colors.teal
                : (shortcut == 2 ? Colors.amber : Colors.purple),
            shortcutKey: shortcut.toString(),
            isDark: isDark,
          ),
        ),
      );
      shortcut++;
    }

    // 3. Custom Quantity Deal Card
    unitCards.add(
      Expanded(
        child: _buildUnitOptionCard(
          unitKey: 'custom',
          title: 'سعر مخصص للكمية',
          subtitle: 'تحديد عدد بسعر',
          price: p.price * 3,
          iconData: Icons.local_offer_rounded,
          accentColor: Colors.teal,
          shortcutKey: '4',
          isDark: isDark,
        ),
      ),
    );

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark ? const BorderSide(color: Color(0xFF1E293B)) : BorderSide.none,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ProductImageDisplay(
                      imageUrl: p.imageUrl,
                      width: 52,
                      height: 52,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.category.isNotEmpty ? p.category : 'عام',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF38BDF8) : Colors.blue.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'المخزون: ${p.stock} ${p.resolvedPackName}',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_alt_outlined, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اختصارات الكيبورد: [1] حبة | [2] علبة | [3] كرتونة | [4] سعر كمية | [Enter] تأكيد',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Unit Cards Row
                Row(
                  children: [
                    for (int i = 0; i < unitCards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      unitCards[i],
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Section 1: Standard Quantity Selector OR Scale Inputs
                if (_selectedUnit != 'custom') ...[
                  if (_activeProductUnit?.isWeighable == true)
                    _buildScaleInputs(isDark, textColor)
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131C31) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الكمية المراد بيعها ($_currentUnitName):',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                                    onPressed: () => _setQuantity(_quantity - 1),
                                  ),
                                  SizedBox(
                                    width: 55,
                                    child: TextField(
                                      controller: _qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        final n = int.tryParse(val);
                                        if (n != null && n > 0) {
                                          setState(() => _quantity = n);
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                                    onPressed: () => _setQuantity(_quantity + 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [1, 2, 3, 4, 5, 6, 10, 12, 20].map((q) {
                              final isSelected = _quantity == q;
                              return ChoiceChip(
                                label: Text(
                                  '$q',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : textColor,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.primaryColor,
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                onSelected: (_) => _setQuantity(q),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],


                // Section 2: Custom Multi-Quantity Pricing Deal (If custom selected)
                if (_selectedUnit == 'custom') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF042F2E) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.teal.shade700 : Colors.teal.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.price_change_rounded, color: Colors.teal, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'تحديد بيع عدد معين بسعر مخصص (آنياً):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                                  ),
                                ),
                              ],
                            ),
                            // Unit selector for custom deal
                            Row(
                              children: [
                                if (p.hasSubUnit)
                                  ChoiceChip(
                                    label: Text('بالـ ${p.resolvedSubUnitName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    selected: _customBaseUnit == 'piece',
                                    onSelected: (val) {
                                      if (val) setState(() => _customBaseUnit = 'piece');
                                    },
                                  ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: Text('بالـ ${p.resolvedPackName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  selected: _customBaseUnit == 'pack',
                                  onSelected: (val) {
                                    if (val) setState(() => _customBaseUnit = 'pack');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'العدد / الكمية:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _customQtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'مثلاً 5',
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السعر الإجمالي المخصص (دج):',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _customPriceController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.teal),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'مثلاً 60',
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick Deal Chip if pre-saved on product
                        if (p.hasCustomQuantityPricing) ...[
                          InkWell(
                            onTap: () {
                              setState(() {
                                _customQtyController.text = p.packMultiplier.toString();
                                _customPriceController.text = p.packPrice.toStringAsFixed(0);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flash_on, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تطبيق السعر المحفوظ للمنتج: ${p.packMultiplier} بـ ${p.packPrice.toStringAsFixed(0)} دج',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          'المعادلة: ${_customQtyController.text} ${_customBaseUnit == "piece" ? p.resolvedSubUnitName : p.resolvedPackName} بسعر إجمالي ${_customPriceController.text} دج (متوسط الحبة: ${_currentUnitPrice.toStringAsFixed(1)} دج)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Footer: Total & Action Button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المجموع الصافي:',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DA ${_totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: Icon(isEditingCart ? Icons.check_circle_outline : Icons.add_shopping_cart, size: 20),
                      label: Text(
                        isEditingCart ? 'تأكيد التعديل (تم) ↵' : 'إضافة إلى السلة ↵',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _applySelection,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitOptionCard({
    required String unitKey,
    required String title,
    required String subtitle,
    required double price,
    required IconData iconData,
    required MaterialColor accentColor,
    required String shortcutKey,
    required bool isDark,
  }) {
    final isSelected = _selectedUnit == unitKey;

    final unselectedBg = isDark ? const Color(0xFF131C31) : Colors.white;
    final selectedBg = isDark ? accentColor.shade900.withOpacity(0.35) : accentColor.shade50;
    final borderColor = isSelected
        ? (isDark ? accentColor.shade400 : accentColor.shade700)
        : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade300);

    return InkWell(
      onTap: () => _selectUnit(unitKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shortcutKey,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
                Icon(iconData, color: isSelected ? accentColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade700), size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isSelected
                    ? (isDark ? Colors.white : accentColor.shade900)
                    : (isDark ? Colors.white : Colors.black87),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected
                    ? (isDark ? accentColor.shade200 : accentColor.shade700)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? accentColor.shade800 : Colors.white)
                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? accentColor.shade400 : accentColor.shade300)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                'DA ${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected
                      ? (isDark ? Colors.white : accentColor.shade900)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleInputs(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF042F2E) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.teal.shade700 : Colors.teal.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.scale, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'بيع بالميزان:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                ),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('وزن (كغ)')),
                  ButtonSegment(value: true, label: Text('سعر إجمالي (دج)')),
                ],
                selected: {_weightByPrice},
                onSelectionChanged: (set) {
                  setState(() => _weightByPrice = set.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_weightByPrice)
            TextField(
              controller: _weightKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                labelText: 'الوزن بالكيلوغرام (كغ)',
                hintText: 'مثال: 1.5',
                suffixText: 'كغ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
              onSubmitted: (_) => _applySelection(),
            )
          else
            TextField(
              controller: _weightPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                labelText: 'السعر الإجمالي (دج)',
                hintText: 'مثال: 500',
                suffixText: 'دج',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
              onSubmitted: (_) => _applySelection(),
            ),
        ],
      ),
    );
  }
}
