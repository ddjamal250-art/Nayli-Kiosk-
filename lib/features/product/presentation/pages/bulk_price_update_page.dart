import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../bloc/product_event.dart';
import '../bloc/product_state.dart';
import '../../../../core/theme/app_theme.dart';

class BulkPriceUpdatePage extends StatefulWidget {
  const BulkPriceUpdatePage({super.key});

  @override
  State<BulkPriceUpdatePage> createState() => _BulkPriceUpdatePageState();
}

class _BulkPriceUpdatePageState extends State<BulkPriceUpdatePage> {
  final Map<String, double> _editedCostPrices = {};
  final Map<String, double> _editedSellPrices = {};
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  final TextEditingController _searchCtrl = TextEditingController();

  void _saveChanges(List<Product> allProducts) {
    if (_editedCostPrices.isEmpty && _editedSellPrices.isEmpty) return;

    final bloc = context.read<ProductBloc>();
    int count = 0;

    for (final p in allProducts) {
      final newCost = _editedCostPrices[p.id];
      final newPrice = _editedSellPrices[p.id];

      if (newCost != null || newPrice != null) {
        final updated = p.copyWith(
          costPrice: newCost ?? p.costPrice,
          price: newPrice ?? p.price,
        );
        bloc.add(UpdateProduct(updated));
        count++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث أسعار \ منتج بنجاح!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديث الأسعار الجماعي', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCategories = ['الكل', ...state.products.map((p) => p.category).toSet().toList()..sort()];

          final filteredProducts = state.products.where((p) {
            final matchSearch = p.name.toLowerCase().contains(_searchQuery) || p.barcode.contains(_searchQuery);
            final matchCat = _selectedCategory == 'الكل' || p.category == _selectedCategory;
            return matchSearch && matchCat;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم أو الباركود...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            items: allCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('لا توجد منتجات مطابقة'))
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          final hasCostEdit = _editedCostPrices.containsKey(p.id);
                          final hasPriceEdit = _editedSellPrices.containsKey(p.id);
                          
                          final currentCost = _editedCostPrices[p.id] ?? p.costPrice;
                          final currentPrice = _editedSellPrices[p.id] ?? p.price;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            color: (hasCostEdit || hasPriceEdit) ? Colors.orange.shade50 : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('المخزون: \', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: (currentCost == currentCost.roundToDouble() ? currentCost.toInt().toString() : currentCost.toString()),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'سعر الشراء',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (val) {
                                        final v = double.tryParse(val);
                                        setState(() {
                                          if (v != null && v != p.costPrice) {
                                            _editedCostPrices[p.id] = v;
                                          } else {
                                            _editedCostPrices.remove(p.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: (currentPrice == currentPrice.roundToDouble() ? currentPrice.toInt().toString() : currentPrice.toString()),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'سعر البيع',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (val) {
                                        final v = double.tryParse(val);
                                        setState(() {
                                          if (v != null && v != p.price) {
                                            _editedSellPrices[p.id] = v;
                                          } else {
                                            _editedSellPrices.remove(p.id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Text(
                      'التعديلات: \ منتج',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: (_editedCostPrices.isEmpty && _editedSellPrices.isEmpty)
                          ? null
                          : () => _saveChanges(state.products),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
