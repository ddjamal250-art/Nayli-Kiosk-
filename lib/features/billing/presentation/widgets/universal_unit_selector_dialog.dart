import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
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
        '🔄 تم تحويل "${p.name}" إلى $_currentUnitName (x$_quantity)',
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
        '🛒 تمت إضافة $_quantity $_currentUnitName من "${p.name}"',
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditingCart = widget.cartItem != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                ProductImageDisplay(
                  imageUrl: p.imageUrl,
                  width: 50,
                  height: 50,
                  borderRadius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.category.isNotEmpty ? p.category : 'عام',
                              style: TextStyle(color: Colors.blue.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'المخزون: ${p.stock} ${p.resolvedPackName}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Instruction Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers_outlined, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditingCart
                          ? 'اختر مستوى التعبئة المطلوب لتحويل السلعة في السلة فوراً:'
                          : 'اختر نوع العبوة والكمية المراد إضافتها إلى السلة:',
                      style: const TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3-Tier Packaging Selector Cards
            Row(
              children: [
                // 1. Piece / SubUnit Option (if available)
                if (p.hasSubUnit)
                  Expanded(
                    child: _buildUnitOptionCard(
                      unitKey: 'piece',
                      title: p.resolvedSubUnitName,
                      subtitle: '1/${p.piecesPerPack > 0 ? p.piecesPerPack : 20} من ${p.resolvedPackName}',
                      price: p.resolvedPiecePrice,
                      iconText: p.isTobacco ? '🚬' : '🧩',
                      accentColor: Colors.amber,
                    ),
                  )
                else
                  Expanded(
                    child: _buildDisabledCard(
                      title: 'تجزئة بالحبة',
                      hint: 'غير مفعلة لهذا المنتج',
                    ),
                  ),
                const SizedBox(width: 10),

                // 2. Standard Pack Option (Always available)
                Expanded(
                  child: _buildUnitOptionCard(
                    unitKey: 'pack',
                    title: p.resolvedPackName,
                    subtitle: 'العبوة القياسية',
                    price: p.price,
                    iconText: '📦',
                    accentColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Carton / Multiplier Option (if available)
                if (p.hasCarton)
                  Expanded(
                    child: _buildUnitOptionCard(
                      unitKey: 'carton',
                      title: p.resolvedCartonName,
                      subtitle: 'x${p.packsPerCarton > 0 ? p.packsPerCarton : (p.packMultiplier > 0 ? p.packMultiplier : 10)} ${p.resolvedPackName}',
                      price: p.resolvedCartonPrice,
                      iconText: '🚛',
                      accentColor: Colors.purple,
                    ),
                  )
                else
                  Expanded(
                    child: _buildDisabledCard(
                      title: 'كرتونة / فاردو',
                      hint: 'غير مفعلة لهذا المنتج',
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Quantity Control Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الكمية بالـ ($_currentUnitName):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      // Stepper controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28),
                            onPressed: () => _setQuantity(_quantity - 1),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                                border: OutlineInputBorder(),
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
                  // Quick Quantity Pills
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
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        onSelected: (_) => _setQuantity(q),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary & Confirm Action
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المجموع النهائي:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        '${_totalPrice.toStringAsFixed(2)} DA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xFF1E3A8A),
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
                  icon: Icon(isEditingCart ? Icons.sync : Icons.add_shopping_cart, size: 20),
                  label: Text(
                    isEditingCart ? 'تأكيد التبديل في السلة' : 'إضافة إلى السلة',
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
    required String iconText,
    required MaterialColor accentColor,
  }) {
    final isSelected = _selectedUnit == unitKey;

    return InkWell(
      onTap: () => _selectUnit(unitKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor.shade700 : Colors.grey.shade300,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(iconText, style: const TextStyle(fontSize: 20)),
                if (isSelected)
                  Icon(Icons.check_circle, color: accentColor.shade700, size: 18)
                else
                  Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? accentColor.shade900 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? accentColor.shade700 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? accentColor.shade300 : Colors.transparent,
                ),
              ),
              child: Text(
                '${price.toStringAsFixed(0)} DA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? accentColor.shade900 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledCard({required String title, required String hint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.block, color: Colors.grey, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 9.5, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('—', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
