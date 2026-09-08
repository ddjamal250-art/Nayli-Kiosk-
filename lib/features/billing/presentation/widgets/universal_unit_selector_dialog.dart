import 'package:flutter/material.dart';
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
  final int initialQuantity;

  const UniversalUnitSelectorDialog({
    super.key,
    required this.product,
    this.cartItem,
    this.initialUnit = 'pack',
    this.initialQuantity = 1,
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

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.initialUnit;
    if (_selectedUnit == 'piece' && !p.hasSubUnit) {
      _selectedUnit = 'pack';
    }
    if (_selectedUnit == 'carton' && !p.hasCarton) {
      _selectedUnit = 'pack';
    }
    _quantity = widget.initialQuantity;
    _qtyController = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Product get p => widget.product;

  double get _currentUnitPrice {
    if (_selectedUnit == 'piece') return p.resolvedPiecePrice;
    if (_selectedUnit == 'carton') return p.resolvedCartonPrice;
    return p.price;
  }

  String get _currentUnitName {
    if (_selectedUnit == 'piece') return p.resolvedSubUnitName;
    if (_selectedUnit == 'carton') return p.resolvedCartonName;
    return p.resolvedPackName;
  }

  double get _totalPrice => _currentUnitPrice * _quantity;

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

  void _applySelection() {
    SoundService.playScanBeep();
    if (widget.cartItem != null) {
      context.read<BillingBloc>().add(
            SwitchCartItemUnitEvent(
              cartKey: widget.cartItem!.cartKey,
              targetUnit: _selectedUnit,
              newQuantity: _quantity,
            ),
          );
      SnackbarHelper.showSuccess(
        context,
        '${context.tr("unit_switched_msg")}: "${p.name}" ($posUnitLabel x$_quantity)',
      );
    } else {
      context.read<BillingBloc>().add(
            AddProductToCartEvent(
              p,
              unitLevel: _selectedUnit,
              quantity: _quantity,
            ),
          );
      SnackbarHelper.showSuccess(
        context,
        '${context.tr("added_to_cart")}: $_quantity $posUnitLabel (${p.name})',
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

    if (p.hasCarton) {
      unitCards.add(
        Expanded(
          child: _buildUnitOptionCard(
            unitKey: 'carton',
            title: p.resolvedCartonName,
            subtitle: 'x${p.effectivePacksPerCarton} ${p.resolvedPackName}',
            price: p.resolvedCartonPrice,
            iconData: p.isBeverage ? Icons.inventory_2_rounded : Icons.all_inbox_rounded,
            accentColor: Colors.purple,
            isDark: isDark,
          ),
        ),
      );
    }

    unitCards.add(
      Expanded(
        child: _buildUnitOptionCard(
          unitKey: 'pack',
          title: p.resolvedPackName,
          subtitle: p.isBeverage ? 'وحدة مفردة' : 'علبة أساسية',
          price: p.price,
          iconData: p.isBeverage ? Icons.local_drink_rounded : Icons.check_box_outline_blank_rounded,
          accentColor: Colors.blue,
          isDark: isDark,
        ),
      ),
    );

    if (p.hasSubUnit) {
      unitCards.add(
        Expanded(
          child: _buildUnitOptionCard(
            unitKey: 'piece',
            title: p.resolvedSubUnitName,
            subtitle: '1/${p.effectivePiecesPerPack} ${p.resolvedPackName}',
            price: p.resolvedPiecePrice,
            iconData: p.isTobaccoProduct ? Icons.smoking_rooms_rounded : Icons.grain_rounded,
            accentColor: Colors.amber,
            isDark: isDark,
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark ? const BorderSide(color: Color(0xFF1E293B)) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF15803D) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditingCart
                          ? 'اختر الوحدة المناسبة لتبديلها في السلة الحالية:'
                          : 'حدد وحدة التعبئة والكمية المراد إضافتها إلى السلة:',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (int i = 0; i < unitCards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  unitCards[i],
                ],
              ],
            ),
            const SizedBox(height: 16),
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
                            width: 50,
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
            const SizedBox(height: 16),
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
                          fontSize: 20,
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
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: Icon(isEditingCart ? Icons.sync : Icons.add_shopping_cart, size: 20),
                  label: Text(
                    isEditingCart ? 'تأكيد التعديل في السلة' : 'إضافة إلى السلة',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _applySelection,
                ),
              ],
            ),
          ],
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
        padding: const EdgeInsets.all(12),
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
                Icon(iconData, color: isSelected ? accentColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade700), size: 22),
                if (isSelected)
                  Icon(Icons.check_circle, color: isDark ? accentColor.shade300 : accentColor.shade700, size: 18)
                else
                  Icon(Icons.radio_button_unchecked, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
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
                fontSize: 10,
                color: isSelected
                    ? (isDark ? accentColor.shade200 : accentColor.shade700)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  fontSize: 12,
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
}
