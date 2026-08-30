import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../shop/data/models/shop_model.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/security_pin_helper.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'الكل';

  static const List<String> _categoryTabs = [
    'الكل',
    '⚖️ مواد الميزان',
    'مواد غذائية ومعلبات',
    'حليب ومشتقاته',
    'مخبوزات وعجائن',
    'مشروبات ومياه',
    'نظافة وتجميل',
    'حلويات وسكاكر',
    'خضر وفواكه',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      final matchedProduct =
          products.where((p) => p.barcode.trim() == barcode.trim()).firstOrNull;
      if (matchedProduct != null) {
        _searchController.text = matchedProduct.name;
        if (mounted) {
          context.push('/products/edit/${matchedProduct.id}', extra: matchedProduct);
        }
      } else {
        _searchController.text = barcode;
      }
    }
  }

  void _showQuickRestockModal(Product product) {
    int addQty = 10;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                  Row(
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      Text('استلام شحنة جديدة 📦', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('المخزون الحالي: ${product.stock} ${product.isWeighted ? "كغ" : "قطعة"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('اختر الكمية المضافة للشحنة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: addQty > 1 ? () => setModalState(() => addQty--) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text('+$addQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => setModalState(() => addQty++),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [5, 10, 24, 50, 100].map((amt) {
                  return ActionChip(
                    label: Text('+$amt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    backgroundColor: addQty == amt ? Colors.green.withOpacity(0.2) : Colors.grey[100],
                    onPressed: () => setModalState(() => addQty = amt),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text('تأكيد إضافة +$addQty إلى المخزن (المجموع: ${product.stock + addQty})', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  final updated = Product(
                    id: product.id,
                    name: product.name,
                    barcode: product.barcode,
                    price: product.price,
                    costPrice: product.costPrice,
                    wholesalePrice: product.wholesalePrice,
                    stock: product.stock + addQty,
                    category: product.category,
                    isWeighted: product.isWeighted,
                    expiryDate: product.expiryDate,
                  );
                  context.read<ProductBloc>().add(UpdateProduct(updated));
                  SoundService.playCheckoutSuccess();
                  context.showAppSnackBar('✅ تم استلام الشحنة وتحديث المخزون بنجاح!');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pinToQuickSale(BuildContext context, Product product) async {
    final box = HiveDatabase.quickItemsBox;
    final id = 'quick_${product.id}';
    final item = {
      'id': id,
      'name': product.name,
      'price': product.price,
      'costPrice': product.costPrice,
      'icon': '🛍️',
      'linkedProductId': product.id,
    };
    await box.put(id, item);
    SoundService.playScanBeep();
    if (context.mounted) {
      context.showAppSnackBar(
        '⚡ تم تثبيت (${product.name}) في شريط البيع السريع بنجاح!',
        backgroundColor: Colors.teal[800]!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(context.tr('products_management'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),
            tooltip: context.tr('export_excel'),
            onPressed: () {
              final productState = context.read<ProductBloc>().state;
              final products = productState.products;
              final buffer = StringBuffer();
              buffer.writeln('Code-Barres,Nom Produit,Prix Vente (DA),Prix Achat (DA),Stock');
              for (final p in products) {
                buffer.writeln('"${p.barcode}","${p.name}",${p.price},${p.costPrice},${p.stock}');
              }

              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.table_view, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(context.tr('export_excel'), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${context.tr('exported_success')} (${products.length} articles)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            buffer.toString(),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.tr('close')),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
            tooltip: 'كتالوج السلع الجزائرية (15,500+)',
            onPressed: () => context.push('/products/catalog'),
          ),
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryColor),
            tooltip: 'فواتير الموردين والمشتريات',
            onPressed: () => context.push('/products/supplier-invoices'),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: AppTheme.primaryColor),
            tooltip: context.tr('stock_in'),
            onPressed: () => context.push('/products/stock-in'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Master Catalog Quick Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              onTap: () => context.push('/products/catalog'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor.withOpacity(0.12), AppTheme.primaryColor.withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مكتبة السلع الجزائرية (15,500+ منتج)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                          Text('استورد السلع الجاهزة وأسعارها لمخزونك بدون مسح فردي',
                              style: TextStyle(fontSize: 10, color: Colors.black87)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
          ),

          // Quick Tools Row (Shelf Price Tags, Inventory Audit & Invoices)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/inventory-audit'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_rounded, size: 15, color: Colors.teal),
                          SizedBox(width: 4),
                          Text('الجرد ورأس المال 📋', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/shelf-labels'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.label_important_outline, size: 15, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('ملصقات الرفوف 🏷️', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/products/supplier-invoices'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 15, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('فواتير الموردين 🚚', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم أو الباركود...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),

          // Categories & Scale Items Horizontal Filter Ribbon
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              return Container(
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categoryTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = _categoryTabs[idx];
                    final isSelected = _selectedCategoryFilter == cat;

                    // Calculate count for this tab
                    int count = 0;
                    if (cat == 'الكل') {
                      count = state.products.length;
                    } else if (cat == '⚖️ مواد الميزان') {
                      count = state.products.where((p) => p.isWeighted || p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ')).length;
                    } else {
                      count = state.products.where((p) => p.category == cat).length;
                    }

                    return FilterChip(
                      label: Text(
                        '$cat ($count)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: cat == '⚖️ مواد الميزان' ? Colors.teal : AppTheme.primaryColor,
                      backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryFilter = cat;
                        });
                        SoundService.playScanBeep();
                      },
                    );
                  },
                ),
              );
            },
          ),

          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listener: (context, state) {
                if (state.status == ProductStatus.success &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.green),
                  );
                } else if (state.status == ProductStatus.error &&
                    state.message != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(state.message!),
                        backgroundColor: Colors.red),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == ProductStatus.loading &&
                    state.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.products.isEmpty) {
                  if (state.status == ProductStatus.error) {
                    return Center(child: Text('Error: ${state.message}'));
                  }
                  return const Center(
                      child: Text('No products found. Add some!'));
                }

                final filteredProducts = state.products.where((product) {
                  final matchesSearch = product.name.toLowerCase().contains(_searchQuery) ||
                      product.barcode.toLowerCase().contains(_searchQuery);
                  if (!matchesSearch) return false;

                  if (_selectedCategoryFilter == 'الكل') return true;
                  if (_selectedCategoryFilter == '⚖️ مواد الميزان') {
                    return product.isWeighted ||
                        product.barcode.startsWith('SCALE_') ||
                        product.name.contains('ميزان') ||
                        product.name.contains('كغ');
                  }
                  return product.category == _selectedCategoryFilter;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('لا توجد سلع في قسم "$_selectedCategoryFilter"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isWeighable = product.isWeighted || product.barcode.startsWith('SCALE_') || product.name.contains('ميزان') || product.name.contains('كغ');

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5),
                                      ),
                                    ),
                                    if (isWeighable) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                        ),
                                        child: const Text('⚖️ ميزان', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: product.stock > 5
                                            ? Colors.green.withOpacity(0.1)
                                            : (product.stock > 0
                                                ? Colors.orange.withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isWeighable
                                            ? '${product.stock} كغ'
                                            : '${product.stock} ${context.tr('in_stock')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: product.stock > 5
                                              ? Colors.green[800]
                                              : (product.stock > 0
                                                  ? Colors.orange[800]
                                                  : Colors.red[800]),
                                        ),
                                      ),
                                    ),
                                    if (product.category.isNotEmpty && product.category != 'عام') ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(product.category, style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Quick Arrivage Restock Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add_shopping_cart_rounded,
                                      color: Colors.green, size: 19),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'استلام شحنة سريعة 📦',
                                  padding: const EdgeInsets.all(7),
                                  onPressed: () => _showQuickRestockModal(product),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.label_important_outline,
                                      color: Colors.amber, size: 19),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'طباعة بطاقة الرف 🏷️',
                                  padding: const EdgeInsets.all(7),
                                  onPressed: () => _printSingleShelfLabel(context, product),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppTheme.primaryColor, size: 19),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'تعديل السلعة والاستلام الكامل',
                                  padding: const EdgeInsets.all(7),
                                  onPressed: () async {
                                    final auth = await SecurityPinHelper.authenticate(
                                      context,
                                      title: 'تعديل السلعة والأسعار',
                                    );
                                    if (auth && context.mounted) {
                                      context.push('/products/edit/${product.id}',
                                          extra: product);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 19),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(7),
                                  onPressed: () =>
                                      _confirmDelete(context, product),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final auth = await SecurityPinHelper.authenticate(
            context,
            title: 'إضافة سلعة جديدة',
          );
          if (auth && context.mounted) {
            context.push('/products/add');
          }
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) async {
    final auth = await SecurityPinHelper.authenticate(
      context,
      title: 'حذف السلعة نهائياً',
    );
    if (!auth || !context.mounted) return;

    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: const Text('حذف السلعة'),
          content: Text('هل أنت متأكد من حذف ${product.name} نهائياً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductBloc>().add(DeleteProduct(product.id));
                Navigator.pop(innerContext);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printSingleShelfLabel(BuildContext context, Product product) async {
    int copies = 1;
    String shopName = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.label_important_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('طباعة ملصق الرف 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live Tag Preview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                ),
                child: Column(
                  children: [
                    Text('🏪 $shopName', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      '${product.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                    if (product.barcode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('||||| ${product.barcode} |||||', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', letterSpacing: 1.2)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quantity Selector Row
              const Text('عدد النسخ المراد طباعتها:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final count in [1, 2, 3, 5]) ...[
                    ChoiceChip(
                      label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      selected: copies == count,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      onSelected: (v) {
                        if (v) setDialogState(() => copies = count);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.print, size: 18),
              label: Text('طباعة ($copies)', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                final isConnected = await PrintBluetoothThermal.connectionStatus;
                if (!isConnected) {
                  if (context.mounted) {
                    context.showAppSnackBar(
                      '⚠️ الطابعة الحرارية غير متصلة! يرجى تشغيل البلوتوث وتوصيلها في الإعدادات.',
                      backgroundColor: Colors.orange[800]!,
                    );
                  }
                  return;
                }

                final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
                try {
                  final List<int> bytes = [];
                  for (int i = 0; i < copies; i++) {
                    bytes.addAll([27, 64]); // Initialize
                    bytes.addAll([27, 97, 1]); // Center
                    bytes.addAll('$shopName\n'.codeUnits);
                    bytes.addAll([27, 33, 16]); // Double height
                    bytes.addAll('${product.name}\n'.codeUnits);
                    bytes.addAll([27, 33, 48]); // Huge Price
                    bytes.addAll('${product.price.toStringAsFixed(0)} DZD\n'.codeUnits);
                    if (product.barcode.isNotEmpty) {
                      bytes.addAll([27, 33, 0]);
                      bytes.addAll('||||| ${product.barcode} |||||\n'.codeUnits);
                    }
                    bytes.addAll([27, 33, 0]);
                    bytes.addAll('Date: $dateStr\n'.codeUnits);
                    bytes.addAll('--------------------------------\n\n'.codeUnits);
                  }
                  bytes.addAll([29, 86, 66, 0]); // Cut paper
                  await PrintBluetoothThermal.writeBytes(bytes);
                  SoundService.playCheckoutSuccess();
                  if (context.mounted) {
                    context.showAppSnackBar(
                      '✅ تم إرسال $copies ملصق رف لـ (${product.name}) إلى الطابعة بنجاح!',
                      backgroundColor: Colors.green[800]!,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

