import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_unit.dart';
import '../bloc/product_bloc.dart';
import '../../../../core/utils/snackbar_helper.dart';

class CoffeeRecipeModal extends StatefulWidget {
  final Product? existingProduct;
  const CoffeeRecipeModal({super.key, this.existingProduct});

  static Future<void> show(BuildContext context, {Product? existingProduct}) {
    return showDialog(
      context: context,
      builder: (ctx) => CoffeeRecipeModal(existingProduct: existingProduct),
    );
  }

  @override
  State<CoffeeRecipeModal> createState() => _CoffeeRecipeModalState();
}

class _CoffeeRecipeModalState extends State<CoffeeRecipeModal> {
  final _nameCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  
  Product? _selectedRawMaterial;
  final _gramsPerCupCtrl = TextEditingController();

  List<Product> _rawMaterials = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameCtrl.text = widget.existingProduct!.name;
      _sellPriceCtrl.text = widget.existingProduct!.price.toString();
      if (widget.existingProduct!.coffeeRecipeJson != null) {
        try {
          final List<dynamic> recipe = jsonDecode(widget.existingProduct!.coffeeRecipeJson!);
          if (recipe.isNotEmpty) {
             final item = recipe.first;
             _gramsPerCupCtrl.text = item['qty'].toString();
             // We will find _selectedRawMaterial after loading
          }
        } catch (_) {}
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<ProductBloc>().state;
    _rawMaterials = state.products.where((p) => p.category == 'مقهى - مواد خام').toList();
    
    if (widget.existingProduct?.coffeeRecipeJson != null) {
        try {
          final List<dynamic> recipe = jsonDecode(widget.existingProduct!.coffeeRecipeJson!);
          if (recipe.isNotEmpty) {
             final item = recipe.first;
             _selectedRawMaterial = _rawMaterials.where((r) => r.id == item['rawProductId']).firstOrNull;
          }
        } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.coffee, color: Colors.brown),
          SizedBox(width: 8),
          Text(widget.existingProduct == null ? 'بناء وصفة قهوة جديدة' : 'تعديل وصفة القهوة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1. معلومات الكوب (المنتج النهائي)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: 'اسم المشروب (مثال: قهوة كابوتشينو)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _sellPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'سعر البيع للزبون (دج)', border: OutlineInputBorder()),
            ),
            
            SizedBox(height: 20),
            Text('2. تركيبة الوصفة (المواد الخام)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            SizedBox(height: 8),
            
            if (_rawMaterials.isEmpty)
              Container(
                 padding: EdgeInsets.all(8),
                 color: Colors.orange.withOpacity(0.1),
                 child: Text('لا توجد مواد خام في المخزون. يرجى إضافة سلع في قسم "مقهى - مواد خام" أولاً.'),
              )
            else ...[
              DropdownButtonFormField<Product>(
                value: _selectedRawMaterial,
                decoration: InputDecoration(labelText: 'اختر المادة الخام (مثال: بن مطحون)', border: OutlineInputBorder()),
                items: _rawMaterials.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedRawMaterial = v),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _gramsPerCupCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'الكمية المستهلكة في الكوب الواحد (غرام / مل)', border: OutlineInputBorder()),
              ),
            ],
            
            SizedBox(height: 16),
            if (_selectedRawMaterial != null && _gramsPerCupCtrl.text.isNotEmpty)
              Builder(
                builder: (ctx) {
                  final grams = double.tryParse(_gramsPerCupCtrl.text) ?? 0.0;
                  final rawCostPerGram = (_selectedRawMaterial!.costPrice / 1000.0);
                  final cupCost = rawCostPerGram * grams;
                  
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('التكلفة الحقيقية للكوب:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(' دج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 16)),
                      ],
                    ),
                  );
                }
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.isEmpty || _selectedRawMaterial == null) return;
            
            final grams = double.tryParse(_gramsPerCupCtrl.text) ?? 0.0;
            final rawCostPerGram = (_selectedRawMaterial!.costPrice / 1000.0);
            final cupCost = rawCostPerGram * grams;
            
            final recipeJson = jsonEncode([
               {
                 'rawProductId': _selectedRawMaterial!.id,
                 'rawProductName': _selectedRawMaterial!.name,
                 'qty': grams,
                 'unit': 'g'
               }
            ]);

            final product = Product(
              id: widget.existingProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameCtrl.text.trim(),
              barcode: widget.existingProduct?.barcode ?? 'COFFEE_CUP',
              price: double.tryParse(_sellPriceCtrl.text) ?? 0.0,
              costPrice: cupCost,
              wholesalePrice: cupCost,
              stock: 999, // Cups don't have stock, they draw from raw materials
              category: 'قهوة جاهزة',
              unitSystemType: UnitSystemType.discrete,
              baseUnitName: 'كوب',
              coffeeRecipeJson: recipeJson,
            );

            if (widget.existingProduct != null) {
              context.read<ProductBloc>().add(UpdateProduct(product));
            } else {
              context.read<ProductBloc>().add(AddProduct(product));
            }
            
            SnackbarHelper.showSuccess(context, 'تم حفظ وصفة القهوة بنجاح!');
            Navigator.pop(context);
          },
          child: Text('حفظ الوصفة'),
        ),
      ],
    );
  }
}
