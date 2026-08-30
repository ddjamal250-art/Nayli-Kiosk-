import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/snackbar_helper.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';

import '../bloc/billing_bloc.dart';
import '../widgets/quick_amount_modal.dart';
import '../widgets/smart_scale_modal.dart';
import '../widgets/held_carts_modal.dart';

class QuickItem {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final String icon;
  final String? linkedProductId;

  QuickItem({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.icon,
    this.linkedProductId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'costPrice': costPrice,
        'icon': icon,
        'linkedProductId': linkedProductId,
      };

  factory QuickItem.fromMap(Map<dynamic, dynamic> map) => QuickItem(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
        icon: map['icon'] ?? '🛍️',
        linkedProductId: map['linkedProductId'] as String?,
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  final Map<String, int> _lastScanTimes = {};
  static const int _scanCooldownMs = 1200;
  bool _isScanningPaused = false;
  bool _isFlashOn = false;
  bool _isCameraOn = true;

  // Continuous Multi-Scan Mode
  bool _isMultiScanMode = false;
  int _multiScanCount = 0;
  String? _lastScannedToast;

  List<QuickItem> _quickItems = [];
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _currentSheetSize = 0.22;

  static final List<QuickItem> _defaultQuickItems = [
    QuickItem(id: 'bread', name: 'خبز باكيط', price: 10.0, costPrice: 8.5, icon: '🥖'),
    QuickItem(id: 'egg_single', name: 'حبة بيض', price: 20.0, costPrice: 17.0, icon: '🥚'),
    QuickItem(id: 'milk_bag', name: 'حليب شكارة', price: 25.0, costPrice: 23.5, icon: '🥛'),
    QuickItem(id: 'water_500', name: 'ماء 0.5L', price: 25.0, costPrice: 18.0, icon: '💧'),
    QuickItem(id: 'bag_5', name: 'كيس بلاستيكي', price: 5.0, costPrice: 2.5, icon: '🛍️'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _loadQuickItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed && _isCameraOn) {
      _scannerController.start();
    }
  }

  void _loadQuickItems() {
    final box = HiveDatabase.quickItemsBox;
    final saved = box.values.toList();
    if (saved.isNotEmpty) {
      setState(() {
        _quickItems = saved.map((e) => QuickItem.fromMap(e as Map)).toList();
      });
    } else {
      for (final item in _defaultQuickItems) {
        box.put(item.id, item.toMap());
      }
      setState(() {
        _quickItems = List.from(_defaultQuickItems);
      });
    }
  }

  Future<void> _saveQuickItem(QuickItem item) async {
    final box = HiveDatabase.quickItemsBox;
    await box.put(item.id, item.toMap());
    _loadQuickItems();
  }

  Future<void> _deleteQuickItem(String id) async {
    final box = HiveDatabase.quickItemsBox;
    await box.delete(id);
    _loadQuickItems();
  }

  Future<void> _onReorderQuickItems(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _quickItems.removeAt(oldIndex);
      _quickItems.insert(newIndex, item);
    });
    final box = HiveDatabase.quickItemsBox;
    await box.clear();
    for (final item in _quickItems) {
      await box.put(item.id, item.toMap());
    }
    SoundService.playScanBeep();
  }

  void _addQuickItem(QuickItem item) {
    if (item.linkedProductId != null && item.linkedProductId!.isNotEmpty) {
      final productState = context.read<ProductBloc>().state;
      final matched = productState.products
          .where((p) => p.id == item.linkedProductId)
          .firstOrNull;
      if (matched != null) {
        context.read<BillingBloc>().add(AddProductToCartEvent(matched));
        SoundService.playScanBeep();
        if (_currentSheetSize < 0.35) {
          _sheetController.animateTo(
            0.52,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
        context.showAppSnackBar(
          '✅ تمت إضافة ${matched.name} (${matched.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
          icon: Icons.add_shopping_cart,
        );
        return;
      }
    }

    final double effectiveCost = item.costPrice > 0 ? item.costPrice : (item.price * 0.8);
    context.read<BillingBloc>().add(AddCustomItemEvent(
          name: item.name,
          price: item.price,
          costPrice: effectiveCost,
          quantity: 1,
        ));
    SoundService.playScanBeep();
    if (_currentSheetSize < 0.35) {
      _sheetController.animateTo(
        0.52,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    context.showAppSnackBar(
      '✅ تمت إضافة ${item.name} (${item.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
      icon: Icons.add_shopping_cart,
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanningPaused) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        final cleanCode = code.trim();
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastScan = _lastScanTimes[cleanCode] ?? 0;

        if (now - lastScan > _scanCooldownMs) {
          _lastScanTimes[cleanCode] = now;
          _handleScannedBarcode(cleanCode);
          break;
        }
      }
    }
  }

  void _handleScannedBarcode(String code) {
    SoundService.playScanBeep();

    final productState = context.read<ProductBloc>().state;
    final matchedProduct = productState.products
        .where((p) => p.barcode.trim() == code)
        .firstOrNull;

    if (_isMultiScanMode) {
      setState(() {
        _multiScanCount++;
        if (matchedProduct != null) {
          _lastScannedToast = '✅ ${matchedProduct.name} (${matchedProduct.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})';
        } else {
          _lastScannedToast = '⚡ تم مسح باركود: $code';
        }
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _lastScannedToast != null) {
          setState(() => _lastScannedToast = null);
        }
      });
    } else if (_currentSheetSize < 0.35) {
      _sheetController.animateTo(
        0.52,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    context.read<BillingBloc>().add(ScanBarcodeEvent(code));
  }

  void _handleQuickAddProduct(String barcode) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                const Text('إضافة سريعة لسلعة غير مسجلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'باركود: $barcode',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج',
                hintText: 'e.g. حليب كونديا 1 لتر',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع',
                      suffixText: AppConstants.currencySymbol,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: costPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء (التكلفة)',
                      suffixText: AppConstants.currencySymbol,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية الأولية بالمخزون',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                final costPrice = double.tryParse(costPriceController.text.trim()) ?? (price * 0.8);
                final stock = int.tryParse(stockController.text.trim()) ?? 10;

                if (name.isNotEmpty && price > 0) {
                  final newProduct = Product(
                    id: barcode,
                    name: name,
                    barcode: barcode,
                    price: price,
                    costPrice: costPrice,
                    stock: stock,
                  );

                  context.read<ProductBloc>().add(AddProduct(newProduct));
                  context.read<BillingBloc>().add(AddProductToCartEvent(newProduct));
                  Navigator.pop(ctx);
                  SoundService.playCheckoutSuccess();
                  context.showAppSnackBar(
                    '✅ تمت إضافة وحفظ $name في المخزون والسلة!',
                    backgroundColor: Colors.green[800]!,
                  );
                }
              },
              label: 'حفظ وإضافة للسلة',
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('إفراغ السلة الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف جميع السلع الممسوحة في هذه السلة والبدء من جديد؟',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BillingBloc>().add(ClearCartEvent());
              Navigator.pop(ctx);
              SoundService.playDeleteSound();
              context.showAppSnackBar(
                '🗑️ تم إفراغ السلة بالكامل!',
                backgroundColor: Colors.red[800]!,
              );
            },
            child: const Text('تأكيد الإفراغ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showParkCartDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.orange),
            SizedBox(width: 8),
            Text('تعليق السلة الحالية (Panier en attente)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم حفظ سلة هذا الزبون مؤقتاً لخدمة زبون آخر، ويمكنك استرجاعها في أي وقت خلال 20 دقيقة.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'اسم الزبون أو وصف السلة (اختياري)',
                hintText: 'مثال: الشاب ذو القميص الأزرق',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () {
              context.read<BillingBloc>().add(ParkCurrentCartEvent(label: controller.text.trim()));
              Navigator.pop(ctx);
              context.showAppSnackBar(
                '⏸️ تم تعليق السلة بنجاح في السلات المؤقتة!',
                backgroundColor: Colors.orange[800]!,
              );
            },
            child: const Text('تعليق الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BillingState state) {
    final controller = TextEditingController(
      text: state.discountValue > 0
          ? state.discountValue.toStringAsFixed(state.isDiscountPercentage ? 0 : 2)
          : '',
    );
    bool isPercent = state.isDiscountPercentage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final double enteredVal = double.tryParse(controller.text.trim()) ?? 0.0;
          double previewTotal = state.subTotalAmount;
          if (isPercent) {
            previewTotal = (state.subTotalAmount * (1.0 - (enteredVal / 100.0))).clamp(0.0, double.infinity);
          } else {
            previewTotal = (state.subTotalAmount - enteredVal).clamp(0.0, double.infinity);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.percent_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('تطبيق تخفيض / Remise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('نسبة مئوية %')),
                        selected: isPercent,
                        onSelected: (val) => setDlgState(() => isPercent = true),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text('مبلغ (${AppConstants.currencySymbol})')),
                        selected: !isPercent,
                        onSelected: (val) => setDlgState(() => isPercent = false),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isPercent ? 'نسبة الخصم (%)' : 'مبلغ الخصم (${AppConstants.currencySymbol})',
                    suffixText: isPercent ? '%' : AppConstants.currencySymbol,
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع بعد التخفيض:', style: TextStyle(fontSize: 13)),
                      Text(
                        '${previewTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (state.calculatedDiscount > 0)
                TextButton(
                  onPressed: () {
                    context.read<BillingBloc>().add(RemoveDiscountEvent());
                    Navigator.pop(ctx);
                  },
                  child: const Text('إلغاء التخفيض', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () {
                  final val = double.tryParse(controller.text.trim()) ?? 0.0;
                  if (val > 0) {
                    context.read<BillingBloc>().add(ApplyDiscountEvent(value: val, isPercentage: isPercent));
                  } else {
                    context.read<BillingBloc>().add(RemoveDiscountEvent());
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('تطبيق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddQuickItemDialog() {
    int selectedTab = 0; // 0 = From Stock, 1 = Custom
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final iconController = TextEditingController(text: '🏷️');
    final searchStockController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final products = context.read<ProductBloc>().state.products;
          final query = searchStockController.text.trim().toLowerCase();
          final filteredStock = products.where((p) {
            if (query.isEmpty) return true;
            return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
          }).take(30).toList();

          double parsedPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
          double parsedCost = double.tryParse(costPriceController.text.trim()) ?? 0.0;
          double profit = parsedPrice - parsedCost;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.amber),
                          SizedBox(width: 6),
                          Text('إضافة سلعة لشريط البيع السريع ⚡', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mode Segmented Buttons (From Stock vs Custom)
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('📦 تثبيت من المخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          selected: selectedTab == 0,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                          onSelected: (v) => setDlgState(() => selectedTab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('✏️ سلعة مخصصة جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          selected: selectedTab == 1,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                          onSelected: (v) => setDlgState(() => selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (selectedTab == 0) ...[
                    // Tab 1: Pick from Stock
                    TextField(
                      controller: searchStockController,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن سلعة في المخزون...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredStock.isEmpty
                          ? Center(
                              child: Text('لا توجد سلع في المخزون تطابق البحث', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            )
                          : ListView.separated(
                              itemCount: filteredStock.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = filteredStock[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: const Text('🛍️', style: TextStyle(fontSize: 16)),
                                  ),
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(
                                    'السعر: ${p.price.toStringAsFixed(0)} دج • المخزون: ${p.stock} قطعة',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      final newItem = QuickItem(
                                        id: 'quick_${p.id}',
                                        name: p.name,
                                        price: p.price,
                                        costPrice: p.costPrice,
                                        icon: '🛍️',
                                        linkedProductId: p.id,
                                      );
                                      await _saveQuickItem(newItem);
                                      if (mounted) Navigator.pop(ctx);
                                      context.showAppSnackBar('⚡ تم تثبيت (${p.name}) في شريط البيع السريع بنجاح!', backgroundColor: Colors.teal[800]!);
                                    },
                                    child: const Text('تثبيت ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    // Tab 2: Custom Quick Item
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'اسم السلعة', hintText: 'مثال: خبز تقليدي، كيس، سجائر...'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'سعر البيع (دج)', suffixText: AppConstants.currencySymbol),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: costPriceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'سعر الشراء / التكلفة 🔒', suffixText: AppConstants.currencySymbol),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: iconController,
                              decoration: const InputDecoration(labelText: 'الأيقونة / الرمز التعبيري', hintText: 'e.g. 🥖, 🥚, 🥛, 🛍️'),
                            ),
                            const SizedBox(height: 14),

                            // Confidential Notice Banner
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: Colors.blue),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'سعر التكلفة سري ومحمي ويستخدم لحساب أرباح المحل في التقارير الإدارية فقط.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            PrimaryButton(
                              label: 'حفظ وإضافة لشريط البيع السريع',
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                                final costPrice = double.tryParse(costPriceController.text.trim()) ?? (price * 0.8);
                                final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : '🏷️';

                                if (name.isNotEmpty && price > 0) {
                                  final newItem = QuickItem(
                                    id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
                                    name: name,
                                    price: price,
                                    costPrice: costPrice,
                                    icon: icon,
                                  );
                                  await _saveQuickItem(newItem);
                                  if (mounted) Navigator.pop(ctx);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditQuickItemDialog(QuickItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final costPriceController = TextEditingController(text: item.costPrice > 0 ? item.costPrice.toStringAsFixed(0) : '');
    final iconController = TextEditingController(text: item.icon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
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
                    const Text('✏️ تعديل السلعة السريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم السلعة'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'سعر البيع', suffixText: AppConstants.currencySymbol),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: costPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'سعر التكلفة 🔒', suffixText: AppConstants.currencySymbol),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: iconController,
                  decoration: const InputDecoration(labelText: 'الأيقونة / الرمز التعبيري'),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                        onPressed: () async {
                          await _deleteQuickItem(item.id);
                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text.trim()) ?? item.price;
                          final costPrice = double.tryParse(costPriceController.text.trim()) ?? item.costPrice;
                          final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : item.icon;

                          if (name.isNotEmpty && price > 0) {
                            final updated = QuickItem(
                              id: item.id,
                              name: name,
                              price: price,
                              costPrice: costPrice,
                              icon: icon,
                              linkedProductId: item.linkedProductId,
                            );
                            await _saveQuickItem(updated);
                            if (mounted) Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToSettings() {
    setState(() => _isScanningPaused = true);
    try {
      _scannerController.stop();
    } catch (_) {}
    context.push('/settings').then((_) {
      if (mounted) {
        if (_isCameraOn) {
          try {
            _scannerController.start();
          } catch (_) {}
        }
        setState(() {
          _isScanningPaused = false;
          _lastScanTimes.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (state.error != null && state.error!.startsWith('Product not found: ')) {
            final barcode = state.error!.replaceFirst('Product not found: ', '').trim();
            _handleQuickAddProduct(barcode);
          } else if (state.error != null) {
            context.showAppSnackBar(
              state.error!,
              backgroundColor: Colors.red[800]!,
            );
          }
        },
        child: NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            setState(() {
              _currentSheetSize = notification.extent;
            });
            return true;
          },
          child: Stack(
            children: [
              // 1. FULL BACKGROUND SCANNER VIEW
              Positioned.fill(
                child: _buildScannerSection(),
              ),

              // 2. DRAGGABLE SCROLLABLE CART SHEET
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.22,
                minChildSize: 0.20,
                maxChildSize: 0.90,
                snap: true,
                snapSizes: const [0.22, 0.52, 0.90],
                builder: (context, scrollController) {
                  return _buildBottomPanel(scrollController);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          if (!_isCameraOn) _buildCameraOffState(),

          // TOP ADAPTIVE ACTION BAR: Multi-Scan Mode (Left) & Hamburger Menu (Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Multi-Scan Stacked Barcode Toggle Button
                _buildMultiScanButton(),

                // Full-Screen Settings & Management Hamburger Button
                InkWell(
                  onTap: _navigateToSettings,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // RIGHT SIDE FLOATING ESSENTIAL BUTTONS (Flash & Camera Only)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 14,
            child: Column(
              children: [
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon: _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    tooltip: 'تشغيل/إيقاف الفلاش',
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) const SizedBox(height: 10),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  tooltip: 'تشغيل/إيقاف الكاميرا',
                  onPressed: () {
                    setState(() {
                      _isCameraOn = !_isCameraOn;
                    });
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Live Scan Toast Confirmation
          if (_lastScannedToast != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 65,
              left: 20,
              right: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _lastScannedToast!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Central Scan Target Frame (Positioned comfortably in the camera area)
          if (_isCameraOn)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 250,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.85), width: 2.2),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.redAccent.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),

          // Floating Multi-Scan Counter
          if (_isMultiScanMode && _multiScanCount > 0)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                  ),
                  child: Text(
                    '⚡ تم مسح $_multiScanCount سلع في هذه السلة',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(context.tr('camera_off'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            icon: const Icon(Icons.videocam),
            label: Text(context.tr('turn_on_camera')),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultiScanButton() {
    return Tooltip(
      message: _isMultiScanMode ? 'المسح المتعدد مفعّل (انقر للتبديل للعادي)' : 'المسح العادي (انقر لتفعيل المسح المتعدد ⚡)',
      child: InkWell(
        onTap: () {
          setState(() {
            _isMultiScanMode = !_isMultiScanMode;
            _multiScanCount = 0;
          });
          SoundService.playScanBeep();
          HapticFeedback.mediumImpact();
          context.showAppSnackBar(
            _isMultiScanMode ? '⚡ تم تفعيل وضع المسح المتعدد السريع' : '📱 تم التبديل إلى وضع المسح الفردي العادي',
            duration: const Duration(milliseconds: 1500),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isMultiScanMode ? const Color(0xFF15803D) : Colors.black54,
            border: Border.all(
              color: _isMultiScanMode ? Colors.greenAccent : Colors.white70,
              width: _isMultiScanMode ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isMultiScanMode ? Colors.greenAccent.withOpacity(0.35) : Colors.black26,
                blurRadius: _isMultiScanMode ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isMultiScanMode) ...[
                // Back Barcode layer 3 (Offset top-left, subtle opacity)
                Transform.translate(
                  offset: const Offset(-4.5, -4),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white30,
                    size: 19,
                  ),
                ),
                // Middle Barcode layer 2 (Offset top-left, medium opacity)
                Transform.translate(
                  offset: const Offset(-2.2, -2),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                // Front Barcode layer 1 (Prominent, sharp, full opacity)
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                // Tiny Active Lightning Accent Badge
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt,
                      size: 9,
                      color: Colors.black,
                    ),
                  ),
                ),
              ] else ...[
                // Single Clean Barcode Icon for Normal Single-Scan Mode
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayButton({required IconData icon, required VoidCallback onPressed, String? tooltip}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBottomPanel(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Drag handle & Clickable Header to Expand/Collapse
          InkWell(
            onTap: () {
              if (_currentSheetSize < 0.35) {
                _sheetController.animateTo(
                  0.52,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
              } else {
                _sheetController.animateTo(
                  0.22,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                BlocBuilder<BillingBloc, BillingState>(
                  builder: (context, state) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        context.tr('cart'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _currentSheetSize > 0.35 ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${state.cartItems.length} ${context.tr('items_count')}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              if (state.cartItems.isNotEmpty) ...[
                                InkWell(
                                  onTap: _showClearCartConfirmationDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 12, color: Colors.red),
                                        SizedBox(width: 2),
                                        Text('إفراغ', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _showParkCartDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.pause_circle_outline, size: 12, color: Colors.orange),
                                        SizedBox(width: 2),
                                        Text('تعليق', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (state.heldCarts.isNotEmpty) ...[
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => const HeldCartsModal(),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.indigo.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.indigo),
                                        const SizedBox(width: 4),
                                        Text(
                                          'المعلقة (${state.heldCarts.length})',
                                          style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${state.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              if (state.calculatedDiscount > 0)
                                Text(
                                  'تخفيض: -${state.calculatedDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                  style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 12),

          // Action Pills (Scale Vrac, Quick Amount, Discount, Return Mode)
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Container(
                height: 38,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Smart Scale Modal
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const SmartScaleModal(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.scale, size: 15, color: Colors.teal),
                            SizedBox(width: 4),
                            Text('ميزان وتجزئة (Vrac)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Amount
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const QuickAmountModal(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.dialpad, size: 15, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('مبلغ مباشر (دايركت)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Discount Remise
                    InkWell(
                      onTap: () => _showDiscountDialog(state),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.calculatedDiscount > 0 ? Colors.purple : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.percent_rounded, size: 15, color: state.calculatedDiscount > 0 ? Colors.white : Colors.purple),
                            const SizedBox(width: 4),
                            Text(
                              state.calculatedDiscount > 0 ? 'تخفيض (${state.calculatedDiscount.toStringAsFixed(0)}دج)' : 'تخفيض / Remise',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: state.calculatedDiscount > 0 ? Colors.white : Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Return Mode
                    InkWell(
                      onTap: () {
                        context.read<BillingBloc>().add(ToggleReturnModeEvent());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.isReturnMode ? Colors.red : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: state.isReturnMode ? Colors.red : Colors.grey[400]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.replay_circle_filled, size: 15, color: state.isReturnMode ? Colors.white : Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              state.isReturnMode ? 'وضع الإرجاع مفعّل 🔄' : 'وضع الإرجاع',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: state.isReturnMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Quick Items Header & Micro-hint
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text('شريط البيع السريع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Text('💡 اضغط واسحب للترتيب', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),

          // Quick Items Horizontal Ribbon with Fluid Drag-and-Drop Reordering
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _quickItems.length,
                    onReorder: _onReorderQuickItems,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 6,
                        shadowColor: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = _quickItems[index];
                      return Container(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: () => _addQuickItem(item),
                          onLongPress: () => _showEditQuickItemDialog(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 85),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.icon, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 6),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${item.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16),
                  child: InkWell(
                    onTap: _showAddQuickItemDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('إضافة', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Cart Items List
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey[400]),
                      const SizedBox(height: 6),
                      Text(context.tr('cart_empty'),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(context.tr('cart_empty_hint'),
                          style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return _buildCartItemCard(context, item);
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PrimaryButton(
                      label: '${context.tr('review_order')} (${state.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol})',
                      onPressed: () async {
                        setState(() => _isScanningPaused = true);
                        await context.push('/checkout');
                        if (mounted) {
                          setState(() {
                            _isScanningPaused = false;
                            _lastScanTimes.clear();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    return Dismissible(
      key: ValueKey('cart_item_${item.product.id}_${item.quantity}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green[600],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text('+1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.quantity > 1 ? '-1' : 'حذف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(item.quantity > 1 ? Icons.remove_circle : Icons.delete, color: Colors.white, size: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right -> +1
          context.read<BillingBloc>().add(
                UpdateQuantityEvent(
                  item.product.id,
                  item.quantity + 1,
                ),
              );
          SoundService.playScanBeep();
          HapticFeedback.lightImpact();
          return false;
        } else {
          // Swipe Left -> -1 or Delete
          final newQty = item.quantity - 1;
          context.read<BillingBloc>().add(
                UpdateQuantityEvent(
                  item.product.id,
                  newQty,
                ),
              );
          SoundService.playDeleteSound();
          HapticFeedback.mediumImpact();
          return newQty <= 0;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.product.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                  onPressed: () {
                    context.read<BillingBloc>().add(
                          UpdateQuantityEvent(
                            item.product.id,
                            item.quantity - 1,
                          ),
                        );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                  onPressed: () {
                    context.read<BillingBloc>().add(
                          UpdateQuantityEvent(
                            item.product.id,
                            item.quantity + 1,
                          ),
                        );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Text(
              '${item.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: () {
                context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
