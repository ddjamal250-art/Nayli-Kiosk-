import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../bloc/product_bloc.dart';

class QuickReceiveModal extends StatefulWidget {
  final Product product;
  final VoidCallback onReceived;

  const QuickReceiveModal({
    super.key,
    required this.product,
    required this.onReceived,
  });

  static Future<void> show(BuildContext context, Product product) async {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: QuickReceiveModal(
            product: product,
            onReceived: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  @override
  State<QuickReceiveModal> createState() => _QuickReceiveModalState();
}

class _QuickReceiveModalState extends State<QuickReceiveModal> {
  late Product _product;
  double _quantity = 10.0;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  ProductUnit? _selectedUnit;
  final DateTime _dateAdded = DateTime.now();
  DateTime? _expiryDate;
  late List<ProductUnit> _availableUnits;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _quantityCtrl = TextEditingController(text: '10');
    _costPriceCtrl = TextEditingController(text: _product.costPrice.toStringAsFixed(2));
    _sellPriceCtrl = TextEditingController(text: _product.price.toStringAsFixed(2));
    
    if (_product.expiryDate != null) {
      _expiryDate = DateTime.tryParse(_product.expiryDate!);
    }

    _availableUnits = _getAvailableUnits();
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    super.dispose();
  }

  List<ProductUnit> _getAvailableUnits() {
    final List<ProductUnit> list = [];
    if (_product.units.isNotEmpty) {
      for (final u in _product.units) {
        if (!u.isEnabled) continue;
        double mult = u.multiplier;
        // تصحيح معامل الكرتونة في حالة كانت البيانات القديمة تسجل سعة العلب وليس مجموع الحبات
        if (u.tier == UnitTier.large) {
          final pack = _product.units.firstWhereOrNull(
            (p) => p.tier == UnitTier.medium || (p.tier != UnitTier.large && p.multiplier > 1),
          );
          if (pack != null && mult > 0 && pack.multiplier > 0 && mult <= pack.multiplier) {
            mult = mult * pack.multiplier;
          }
        }
        if (mult > 1 || (u.name.trim() != _product.baseUnitName.trim())) {
          list.add(u.copyWith(multiplier: mult > 0 ? mult : 1.0));
        }
      }
    } else {
      if (_product.packMultiplier > 1) {
        list.add(ProductUnit(
          name: _product.resolvedPackName,
          tier: UnitTier.medium,
          multiplier: _product.packMultiplier.toDouble(),
          price: _product.packPrice,
          cost: _product.costPrice * _product.packMultiplier,
        ));
      }
      if (_product.hasCarton && _product.packsPerCarton > 1) {
        final cMult = _product.packMultiplier > 1
            ? (_product.packMultiplier * _product.packsPerCarton).toDouble()
            : _product.packsPerCarton.toDouble();
        list.add(ProductUnit(
          name: 'كرتونة',
          tier: UnitTier.large,
          multiplier: cMult,
          price: _product.cartonPrice,
          cost: _product.cartonCostPrice,
        ));
      }
    }
    return list;
  }

  double get _effectiveMultiplier => _selectedUnit?.multiplier ?? 1.0;
  double get _totalPiecesAdded => _quantity * _effectiveMultiplier;
  String get _currentUnitName => _selectedUnit?.name ?? _product.baseUnitName;

  void _updateQuantity(double q) {
    final validQ = q.clamp(0.01, 99999.0);
    setState(() {
      _quantity = validQ;
      _quantityCtrl.text = validQ == validQ.roundToDouble()
          ? validQ.toInt().toString()
          : validQ.toString();
    });
  }

  void _onUnitChanged(ProductUnit? val) {
    setState(() {
      _selectedUnit = val;
      if (val != null) {
        if (val.cost > 0) {
          _costPriceCtrl.text = val.cost.toStringAsFixed(2);
        } else if (_product.costPrice > 0) {
          _costPriceCtrl.text = (_product.costPrice * val.multiplier).toStringAsFixed(2);
        }
        if (val.price > 0) {
          _sellPriceCtrl.text = val.price.toStringAsFixed(2);
        } else {
          _sellPriceCtrl.text = (_product.price * val.multiplier).toStringAsFixed(2);
        }
      } else {
        _costPriceCtrl.text = _product.costPrice.toStringAsFixed(2);
        _sellPriceCtrl.text = _product.price.toStringAsFixed(2);
      }
    });
  }

  void _confirmReceive() {
    final enteredCost = double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0;
    final enteredSell = double.tryParse(_sellPriceCtrl.text.trim()) ?? 0.0;
    final multiplier = _effectiveMultiplier;
    final realQtyAdded = _totalPiecesAdded;

    if (realQtyAdded <= 0) {
      SnackbarHelper.showError(context, 'يرجى إدخال كمية استلام صحيحة أكبر من الصفر');
      return;
    }

    final pieceCost = multiplier > 0 ? (enteredCost / multiplier) : enteredCost;

    final newBatch = PurchaseBatch(
      costPrice: pieceCost > 0 ? pieceCost : _product.costPrice,
      remainingQuantity: realQtyAdded,
      dateAdded: _dateAdded,
    );

    final newBatches = List<PurchaseBatch>.from(_product.stockBatches)..add(newBatch);

    List<ProductUnit> updatedUnits = _product.units.isNotEmpty
        ? _product.units.map((u) {
            final eff = (_selectedUnit != null && (u.tier == _selectedUnit!.tier || u.name == _selectedUnit!.name))
                ? _selectedUnit!.multiplier
                : u.multiplier;
            if (_selectedUnit != null && (u.tier == _selectedUnit!.tier || u.name == _selectedUnit!.name)) {
              return u.copyWith(multiplier: eff, price: enteredSell, cost: enteredCost);
            }
            return u.copyWith(multiplier: eff);
          }).toList()
        : _availableUnits;

    final updated = _product.copyWith(
      stock: _product.stock + realQtyAdded,
      costPrice: pieceCost > 0 ? pieceCost : _product.costPrice,
      price: _selectedUnit == null ? (enteredSell > 0 ? enteredSell : _product.price) : _product.price,
      units: updatedUnits,
      stockBatches: newBatches,
      expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
    );

    context.read<ProductBloc>().add(UpdateProduct(updated));
    SoundService.playSaveSuccess();
    SnackbarHelper.showSuccess(
      context,
      '✅ تم استلام ${_quantity == _quantity.roundToDouble() ? _quantity.toInt() : _quantity} $_currentUnitName (+$realQtyAdded ${_product.baseUnitName}) بنجاح كدفعة جديدة!',
    );
    widget.onReceived();
  }

  @override
  Widget build(BuildContext context) {
    final mult = _effectiveMultiplier;
    final totalAdded = _totalPiecesAdded;
    final newStock = _product.stock + totalAdded;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text('استلام سريع ذكي (FIFO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onReceived),
            ],
          ),
          const SizedBox(height: 6),
          Text(_product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(
            'المخزون الحالي: ${_product.stock} ${_product.baseUnitName}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // Quantity and Unit Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity Input with - / + buttons and editable TextField
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الكمية المستلمة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => _updateQuantity(_quantity - 1) : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _quantityCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              fillColor: Colors.green.withOpacity(0.08),
                              filled: true,
                            ),
                            onChanged: (val) {
                              final q = double.tryParse(val.trim());
                              if (q != null && q > 0) {
                                setState(() => _quantity = q);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: () => _updateQuantity(_quantity + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 14),

              // Unit Selector Dropdown
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('وحدة الاستلام:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProductUnit?>(
                      value: _selectedUnit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        DropdownMenuItem<ProductUnit?>(
                          value: null,
                          child: Text('${_product.baseUnitName} (وحدة أساسية x1)', style: const TextStyle(fontSize: 12.5)),
                        ),
                        ..._availableUnits.map((u) {
                          final multLabel = u.multiplier == u.multiplier.roundToDouble()
                              ? u.multiplier.toInt().toString()
                              : u.multiplier.toString();
                          return DropdownMenuItem<ProductUnit?>(
                            value: u,
                            child: Text('${u.name} (تحتوي $multLabel ${_product.baseUnitName})', style: const TextStyle(fontSize: 12.5)),
                          );
                        }),
                      ],
                      onChanged: _onUnitChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // Common Quantity Quick-Select Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [1.0, 5.0, 10.0, 20.0, 24.0, 50.0, 100.0].map((amt) {
              final isSel = _quantity == amt;
              return ActionChip(
                label: Text(
                  '+${amt == amt.roundToDouble() ? amt.toInt() : amt}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSel ? Colors.green.shade900 : Colors.black87,
                  ),
                ),
                backgroundColor: isSel ? Colors.green.withOpacity(0.25) : Colors.grey[100],
                side: isSel ? const BorderSide(color: Colors.green, width: 1.5) : BorderSide.none,
                onPressed: () => _updateQuantity(amt),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),

          // Calculation Live Preview Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: Colors.green, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      'معاينة المخزون الدقيقة:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_quantity == _quantity.roundToDouble() ? _quantity.toInt() : _quantity} x $_currentUnitName (${mult == mult.roundToDouble() ? mult.toInt() : mult} ${_product.baseUnitName}) = +${totalAdded == totalAdded.roundToDouble() ? totalAdded.toInt() : totalAdded.toStringAsFixed(1)} ${_product.baseUnitName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'المخزون الحالي: ${_product.stock} ${_product.baseUnitName} ➔ المخزون الجديد: ${newStock == newStock.roundToDouble() ? newStock.toInt() : newStock.toStringAsFixed(1)} ${_product.baseUnitName}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          
          // Cost and Price
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر شراء $_currentUnitName',
                    prefixIcon: const Icon(Icons.attach_money, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _sellPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر بيع $_currentUnitName',
                    prefixIcon: const Icon(Icons.price_change, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Dates
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _expiryDate = picked);
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_expiryDate == null ? 'تاريخ الصلاحية' : DateFormat('yyyy-MM-dd').format(_expiryDate!)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              'تأكيد وحفظ الدفعة في المخزن (+${totalAdded == totalAdded.roundToDouble() ? totalAdded.toInt() : totalAdded.toStringAsFixed(1)} ${_product.baseUnitName})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _confirmReceive,
          ),
        ],
      ),
    );
  }
}
