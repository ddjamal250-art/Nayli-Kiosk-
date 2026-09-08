import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_client.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/utils/expiry_tracker_service.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';

import '../bloc/billing_bloc.dart';
import '../widgets/quick_amount_modal.dart';
import '../widgets/smart_scale_modal.dart';
import '../widgets/held_carts_modal.dart';
import '../widgets/universal_unit_selector_dialog.dart';
import '../widgets/session_lock_overlay.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/category_taxonomy.dart';

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
        id: map['id'] as String? ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
        icon: map['icon'] as String? ?? '🏷️',
        linkedProductId: map['linkedProductId'] as String?,
      );
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimationController;
  bool _isScanFlash = false;
  Offset? _dynamicTargetOffset;
  bool _isLockedOnBarcode = false;
  final Map<String, int> _lastScanTimes = {};
  static const int _scanCooldownMs = 850;
  bool _isScanningPaused = false;
  bool _isFlashOn = false;
  bool _isCameraOn = true;
  double _cameraZoomScale = 0.0;

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
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
    _laserAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadQuickItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimationController.dispose();
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

  Product _resolveProductForQuickItem(QuickItem item) {
    // 1. Try finding in productBox or state
    Product? matched;
    if (item.linkedProductId != null && item.linkedProductId!.isNotEmpty) {
      if (HiveDatabase.productBox.containsKey(item.linkedProductId!)) {
        final p = HiveDatabase.productBox.get(item.linkedProductId!);
        if (p is Product) matched = p;
      }
    }
    if (matched == null && item.name.isNotEmpty) {
      for (var p in HiveDatabase.productBox.values) {
        if (p is Product && p.name.trim().toLowerCase() == item.name.trim().toLowerCase()) {
          matched = p;
          break;
        }
      }
    }
    if (matched != null) return matched;

    // 2. Smart detection for tobacco/beverage/category
    final detectedSub = CategoryTaxonomy.smartDetect(item.name);
    final nameL = item.name.toLowerCase();
    final isTob = detectedSub.domainId == 'tobacco' ||
        detectedSub.id == 'cigarettes' ||
        nameL.contains('مارلبورو') ||
        nameL.contains('marlboro') ||
        nameL.contains('ريم') ||
        nameL.contains('rym') ||
        nameL.contains('جولواز') ||
        nameL.contains('gauloises') ||
        nameL.contains('سجائر') ||
        nameL.contains('دخان') ||
        nameL.contains('شمة');
    final isBev = detectedSub.id == 'beverages' ||
        nameL.contains('ماء') ||
        nameL.contains('مشروب') ||
        nameL.contains('كوكا') ||
        nameL.contains('عصير') ||
        nameL.contains('حمود') ||
        nameL.contains('رويبة') ||
        nameL.contains('إفري') ||
        nameL.contains('رامي');

    final effectivePacksPerCarton = isTob ? 10 : (isBev ? 6 : 10);
    final effectivePiecesPerPack = isTob ? 20 : 1;
    final singlePiecePrice = isTob ? (item.price / 20).ceilToDouble() : 0.0;
    final cartonPrice = item.price * effectivePacksPerCarton;

    return Product(
      id: item.linkedProductId ?? item.id,
      name: item.name,
      barcode: 'QUICK_${item.id}',
      price: item.price,
      costPrice: item.costPrice > 0 ? item.costPrice : (item.price * 0.8),
      stock: 999,
      category: isTob ? 'المواد التبغية' : (isBev ? 'المشروبات' : detectedSub.titleAr),
      isTobacco: isTob,
      packsPerCarton: effectivePacksPerCarton,
      piecesPerPack: effectivePiecesPerPack,
      singlePiecePrice: singlePiecePrice,
      cartonPrice: cartonPrice,
      packPrice: cartonPrice,
      packMultiplier: effectivePacksPerCarton,
      packName: isTob ? 'كرطوشة' : (isBev ? 'فاردو' : null),
    );
  }

  void _addQuickItem(QuickItem item) {
    final prod = _resolveProductForQuickItem(item);
    if (prod.hasMultiUnitPricing || prod.isTobaccoProduct || prod.isBeverage) {
      UniversalUnitSelectorDialog.showForProduct(context, prod);
      return;
    }

    context.read<BillingBloc>().add(AddProductToCartEvent(prod));
    SoundService.playScanBeep();
    if (_currentSheetSize < 0.35) {
      _sheetController.animateTo(
        0.52,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    context.showAppSnackBar(
      '✅ تمت إضافة ${prod.name} (${prod.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
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

          // Track barcode dynamic location on screen if corners provided
          if (barcode.corners.isNotEmpty) {
            double minX = double.infinity, maxX = -double.infinity;
            double minY = double.infinity, maxY = -double.infinity;
            for (final pt in barcode.corners) {
              if (pt.dx < minX) minX = pt.dx;
              if (pt.dx > maxX) maxX = pt.dx;
              if (pt.dy < minY) minY = pt.dy;
              if (pt.dy > maxY) maxY = pt.dy;
            }
            final screenW = MediaQuery.of(context).size.width;
            final screenH = MediaQuery.of(context).size.height;
            setState(() {
              _dynamicTargetOffset = Offset(
                ((minX + maxX) / 2).clamp(60.0, screenW - 60.0),
                ((minY + maxY) / 2).clamp(120.0, screenH * 0.48),
              );
              _isLockedOnBarcode = true;
            });
          }

          _handleScannedBarcode(cleanCode);
          break;
        }
      }
    }
  }

  bool _isLanPairingCode(String raw) {
    final s = raw.trim();
    // 1. JSON payload with pairing identifiers
    if (s.startsWith('{' /*}*/) && (s.contains('nayli_pos') || s.contains('nayli_lan_pair') || s.contains('"action"') || s.contains('"ip"') || s.contains('pair'))) {
      return true;
    }
    // 2. Direct keywords
    if (s.contains('nayli_lan_pair') || s.contains('nayli_pos_pair') || s.contains('nayli_pos')) {
      return true;
    }
    // 3. HTTP URL to LAN server with port 8080 or /api/
    if ((s.startsWith('http://') || s.startsWith('https://')) && (s.contains(':8080') || s.contains('/api/status') || s.contains('/api/remote-cart'))) {
      return true;
    }
    return false;
  }

  void _handleLanPairingQr(String rawCode) async {
    try {
      String ip = '';
      String port = '8080';
      String shopName = 'كاشير الكمبيوتر الرئيسي';

      final trimmed = rawCode.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final data = jsonDecode(trimmed) as Map<String, dynamic>;
        ip = data['ip']?.toString() ?? '';
        port = data['port']?.toString() ?? '8080';
        shopName = data['name']?.toString() ?? data['shopName']?.toString() ?? 'Nayli POS Master';
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          ip = uri.host;
          if (uri.port > 0) port = uri.port.toString();
        }
      } else if (trimmed.contains(':')) {
        final parts = trimmed.replaceAll('nayli_lan_pair:', '').trim().split(':');
        if (parts.isNotEmpty) ip = parts[0];
        if (parts.length > 1) port = parts[1];
      }

      ip = ip.trim();
      port = port.trim();

      if (ip.isNotEmpty && ip != '127.0.0.1') {
        await HiveDatabase.settingsBox.put('master_pos_ip', ip);
        await HiveDatabase.settingsBox.put('master_pos_port', port);
        await HiveDatabase.settingsBox.put('sync_server_ip', '$ip:$port');
        await HiveDatabase.settingsBox.put('shop_name', shopName);
        await LocalSyncClient.setServerIp('$ip:$port');
        await LicenseService.grantCompanionLicense(storeName: shopName, masterIp: ip);

        SoundService.playSaveSuccess();
        HapticFeedback.heavyImpact();

        if (mounted) {
          context.showAppSnackBar(
            '🎉 تم التعرف على كود الربط بنجاح! متصل مع: $shopName ($ip:$port)',
            icon: Icons.wifi_tethering_rounded,
            backgroundColor: Colors.green.shade800,
          );
        }

        // Test connection live in background and pull latest products automatically
        try {
          final isLive = await LocalSyncClient.testConnection('$ip:$port');
          if (isLive && mounted) {
            final count = await LocalSyncClient.pullProductsFromMaster();
            if (count > 0 && mounted) {
              context.read<ProductBloc>().add(LoadProducts());
              context.showAppSnackBar(
                '🔄 تم جلب وتحديث $count منتج من الكمبيوتر تلقائياً!',
                icon: Icons.sync_rounded,
                backgroundColor: Colors.teal.shade800,
              );
            }
          }
        } catch (_) {}
      } else {
        SoundService.playVoidWarning();
        if (mounted) {
          context.showAppSnackBar(
            '⚠️ تعذر استخراج عنوان IP صحيح من كود الربط. يرجى مسح الكود من شاشة الكمبيوتر.',
            isError: true,
          );
        }
      }
    } catch (e) {
      SoundService.playVoidWarning();
      if (mounted) {
        context.showAppSnackBar('❌ خطأ أثناء معالجة رمز الربط: $e', isError: true);
      }
    }
  }

  Future<void> _sendCartToMasterPos(BillingState state) async {
    String ip = HiveDatabase.settingsBox.get('master_pos_ip', defaultValue: '') as String;
    String port = HiveDatabase.settingsBox.get('master_pos_port', defaultValue: '8080').toString();

    final syncIp = LocalSyncClient.getServerIp();
    if (syncIp.isNotEmpty) {
      if (syncIp.contains(':')) {
        final parts = syncIp.split(':');
        ip = parts[0];
        port = parts[1];
      } else {
        ip = syncIp;
      }
    }

    if (ip.isEmpty) {
      context.showAppSnackBar(
        '⚠️ يرجى مسح كود QR من شاشة الكاشير لربط الهاتف بالشبكة أولاً',
        isError: true,
        icon: Icons.qr_code_scanner_rounded,
      );
      return;
    }

    try {
      final randomTicket = '#${(DateTime.now().millisecondsSinceEpoch % 900 + 100)}';
      final payload = {
        'id': 'rc_${DateTime.now().millisecondsSinceEpoch}',
        'token': randomTicket,
        'senderName': 'هاتف العامل (Floor)',
        'customerName': 'زبون المحل',
        'totalAmount': state.totalAmount,
        'items': state.cartItems.map((ci) => {
          'barcode': ci.product.barcode,
          'name': ci.product.name,
          'price': ci.product.price,
          'costPrice': ci.product.costPrice,
          'quantity': ci.quantity,
          'unit': 'قطعة',
        }).toList(),
      };

      final url = Uri.parse('http://$ip:$port/api/remote-cart');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 4));

      if (res.statusCode == 200) {
        SoundService.playCheckoutSuccess();
        context.read<BillingBloc>().add(ClearCartEvent());
        if (mounted) {
          context.showAppSnackBar(
            '✅ تم إرسال السلة بنجاح إلى الكاشير برقم تذكرة: $randomTicket',
            icon: Icons.send_rounded,
          );
        }
      } else {
        context.showAppSnackBar('❌ تعذر إرسال السلة: خطأ من السيرفر (${res.statusCode})', isError: true);
      }
    } catch (e) {
      context.showAppSnackBar('❌ تعذر الاتصال بالكاشير ($ip:$port). تأكد من تشغيل الواي فاي والسيرفر', isError: true);
    }
  }

  void _handleScannedBarcode(String code) {
    if (_isLanPairingCode(code)) {
      _handleLanPairingQr(code);
      return;
    }

    SoundService.playScanBeep();
    HapticFeedback.lightImpact();

    // Trigger futuristic laser green flash and dynamic lock effect
    setState(() {
      _isScanFlash = true;
      _isLockedOnBarcode = true;
    });
    Future.delayed(Duration(milliseconds: 380), () {
      if (mounted) {
        setState(() {
          _isScanFlash = false;
          _isLockedOnBarcode = false;
          _dynamicTargetOffset = null;
        });
      }
    });

    final productState = context.read<ProductBloc>().state;
    final matchedProduct = BarcodeNormalizer.findProduct(productState.products, code);

    if (_isMultiScanMode) {
      setState(() {
        _multiScanCount++;
        if (matchedProduct != null) {
          _lastScannedToast = '✅ ${matchedProduct.name} (${matchedProduct.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})';
        } else {
          _lastScannedToast = '⚡ تم مسح باركود: $code';
        }
      });

      Future.delayed(Duration(milliseconds: 1200), () {
        if (mounted && _lastScannedToast != null) {
          setState(() => _lastScannedToast = null);
        }
      });
    } else if (_currentSheetSize < 0.35) {
      _sheetController.animateTo(
        0.52,
        duration: Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    if (matchedProduct != null) {
      context.read<BillingBloc>().add(AddProductToCartEvent(matchedProduct));
    } else {
      context.read<BillingBloc>().add(ScanBarcodeEvent(code));
    }
  }

  void _handleQuickAddProduct(String barcode) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
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
                Text('إضافة سريعة لسلعة غير مسجلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'باركود: $barcode',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'اسم المنتج',
                hintText: 'e.g. حليب كونديا 1 لتر',
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع',
                      suffixText: AppConstants.currencySymbol,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: costPriceController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء (التكلفة)',
                      suffixText: AppConstants.currencySymbol,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الكمية الأولية بالمخزون',
              ),
            ),
            SizedBox(height: 20),
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
        title: Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text(context.tr('إفراغ السلة الحالية'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          context.tr('هل أنت متأكد من حذف جميع السلع الممسوحة في هذه السلة والبدء من جديد؟'),
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
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
            child: Text(context.tr('تأكيد الإفراغ'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: Row(
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.orange),
            SizedBox(width: 8),
            Text(context.tr('تعليق السلة الحالية (Panier en attente)'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم حفظ سلة هذا الزبون مؤقتاً لخدمة زبون آخر، ويمكنك استرجاعها في أي وقت خلال 20 دقيقة.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.tr('اسم الزبون أو وصف السلة (اختياري)'),
                hintText: 'مثال: الشاب ذو القميص الأزرق',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
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
            child: Text(context.tr('تعليق الفاتورة'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            title: Row(
              children: [
                Icon(Icons.percent_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(context.tr('تطبيق تخفيض / Remise'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(context.tr('نسبة مئوية %'))),
                        selected: isPercent,
                        onSelected: (val) => setDlgState(() => isPercent = true),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(context.tr('amount') + ' (' + context.tr('currency_symbol') + ')')),
                        selected: !isPercent,
                        onSelected: (val) => setDlgState(() => isPercent = false),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: isPercent ? context.tr('discount_percentage') : context.tr('discount_amount'),
                    suffixText: isPercent ? '%' : AppConstants.currencySymbol,
                  ),
                  onChanged: (_) => setDlgState(() {}),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('المجموع بعد التخفيض:'), style: TextStyle(fontSize: 13)),
                      Text(
                        '${previewTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
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
                  child: Text(context.tr('إلغاء التخفيض'), style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('cancel')),
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
                child: Text(context.tr('تطبيق'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
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
                      Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.amber),
                          SizedBox(width: 6),
                          Text(context.tr('إضافة سلعة لشريط البيع السريع ⚡'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  SizedBox(height: 10),

                  // Mode Segmented Buttons (From Stock vs Custom)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text('📦 ' + context.tr('تثبيت من المخزون'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        selected: selectedTab == 0,
                        selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                        onSelected: (v) => setDlgState(() => selectedTab = 0),
                      ),
                      ChoiceChip(
                        label: Text('✏️ ' + context.tr('سلعة مخصصة جديدة'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        selected: selectedTab == 1,
                        selectedColor: AppTheme.primaryColor.withOpacity(0.18),
                        onSelected: (v) => setDlgState(() => selectedTab = 1),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  if (selectedTab == 0) ...[
                    // Tab 1: Pick from Stock
                    TextField(
                      controller: searchStockController,
                      decoration: InputDecoration(
                        hintText: context.tr('ابحث عن سلعة في المخزون...'),
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: filteredStock.isEmpty
                          ? Center(
                              child: Text('لا توجد سلع في المخزون تطابق البحث', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            )
                          : ListView.separated(
                              itemCount: filteredStock.length,
                              separatorBuilder: (_, __) => Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final p = filteredStock[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                    child: Text('🛍️', style: TextStyle(fontSize: 16)),
                                  ),
                                  title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(
                                    'السعر: ${p.price.toStringAsFixed(0)} دج • المخزون: ${p.stock} قطعة',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                    child: Text(context.tr('تثبيت ⚡'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                              decoration: InputDecoration(labelText: 'اسم السلعة', hintText: 'مثال: خبز تقليدي، كيس، سجائر...'),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: priceController,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'سعر البيع (دج)', suffixText: AppConstants.currencySymbol),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: costPriceController,
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'سعر الشراء / التكلفة 🔒', suffixText: AppConstants.currencySymbol),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: iconController,
                              decoration: InputDecoration(labelText: 'الأيقونة / الرمز التعبيري', hintText: 'e.g. 🥖, 🥚, 🥛, 🛍️'),
                            ),
                            SizedBox(height: 14),

                            // Confidential Notice Banner
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              ),
                              child: Row(
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
                            SizedBox(height: 20),

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
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
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
                    Text(context.tr('تعديل السلعة السريعة'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'اسم السلعة'),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'سعر البيع', suffixText: AppConstants.currencySymbol),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: costPriceController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'سعر التكلفة 🔒', suffixText: AppConstants.currencySymbol),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: iconController,
                  decoration: InputDecoration(labelText: 'الأيقونة / الرمز التعبيري'),
                ),
                SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.delete_outline),
                        label: Text('حذف'),
                        onPressed: () async {
                          await _deleteQuickItem(item.id);
                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 12),
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

  void _showQuickItemOptions(QuickItem item) {
    final prod = _resolveProductForQuickItem(item);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(item.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.layers_rounded, color: Colors.teal),
                title: const Text('اختيار الوحدة والكمية (كرتون / فاردو / علبة / حبة)'),
                onTap: () {
                  Navigator.pop(ctx);
                  UniversalUnitSelectorDialog.showForProduct(context, prod);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('تعديل السعر والاسم'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditQuickItemDialog(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف من الشريط السريع', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteQuickItem(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSettings() async {
    if (SecurityPinHelper.isPinEnabled()) {
      final auth = await SecurityPinHelper.authenticate(
        context,
        title: 'الدخول إلى إدارة المتجر والإعدادات',
      );
      if (!auth) return;
    }
    setState(() => _isScanningPaused = true);
    try {
      _scannerController.stop();
    } catch (_) {}
    if (!mounted) return;
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
                snapSizes: [0.22, 0.52, 0.90],
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

                // Top Alerts: Expiry & Low Stock
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expiry Alert Badge
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, prodState) {
                        final expiringList = ExpiryTrackerService.getExpiringProducts(productsList: prodState.products);
                        final urgentCount = expiringList.where((i) => i.status == ExpiryStatus.expired || i.status == ExpiryStatus.critical7Days).length;
                        if (urgentCount == 0) return SizedBox.shrink();

                        return Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: InkWell(
                            onTap: () => context.push('/expiry-monitor'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[900]?.withOpacity(0.90),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.redAccent, width: 1.2),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_bottom_rounded, color: Colors.amberAccent, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '$urgentCount قاربت الصلاحية ⏳',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Low Stock Alert Badge
                    BlocBuilder<ProductBloc, ProductState>(
                      builder: (context, prodState) {
                        final lowStockProducts = prodState.products.where((p) => p.stock <= 5).toList();
                        if (lowStockProducts.isEmpty) return SizedBox.shrink();

                        return InkWell(
                          onTap: () => _handleLowStockBadgeTap(lowStockProducts),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange[900]?.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 1.2),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '${lowStockProducts.length} مخزون منخفض',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick Session Pause Button (إيقاف مؤقت للجلسة / استراحة)
                    Tooltip(
                      message: 'إيقاف مؤقت للجلسة / استراحة',
                      child: InkWell(
                        onTap: () {
                          setState(() => _isScanningPaused = true);
                          try {
                            _scannerController.stop();
                          } catch (_) {}
                          SessionLockOverlay.show(context).then((_) {
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
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 1.5),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

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
              ],
            ),
          ),

          // RIGHT SIDE FLOATING ESSENTIAL BUTTONS (Flash, Zoom & Camera)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 14,
            child: Column(
              children: [
                // 1. Flash Toggle Button
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon: _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    tooltip: 'تشغيل/إيقاف الفلاش',
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) SizedBox(height: 10),

                // 2. Single 2x Zoom Toggle Button
                if (_isCameraOn)
                  Tooltip(
                    message: _cameraZoomScale > 0.1 ? 'تكبير 2x مفعل (انقر للعودة لـ 1x)' : 'تكبير 1x (انقر للتكبير 2x ⚡)',
                    child: InkWell(
                      onTap: () {
                        final isZoomed = _cameraZoomScale > 0.1;
                        final newZoom = isZoomed ? 0.0 : 0.5; // 0.0 = 1x, 0.5 = 2x
                        setState(() {
                          _cameraZoomScale = newZoom;
                        });
                        _scannerController.setZoomScale(newZoom);
                        SoundService.playTabSwitch();
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_cameraZoomScale > 0.1)
                              ? AppTheme.primaryColor.withOpacity(0.9)
                              : Colors.black54,
                          border: Border.all(
                            color: (_cameraZoomScale > 0.1) ? Colors.white : Colors.white30,
                            width: (_cameraZoomScale > 0.1) ? 1.8 : 1.0,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (_cameraZoomScale > 0.1) ? '2x' : '1x',
                          style: TextStyle(
                            color: (_cameraZoomScale > 0.1) ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isCameraOn) SizedBox(height: 10),

                // 3. Camera Enable / Disable Button
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
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _lastScannedToast!,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Centered High-Tech Scanner Viewfinder Reticle
          if (_isCameraOn)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.16,
              left: (MediaQuery.of(context).size.width - 270) / 2,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 150),
                width: 270,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isScanFlash
                        ? Colors.greenAccent
                        : (_isLockedOnBarcode ? Colors.cyanAccent : Colors.white.withOpacity(0.7)),
                    width: _isScanFlash ? 3.5 : 2.0,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _isScanFlash
                          ? Colors.greenAccent.withOpacity(0.7)
                          : (_isLockedOnBarcode ? Colors.cyanAccent.withOpacity(0.4) : Colors.black.withOpacity(0.3)),
                      blurRadius: _isScanFlash ? 20 : 10,
                      spreadRadius: _isScanFlash ? 2 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Dynamic Laser Sweep
                    AnimatedBuilder(
                      animation: _laserAnimationController,
                      builder: (context, child) {
                        return Positioned(
                          top: 10 + (_laserAnimationController.value * 135),
                          left: 14,
                          right: 14,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: _isScanFlash
                                    ? [
                                        Colors.transparent,
                                        Colors.greenAccent,
                                        Colors.greenAccent,
                                        Colors.transparent,
                                      ]
                                    : [
                                        Colors.transparent,
                                        Colors.redAccent.withOpacity(0.9),
                                        Colors.red,
                                        Colors.redAccent.withOpacity(0.9),
                                        Colors.transparent,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _isScanFlash
                                      ? Colors.greenAccent.withOpacity(0.9)
                                      : Colors.redAccent.withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // High-tech corner HUD brackets
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                            left: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                            right: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                            left: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                            right: BorderSide(color: _isScanFlash ? Colors.greenAccent : Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70),
                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6)],
                  ),
                  child: Text(
                    '⚡ تم مسح $_multiScanCount سلع في هذه السلة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleLowStockBadgeTap(List<Product> lowStockProducts) {
    SoundService.playScanBeep();
    HapticFeedback.selectionClick();

    if (lowStockProducts.length == 1) {
      context.push('/products/edit/${lowStockProducts.first.id}', extra: lowStockProducts.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                    SizedBox(width: 8),
                    Text('سلع قريبة من النفاد (${lowStockProducts.length}) ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lowStockProducts.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = lowStockProducts[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text('الباركود: ${p.barcode} • البيع: ${p.price.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Text(
                            'المخزون: ${p.stock}',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 6),
                        IconButton(
                          icon: Icon(Icons.edit_note, color: AppTheme.primaryColor, size: 24),
                          tooltip: 'تعديل السلعة وتزويد المخزون',
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/products/edit/${p.id}', extra: p);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                    label: Text(context.tr('قائمة النواقص 🛒'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/products/shopping-list');
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(context.tr('كامل المخزن'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/products');
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

  Widget _buildCameraOffState() {
    return Container(
      color: Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, color: Colors.white, size: 32),
          SizedBox(height: 8),
          Text(context.tr('camera_off'),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            icon: Icon(Icons.videocam),
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
            duration: Duration(milliseconds: 1500),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isMultiScanMode ? Color(0xFF15803D) : Colors.black54,
            border: Border.all(
              color: _isMultiScanMode ? Colors.greenAccent : Colors.white70,
              width: _isMultiScanMode ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isMultiScanMode ? Colors.greenAccent.withOpacity(0.35) : Colors.black26,
                blurRadius: _isMultiScanMode ? 8 : 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isMultiScanMode) ...[
                // Back Barcode layer 3 (Offset top-left, subtle opacity)
                Transform.translate(
                  offset: Offset(-4.5, -4),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white30,
                    size: 19,
                  ),
                ),
                // Middle Barcode layer 2 (Offset top-left, medium opacity)
                Transform.translate(
                  offset: Offset(-2.2, -2),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                // Front Barcode layer 1 (Prominent, sharp, full opacity)
                Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                // Tiny Active Lightning Accent Badge
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(
                    padding: EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bolt,
                      size: 9,
                      color: Colors.black,
                    ),
                  ),
                ),
              ] else ...[
                // Single Clean Barcode Icon for Normal Single-Scan Mode
                Icon(
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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))],
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
                  duration: Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
              } else {
                _sheetController.animateTo(
                  0.22,
                  duration: Duration(milliseconds: 280),
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
                    margin: EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                BlocBuilder<BillingBloc, BillingState>(
                  builder: (context, state) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        _currentSheetSize > 0.35 ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${state.cartItems.length} ${context.tr('items_count')}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(width: 10),
                              if (state.cartItems.isNotEmpty) ...[
                                InkWell(
                                  onTap: _showClearCartConfirmationDialog,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 12, color: Colors.red),
                                        SizedBox(width: 2),
                                        Text(context.tr('clear'), style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                InkWell(
                                  onTap: _showParkCartDialog,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.pause_circle_outline, size: 12, color: Colors.orange),
                                        SizedBox(width: 2),
                                        Text(context.tr('hold'), style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                              ],
                              if (state.heldCarts.isNotEmpty) ...[
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => HeldCartsModal(),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.indigo.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 12, color: Colors.indigo),
                                        SizedBox(width: 4),
                                        Text(
                                          'المعلقة (${state.heldCarts.length})',
                                          style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold),
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
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              if (state.calculatedDiscount > 0)
                                Text(
                                  'تخفيض: -${state.calculatedDiscount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                                  style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
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
          Divider(height: 12),

          // Action Pills (Scale Vrac, Quick Amount, Discount, Return Mode)
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Container(
                height: 38,
                margin: EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Smart Scale Modal
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SmartScaleModal(),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.scale, size: 15, color: Colors.teal),
                            SizedBox(width: 4),
                            Text('ميزان وتجزئة (Vrac)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Quick Amount
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => QuickAmountModal(),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.dialpad, size: 15, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('مبلغ مباشر (دايركت)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Discount Remise
                    InkWell(
                      onTap: () => _showDiscountDialog(state),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.calculatedDiscount > 0 ? Colors.purple : Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.percent_rounded, size: 15, color: state.calculatedDiscount > 0 ? Colors.white : Colors.purple),
                            SizedBox(width: 4),
                            Text(
                              state.calculatedDiscount > 0 ? 'تخفيض (${state.calculatedDiscount.toStringAsFixed(0)}دج)' : 'تخفيض / Remise',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: state.calculatedDiscount > 0 ? Colors.white : Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),

                    // Return Mode
                    InkWell(
                      onTap: () {
                        context.read<BillingBloc>().add(ToggleReturnModeEvent());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: state.isReturnMode ? Colors.red : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: state.isReturnMode ? Colors.red : Colors.grey[400]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.replay_circle_filled, size: 15, color: state.isReturnMode ? Colors.white : Colors.black87),
                            SizedBox(width: 4),
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
            padding: EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    padding: EdgeInsets.symmetric(horizontal: 16),
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
                        margin: EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: () => _addQuickItem(item),
                          onLongPress: () => _showQuickItemOptions(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: BoxConstraints(minWidth: 85),
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.icon, style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${item.price.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF1E40AF), fontWeight: FontWeight.w700),
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
                  padding: EdgeInsets.only(left: 8, right: 16),
                  child: InkWell(
                    onTap: _showAddQuickItemDialog,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                      ),
                      child: Row(
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
          SizedBox(height: 8),

          // Cart Items List
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return Container(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey[400]),
                      SizedBox(height: 6),
                      Text(context.tr('cart_empty'),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
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
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.cartItems.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return _buildCartItemCard(context, item);
                    },
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Button 1: Send Cart to Master POS Desktop (F9)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            icon: Icon(Icons.send_rounded, size: 20),
                            label: Text(
                              'إرسال السلة للكاشير الرئيسي 📤',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            onPressed: () => _sendCartToMasterPos(state),
                          ),
                        ),
                        SizedBox(height: 8),

                        // Button 2: Local Checkout
                        PrimaryButton(
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
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    final hasMulti = item.product.hasMultiUnit;

    return Dismissible(
      key: ValueKey('cart_item_${item.cartKey}_${item.quantity}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green[600],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
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
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.quantity > 1 ? '-1' : 'حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(width: 4),
            Icon(item.quantity > 1 ? Icons.remove_circle : Icons.delete, color: Colors.white, size: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right -> +1
          context.read<BillingBloc>().add(
                UpdateQuantityEvent(
                  item.cartKey,
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
                  item.cartKey,
                  newQty,
                ),
              );
          SoundService.playDeleteSound();
          HapticFeedback.mediumImpact();
          return newQty <= 0;
        }
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasMulti) ...[
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () => UniversalUnitSelectorDialog.showForCartItem(context, item),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: item.unitLevel == 'piece'
                                  ? Colors.amber.shade50
                                  : item.unitLevel == 'carton'
                                      ? Colors.purple.shade50
                                      : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.unitLevel == 'piece'
                                    ? Colors.amber.shade400
                                    : item.unitLevel == 'carton'
                                        ? Colors.purple.shade400
                                        : Colors.blue.shade400,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.unitDisplayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.unitLevel == 'piece'
                                        ? Colors.amber.shade900
                                        : item.unitLevel == 'carton'
                                            ? Colors.purple.shade900
                                            : Colors.blue.shade900,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, size: 13, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${item.unitPrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}' +
                        (item.unitLevel != 'pack' ? ' [${item.unitDisplayName}]' : ''),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                  onPressed: () {
                    context.read<BillingBloc>().add(
                          UpdateQuantityEvent(
                            item.cartKey,
                            item.quantity - 1,
                          ),
                        );
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                  onPressed: () {
                    context.read<BillingBloc>().add(
                          UpdateQuantityEvent(
                            item.cartKey,
                            item.quantity + 1,
                          ),
                        );
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            SizedBox(width: 12),
            Text(
              '${item.total.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.grey),
              onPressed: () {
                context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.cartKey));
              },
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
