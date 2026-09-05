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
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/adaptive_modal_helper.dart';

class MasterCatalogPage extends StatefulWidget {
  const MasterCatalogPage({super.key});

  @override
  State<MasterCatalogPage> createState() => _MasterCatalogPageState();
}

class _MasterCatalogPageState extends State<MasterCatalogPage> {
  String _selectedCategory = 'الكل';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _displayLimit = 50;

  // Persistent Multi-selection across searches and category filters
  final Set<String> _selectedBarcodes = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
        _displayLimit = 50;
      });
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        setState(() {
          _displayLimit += 50;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleBarcodeSelection(String barcode) {
    setState(() {
      if (_selectedBarcodes.contains(barcode)) {
        _selectedBarcodes.remove(barcode);
      } else {
        _selectedBarcodes.add(barcode);
      }
    });
    SoundService.playTabSwitch();
  }

  void _selectAllInList(List<MasterCatalogItem> items) {
    setState(() {
      for (var item in items) {
        _selectedBarcodes.add(item.barcode);
      }
    });
    SoundService.playTabSwitch();
  }

  void _clearSelection() {
    setState(() {
      _selectedBarcodes.clear();
    });
    SoundService.playTabSwitch();
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

    AdaptiveModalHelper.showAdaptiveModal(
      context: context,
      desktopMaxWidth: 560,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 12),
                Text(
                  'باركود: ${item.barcode} • التصنيف: ${item.category}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('product_name'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'سعر البيع (${AppConstants.currencySymbol})',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: costPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'سعر الشراء (${AppConstants.currencySymbol})',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        int val = int.tryParse(qtyController.text) ?? 12;
                        if (val > 1) {
                          val--;
                          setModalState(() => qtyController.text = val.toString());
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: existingProduct != null ? 'إضافة كمية للمخزون' : 'الكمية المستلمة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        int val = int.tryParse(qtyController.text) ?? 12;
                        val++;
                        setModalState(() => qtyController.text = val.toString());
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
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
                        final updated = existingProduct.copyWith(
                          name: name,
                          price: price,
                          costPrice: cost,
                          stock: existingProduct.stock + qty,
                          category: item.category,
                          imageUrl: existingProduct.imageUrl ?? item.imageUrl,
                          isTobacco: item.isTobacco || existingProduct.isTobacco,
                          cartonPrice: item.cartonPrice > 0 ? item.cartonPrice : existingProduct.cartonPrice,
                          wholesaleCartonPrice: item.wholesaleCartonPrice > 0 ? item.wholesaleCartonPrice : existingProduct.wholesaleCartonPrice,
                          wholesalePackPrice: item.wholesalePackPrice > 0 ? item.wholesalePackPrice : existingProduct.wholesalePackPrice,
                          singlePiecePrice: item.singlePiecePrice > 0 ? item.singlePiecePrice : existingProduct.singlePiecePrice,
                          piecesPerPack: item.piecesPerPack > 0 ? item.piecesPerPack : existingProduct.piecesPerPack,
                          packsPerCarton: item.packsPerCarton > 0 ? item.packsPerCarton : existingProduct.packsPerCarton,
                          unitType: item.unitType.isNotEmpty ? item.unitType : existingProduct.unitType,
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
                          category: item.category,
                          imageUrl: item.imageUrl,
                          isTobacco: item.isTobacco,
                          cartonPrice: item.cartonPrice,
                          wholesaleCartonPrice: item.wholesaleCartonPrice,
                          wholesalePackPrice: item.wholesalePackPrice,
                          singlePiecePrice: item.singlePiecePrice,
                          piecesPerPack: item.piecesPerPack,
                          packsPerCarton: item.packsPerCarton,
                          unitType: item.unitType,
                          wholesalePrice: item.wholesalePackPrice > 0 ? item.wholesalePackPrice : price,
                        );
                        context.read<ProductBloc>().add(AddProduct(newProduct));
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        SoundService.playSaveSuccess();
                        SnackbarHelper.showSuccess(context, 'تم حفظ "$name" في مخزون المحل');
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

  void _batchAddSelectedToShop(List<MasterCatalogItem> allItems, Map<String, Product> existingMap) {
    final selectedItems = allItems.where((i) => _selectedBarcodes.contains(i.barcode)).toList();
    if (selectedItems.isEmpty) return;

    for (var item in selectedItems) {
      final existing = existingMap[item.barcode.trim()];
      if (existing != null) {
        final updated = existing.copyWith(
          stock: existing.stock + 12,
          imageUrl: existing.imageUrl ?? item.imageUrl,
          isTobacco: item.isTobacco || existing.isTobacco,
          cartonPrice: item.cartonPrice > 0 ? item.cartonPrice : existing.cartonPrice,
          wholesaleCartonPrice: item.wholesaleCartonPrice > 0 ? item.wholesaleCartonPrice : existing.wholesaleCartonPrice,
          wholesalePackPrice: item.wholesalePackPrice > 0 ? item.wholesalePackPrice : existing.wholesalePackPrice,
          singlePiecePrice: item.singlePiecePrice > 0 ? item.singlePiecePrice : existing.singlePiecePrice,
          piecesPerPack: item.piecesPerPack > 0 ? item.piecesPerPack : existing.piecesPerPack,
          packsPerCarton: item.packsPerCarton > 0 ? item.packsPerCarton : existing.packsPerCarton,
          unitType: item.unitType.isNotEmpty ? item.unitType : existing.unitType,
        );
        context.read<ProductBloc>().add(UpdateProduct(updated));
      } else {
        final newProduct = Product(
          id: const Uuid().v4(),
          name: item.name,
          barcode: item.barcode,
          price: item.defaultPrice,
          costPrice: item.defaultCost,
          stock: 12,
          category: item.category,
          imageUrl: item.imageUrl,
          isTobacco: item.isTobacco,
          cartonPrice: item.cartonPrice,
          wholesaleCartonPrice: item.wholesaleCartonPrice,
          wholesalePackPrice: item.wholesalePackPrice,
          singlePiecePrice: item.singlePiecePrice,
          piecesPerPack: item.piecesPerPack,
          packsPerCarton: item.packsPerCarton,
          unitType: item.unitType,
          wholesalePrice: item.wholesalePackPrice > 0 ? item.wholesalePackPrice : item.defaultPrice,
        );
        context.read<ProductBloc>().add(AddProduct(newProduct));
      }
    }

    final count = selectedItems.length;
    _clearSelection();
    SoundService.playCheckoutSuccess();
    SnackbarHelper.showSuccess(context, 'تمت إضافة $count سلعة بنجاح إلى مخزون المحل!');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        final existingProducts = state.products;
        final existingProductsMap = {
          for (var p in existingProducts) p.barcode.trim(): p,
        };

        final allItems = MasterCatalogService.getAllItems();
        final filteredItems = MasterCatalogService.searchAndFilter(
          query: _searchQuery,
          category: _selectedCategory,
        );
        final displayedItems = filteredItems.take(_displayLimit).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مكتبة السلع الجزائرية (${allItems.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'حدد السلع واضغط إضافة جماعية للمحل',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث وتحميل الكتالوج',
                onPressed: () async {
                  await MasterCatalogService.instance.init();
                  setState(() {});
                  SnackbarHelper.showInfo(context, 'تم تحديث قائمة السلع (${allItems.length} منتج متوفر)');
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Search Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المنتج، الماركة (رامي، صومام...) أو الباركود...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Categories Horizontal Bar
              Container(
                height: 48,
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: MasterCatalogService.categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = MasterCatalogService.categories[index];
                    final isSelected = _selectedCategory == cat;
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
                          setState(() {
                            _selectedCategory = cat;
                            _displayLimit = 50;
                          });
                        }
                      },
                    );
                  },
                ),
              ),

              // Multi-selection actions row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filteredItems.length} سلعة مطابقة • (${_selectedBarcodes.length} محددة)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('تحديد الكل المعروض'),
                          onPressed: () => _selectAllInList(displayedItems),
                        ),
                        if (_selectedBarcodes.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('إلغاء التحديد', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ],
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
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: displayedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = displayedItems[index];
                          final existing = existingProductsMap[item.barcode.trim()];
                          final isInShop = existing != null;
                          final isSelected = _selectedBarcodes.contains(item.barcode);

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withOpacity(0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : (isInShop ? Colors.green.withOpacity(0.4) : Colors.grey[200]!),
                                width: isSelected ? 2 : (isInShop ? 1.5 : 1),
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
                                // Checkbox for multi-selection
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppTheme.primaryColor,
                                  onChanged: (_) => _toggleBarcodeSelection(item.barcode),
                                ),

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
          bottomNavigationBar: _selectedBarcodes.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تم تحديد ${_selectedBarcodes.length} منتج من الكتالوج',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('إلغاء التحديد', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'إضافة المحددة لمخزون المحل فوراً',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _batchAddSelectedToShop(allItems, existingProductsMap),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}