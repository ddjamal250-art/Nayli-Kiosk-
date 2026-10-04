import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../bloc/product_bloc.dart';
import '../../../../core/utils/snackbar_helper.dart';

class _RecipeIngredientRow {
  Product? rawProduct;
  final TextEditingController qtyCtrl;
  String unit;

  _RecipeIngredientRow({
    this.rawProduct,
    required double qty,
    this.unit = 'غرام',
  }) : qtyCtrl = TextEditingController(text: qty > 0 ? (qty % 1 == 0 ? (qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString()) : qty.toString()) : '18');

  double get cost {
    if (rawProduct == null) return 0.0;
    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
    final unitCost = rawProduct!.costPrice;
    if (unit == 'حبة') {
      return unitCost * qty;
    }
    // For grams or milliliters (assuming cost is per 1000g or 1000ml)
    return (unitCost / 1000.0) * qty;
  }

  void dispose() {
    qtyCtrl.dispose();
  }
}

class CoffeeRecipeModal extends StatefulWidget {
  final Product? existingProduct;
  const CoffeeRecipeModal({super.key, this.existingProduct});

  static Future<Product?> show(BuildContext context, {Product? existingProduct}) {
    return showDialog<Product>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CoffeeRecipeModal(existingProduct: existingProduct),
    );
  }

  @override
  State<CoffeeRecipeModal> createState() => _CoffeeRecipeModalState();
}

class _CoffeeRecipeModalState extends State<CoffeeRecipeModal> {
  final _nameCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  bool _showAllProductsAsRaw = false;

  final List<_RecipeIngredientRow> _ingredients = [];
  List<Product> _allProducts = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameCtrl.text = widget.existingProduct!.name;
      _sellPriceCtrl.text = widget.existingProduct!.price > 0
          ? (widget.existingProduct!.price % 1 == 0
              ? widget.existingProduct!(.price == .price.roundToDouble() ? .price.toInt().toString() : .price.toString())
              : widget.existingProduct!.price.toString())
          : '';
    }
    _sellPriceCtrl.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allProducts = context.read<ProductBloc>().state.products;

    if (_ingredients.isEmpty) {
      if (widget.existingProduct?.coffeeRecipeJson != null) {
        try {
          final List<dynamic> recipe = jsonDecode(widget.existingProduct!.coffeeRecipeJson!);
          for (final item in recipe) {
            if (item is! Map) continue;
            final rawId = item['rawProductId']?.toString();
            final rawProduct = _allProducts.where((p) => p.id == rawId).firstOrNull;
            final qty = (item['qty'] as num?)?.toDouble() ?? 18.0;
            final rawUnit = item['unit']?.toString() ?? 'غرام';
            final normalizedUnit = (rawUnit == 'g' || rawUnit == 'غرام')
                ? 'غرام'
                : ((rawUnit == 'ml' || rawUnit == 'مل') ? 'مل' : 'حبة');

            final row = _RecipeIngredientRow(
              rawProduct: rawProduct,
              qty: qty,
              unit: normalizedUnit,
            );
            row.qtyCtrl.addListener(() => setState(() {}));
            _ingredients.add(row);
          }
        } catch (_) {}
      }

      // If still empty, add default first row
      if (_ingredients.isEmpty) {
        final defaultRaw = _getFilteredRawMaterials().firstOrNull;
        final row = _RecipeIngredientRow(
          rawProduct: defaultRaw,
          qty: 18.0,
          unit: 'غرام',
        );
        row.qtyCtrl.addListener(() => setState(() {}));
        _ingredients.add(row);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sellPriceCtrl.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    super.dispose();
  }

  List<Product> _getFilteredRawMaterials() {
    if (_showAllProductsAsRaw) return _allProducts;
    final filtered = _allProducts.where((p) {
      final c = p.category.toLowerCase();
      final n = p.name.toLowerCase();
      return c.contains('مقهى') ||
          c.contains('مواد خام') ||
          c.contains('بن') ||
          c.contains('قهوة') ||
          c.contains('مشروب') ||
          n.contains('بن') ||
          n.contains('قهوة') ||
          n.contains('حليب') ||
          n.contains('سكر') ||
          n.contains('كأس') ||
          n.contains('كوب') ||
          n.contains('حبوب');
    }).toList();

    return filtered.isNotEmpty ? filtered : _allProducts;
  }

  void _addNewIngredientRow() {
    final available = _getFilteredRawMaterials();
    final row = _RecipeIngredientRow(
      rawProduct: available.firstOrNull,
      qty: 1.0,
      unit: 'حبة',
    );
    row.qtyCtrl.addListener(() => setState(() {}));
    setState(() {
      _ingredients.add(row);
    });
  }

  void _removeIngredientRow(int index) {
    if (_ingredients.length <= 1) return;
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  double get _totalCupCost {
    double sum = 0.0;
    for (final row in _ingredients) {
      sum += row.cost;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final availableRaw = _getFilteredRawMaterials();
    final sellPrice = double.tryParse(_sellPriceCtrl.text.trim()) ?? 0.0;
    final cupCost = _totalCupCost;
    final netProfit = sellPrice - cupCost;
    final profitMarginPct = sellPrice > 0 ? (netProfit / sellPrice) * 100 : 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.coffee_rounded, color: Colors.brown, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingProduct == null ? 'إعداد وصنع وصفة قهوة جديدة ☕' : 'تعديل تركيبة ووصفة القهوة ☕',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'تحديد استهلاك المواد الخام لكل كوب وحساب التكلفة والربح تلقائياً',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Basic Drink Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.brown.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. بيانات المشروب (الكوب الجاهز للزبون)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'اسم المشروب (مثال: قهوة كابوتشينو)',
                              hintText: 'قهوة براسيلي، إسبريسو...',
                              prefixIcon: const Icon(Icons.local_cafe_rounded, size: 20, color: Colors.brown),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _sellPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'سعر البيع للزبون (دج)',
                              hintText: '50, 70, 100...',
                              prefixIcon: const Icon(Icons.monetization_on_rounded, size: 20, color: Colors.teal),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Ingredients Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2. تركيبة المواد الخام المستهلكة في الكوب الواحد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                  Row(
                    children: [
                      const Text('إظهار كل السلع', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _showAllProductsAsRaw,
                          activeColor: Colors.brown,
                          onChanged: (v) => setState(() => _showAllProductsAsRaw = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (availableRaw.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد مواد أولية مسجلة حالياً. يمكنك تفعيل "إظهار كل السلع" أعلاه لاختيار أي منتج كمادة خام.',
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_ingredients.length, (idx) {
                  final row = _ingredients[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        // Raw Material Picker
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<Product>(
                            value: availableRaw.contains(row.rawProduct) ? row.rawProduct : availableRaw.firstOrNull,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'المادة الخام #${idx + 1}',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: availableRaw.map((r) {
                              final costStr = r.costPrice > 0 ? ' (تكلفة: ${(r.costPrice == r.costPrice.roundToDouble() ? (r.costPrice == r.costPrice.roundToDouble() ? r.costPrice.toInt().toString() : r.costPrice.toString()) : r.costPrice.toString())} دج)' : '';
                              return DropdownMenuItem(
                                value: r,
                                child: Text('${r.name}$costStr', style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                row.rawProduct = v;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Qty input
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'الكمية',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Unit Picker
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: row.unit,
                            decoration: InputDecoration(
                              labelText: 'الوحدة',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'غرام', child: Text('غرام', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'مل', child: Text('مل', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'حبة', child: Text('حبة/كوب', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (u) {
                              if (u != null) {
                                setState(() => row.unit = u);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Item Cost Display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.brown.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.brown.shade200),
                          ),
                          child: Text(
                            '${row.cost.toStringAsFixed(2)} دج',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.brown),
                          ),
                        ),

                        if (_ingredients.length > 1) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            onPressed: () => _removeIngredientRow(idx),
                            tooltip: 'حذف المكون',
                          ),
                        ],
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addNewIngredientRow,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.brown),
                  label: const Text('+ إضافة مكون أو مادة خام أخرى للوصفة (سكر، حليب، أكواب...)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown)),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Smart Profit & Cost Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade50, Colors.teal.shade100.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('التكلفة الحقيقية للكوب الواحد:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                        Text('${cupCost.toStringAsFixed(2)} دج',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange, fontSize: 15)),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('سعر البيع المحدد للزبون:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                        Text('${sellPrice.toStringAsFixed(2)} دج',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.teal, fontSize: 15)),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صافي الربح في الكوب الواحد:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                        Text(
                          '${netProfit.toStringAsFixed(2)} دج (${profitMarginPct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: netProfit >= 0 ? Colors.green.shade800 : Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('حفظ واعتماد الوصفة ☕', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) {
              SnackbarHelper.showWarning(context, 'يرجى إدخال اسم المشروب أولاً');
              return;
            }

            final validRows = _ingredients.where((r) => r.rawProduct != null).toList();
            if (validRows.isEmpty) {
              SnackbarHelper.showWarning(context, 'يرجى اختيار مادة خام واحدة على الأقل');
              return;
            }

            final recipePayload = validRows.map((r) {
              final q = double.tryParse(r.qtyCtrl.text.trim()) ?? 1.0;
              final apiUnit = (r.unit == 'غرام') ? 'g' : ((r.unit == 'مل') ? 'ml' : 'piece');
              return {
                'rawProductId': r.rawProduct!.id,
                'rawProductName': r.rawProduct!.name,
                'qty': q,
                'unit': apiUnit,
              };
            }).toList();

            final recipeJson = jsonEncode(recipePayload);
            final finalCupCost = _totalCupCost;
            final finalSellPrice = double.tryParse(_sellPriceCtrl.text.trim()) ?? 0.0;

            final product = (widget.existingProduct ??
                    Product(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameCtrl.text.trim(),
                      barcode: 'COFFEE_${DateTime.now().millisecondsSinceEpoch}',
                      price: finalSellPrice,
                    ))
                .copyWith(
              name: _nameCtrl.text.trim(),
              barcode: (widget.existingProduct?.barcode.isNotEmpty == true &&
                      !widget.existingProduct!.barcode.startsWith('NO_BARCODE_'))
                  ? widget.existingProduct!.barcode
                  : 'COFFEE_${DateTime.now().millisecondsSinceEpoch}',
              price: finalSellPrice,
              costPrice: finalCupCost,
              wholesalePrice: finalCupCost,
              stock: 999, // Drawing dynamically from raw materials
              category: 'القهوة الجاهزة',
              unitSystemType: UnitSystemType.discrete,
              baseUnitName: 'كأس',
              isCoffeeMachineProduct: true,
              coffeeRecipeJson: recipeJson,
            );

            if (widget.existingProduct != null) {
              context.read<ProductBloc>().add(UpdateProduct(product));
            } else {
              context.read<ProductBloc>().add(AddProduct(product));
            }

            SnackbarHelper.showSuccess(context, '✅ تم حفظ تركيبة ووصفة القهوة بنجاح!');
            Navigator.pop(context, product);
          },
        ),
      ],
    );
  }
}
