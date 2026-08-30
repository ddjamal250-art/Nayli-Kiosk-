import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ShelfLabelsPage extends StatefulWidget {
  const ShelfLabelsPage({super.key});

  @override
  State<ShelfLabelsPage> createState() => _ShelfLabelsPageState();
}

class _ShelfLabelsPageState extends State<ShelfLabelsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedProductIds = {};
  final Map<String, int> _labelQuantities = {};
  String _selectedCategoryFilter = 'الكل';
  bool _includeShopName = true;
  bool _includeDate = true;
  bool _includeBarcode = true;
  String _labelSize = 'medium'; // 'small', 'medium', 'large'

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleProduct(String id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
        _labelQuantities[id] = _labelQuantities[id] ?? 1;
      }
    });
    SoundService.playScanBeep();
  }

  void _selectAll(List<Product> products) {
    setState(() {
      for (final p in products) {
        _selectedProductIds.add(p.id);
        _labelQuantities[p.id] = _labelQuantities[p.id] ?? 1;
      }
    });
    SoundService.playScanBeep();
  }

  void _setBatchQuantity(int qty) {
    setState(() {
      for (final id in _selectedProductIds) {
        _labelQuantities[id] = qty;
      }
    });
    SoundService.playScanBeep();
    context.showAppSnackBar('🏷️ تم تعيين $qty ملصقات لكل السلع المحددة!');
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
    });
  }

  Future<void> _printSelectedLabels(List<Product> allProducts) async {
    final selectedProds = allProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selectedProds.isEmpty) {
      context.showAppSnackBar('يرجى اختيار سلعة واحدة على الأقل لطباعة ملصق الرف!', backgroundColor: Colors.orange[800]!);
      return;
    }

    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      context.showAppSnackBar('⚠️ الطابعة الحرارية غير متصلة بالبلوتوث! يرجى توصيلها في الإعدادات.', backgroundColor: Colors.red[800]!);
      return;
    }

    // Get Shop Name
    String shopName = AppConstants.defaultShopName;
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());

    try {
      final List<int> bytes = [];

      for (final p in selectedProds) {
        final count = _labelQuantities[p.id] ?? 1;
        for (int c = 0; c < count; c++) {
          // ESC/POS Label Format
          bytes.addAll([27, 64]); // Initialize
          bytes.addAll([27, 97, 1]); // Center align

          if (_includeShopName) {
            bytes.addAll([27, 33, 0]); // Normal
            bytes.addAll('$shopName\n'.codeUnits);
          }

          bytes.addAll([27, 33, 16]); // Double height (Product Name)
          bytes.addAll('${p.name}\n'.codeUnits);

          bytes.addAll([27, 33, 48]); // Double width + double height (Huge Price)
          bytes.addAll('${p.price.toStringAsFixed(0)} DZD\n'.codeUnits);

          if (_includeBarcode && p.barcode.isNotEmpty) {
            bytes.addAll([27, 33, 0]); // Normal
            bytes.addAll('||||| ${p.barcode} |||||\n'.codeUnits);
          }

          if (_includeDate) {
            bytes.addAll([27, 33, 0]);
            bytes.addAll('Date: $dateStr\n'.codeUnits);
          }

          bytes.addAll('--------------------------------\n\n'.codeUnits);
        }
      }

      bytes.addAll([29, 86, 66, 0]); // Cut paper
      await PrintBluetoothThermal.writeBytes(bytes);

      SoundService.playCheckoutSuccess();
      if (mounted) {
        context.showAppSnackBar(
          '✅ تم إرسال ${selectedProds.length} ملصق رف إلى الطابعة بنجاح!',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مولد ملصقات الرفوف والباركود 🏷️',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = state.products.where((p) {
            final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query) || p.barcode.contains(query);
            if (!matchesQuery) return false;

            if (_selectedCategoryFilter == 'الكل') return true;
            if (_selectedCategoryFilter == '⚖️ مواد الميزان') {
              return p.isWeighted || p.barcode.startsWith('SCALE_') || p.name.contains('ميزان') || p.name.contains('كغ');
            }
            return p.category == _selectedCategoryFilter;
          }).toList();

          return Column(
            children: [
              // Top Action Header (Options & Selection count)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'ابحث عن السلع المراد طباعة أسعارها...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _searchCtrl.clear()),
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _selectAll(filtered),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('تحديد الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        if (_selectedProductIds.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.clear_all, color: Colors.red),
                            tooltip: 'إلغاء التحديد',
                            onPressed: _clearSelection,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Options Switches Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('اسم المحل', style: TextStyle(fontSize: 11)),
                              selected: _includeShopName,
                              onSelected: (v) => setState(() => _includeShopName = v),
                            ),
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('الباركود', style: TextStyle(fontSize: 11)),
                              selected: _includeBarcode,
                              onSelected: (v) => setState(() => _includeBarcode = v),
                            ),
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('التاريخ', style: TextStyle(fontSize: 11)),
                              selected: _includeDate,
                              onSelected: (v) => setState(() => _includeDate = v),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'المحدد: ${_selectedProductIds.length}',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('تعيين عدد النسخ للكل:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(width: 6),
                          Wrap(
                            spacing: 6,
                            children: [1, 2, 5, 10, 20].map((qty) {
                              return ActionChip(
                                label: Text('$qty', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.amber.withOpacity(0.15),
                                side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                                onPressed: () => _setBatchQuantity(qty),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Categories & Weighted Filter Ribbon
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categoryTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = _categoryTabs[idx];
                    final isSelected = _selectedCategoryFilter == cat;
                    return FilterChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: cat == '⚖️ مواد الميزان' ? Colors.teal : AppTheme.primaryColor,
                      backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) {
                        setState(() => _selectedCategoryFilter = cat);
                        SoundService.playScanBeep();
                      },
                    );
                  },
                ),
              ),

              // Products List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.label_off_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            const Text('لا توجد سلع مطابقة في المخزون', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final isSelected = _selectedProductIds.contains(p.id);
                          final qty = _labelQuantities[p.id] ?? 1;

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withOpacity(0.04) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (_) => _toggleProduct(p.id),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(
                                '${p.barcode} • السعر: ${p.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              trailing: isSelected
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey),
                                          onPressed: () {
                                            if (qty > 1) {
                                              setState(() => _labelQuantities[p.id] = qty - 1);
                                            }
                                          },
                                        ),
                                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryColor),
                                          onPressed: () {
                                            setState(() => _labelQuantities[p.id] = qty + 1);
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                              onTap: () => _toggleProduct(p.id),
                            ),
                          );
                        },
                      ),
              ),

              // Live Shelf Tag Preview Box
              if (_selectedProductIds.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final firstSelected = filtered.firstWhere((p) => _selectedProductIds.contains(p.id), orElse: () => filtered.first);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[100],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('معاينة شكل بطاقة الرف الحقيقية:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Center(
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black87, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                              ),
                              child: Column(
                                children: [
                                  if (_includeShopName)
                                    const Text('🏪 سوبرماركت النايلي', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text(
                                    firstSelected.name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${firstSelected.price.toStringAsFixed(0)} دج',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  if (_includeBarcode)
                                    Text('||||| ${firstSelected.barcode} |||||', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', letterSpacing: 1.5)),
                                  if (_includeDate)
                                    Text('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // Bottom Print Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.print, size: 20),
                    label: Text(
                      'طباعة الملصقات المحددة (${_selectedProductIds.length} بطاقة)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _printSelectedLabels(state.products),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
