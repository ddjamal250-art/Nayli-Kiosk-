import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
          constraints: const BoxConstraints(maxWidth: 540),
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
  double _quantity = 10;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _sellPriceCtrl;
  ProductUnit? _selectedUnit;
  DateTime _dateAdded = DateTime.now();
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _costPriceCtrl = TextEditingController(text: _product.costPrice.toStringAsFixed(2));
    _sellPriceCtrl = TextEditingController(text: _product.price.toStringAsFixed(2));
    
    if (_product.expiryDate != null) {
      _expiryDate = DateTime.tryParse(_product.expiryDate!);
    }
  }

  @override
  void dispose() {
    _costPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    super.dispose();
  }

  void _confirmReceive() {
    final costPrice = double.tryParse(_costPriceCtrl.text.trim()) ?? _product.costPrice;
    final sellPrice = double.tryParse(_sellPriceCtrl.text.trim()) ?? _product.price;
    final multiplier = _selectedUnit?.multiplier ?? 1.0;
    
    final realQtyAdded = _quantity * multiplier;
    
    // Create new batch for FIFO
    final newBatch = PurchaseBatch(
      costPrice: costPrice,
      remainingQuantity: realQtyAdded,
      dateAdded: _dateAdded,
    );
    
    final newBatches = List<PurchaseBatch>.from(_product.stockBatches)..add(newBatch);
    
    final updated = _product.copyWith(
      stock: _product.stock + realQtyAdded,
      costPrice: costPrice, // update the display cost price to the newest one
      price: sellPrice, // update display sell price
      stockBatches: newBatches,
      expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
    );

    context.read<ProductBloc>().add(UpdateProduct(updated));
    SoundService.playSaveSuccess();
    SnackbarHelper.showSuccess(context, '✅ تم استلام ${realQtyAdded.toStringAsFixed(1)} ${_product.baseUnitName} بنجاح كدفعة جديدة!');
    widget.onReceived();
  }

  @override
  Widget build(BuildContext context) {
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
          Text('المخزون الحالي: ${_product.stock} ${_product.baseUnitName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          
          // Quantity and Unit Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الكمية المستلمة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('+${_quantity.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_product.units.isNotEmpty) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('وحدة الاستلام:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ProductUnit?>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text(_product.baseUnitName)),
                          ..._product.units.map((u) => DropdownMenuItem(value: u, child: Text('${u.name} (x${u.multiplier})'))),
                        ],
                        onChanged: (val) => setState(() => _selectedUnit = val),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          // Chips
          Wrap(
            spacing: 6,
            children: [5.0, 10.0, 24.0, 50.0, 100.0].map((amt) {
              return ActionChip(
                label: Text('+$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                backgroundColor: _quantity == amt ? Colors.green.withOpacity(0.2) : Colors.grey[100],
                onPressed: () => setState(() => _quantity = amt),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Cost and Price
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر شراء هذه الدفعة',
                    prefixIcon: Icon(Icons.attach_money, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _sellPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر بيع التجزئة',
                    prefixIcon: Icon(Icons.price_change, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
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
          
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text('تأكيد وحفظ الدفعة في المخزن (+${(_quantity * (_selectedUnit?.multiplier ?? 1.0)).toStringAsFixed(1)})', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _confirmReceive,
          ),
        ],
      ),
    );
  }
}
