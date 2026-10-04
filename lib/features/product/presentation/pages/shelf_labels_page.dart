import 'dart:io';
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
  LabelCodeType _selectedCodeType = LabelCodeType.barcode1D;
  bool _autoFillA4Sheet = true;
  bool _includeShopName = true;
  bool _includeDate = true;
  bool _includeBarcode = true;
  bool _showHriDigits = true;
  double _barcodeHeight = 12.0;
  bool _isPrinting = false;

  // Custom Size dimensions (mm)
  double _customWidthMm = 50.0;
  double _customHeightMm = 30.0;
  double _customMarginMm = 1.5;
  late TextEditingController _customWidthCtrl;
  late TextEditingController _customHeightCtrl;
  late TextEditingController _customMarginCtrl;

  // Label Element Ordering & Alignments
  List<String> _elementOrder = List<String>.from(ShelfLabelConfig.defaultElementOrder);
  Map<String, String> _elementAlignments = Map<String, String>.from(ShelfLabelConfig.defaultElementAlignments);
  int _previewRevision = 0;

  static const Map<String, ({String title, IconData icon, String subtitle})> _kLabelElementInfo = {
    'shop_name': (title: 'اسم المحل / المتجر', icon: Icons.storefront_rounded, subtitle: 'يظهر في أعلى أو منتصف الملصق'),
    'product_name': (title: 'اسم السلعة والوصف', icon: Icons.shopping_bag_rounded, subtitle: 'اسم المنتوج بخط واضح وبارز'),
    'price': (title: 'السعر والعملة', icon: Icons.monetization_on_rounded, subtitle: 'السعر بالخط العريض مع العملة دج'),
    'barcode': (title: 'خطوط الباركود والأرقام', icon: Icons.qr_code_scanner_rounded, subtitle: 'خطوط الكود وأرقام القراءة الضوئية'),
    'date_unit': (title: 'التاريخ / الوحدة', icon: Icons.calendar_today_rounded, subtitle: 'تاريخ اليوم أو وحدة الكغ أو طازج يومياً'),
  };

  @override
  void initState() {
    super.initState();
    final box = HiveDatabase.settingsBox;
    _customWidthMm = (box.get('shelf_label_custom_width', defaultValue: 50.0) as num).toDouble();
    _customHeightMm = (box.get('shelf_label_custom_height', defaultValue: 30.0) as num).toDouble();
    _customMarginMm = (box.get('shelf_label_custom_margin', defaultValue: 1.5) as num).toDouble();
    final savedSizeName = box.get('shelf_label_saved_size');
    if (savedSizeName != null) {
      final found = ShelfLabelSize.values.where((s) => s.name == savedSizeName).firstOrNull;
      if (found != null) _selectedSize = found;
    }
    final savedCodeType = box.get('shelf_label_code_type');
    if (savedCodeType != null) {
      final found = LabelCodeType.values.where((c) => c.name == savedCodeType).firstOrNull;
      if (found != null) _selectedCodeType = found;
    }
    _autoFillA4Sheet = box.get('shelf_label_autofill_a4', defaultValue: true);
    final savedOrder = box.get('shelf_label_element_order');
    if (savedOrder is List) {
      _elementOrder = savedOrder.map((e) => e.toString()).toList();
      for (final def in ShelfLabelConfig.defaultElementOrder) {
        if (!_elementOrder.contains(def)) {
          _elementOrder.add(def);
        }
      }
    }
    final savedAligns = box.get('shelf_label_element_alignments');
    if (savedAligns is Map) {
      _elementAlignments = savedAligns.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    _customWidthCtrl = TextEditingController(text: (_customWidthMm == _customWidthMm.roundToDouble() ? (_customWidthMm == _customWidthMm.roundToDouble() ? _customWidthMm.toInt().toString() : _customWidthMm.toString()) : _customWidthMm.toString()));
    _customHeightCtrl = TextEditingController(text: (_customHeightMm == _customHeightMm.roundToDouble() ? (_customHeightMm == _customHeightMm.roundToDouble() ? _customHeightMm.toInt().toString() : _customHeightMm.toString()) : _customHeightMm.toString()));
    _customMarginCtrl = TextEditingController(text: _customMarginMm.toStringAsFixed(1));
  }

  void _moveElementUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _elementOrder.removeAt(index);
      _elementOrder.insert(index - 1, item);
      _previewRevision++;
    });
    HiveDatabase.settingsBox.put('shelf_label_element_order', _elementOrder);
    SoundService.playTabSwitch();
  }

  void _moveElementDown(int index) {
    if (index >= _elementOrder.length - 1) return;
    setState(() {
      final item = _elementOrder.removeAt(index);
      _elementOrder.insert(index + 1, item);
      _previewRevision++;
    });
    HiveDatabase.settingsBox.put('shelf_label_element_order', _elementOrder);
    SoundService.playTabSwitch();
  }

  void _setElementAlignment(String key, String align) {
    setState(() {
      _elementAlignments[key] = align;
      _previewRevision++;
    });
    HiveDatabase.settingsBox.put('shelf_label_element_alignments', _elementAlignments);
  }

  void _resetElementOrderAndAlign() {
    setState(() {
      _elementOrder = List<String>.from(ShelfLabelConfig.defaultElementOrder);
      _elementAlignments = Map<String, String>.from(ShelfLabelConfig.defaultElementAlignments);
      _previewRevision++;
    });
    HiveDatabase.settingsBox.put('shelf_label_element_order', _elementOrder);
    HiveDatabase.settingsBox.put('shelf_label_element_alignments', _elementAlignments);
    SoundService.playTabSwitch();
    context.showAppSnackBar('تمت استعادة ترتيب ومحاذاة عناصر الملصق الافتراضية!');
  }

  static const List<String> _categoryTabs = [
    'الكل',
    '⚖️ مواد الميزان',
    '📚 أدوات مدرسية ومكتبية',
    '🚬 تبغ وسجائر',
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
    _customWidthCtrl.dispose();
    _customHeightCtrl.dispose();
    _customMarginCtrl.dispose();
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
      codeType: _selectedCodeType,
      autoFillA4Sheet: _autoFillA4Sheet,
      currencySymbol: 'دج',
      shopName: ShelfLabelGenerator.getEffectiveShopName(),
      customWidthMm: _customWidthMm,
      customHeightMm: _customHeightMm,
      customMarginMm: _customMarginMm,
      elementOrder: _elementOrder,
      elementAlignments: _elementAlignments,
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

    bool isConnected = false;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      isConnected = await PrintBluetoothThermal.connectionStatus;
    }
    
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
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        await PrintBluetoothThermal.writeBytes(bytes);
      }

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
  Future<void> _printPdfOrWindows(List<Product> allProducts, {List<MapEntry<Product, int>>? directEntries}) async {
    final entries = directEntries ?? _getSelectedEntries(allProducts);
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
      format: config.effectivePageFormat,
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
            if (_selectedCategoryFilter == '📚 أدوات مدرسية ومكتبية') {
              final cat = p.category.toLowerCase();
              return cat.contains('مدرس') || cat.contains('مكتب') || cat.contains('ورق') || cat.contains('كراس') || cat.contains('قلم') || cat.contains('papeterie');
            }
            if (_selectedCategoryFilter == '🚬 تبغ وسجائر') {
              return p.isTobacco || p.category.contains('تبغ') || p.category.contains('سجائر') || p.category.contains('شمة') || p.category.contains('معسل');
            }
            return p.category == _selectedCategoryFilter || p.category.contains(_selectedCategoryFilter);
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
                        Icon(Icons.aspect_ratio_rounded, size: 15, color: AppTheme.primaryColor),
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
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
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
                                if (v) {
                                  setState(() => _selectedSize = size);
                                  HiveDatabase.settingsBox.put('shelf_label_saved_size', size.name);
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    if (_selectedSize == ShelfLabelSize.custom) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo.shade200, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.straighten_rounded, size: 16, color: Colors.indigo),
                                const SizedBox(width: 6),
                                const Text(
                                  'تخصيص أبعاد الملصق (بالمليمتر mm):',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(_customWidthMm == _customWidthMm.roundToDouble() ? (_customWidthMm == _customWidthMm.roundToDouble() ? _customWidthMm.toInt().toString() : _customWidthMm.toString()) : _customWidthMm.toString())} × ${(_customHeightMm == _customHeightMm.roundToDouble() ? (_customHeightMm == _customHeightMm.roundToDouble() ? _customHeightMm.toInt().toString() : _customHeightMm.toString()) : _customHeightMm.toString())} مم',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _customWidthCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'العرض (مم)',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null && parsed >= 15 && parsed <= 300) {
                                        setState(() => _customWidthMm = parsed);
                                        HiveDatabase.settingsBox.put('shelf_label_custom_width', parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _customHeightCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'الارتفاع (مم)',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null && parsed >= 10 && parsed <= 300) {
                                        setState(() => _customHeightMm = parsed);
                                        HiveDatabase.settingsBox.put('shelf_label_custom_height', parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _customMarginCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'الهامش (مم)',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null && parsed >= 0.0 && parsed <= 20) {
                                        setState(() => _customMarginMm = parsed);
                                        HiveDatabase.settingsBox.put('shelf_label_custom_margin', parsed);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('مقاسات سريعة:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ...[
                                  [40, 20],
                                  [40, 30],
                                  [50, 25],
                                  [50, 30],
                                  [60, 40],
                                  [70, 35],
                                  [80, 50],
                                  [100, 50],
                                ].map((dims) {
                                  final w = dims[0].toDouble();
                                  final h = dims[1].toDouble();
                                  final isMatch = _customWidthMm == w && _customHeightMm == h;
                                  return ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text('${dims[0]}×${dims[1]}', style: TextStyle(fontSize: 9.5, fontWeight: isMatch ? FontWeight.bold : FontWeight.normal)),
                                    backgroundColor: isMatch ? Colors.indigo.withOpacity(0.18) : Colors.grey.shade100,
                                    side: BorderSide(color: isMatch ? Colors.indigo.shade300 : Colors.grey.shade300),
                                    onPressed: () {
                                      setState(() {
                                        _customWidthMm = w;
                                        _customHeightMm = h;
                                        _customWidthCtrl.text = (w == w.roundToDouble() ? (w == w.roundToDouble() ? w.toInt().toString() : w.toString()) : w.toString());
                                        _customHeightCtrl.text = (h == h.roundToDouble() ? (h == h.roundToDouble() ? h.toInt().toString() : h.toString()) : h.toString());
                                      });
                                      HiveDatabase.settingsBox.put('shelf_label_custom_width', w);
                                      HiveDatabase.settingsBox.put('shelf_label_custom_height', h);
                                    },
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        if (_selectedSize == ShelfLabelSize.sheetA4_24 || _selectedSize == ShelfLabelSize.sheetA4_40)
                          FilterChip(
                            avatar: const Icon(Icons.auto_awesome, size: 14, color: Colors.indigo),
                            label: const Text('ملء كامل ورقة A4 تلقائياً', style: TextStyle(fontSize: 10.5)),
                            selected: _autoFillA4Sheet,
                            selectedColor: Colors.indigo.withOpacity(0.18),
                            onSelected: (v) {
                              setState(() {
                                _autoFillA4Sheet = v;
                                _previewRevision++;
                              });
                              HiveDatabase.settingsBox.put('shelf_label_autofill_a4', v);
                            },
                          ),
                      ],
                    ),

                    // Code Type Selector (1D Barcode / 2D QR Code / Both)
                    if (_includeBarcode) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.teal),
                          const SizedBox(width: 4),
                          const Text('نوع الكود:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: LabelCodeType.values.map((codeType) {
                                  final isSel = _selectedCodeType == codeType;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6.0),
                                    child: ChoiceChip(
                                      label: Text(
                                        codeType.displayName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          color: isSel ? Colors.teal.shade900 : Colors.black87,
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: Colors.teal.withOpacity(0.22),
                                      checkmarkColor: Colors.teal.shade800,
                                      onSelected: (v) {
                                        if (v) {
                                          setState(() {
                                            _selectedCodeType = codeType;
                                            _previewRevision++;
                                          });
                                          HiveDatabase.settingsBox.put('shelf_label_code_type', codeType.name);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Label Element Ordering & Alignments Expansion Card
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.25)),
                        ),
                        child: ExpansionTile(
                          dense: true,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          leading: const Icon(Icons.reorder_rounded, size: 20, color: Colors.orange),
                          title: const Text(
                            'ترتيب ومحاذاة عناصر الملصق (التقديم والتأخير والمحاذاة) 🔀',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'رتّب موضع كل عنصر وحدد محاذاته (يمين، وسط، يسار):',
                                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.orange),
                                  label: const Text('الافتراضي', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                                  onPressed: _resetElementOrderAndAlign,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            for (int i = 0; i < _elementOrder.length; i++) ...[
                              _buildElementOrderTile(_elementOrder[i], i),
                              if (i < _elementOrder.length - 1) const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),
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
                                '${p.barcode.isNotEmpty ? p.barcode : 'بدون كود'} • السعر: ${(p.price == p.price.roundToDouble() ? (p.price == p.price.roundToDouble() ? p.price.toInt().toString() : p.price.toString()) : p.price.toString())} ${AppConstants.currencySymbol}',
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
                                          icon: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryColor),
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

  Widget _buildElementOrderTile(String key, int index) {
    final info = _kLabelElementInfo[key] ?? (
      title: key,
      icon: Icons.label_outline,
      subtitle: '',
    );
    final currentAlign = _elementAlignments[key] ?? 'center';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Index Badge
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 8),
          Icon(info.icon, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(info.title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                if (info.subtitle.isNotEmpty)
                  Text(info.subtitle, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
              ],
            ),
          ),
          // Alignment Selector
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAlignButton(key, 'right', Icons.format_align_right, currentAlign),
                _buildAlignButton(key, 'center', Icons.format_align_center, currentAlign),
                _buildAlignButton(key, 'left', Icons.format_align_left, currentAlign),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Up / Down reorder buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: index > 0 ? () => _moveElementUp(index) : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 16,
                    color: index > 0 ? Colors.indigo : Colors.grey.shade300,
                  ),
                ),
              ),
              InkWell(
                onTap: index < _elementOrder.length - 1 ? () => _moveElementDown(index) : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 16,
                    color: index < _elementOrder.length - 1 ? Colors.indigo : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlignButton(String key, String align, IconData icon, String currentAlign) {
    final isSelected = currentAlign == align;
    return InkWell(
      onTap: () => _setElementAlignment(key, align),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 13,
          color: isSelected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }

  void _showLivePreviewSheet(BuildContext context, List<Product> allProducts) {
    final selectedEntries = _getSelectedEntries(allProducts);
    final previewEntries = selectedEntries.isNotEmpty
        ? selectedEntries
        : [MapEntry(allProducts.isNotEmpty ? allProducts.first : const Product(
            id: 'preview',
            name: 'سلعة تجريبية للمعاينة',
            barcode: '6131234567890',
            price: 250.0,
            costPrice: 180.0,
            stock: 50.0,
            category: 'عام',
            isWeighted: false,
          ), 1)];
    final config = _buildConfig();
    final first = previewEntries.first.key;
    final copies = previewEntries.first.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.label_important_rounded, color: AppTheme.primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'معاينة حية للملصق (${config.size.displayName})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: PdfPreview(
                  key: ValueKey('lbl_preview_${_previewRevision}_${config.size.name}_${config.codeType.name}_${config.autoFillA4Sheet}_${config.customWidthMm}_${config.customHeightMm}'),
                  dpi: 250,
                  build: (format) async => await ShelfLabelGenerator.generateLabelsPdf(
                    itemsWithCopies: previewEntries,
                    config: config,
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'معاينة مطابقة بنسبة 100% لمحرك الطباعة الحرارية ومقاس الورق المحدد',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
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
                    label: Text(
                      selectedEntries.isNotEmpty
                          ? 'طباعة السلع المحددة (${selectedEntries.length}) 🖨️'
                          : 'طباعة تجريبية للملصق 🖨️',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _printPdfOrWindows(allProducts, directEntries: previewEntries);
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
}

