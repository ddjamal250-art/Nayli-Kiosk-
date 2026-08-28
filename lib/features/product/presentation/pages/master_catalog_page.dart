import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/data/master_catalog_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/primary_button.dart';

class MasterCatalogPage extends StatefulWidget {
  const MasterCatalogPage({super.key});

  @override
  State<MasterCatalogPage> createState() => _MasterCatalogPageState();
}

class _MasterCatalogPageState extends State<MasterCatalogPage> {
  String _selectedCategory = 'الكل';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOrEditModal(MasterCatalogItem item, Product? existingProduct) {
    final nameController = TextEditingController(text: existingProduct?.name ?? item.name);
    final sellingPriceController = TextEditingController(
      text: (existingProduct != null ? existingProduct.price : item.defaultPrice).toStringAsFixed(2),
    );
    final costPriceController = TextEditingController(
      text: (existingProduct != null ? existingProduct.costPrice : item.defaultCost).toStringAsFixed(2),
    );
    int qtyToAdd = existingProduct != null ? 0 : 12;
    final qtyController = TextEditingController(text: qtyToAdd > 0 ? qtyToAdd.toString() : '12');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        existingProduct != null ? 'تعديل السلعة بالمحل' : 'إضافة السلعة إلى مخزون المحل',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'باركود: ${item.barcode}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        item.category,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('product_name'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('selling_price'),
                          prefixText: '${AppConstants.currencySymbol} ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: costPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.tr('cost_price'),
                          prefixText: '${AppConstants.currencySymbol} ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: existingProduct != null ? 'إضافة كمية للمخزون' : context.tr('initial_stock'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...[6, 12, 24, 48].map((q) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ActionChip(
                        label: Text('+$q', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        padding: const EdgeInsets.all(0),
                        onPressed: () {
                          setModalState(() {
                            qtyController.text = q.toString();
                          });
                        },
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(sellingPriceController.text.trim()) ?? item.defaultPrice;
                    final cost = double.tryParse(costPriceController.text.trim()) ?? item.defaultCost;
                    final qty = int.tryParse(qtyController.text.trim()) ?? 12;

                    if (name.isNotEmpty) {
                      if (existingProduct != null) {
                        final updated = Product(
                          id: existingProduct.id,
                          name: name,
                          barcode: item.barcode,
                          price: price,
                          costPrice: cost,
                          stock: existingProduct.stock + qty,
                        );
                        context.read<ProductBloc>().add(UpdateProduct(updated));
                      } else {
                        final newProduct = Product(
                          id: const Uuid().v4(),
                          name: name,
                          barcode: item.barcode,
                          price: price,
                          costPrice: cost,
                          stock: qty,
                        );
                        context.read<ProductBloc>().add(AddProduct(newProduct));
                      }

                      final hasVib = await Vibration.hasVibrator();
                      if (hasVib == true) Vibration.vibrate(duration: 40);

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ تم حفظ "$name" في مخزون المحل'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icons.check_circle_outline,
                  label: existingProduct != null ? 'تحديث السلعة بالمحل' : 'إضافة إلى المحل فوراً',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBatchImportDialog(List<MasterCatalogItem> availableItems) {
    int defaultStock = 12;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.playlist_add_check, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'استيراد جماعي تلقائي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم إضافة ${availableItems.length} منتج من تصنيف "$_selectedCategory" إلى قاعدة بيانات المحل بالأسعار المقترحة ومخزون افتراضي $defaultStock علبة لكل منتج.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'يمكنك في أي وقت لاحق تعديل الأسعار أو استلام كميات جديدة.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              for (final item in availableItems) {
                final newProduct = Product(
                  id: const Uuid().v4(),
                  name: item.name,
                  barcode: item.barcode,
                  price: item.defaultPrice,
                  costPrice: item.defaultCost,
                  stock: defaultStock,
                );
                context.read<ProductBloc>().add(AddProduct(newProduct));
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 تم بنجاح استيراد ${availableItems.length} منتج إلى المحل!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('تأكيد الاستيراد السريع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        final existingProductsMap = {for (var p in state.products) p.barcode.trim(): p};
        final filteredItems = MasterCatalogService.instance.search(_searchQuery, category: _selectedCategory, limit: 300);
        final notInShopItems = filteredItems.where((item) => !existingProductsMap.containsKey(item.barcode)).toList();
        final categoriesList = MasterCatalogService.instance.categories;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'مكتبة السلع الجزائرية (15,500+ منتج)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left, size: 28),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (notInShopItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.playlist_add_check, color: AppTheme.primaryColor),
                  tooltip: 'استيراد جماعي (${notInShopItems.length})',
                  onPressed: () => _showBatchImportDialog(notInShopItems),
                ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المنتج، الماركة (رامي، صومام...) أو الباركود...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              // Categories Horizontal List
              Container(
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categoriesList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final cat = categoriesList[index];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: Colors.grey[100],
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    );
                  },
                ),
              ),

              // Items Count & Batch Info Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredItems.length} سلعة متوفرة',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    if (notInShopItems.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showBatchImportDialog(notInShopItems),
                        child: Text(
                          '⚡ استيراد الكل (${notInShopItems.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                  ],
                ),
              ),

              // Catalog List
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            const Text('لم يتم العثور على أي سلعة تطابق بحثك', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final existing = existingProductsMap[item.barcode.trim()];
                          final isInShop = existing != null;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isInShop ? Colors.green.withOpacity(0.4) : Colors.grey[200]!,
                                width: isInShop ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Category / Status Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isInShop ? Colors.green.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isInShop ? Icons.check_circle : Icons.inventory_2_outlined,
                                    color: isInShop ? Colors.green : AppTheme.primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.barcode,
                                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item.category,
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (isInShop) ...[
                                        Text(
                                          'بالمحل: ${existing.price.toStringAsFixed(0)} ${AppConstants.currencySymbol} • المخزون: ${existing.stock}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          'مقترح: ${item.defaultPrice.toStringAsFixed(0)} ${AppConstants.currencySymbol} (شراء: ${item.defaultCost.toStringAsFixed(0)})',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Action Button
                                if (isInShop)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                                    tooltip: 'تعديل السعر أو المخزون',
                                    onPressed: () => _showAddOrEditModal(item, existing),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _showAddOrEditModal(item, null),
                                    child: const Text('إضافة +', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}