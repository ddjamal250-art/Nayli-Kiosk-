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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                            hintText: 'Scan or enter barcode',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey[400],
                            ),
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: () => _scanQR(state.products),
                          padding: const EdgeInsets.all(15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                ],
              );
            }),
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

                final filteredProducts = state.products
                    .where((product) =>
                        product.name.toLowerCase().contains(_searchQuery) ||
                        product.barcode.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filteredProducts.isEmpty) {
                  return const Center(
                      child: Text('No products match your search.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${AppConstants.currencySymbol} ${product.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700]),
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
                                      child: Builder(
                                        builder: (_) {
                                          final isWeighable = product.barcode.startsWith('SCALE_') || product.name.contains('ميزان') || product.name.contains('كغ');
                                          final stockText = isWeighable
                                              ? '${product.stock} كغ'
                                              : '${product.stock} ${context.tr('in_stock')}';
                                          return Text(
                                            product.stock > 5
                                                ? stockText
                                                : (product.stock > 0
                                                    ? '${product.stock} ${context.tr('low_stock')}'
                                                    : context.tr('out_of_stock')),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: product.stock > 5
                                                  ? Colors.green[800]
                                                  : (product.stock > 0
                                                      ? Colors.orange[800]
                                                      : Colors.red[800]),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.label_important_outline,
                                      color: Colors.amber, size: 20),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'طباعة بطاقة الرف 🏷️',
                                  padding: const EdgeInsets.all(8),
                                  onPressed: () => _printSingleShelfLabel(context, product),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppTheme.primaryColor, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
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
                              const SizedBox(width: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(8),
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

    String shopName = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());

    try {
      final List<int> bytes = [];
      bytes.addAll([27, 64]); // Initialize
      bytes.addAll([27, 97, 1]); // Center align
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
      bytes.addAll([29, 86, 66, 0]); // Cut paper

      await PrintBluetoothThermal.writeBytes(bytes);
      SoundService.playCheckoutSuccess();
      if (context.mounted) {
        context.showAppSnackBar(
          '✅ تم إرسال ملصق الرف لـ (${product.name}) إلى الطابعة بنجاح!',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
      }
    }
  }
}

