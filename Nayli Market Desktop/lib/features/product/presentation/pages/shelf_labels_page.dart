import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/shelf_label_generator.dart';
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

  // Label Configuration
  ShelfLabelSize _selectedSize = ShelfLabelSize.standard50x30;
  ShelfLabelTemplate _selectedTemplate = ShelfLabelTemplate.shelfTag;
  bool _includeShopName = true;
  bool _includeDate = true;
  bool _includeBarcode = true;
  bool _showHriDigits = true;
  double _barcodeHeight = 12.0;
  bool _isPrinting = false;

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

  ShelfLabelConfig _buildConfig() {
    return ShelfLabelConfig(
      size: _selectedSize,
      template: _selectedTemplate,
      includeShopName: _includeShopName,
      includeDate: _includeDate,
      includeBarcode: _includeBarcode,
      showHriDigits: _showHriDigits,
      barcodeHeight: _barcodeHeight,
      currencySymbol: 'دج',
      shopName: ShelfLabelGenerator.getEffectiveShopName(),
    );
  }

  List<MapEntry<Product, int>> _getSelectedEntries(List<Product> allProducts) {
    return allProducts
        .where((p) => _selectedProductIds.contains(p.id))
        .map((p) => MapEntry(p, _labelQuantities[p.id] ?? 1))
        .toList();
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
      _labelQuantities.clear();
    });
    SoundService.playScanBeep();
  }

  /// Print via Bluetooth Thermal Printer (ESC/POS)
  Future<void> _printThermalBluetooth(List<Product> allProducts) async {
    if (_isPrinting) return;
    final entries = _getSelectedEntries(allProducts);
    if (entries.isEmpty) {
      context.showAppSnackBar('يرجى اختيار سلعة واحدة على الأقل لطباعة ملصق الرف!', backgroundColor: Colors.orange[800]!);
      return;
    }

    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      if (mounted) {
        context.showAppSnackBar('⚠️ الطابعة الحرارية غير متصلة بالبلوتوث! يرجى توصيلها في الإعدادات أو استخدام طباعة ويندوز/PDF.', backgroundColor: Colors.red[800]!);
      }
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final bytes = ShelfLabelGenerator.generateEscPosBytes(
        itemsWithCopies: entries,
        config: _buildConfig(),
      );

      SoundService.playPrintSound();
      await PrintBluetoothThermal.writeBytes(bytes);

      SoundService.playCheckoutSuccess();
      if (mounted) {
        final totalCopies = entries.fold<int>(0, (s, e) => s + e.value);
        context.showAppSnackBar(
          '✅ تم إرسال $totalCopies ملصق رف إلى الطابعة الحرارية بنجاح!',
          backgroundColor: Colors.green[800]!,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('حدث خطأ أثناء الطباعة: $e', backgroundColor: Colors.red[800]!);
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  /// Print or Export via PDF / Windows Printer Dialog
  Future<void> _printPdfOrWindows(List<Product> allProducts) async {
    final entries = _getSelectedEntries(allProducts);
    if (entries.isEmpty) {
      context.showAppSnackBar('يرجى اختيار سلعة واحدة على الأقل لطباعة الملصقات!', backgroundColor: Colors.orange[800]!);
      return;
    }

    final config = _buildConfig();
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final docName = 'shelf_labels_${config.size.name}_$timestamp';

    SoundService.playTabSwitch();
    await Printing.layoutPdf(
      name: docName,
      format: config.size.pageFormat,
      onLayout: (PdfPageFormat format) async {
        return await ShelfLabelGenerator.generateLabelsPdf(
          itemsWithCopies: entries,
          config: config,
        );
      },
    );
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search & Select All
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
                    const SizedBox(height: 10),

                    // Label Size Selector Ribbon
                    Row(
                      children: [
                        const Icon(Icons.aspect_ratio_rounded, size: 15, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        const Text('مقاس الملصق:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'المحدد: ${_selectedProductIds.length}',
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final size in ShelfLabelSize.values) ...[
                            ChoiceChip(
                              label: Text(
                                size.displayName,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: _selectedSize == size ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: _selectedSize == size,
                              selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                              checkmarkColor: AppTheme.primaryColor,
                              onSelected: (v) {
                                if (v) setState(() => _selectedSize = size);
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Label Template Selector Ribbon
                    Row(
                      children: [
                        const Icon(Icons.dashboard_customize_rounded, size: 15, color: Colors.amber),
                        const SizedBox(width: 4),
                        const Text('نموذج التصميم:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final template in ShelfLabelTemplate.values) ...[
                            ChoiceChip(
                              label: Text(
                                template.displayName,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: _selectedTemplate == template ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selected: _selectedTemplate == template,
                              selectedColor: Colors.amber.withOpacity(0.25),
                              checkmarkColor: Colors.brown,
                              onSelected: (v) {
                                if (v) setState(() => _selectedTemplate = template);
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Options Switches (Wrap)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: const Text('اسم المحل', style: TextStyle(fontSize: 10.5)),
                          selected: _includeShopName,
                          onSelected: (v) => setState(() => _includeShopName = v),
                        ),
                        FilterChip(
                          label: const Text('خطوط الباركود', style: TextStyle(fontSize: 10.5)),
                          selected: _includeBarcode,
                          onSelected: (v) => setState(() => _includeBarcode = v),
                        ),
                        if (_includeBarcode)
                          FilterChip(
                            label: const Text('أرقام الكود', style: TextStyle(fontSize: 10.5)),
                            selected: _showHriDigits,
                            onSelected: (v) => setState(() => _showHriDigits = v),
                          ),
                        FilterChip(
                          label: const Text('التاريخ', style: TextStyle(fontSize: 10.5)),
                          selected: _includeDate,
                          onSelected: (v) => setState(() => _includeDate = v),
                        ),
                      ],
                    ),

                    if (_selectedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('تعيين نسخ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ...[1, 2, 5, 10, 20].map((qty) {
                            return ActionChip(
                              label: Text('$qty', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.amber.withOpacity(0.15),
                              side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                              onPressed: () => _setBatchQuantity(qty),
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Categories & Weighted Filter Ribbon
              Container(
                height: 38,
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
                                '${p.barcode.isNotEmpty ? p.barcode : 'بدون كود'} • السعر: ${p.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
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
            ],
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final totalCopies = _selectedProductIds.fold<int>(0, (sum, id) => sum + (_labelQuantities[id] ?? 1));
          final hasSelection = _selectedProductIds.isNotEmpty;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSelection) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المحدد: ${_selectedProductIds.length} سلعة • إجمالي النسخ: $totalCopies ملصق',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.preview_rounded, size: 18, color: Colors.teal),
                          label: const Text('معاينة حية 👁️', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                          onPressed: () => _showLivePreviewSheet(context, state.products),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      // Bluetooth Thermal Print Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: hasSelection ? AppTheme.primaryColor : Colors.grey,
                            side: BorderSide(color: hasSelection ? AppTheme.primaryColor : Colors.grey[300]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isPrinting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.bluetooth_connected_rounded, size: 20),
                          label: const Text('بلوتوث حراري 📱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          onPressed: (_isPrinting || !hasSelection) ? null : () => _printThermalBluetooth(state.products),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Windows / A4 / PDF Printing
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasSelection ? AppTheme.primaryColor : Colors.grey[400],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: hasSelection ? 2 : 0,
                          ),
                          icon: const Icon(Icons.print_rounded, size: 20),
                          label: Text(
                            hasSelection ? 'ويندوز / PDF ($totalCopies) 🖨️' : 'حدد سلعاً للطباعة',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          onPressed: hasSelection ? () => _printPdfOrWindows(state.products) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLivePreviewSheet(BuildContext context, List<Product> allProducts) {
    final selectedProducts = allProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;
    final first = selectedProducts.first;
    final config = _buildConfig();
    final copies = _labelQuantities[first.id] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.label_important_rounded, color: AppTheme.primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'معاينة الملصق (${config.size.displayName})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 16),

            // Realistic Label Card Mockup
            _buildInteractiveLabelPreviewCard(first, config),

            const SizedBox(height: 14),
            Text('سيتم طباعة $copies نسخ لهذه السلعة (${first.name})',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Print Action Inside Preview
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('طباعة الكل الآن 🖨️', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _printPdfOrWindows(allProducts);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveLabelPreviewCard(Product p, ShelfLabelConfig config) {
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    switch (config.template) {
      case ShelfLabelTemplate.productSticker:
        return Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black87, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.includeShopName)
                Text(config.shopName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                p.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (config.includeBarcode && p.barcode.isNotEmpty)
                _BarcodeStripeWidget(
                  barcode: p.barcode,
                  showDigits: config.showHriDigits,
                  height: 38,
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '${p.price.toStringAsFixed(0)} ${config.currencySymbol}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (config.includeDate)
                    Text(dateStr, style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );

      case ShelfLabelTemplate.scaleWeight:
        return Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal[800]!, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(config.shopName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: const Text('⚖️ ميزان', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سعر الكيلوغرام:', style: TextStyle(fontSize: 9.5, color: Colors.grey)),
                  Text('${p.price.toStringAsFixed(0)} ${config.currencySymbol}/كغ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                ],
              ),
              const SizedBox(height: 6),
              if (config.includeBarcode && p.barcode.isNotEmpty)
                _BarcodeStripeWidget(
                  barcode: p.barcode,
                  showDigits: config.showHriDigits,
                  height: 32,
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('طازج يومياً', style: TextStyle(fontSize: 8.5, color: Colors.teal, fontWeight: FontWeight.bold)),
                  if (config.includeDate)
                    Text(dateStr, style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );

      case ShelfLabelTemplate.shelfTag:
      default:
        return Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black87, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.includeShopName)
                Text(config.shopName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                p.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${p.price.toStringAsFixed(0)} ${config.currencySymbol}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
              ),
              if (config.includeBarcode && p.barcode.isNotEmpty) ...[
                const SizedBox(height: 4),
                _BarcodeStripeWidget(
                  barcode: p.barcode,
                  showDigits: config.showHriDigits,
                  height: 28,
                ),
              ],
              if (config.includeDate) ...[
                const SizedBox(height: 4),
                Text('تاريخ: $dateStr', style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
              ],
            ],
          ),
        );
    }
  }
}

/// A lightweight, clean vector simulation of 1D barcode lines for UI preview
class _BarcodeStripeWidget extends StatelessWidget {
  final String barcode;
  final bool showDigits;
  final double height;

  const _BarcodeStripeWidget({
    required this.barcode,
    this.showDigits = true,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final clean = barcode.trim();
    if (clean.isEmpty) return const SizedBox.shrink();

    // Deterministic bar widths pattern based on string
    final chars = clean.codeUnits;
    final List<int> barWidths = [2, 1, 3, 1]; // Start guard
    for (int i = 0; i < chars.length; i++) {
      final v = chars[i];
      barWidths.add((v % 3) + 1);
      barWidths.add(((v ~/ 3) % 2) + 1);
    }
    barWidths.addAll([1, 2, 1, 3]); // Stop guard

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < barWidths.length && i < 40; i++)
                Container(
                  width: barWidths[i].toDouble(),
                  color: (i % 2 == 0) ? Colors.black : Colors.transparent,
                ),
            ],
          ),
        ),
        if (showDigits) ...[
          const SizedBox(height: 2),
          Text(
            clean,
            style: const TextStyle(
              fontSize: 8.5,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
