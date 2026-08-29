import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/security_pin_helper.dart';

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
  final String icon;

  QuickItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'icon': icon,
      };

  factory QuickItem.fromMap(Map<dynamic, dynamic> map) => QuickItem(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        icon: map['icon'] ?? '🛍️',
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
  static const int _scanCooldownMs = 1500;
  bool _isScanningPaused = false;
  bool _isFlashOn = false;
  bool _isCameraOn = true;

  // Continuous Multi-Scan Mode
  bool _isMultiScanMode = false;
  int _multiScanCount = 0;
  String? _lastScannedToast;

  List<QuickItem> _quickItems = [];
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  static final List<QuickItem> _defaultQuickItems = [
    QuickItem(id: 'bread', name: 'خبز عادي', price: 10.0, icon: '🥖'),
    QuickItem(id: 'bag_5', name: 'كيس بلاستيكي', price: 5.0, icon: '🛍️'),
    QuickItem(id: 'bag_10', name: 'كيس كبير', price: 10.0, icon: '🛍️'),
    QuickItem(id: 'water_500', name: 'ماء 0.5ل', price: 25.0, icon: '💧'),
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

  void _addQuickItem(QuickItem item) {
    context.read<BillingBloc>().add(AddCustomItemEvent(
          name: item.name,
          price: item.price,
          quantity: 1,
        ));
    Vibration.vibrate(duration: 40);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تمت إضافة ${item.name} (${item.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})'),
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanningPaused) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastScan = _lastScanTimes[code] ?? 0;

        if (now - lastScan > _scanCooldownMs) {
          _lastScanTimes[code] = now;
          _handleScannedBarcode(code);
          break;
        }
      }
    }
  }

  void _handleScannedBarcode(String code) {
    Vibration.vibrate(duration: 50);

    final productState = context.read<ProductBloc>().state;
    final matchedProduct = productState.products
        .where((p) => p.barcode.trim() == code.trim())
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

      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted && _lastScannedToast != null) {
          setState(() => _lastScannedToast = null);
        }
      });
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
                Text(context.tr('product_not_found_quick_add'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                '${context.tr('barcode')}: $barcode',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('product_name'),
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
                      labelText: context.tr('sale_price'),
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
                      labelText: context.tr('cost_price'),
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
              decoration: InputDecoration(
                labelText: context.tr('stock_quantity'),
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
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    barcode: barcode,
                    price: price,
                    costPrice: costPrice,
                    stock: stock,
                  );

                  context.read<ProductBloc>().add(AddProduct(newProduct));
                  context.read<BillingBloc>().add(AddProductToCartEvent(newProduct));

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ${context.tr('product_added_to_cart_success')}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: Icons.check,
              label: context.tr('save_and_add_to_cart'),
            )
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ تم إفراغ السلة بالكامل!'),
                  backgroundColor: Colors.red,
                  duration: Duration(milliseconds: 1200),
                ),
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
            Icon(Icons.pause_circle_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('تعليق في سلة مؤقتة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سيتم حفظ الفاتورة لخدمة الزبون التالي، وحذفها تلقائياً بعد 20 دقيقة إذا لم يعد.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'اسم السلة / الزبون (اختياري)',
                hintText: 'مثال: الأب مع الطفل',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              final label = controller.text.trim();
              context.read<BillingBloc>().add(ParkCurrentCartEvent(label: label.isNotEmpty ? label : null));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⏸️ تم تعليق السلة لخدمة الزبون التالي!'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('تعليق الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog() {
    final billingBloc = context.read<BillingBloc>();
    final currentState = billingBloc.state;
    final ctrl = TextEditingController(
      text: currentState.discountValue > 0 ? currentState.discountValue.toStringAsFixed(0) : '',
    );
    bool isPercentage = currentState.isDiscountPercentage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.discount_outlined, color: Colors.purple),
              SizedBox(width: 8),
              Text('إضافة تخفيض / Remise 🏷️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('دج (مبلغ ثابت)', style: TextStyle(fontSize: 12)),
                    selected: !isPercentage,
                    onSelected: (v) => setDialogState(() => isPercentage = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('% (نسبة مئوية)', style: TextStyle(fontSize: 12)),
                    selected: isPercentage,
                    onSelected: (v) => setDialogState(() => isPercentage = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isPercentage ? 'نسبة الخصم (%)' : 'مبلغ الخصم (دج)',
                  suffixText: isPercentage ? '%' : 'دج',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (currentState.discountValue > 0)
              TextButton(
                onPressed: () {
                  billingBloc.add(RemoveDiscountEvent());
                  Navigator.pop(ctx);
                },
                child: const Text('حذف التخفيض', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
              onPressed: () {
                final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
                if (val > 0) {
                  billingBloc.add(ApplyDiscountEvent(value: val, isPercentage: isPercentage));
                } else {
                  billingBloc.add(RemoveDiscountEvent());
                }
                Navigator.pop(ctx);
              },
              child: const Text('تطبيق التخفيض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuickItemModal() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final iconController = TextEditingController(text: '🛍️');

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
                Text(context.tr('add_quick_item'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('item_name'),
                hintText: 'e.g. خبز، ماء، كيس...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('price'),
                suffixText: AppConstants.currencySymbol,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: iconController,
              decoration: InputDecoration(
                labelText: context.tr('quick_item_icon'),
                hintText: 'e.g. 🥖 🥚 ☕ 🧀 🥤',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : '🛍️';

                if (name.isNotEmpty && price > 0) {
                  final newItem = QuickItem(
                    id: 'q_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    price: price,
                    icon: icon,
                  );

                  await _saveQuickItem(newItem);
                  if (mounted) Navigator.pop(ctx);
                }
              },
              icon: Icons.add,
              label: context.tr('save'),
            )
          ],
        ),
      ),
    );
  }

  void _showEditQuickItemModal(QuickItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final iconController = TextEditingController(text: item.icon);

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
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'السعر', suffixText: AppConstants.currencySymbol),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: iconController,
              decoration: const InputDecoration(labelText: 'الأيقونة / الرمز التعبيري'),
            ),
            const SizedBox(height: 20),
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
                      final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : item.icon;

                      if (name.isNotEmpty && price > 0) {
                        final updated = QuickItem(id: item.id, name: name, price: price, icon: icon);
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
      ),
    );
  }

  // Samsung OneUI Style Hamburger Menu Drawer
  void _showAppDrawerMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drawer Drag Header
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            // Store Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nayli Market Pro 🇩🇿', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('نظام إدارة ونقاط بيع المتاجر الذكي', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Modules Grid / List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  // Section 1: Financials & Stock (Owner PIN Protected)
                  _buildDrawerSectionHeader('الإدارة والمالية (صلاحيات المالك 🔒)'),
                  _buildDrawerTile(
                    icon: Icons.bar_chart_rounded,
                    color: Colors.indigo,
                    title: 'الداشبورد المالي والتقارير',
                    subtitle: 'صافي الأرباح، الإيرادات، والمصاريف',
                    isLocked: true,
                    onTap: () => _navigateProtected('/reports', 'تقرير الأرباح والداشبورد المالي'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.inventory_2_outlined,
                    color: Colors.deepPurple,
                    title: 'إدارة السلع والمخزون',
                    subtitle: 'إضافة، تعديل الأسعار، ومراقبة المخزون',
                    isLocked: true,
                    onTap: () => _navigateProtected('/products', 'إدارة السلع وتعديل الأسعار'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.local_shipping_outlined,
                    color: Colors.blue,
                    title: 'فواتير الموردين والمشتريات',
                    subtitle: 'تسجيل الشحنات وإدخال سلع الموزعين',
                    isLocked: true,
                    onTap: () => _navigateProtected('/products/supplier-invoices', 'فواتير الموردين والمشتريات'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.payments_outlined,
                    color: Colors.amber[800]!,
                    title: 'مصاريف ونفقات المحل',
                    subtitle: 'تسجيل النفقات وخصمها من الكاسة',
                    isLocked: true,
                    onTap: () => _navigateProtected('/expenses', 'تسجيل مصاريف المحل'),
                  ),

                  const SizedBox(height: 12),
                  // Section 2: Daily Operations (Open for Cashier)
                  _buildDrawerSectionHeader('العمليات اليومية والكاسة 🛒'),
                  _buildDrawerTile(
                    icon: Icons.people_alt_outlined,
                    color: Colors.teal,
                    title: 'دفتر الزبائن والديون (Carnet Crédit)',
                    subtitle: 'متابعة ديون الزبائن وتسديد المستحقات',
                    onTap: () => _navigateDirect('/customers'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.lock_clock_outlined,
                    color: Colors.green,
                    title: 'مناوبات الكاسة (Fond de Caisse)',
                    subtitle: 'فتح وإغلاق اليومية وجرد الصندوق',
                    onTap: () => _navigateDirect('/shifts'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.description_outlined,
                    color: Colors.orange,
                    title: 'عروض الأسعار والفواتير المبدئية (Devis)',
                    subtitle: 'أرشيف عروض الأسعار ومشاركتها',
                    onTap: () => _navigateDirect('/devis'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.auto_awesome,
                    color: Colors.purple,
                    title: 'مكتبة السلع الجزائرية (15,500+)',
                    subtitle: 'استيراد باركودات وأسماء السلع فوراً',
                    onTap: () => _navigateDirect('/master-catalog'),
                  ),

                  const SizedBox(height: 12),
                  // Section 3: Settings & Receipt (Owner Protected)
                  _buildDrawerSectionHeader('النظام والإعدادات ⚙️'),
                  _buildDrawerTile(
                    icon: Icons.receipt_long_outlined,
                    color: Colors.brown,
                    title: 'تخصيص وتصميم الوصل الحراري',
                    subtitle: 'تعديل الشعار، الهواتف، والشروط',
                    onTap: () => _navigateDirect('/settings/receipt-designer'),
                  ),
                  _buildDrawerTile(
                    icon: Icons.settings_outlined,
                    color: Colors.blueGrey,
                    title: 'الإعدادات العامة وقفل التطبيق',
                    subtitle: 'الطابعة، النسخ الاحتياطي، والأمان',
                    isLocked: true,
                    onTap: () => _navigateProtected('/settings', 'الإعدادات العامة'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateDirect(String route) {
    Navigator.pop(context);
    setState(() => _isScanningPaused = true);
    context.push(route).then((_) {
      if (mounted) {
        setState(() {
          _isScanningPaused = false;
          _lastScanTimes.clear();
        });
      }
    });
  }

  Future<void> _navigateProtected(String route, String title) async {
    Navigator.pop(context);
    final auth = await SecurityPinHelper.authenticate(context, title: title);
    if (auth && mounted) {
      setState(() => _isScanningPaused = true);
      context.push(route).then((_) {
        if (mounted) {
          setState(() {
            _isScanningPaused = false;
            _lastScanTimes.clear();
          });
        }
      });
    }
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 10, color: Colors.brown),
                    SizedBox(width: 2),
                    Text('PIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.brown)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
              initialChildSize: 0.48,
              minChildSize: 0.12,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.12, 0.48, 0.92],
              builder: (context, scrollController) {
                return _buildBottomPanel(scrollController);
              },
            ),
          ],
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

          // TOP ACTION BAR: Multi-Scan Mode (Left) & Samsung Style Burger Menu (Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Multi-Scan Pill Toggle
                InkWell(
                  onTap: () {
                    setState(() {
                      _isMultiScanMode = !_isMultiScanMode;
                      _multiScanCount = 0;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isMultiScanMode ? Colors.green[700] : Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white70),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isMultiScanMode ? Icons.bolt : Icons.qr_code, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _isMultiScanMode ? 'مسح متعدد ⚡' : 'مسح عادي',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Samsung Style Hamburger Button
                InkWell(
                  onTap: _showAppDrawerMenu,
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

          // RIGHT SIDE FLOATING ESSENTIAL BUTTONS ONLY
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
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
                const SizedBox(height: 10),
                _buildOverlayButton(
                  icon: Icons.archive_outlined,
                  tooltip: 'إدخال سريع للمخزون (Stock-In)',
                  onPressed: () async {
                    setState(() => _isScanningPaused = true);
                    await context.push('/products/stock-in');
                    if (mounted) {
                      setState(() {
                        _isScanningPaused = false;
                        _lastScanTimes.clear();
                      });
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

          // Central Scan Target Frame
          if (_isCameraOn)
            Center(
              child: Container(
                width: 240,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),

          // Floating Multi-Scan Bottom Counter (Positioned under scan reticle, NEVER overlapping cart!)
          if (_isMultiScanMode && _multiScanCount > 0)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.38 - 30,
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
          )
        ],
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
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header with Total and Cart Actions
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('cart'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${state.cartItems.length} ${context.tr('items_count')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(width: 10),
                        // Clear Cart Button
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
                                  Icon(Icons.delete_sweep_outlined, size: 14, color: Colors.red),
                                  SizedBox(width: 3),
                                  Text('إفراغ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Park Cart Button
                          InkWell(
                            onTap: _showParkCartDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.pause_circle_outline, size: 14, color: Colors.orange),
                                  SizedBox(width: 3),
                                  Text('سلة مؤقتة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Discount / Remise Button
                          InkWell(
                            onTap: _showDiscountDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.calculatedDiscount > 0 ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.purple.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.discount_outlined, size: 14, color: Colors.purple),
                                  const SizedBox(width: 3),
                                  Text(
                                    state.calculatedDiscount > 0
                                        ? 'خصم (-${state.calculatedDiscount.toStringAsFixed(0)} دج)'
                                        : 'تخفيض',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Return Mode (Mode Retour) Button
                          InkWell(
                            onTap: () => context.read<BillingBloc>().add(ToggleReturnModeEvent()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.isReturnMode ? Colors.red : Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: state.isReturnMode ? Colors.red : Colors.grey[400]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.replay_circle_filled, size: 14, color: state.isReturnMode ? Colors.white : Colors.black87),
                                  const SizedBox(width: 3),
                                  Text(
                                    'إرجاع',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: state.isReturnMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (state.hasParkedCart) ...[
                          const SizedBox(width: 6),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.green),
                                  const SizedBox(width: 3),
                                  Text('السلات (${state.activeHeldCarts.length})',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.tr('total_price'),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(
                          '${state.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Quick Actions & Items Bar Pro
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // 1. Smart Scale / Vrac Modal
                ActionChip(
                  avatar: const Icon(Icons.scale_rounded, size: 16, color: Colors.teal),
                  label: const Text('⚖️ ميزان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                  backgroundColor: Colors.teal.withOpacity(0.08),
                  side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SmartScaleModal(),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // 2. Direct Price / Vente Libre Modal
                ActionChip(
                  avatar: const Icon(Icons.calculate_rounded, size: 16, color: Colors.purple),
                  label: const Text('🧮 سعر حر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                  backgroundColor: Colors.purple.withOpacity(0.08),
                  side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QuickAmountModal(),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // 3. Quick Chips List
                ..._quickItems.map((q) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => _addQuickItem(q),
                      onLongPress: () => _showEditQuickItemModal(q),
                      child: Chip(
                        avatar: Text(q.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(
                          '${q.name} (${q.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  );
                }),

                // 4. Add Custom Quick Item Button (+)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                    label: Text(context.tr('add_quick_item'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                    side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: _showAddQuickItemModal,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Cart Items List
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _buildEmptyCart(),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 16),
                itemCount: state.cartItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = state.cartItems[index];
                  return _buildCartItemCard(context, item);
                },
              );
            },
          ),

          // Bottom Review Order Button inside sheet
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: PrimaryButton(
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
                  icon: Icons.payment,
                  label: '${context.tr('review_order')} (${state.cartItems.length} سلع) - ${state.totalAmount.toStringAsFixed(2)} دج',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(context.tr('cart_empty'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(context.tr('cart_empty_hint'),
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    return Dismissible(
      key: ValueKey('cart_${item.product.id}_${item.product.price}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('حذف من السلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
        Vibration.vibrate(duration: 40);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ تم حذف ${item.product.name} من السلة'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${item.product.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600),
                      ),
                      if (item.product.stock > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${context.tr('in_stock')}: ${item.product.stock}',
                          style: TextStyle(fontSize: 10, color: Colors.green[700]),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildQuantityButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (item.quantity > 1) {
                      context.read<BillingBloc>().add(
                            UpdateQuantityEvent(item.product.id, item.quantity - 1),
                          );
                    } else {
                      context.read<BillingBloc>().add(
                            RemoveProductFromCartEvent(item.product.id),
                          );
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildQuantityButton(
                  icon: Icons.add,
                  onPressed: () {
                    context.read<BillingBloc>().add(
                          UpdateQuantityEvent(item.product.id, item.quantity + 1),
                        );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.black87),
        ),
      ),
    );
  }
}
