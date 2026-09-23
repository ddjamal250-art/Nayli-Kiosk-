import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/kiosk_service.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../../core/data/master_catalog_service.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/utils/category_taxonomy.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/staff_permissions_service.dart';
import '../../../../core/utils/whatsapp_helper.dart';
import '../../../../core/utils/adaptive_modal_helper.dart';
import '../../../settings/presentation/pages/advanced_pos_settings_page.dart';
import '../../../product/presentation/pages/expiry_monitor_page.dart';
import '../../../../core/utils/tpe_payment_service.dart';
import '../../../customer/presentation/cubit/customer_cubit.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../../core/widgets/product_image_display.dart';
import '../../../shifts/data/shift_service.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/held_cart.dart';
import '../bloc/billing_bloc.dart';
import '../widgets/held_carts_modal.dart';
import '../widgets/quick_items_manager_dialog.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/pos_payment_modal.dart';
import '../widgets/pos_header_toolbar.dart';
import '../widgets/universal_unit_selector_dialog.dart';
import '../../../../core/services/github_update_service.dart';

enum PosPriceTier { detail, demiGros, gros }

class DesktopPosPage extends StatefulWidget {
  const DesktopPosPage({super.key});

  @override
  State<DesktopPosPage> createState() => _DesktopPosPageState();
}

class _DesktopPosPageState extends State<DesktopPosPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _globalKeyboardFocusNode = FocusNode();

  String _selectedCategoryKey = 'all';
  String? _selectedCustomerId;
  String _selectedCustomerName = 'زبون عادي';
  double _customerCreditBalance = 0.0;

  // Operating Modes
  PosPriceTier _activePriceTier = PosPriceTier.detail;
  bool _isReturnMode = false;
  double _cartDiscountValue = 0.0;
  bool _isDiscountPercentage = false;
  bool _showTouchNumpad = false;
  List<Product> _searchSuggestions = [];

  // Costco IPM Speedometer tracking
  int _scannedItemsCount = 0;
  DateTime _sessionStartTime = DateTime.now();
  double _currentIpm = 0.0;
  Timer? _ipmTimer;

  // Local Master Server Status & Remote Carts Stream
  String _serverIp = '127.0.0.1';
  bool _isServerRunning = false;
  StreamSubscription<RemoteIncomingCart>? _remoteCartSub;
  StreamSubscription<RemoteIncomingCart>? _handoffCartSub;
  StreamSubscription<Map<String, dynamic>>? _unlistedKioskScanSub;
  int _pendingRemoteCartsCount = 0;

  // USB Barcode Wedge Rapid Buffer
  String _hardwareBarcodeBuffer = '';
  DateTime _lastHardwareKeyTime = DateTime.now();

  static const List<Map<String, String>> _categoriesDef = [
    {'key': 'all', 'tr': 'cat_all', 'ar': 'الكل', 'icon': '🛒'},
    {'key': 'tobacco', 'tr': 'tobacco_btn', 'ar': 'المواد التبغية', 'icon': '🚬'},
    {'key': 'cold_drinks', 'tr': 'cat_beverages', 'ar': 'المشروبات والعصائر', 'icon': '🥤'},
    {'key': 'dairy', 'tr': 'cat_dairy', 'ar': 'الألبان والأجبان', 'icon': '🥛'},
    {'key': 'coffee_tea', 'tr': 'cat_coffee_tea', 'ar': 'القهوة الجاهزة', 'icon': '☕'},
    {'key': 'sweets', 'tr': 'cat_sweets', 'ar': 'الحلويات والسكاكر', 'icon': '🍫'},
    {'key': 'scale', 'tr': 'cat_scale', 'ar': 'سلع الميزان', 'icon': '⚖️'},
    {'key': 'pulses', 'tr': 'cat_pulses', 'ar': 'البقوليات والحبوب', 'icon': '🌾'},
    {'key': 'canned', 'tr': 'cat_canned', 'ar': 'المعلبات والزيوت', 'icon': '🥫'},
    {'key': 'bakery', 'tr': 'cat_bakery', 'ar': 'المخبوزات والعجائن', 'icon': '🥖'},
    {'key': 'cleaning', 'tr': 'cat_cleaning', 'ar': 'المنظفات والتطهير', 'icon': '🧽'},
    {'key': 'hygiene', 'tr': 'cat_hygiene', 'ar': 'العناية الشخصية', 'icon': '🧴'},
    {'key': 'stationery', 'tr': 'cat_stationery', 'ar': 'الأدوات المدرسية والمكتبية', 'icon': '📚'},
    {'key': 'phone_accessories', 'tr': 'cat_phone_acc', 'ar': 'لواحق هواتف وإلكترونيات', 'icon': '📱'},
    {'key': 'batteries', 'tr': 'cat_batteries', 'ar': 'بطاريات وكهربائيات', 'icon': '🔋'},
    {'key': 'cosmetics', 'tr': 'cat_cosmetics', 'ar': 'كوسميتيك وعطور', 'icon': '💄'},
    {'key': 'toys', 'tr': 'cat_toys', 'ar': 'ألعاب وهدايا', 'icon': '🧸'},
    {'key': 'produce', 'tr': 'cat_produce', 'ar': 'الخضر والفواكه واللحوم', 'icon': '🍏'},
    {'key': 'general_news', 'tr': 'cat_general', 'ar': 'منتجات عامة وجرائد', 'icon': '📰'},
    {'key': 'spices', 'tr': 'cat_spices', 'ar': 'التوابل والبهارات', 'icon': '🧂'},
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
    _initLocalServer();
    _startIpmCalculator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
      _restoreAutoSavedCart();
      GitHubUpdateService.runStartupCheck(context);
    });
  }

  /// استعادة السلة المعلقة تلقائياً إذا تم حفظها قبل تثبيت تحديث
  void _restoreAutoSavedCart() {
    try {
      final savedData = HiveDatabase.settingsBox.get('auto_saved_cart_before_update');
      if (savedData != null && savedData is Map) {
        final heldCart = HeldCart.fromMap(savedData);
        if (heldCart.items.isNotEmpty) {
          final billingBloc = context.read<BillingBloc>();
          for (final item in heldCart.items) {
            billingBloc.add(AddProductToCartEvent(item.product, quantity: item.quantity));
          }
          HiveDatabase.settingsBox.delete('auto_saved_cart_before_update');
          SoundService.playSaveSuccess();
          SnackbarHelper.showSuccess(
            context,
            '✅ تمت استعادة سلة المبيعات (${heldCart.items.length} سلع) تلقائياً بعد التحديث!',
          );
        }
      }
    } catch (e) {
      debugPrint('Error restoring auto-saved cart: $e');
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _globalKeyboardFocusNode.dispose();
    _ipmTimer?.cancel();
    _remoteCartSub?.cancel();
    _handoffCartSub?.cancel();
    _unlistedKioskScanSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocalServer() async {
    try {
      final started = await LocalSyncServer.startServer();
      final ip = await LocalSyncServer.getLocalIp();
      
      _remoteCartSub = LocalSyncServer.remoteCartStream.listen((cart) {
        if (mounted) {
          setState(() {
            _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
          });
          SoundService.playRestockSound();
          SnackbarHelper.showSuccess(
            context,
            '🔔 ${context.tr('pos_incoming_carts')}: ${cart.senderName} (${cart.token}) - ${cart.totalAmount.toStringAsFixed(2)} DA',
          );
        }
      });

      _handoffCartSub = LocalSyncServer.posHandoffStream.listen((cart) {
        if (mounted) {
          SoundService.playMemberCardScan();
          _showIncomingHandoffBanner(cart);
        }
      });
      _unlistedKioskScanSub = KioskService.unlistedScanStream.listen((scanData) {
        if (mounted) {
          SoundService.playWarning();
          final barcode = scanData['barcode']?.toString() ?? '';
          final count = scanData['scanCount'] ?? 1;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFC2410C),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 8),
              content: Row(
                children: [
                  const Icon(Icons.notification_important_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ كشك الزبائن: زبون مسح سلعة غير مسجلة ($barcode) • مسحت $count مرات',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'أضف للمخزون ➕',
                textColor: Colors.amberAccent,
                onPressed: () => context.push('/add-product?barcode=$barcode'),
              ),
            ),
          );
        }
      });

      if (mounted) {
        setState(() {
          _isServerRunning = started;
          _serverIp = ip;
          _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
        });
      }
    } catch (e) {
      debugPrint('Local server init failed: $e');
    }
  }

  void _startIpmCalculator() {
    _sessionStartTime = DateTime.now();
    _ipmTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final elapsedMinutes = DateTime.now().difference(_sessionStartTime).inSeconds / 60.0;
      if (elapsedMinutes > 0.1 && mounted) {
        setState(() {
          _currentIpm = (_scannedItemsCount / elapsedMinutes).clamp(0.0, 99.0);
        });
      }
    });
  }

  void _onItemScanned() {
    _scannedItemsCount++;
    SoundService.playScanBeep();
  }

  String _normalizeSearchText(String input) {
    if (input.isEmpty) return '';
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // Remove Arabic tashkeel
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا') // Unify Alef
        .replaceAll('ة', 'ه') // Unify Taa Marbuta
        .replaceAll('ى', 'ي') // Unify Yaa / Alef Maqsura
        .replaceAll(RegExp(r'[\s\-_]+'), ' ');
  }

  int _getCurrentMultiplier() {
    final text = _barcodeController.text.trim();
    if (text.contains('*')) {
      final parts = text.split('*');
      final qty = int.tryParse(parts[0]);
      if (qty != null && qty > 0 && qty <= 500) {
        return qty;
      }
    }
    return 1;
  }

  Future<void> _showCoffeeSaleDialog(Product product, int multiplier) async {
    final TextEditingController priceCtrl = TextEditingController(text: product.resolvedPiecePrice.toStringAsFixed(0));
    String deductType = 'cup'; // 'cup', 'full_pack'
    int cupQty = (multiplier > 1) ? multiplier : 1;
    
    // Load accessories from state
    final productsState = context.read<ProductBloc>().state;
    List<Product> availableAccessories = [];
    Set<String> selectedAccessoryIds = {};

    if (productsState.status == ProductStatus.loaded) {
      availableAccessories = productsState.products.where((p) {
        if (p.id == product.id) return false;
        final n = p.name.toLowerCase();
        final c = p.category.toLowerCase();
        // Strictly exclude packaged beverages, water bottles, and juices from coffee supplies
        if (p.isBeverage || n.contains('ماء') || n.contains('eau') || n.contains('عصير') || n.contains('قارورة') || n.contains('كوكا')) {
          return false;
        }
        return c.contains('مستلزم') || n.contains('سكر') || n.contains('غوبلي') || n.contains('gobelet') || n.contains('مغرف') || n.contains('ملعق') || n.contains('cuill');
      }).toList();

      // Auto-select standard accessories if they exist
      for (var acc in availableAccessories) {
        final n = acc.name.toLowerCase();
        if (n.contains('غوبلي') || n.contains('gobelet') || 
            n.contains('سكر') || n.contains('sucre') || 
            n.contains('مغرف') || n.contains('ملعق') || n.contains('cuill')) {
          selectedAccessoryIds.add(acc.id);
        }
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isFullPack = deductType == 'full_pack';
            
            // Calculate Total Cost per single unit
            double singleCost = isFullPack ? product.costPrice : product.resolvedPieceCost;
            if (!isFullPack) {
              for (var accId in selectedAccessoryIds) {
                final acc = availableAccessories.firstWhere((p) => p.id == accId);
                singleCost += acc.resolvedPieceCost;
              }
            }
            final currentQty = isFullPack ? (1 * multiplier) : cupQty;
            final double totalCost = singleCost * currentQty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.coffee_maker, color: Colors.brown),
                  SizedBox(width: 8),
                  Expanded(child: Text('${context.tr("بيع / تحضير:")} ${product.name}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('المخزون الحالي:'), style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            isFullPack 
                              ? '${product.stock} ${product.resolvedPackName}'
                              : '${product.stock * product.cupsYield} ${product.resolvedSubUnitName}',
                            style: TextStyle(color: Colors.brown.shade900, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(context.tr('نوع المبيعة:'), style: TextStyle(fontWeight: FontWeight.bold)),
                    Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('${context.tr("تحضير وبيع بالأكواب")} (${product.resolvedSubUnitName})', style: TextStyle(fontSize: 13)),
                          value: 'cup',
                          groupValue: deductType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) {
                            setDialogState(() {
                              deductType = v!;
                              priceCtrl.text = product.resolvedPiecePrice.toStringAsFixed(0);
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: Text('${context.tr("بيع العلبة بالكامل")} (${product.resolvedPackName})', style: TextStyle(fontSize: 13)),
                          value: 'full_pack',
                          groupValue: deductType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) {
                            setDialogState(() {
                              deductType = v!;
                              priceCtrl.text = product.price.toStringAsFixed(0);
                            });
                          },
                        ),
                      ],
                    ),

                    if (!isFullPack) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(context.tr('عدد الكؤوس:'), style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.brown),
                            onPressed: () {
                              if (cupQty > 1) {
                                setDialogState(() => cupQty--);
                              }
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.brown.shade300),
                            ),
                            child: Text(
                              '$cupQty',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.brown),
                            onPressed: () => setDialogState(() => cupQty++),
                          ),
                          const Spacer(),
                          ...[1, 2, 3, 5].map((q) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => setDialogState(() => cupQty = q),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cupQty == q ? Colors.brown : Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: cupQty == q ? Colors.brown : Colors.brown.shade200),
                                ),
                                child: Text(
                                  '$q',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: cupQty == q ? Colors.white : Colors.brown,
                                  ),
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),
                    ],
                    
                    if (!isFullPack && availableAccessories.isNotEmpty) ...[
                      SizedBox(height: 14),
                      Text(context.tr('مستلزمات الطلب (تخصم تلقائياً من المخزون وتُحسب تكلفتها):'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableAccessories.map((acc) {
                          final isSelected = selectedAccessoryIds.contains(acc.id);
                          return FilterChip(
                            label: Text('${acc.name} (${acc.resolvedPieceCost.toStringAsFixed(2)} دج)'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedAccessoryIds.add(acc.id);
                                } else {
                                  selectedAccessoryIds.remove(acc.id);
                                }
                              });
                            },
                            selectedColor: Colors.brown.shade100,
                            checkmarkColor: Colors.brown,
                          );
                        }).toList(),
                      ),
                    ],
                    
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isFullPack ? context.tr('التكلفة الإجمالية:') : '${context.tr("التكلفة الإجمالية")} ($cupQty):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text('${totalCost.toStringAsFixed(2)} دج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 16)),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 10),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isFullPack ? context.tr('سعر بيع العلبة') : context.tr('سعر بيع الكأس الواحد للزبون'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixText: context.tr('currency_symbol'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.tr('إلغاء'), style: TextStyle(color: Colors.grey.shade700)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text) ?? (isFullPack ? product.price : product.resolvedPiecePrice);
                    final finalQty = isFullPack ? (1 * multiplier) : cupQty;

                    if (isFullPack) {
                      context.read<BillingBloc>().add(AddProductToCartEvent(
                        product,
                        unitLevel: 'pack',
                        quantity: finalQty,
                        customPrice: price,
                      ));
                    } else {
                      // 1. Add Main Coffee Product
                      context.read<BillingBloc>().add(AddProductToCartEvent(
                        product,
                        unitLevel: 'piece',
                        quantity: finalQty,
                        customPrice: price,
                      ));

                      // 2. Add Selected Accessories
                      for (var accId in selectedAccessoryIds) {
                        final acc = availableAccessories.firstWhere((p) => p.id == accId);
                        context.read<BillingBloc>().add(AddProductToCartEvent(
                          acc, unitLevel: 'piece', quantity: finalQty, customPrice: 0.0, customUnitName: 'مستلزمات',
                        ));
                      }
                    }
                    
                    Navigator.pop(ctx);
                    SnackbarHelper.showSuccess(context, 'تمت إضافة $finalQty بنجاح!');
                  },
                  child: Text(context.tr('تأكيد وإضافة')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addProductToCartWithPricing(Product product, {int quantity = 1}) {
    if (product.isCoffeeMachineProduct && !_isReturnMode) {
      _showCoffeeSaleDialog(product, quantity);
      return;
    }
    double effectivePrice = product.price;
    if (_activePriceTier == PosPriceTier.gros && product.wholesalePrice > 0) {
      effectivePrice = product.wholesalePrice;
    } else if (_activePriceTier == PosPriceTier.demiGros && product.wholesalePrice > 0) {
      effectivePrice = (product.price + product.wholesalePrice) / 2;
    }

    if (_isReturnMode) {
      effectivePrice = -effectivePrice.abs();
    }

    final itemProduct = Product(
      id: product.id,
      name: _isReturnMode ? '[${context.tr('return_mode')}] ${product.name}' : product.name,
      barcode: product.barcode,
      price: effectivePrice,
      costPrice: product.costPrice,
      stock: product.stock,
      category: product.category,
      imageUrl: product.imageUrl,
      isTobacco: product.isTobacco,
      wholesalePrice: product.wholesalePrice,
      cartonPrice: product.cartonPrice,
      wholesaleCartonPrice: product.wholesaleCartonPrice,
      wholesalePackPrice: product.wholesalePackPrice,
      singlePiecePrice: product.singlePiecePrice,
      piecesPerPack: product.piecesPerPack,
      packsPerCarton: product.packsPerCarton,
      unitType: product.unitType,
      isWeighted: product.isWeighted,
    );

    context.read<BillingBloc>().add(AddProductToCartEvent(itemProduct, quantity: quantity));
    _onItemScanned();
    if (mounted) {
      setState(() {
        _searchSuggestions = [];
        _barcodeController.clear();
      });
      _barcodeFocusNode.requestFocus();
    }
  }

  List<Product> _findProductsByNameOrBarcode(String rawQuery) {
    if (rawQuery.trim().isEmpty) return [];
    final query = rawQuery.trim();
    final normQuery = _normalizeSearchText(query);
    final products = context.read<ProductBloc>().state.products;

    // 1. Check exact barcode match first
    final exactBarcode = products.where((p) => BarcodeNormalizer.matches(p.barcode, query)).toList();
    if (exactBarcode.isNotEmpty) {
      return exactBarcode;
    }

    final matched = <Product>[];
    for (final p in products) {
      final normName = _normalizeSearchText(p.name);
      final normBarcode = BarcodeNormalizer.clean(p.barcode);
      final normCategory = _normalizeSearchText(p.category);

      if (normName.contains(normQuery) ||
          normBarcode.contains(query) ||
          normCategory.contains(normQuery)) {
        matched.add(p);
      }
    }

    // Sort: exact name match first, prefix match second, then alphabetical
    matched.sort((a, b) {
      final aName = _normalizeSearchText(a.name);
      final bName = _normalizeSearchText(b.name);

      final aExact = aName == normQuery;
      final bExact = bName == normQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      final aStarts = aName.startsWith(normQuery);
      final bStarts = bName.startsWith(normQuery);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return aName.compareTo(bName);
    });

    return matched;
  }

  void _onSearchTextChanged(String text) {
    final raw = text.trim();
    if (raw.isEmpty || raw.length < 2) {
      if (_searchSuggestions.isNotEmpty) {
        setState(() {
          _searchSuggestions = [];
        });
      }
      return;
    }

    String query = raw;
    if (raw.contains('*')) {
      final parts = raw.split('*');
      if (parts.length > 1) {
        query = parts.sublist(1).join('*').trim();
      }
    }

    if (query.length < 2) {
      if (_searchSuggestions.isNotEmpty) {
        setState(() {
          _searchSuggestions = [];
        });
      }
      return;
    }

    // If query is pure digits and >= 8 digits, likely hardware wedge barcode scan
    final isBarcodeOnly = RegExp(r'^\d+$').hasMatch(query);
    if (isBarcodeOnly && query.length >= 8) {
      final matches = _findProductsByNameOrBarcode(query);
      setState(() {
        _searchSuggestions = matches.take(6).toList();
      });
      return;
    }

    final matches = _findProductsByNameOrBarcode(query);
    setState(() {
      _searchSuggestions = matches.take(8).toList();
    });
  }

  void _showProductSelectionModal(List<Product> matches, {int multiplier = 1, required String query}) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نتائج البحث: "$query"',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'اختر السلعة المطلوبة لإضافتها إلى السلة (${matches.length} نتائج)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final product = matches[index];
                      double effectivePrice = product.price;
                      if (_activePriceTier == PosPriceTier.gros && product.wholesalePrice > 0) {
                        effectivePrice = product.wholesalePrice;
                      } else if (_activePriceTier == PosPriceTier.demiGros && product.wholesalePrice > 0) {
                        effectivePrice = (product.price + product.wholesalePrice) / 2;
                      }

                      final isOutOfStock = product.stock <= 0;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _addProductToCartWithPricing(product, quantity: multiplier);
                          SnackbarHelper.showSuccess(
                            context,
                            '${context.tr("added_to_cart")}: ${product.name} (x$multiplier)',
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: ProductImageDisplay(
                                    imageUrl: product.imageUrl,
                                    width: 48,
                                    height: 48,
                                    borderRadius: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (product.barcode.isNotEmpty) ...[
                                          Text(
                                            product.barcode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            product.category,
                                            style: TextStyle(fontSize: 10, color: Colors.teal.shade800),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'المخزون: ${product.stock}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isOutOfStock ? Colors.red.shade700 : Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${effectivePrice.toStringAsFixed(0)} ${context.tr("currency_symbol")}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: const Size(0, 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(dialogCtx);
                                      _addProductToCartWithPricing(product, quantity: multiplier);
                                      SnackbarHelper.showSuccess(
                                        context,
                                        '${context.tr("added_to_cart")}: ${product.name} (x$multiplier)',
                                      );
                                    },
                                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                                    label: Text(multiplier > 1 ? 'إضافة (x$multiplier)' : 'إضافة', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMasterCatalogSuggestionModal(List<MasterCatalogItem> catalogMatches, {int multiplier = 1, required String query}) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 620,
            constraints: const BoxConstraints(maxHeight: 520),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.travel_explore_rounded, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الكتالوج الجزائري الشامل (59 ألف منتج)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'غير مسجل بمحلك بعد. اختر لإضافته إلى المخزون وبيعه فوراً:',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: catalogMatches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = catalogMatches[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.blue.shade50.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(item.categoryIcon, style: const TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        item.barcode,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: TextStyle(fontSize: 10, color: Colors.blue.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.defaultPrice.toStringAsFixed(0)} ${context.tr("currency_symbol")}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    final newProduct = Product(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      name: item.name,
                                      barcode: item.barcode,
                                      price: item.defaultPrice > 0 ? item.defaultPrice : 100.0,
                                      costPrice: item.defaultCost > 0 ? item.defaultCost : 80.0,
                                      stock: 50,
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
                                      wholesalePrice: item.wholesalePrice > 0 ? item.wholesalePrice : item.defaultPrice,
                                    );
                                    context.read<ProductBloc>().add(AddProduct(newProduct));
                                    _addProductToCartWithPricing(newProduct, quantity: multiplier);
                                    SnackbarHelper.showSuccess(
                                      context,
                                      'تمت إضافة "${item.name}" إلى مخزون المحل والسلة بنجاح',
                                    );
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(context.tr('إضافة وبيع'), style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleBarcodeSubmit(String rawInput) {
    if (rawInput.trim().isEmpty) return;
    final input = rawInput.trim();
    _barcodeController.clear();
    setState(() {
      _searchSuggestions = [];
    });
    _barcodeFocusNode.requestFocus();

    // Check for quantity multiplier syntax (e.g., "5*6130140001019" or "3*حليب")
    int multiplier = 1;
    String barcodeToScan = input;
    if (input.contains('*')) {
      final parts = input.split('*');
      final parsedQty = int.tryParse(parts[0]);
      if (parsedQty != null && parsedQty > 0 && parsedQty <= 500) {
        multiplier = parsedQty;
        barcodeToScan = parts.sublist(1).join('*').trim();
      }
    }

    if (barcodeToScan.isEmpty) return;

    _onItemScanned();

    // 1. Check if input matches any Quick Item shortCode or barcode
    final quickBox = HiveDatabase.quickItemsBox;
    Map? matchedQuickItem;
    for (var val in quickBox.values) {
      if (val is Map) {
        final sc = val['shortCode']?.toString().trim();
        final bc = val['barcode']?.toString().trim();
        final id = val['id']?.toString().trim();
        if (sc == barcodeToScan || bc == barcodeToScan || id == barcodeToScan) {
          matchedQuickItem = val;
          break;
        }
      }
    }

    if (matchedQuickItem != null) {
      final quickProduct = _resolveProductForQuickItem(matchedQuickItem);
      if (quickProduct.isCoffeeMachineProduct && !_isReturnMode) {
        _showCoffeeSaleDialog(quickProduct, 1);
      } else {
        UniversalUnitSelectorDialog.showForProduct(context, quickProduct);
      }
      return;
    }

    // 2. Check for electronic scale barcode (Dibal, CAS, Bizerba, Aclas)
    if (StaffPermissionsService.enableScaleBarcode) {
      final scaleResult = BarcodeNormalizer.parseScaleBarcode(
        barcodeToScan,
        prefixes: StaffPermissionsService.scaleBarcodePrefixes,
      );
      if (scaleResult != null) {
        final productBloc = context.read<ProductBloc>();
        final products = productBloc.state.products;
        final scaleProduct = BarcodeNormalizer.findScaleProduct(products, scaleResult);
        if (scaleProduct != null) {
          double effectiveUnitPrice = scaleProduct.price;
          if (_activePriceTier == PosPriceTier.gros && scaleProduct.wholesalePrice > 0) {
            effectiveUnitPrice = scaleProduct.wholesalePrice;
          } else if (_activePriceTier == PosPriceTier.demiGros && scaleProduct.wholesalePrice > 0) {
            effectiveUnitPrice = (scaleProduct.price + scaleProduct.wholesalePrice) / 2;
          }

          final double calculatedTotal = scaleResult.isWeightBased
              ? (effectiveUnitPrice * scaleResult.weightKg)
              : (scaleResult.totalPrice ?? effectiveUnitPrice);

          final double finalPrice = _isReturnMode ? -calculatedTotal.abs() : calculatedTotal;
          final weightDisplay = scaleResult.isWeightBased ? ' (${scaleResult.weightKg.toStringAsFixed(3)} ' + context.tr('kg') + ')' : '';

          final scaleCartProduct = Product(
            id: 'scale_${scaleProduct.id}_${DateTime.now().millisecondsSinceEpoch}',
            name: _isReturnMode
                ? '[${context.tr("return_mode")}] ${scaleProduct.name}$weightDisplay'
                : '${scaleProduct.name}$weightDisplay',
            barcode: barcodeToScan,
            price: finalPrice,
            costPrice: scaleProduct.costPrice * (scaleResult.isWeightBased ? scaleResult.weightKg : 1.0),
            stock: scaleProduct.stock,
            category: scaleProduct.category,
            isWeighted: true,
          );

          context.read<BillingBloc>().add(AddProductToCartEvent(scaleCartProduct));
          _onItemScanned();
          _barcodeFocusNode.requestFocus();
          return;
        }
      }
    }

    // 3. Find product in local inventory by barcode (exact or normalized)
    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    final barcodeProduct = BarcodeNormalizer.findProduct(products, barcodeToScan);

    if (barcodeProduct != null) {
      _addProductToCartWithPricing(barcodeProduct, quantity: multiplier);
      return;
    }

    // 4. Search by product name / keyword in local inventory
    final nameMatches = _findProductsByNameOrBarcode(barcodeToScan);
    if (nameMatches.length == 1) {
      _addProductToCartWithPricing(nameMatches.first, quantity: multiplier);
      SnackbarHelper.showSuccess(
        context,
        '${context.tr("added_to_cart")}: ${nameMatches.first.name} (x$multiplier)',
      );
      return;
    } else if (nameMatches.length > 1) {
      _showProductSelectionModal(nameMatches, multiplier: multiplier, query: barcodeToScan);
      return;
    }

    // 5. Check Algerian National Master Catalog (59,000 items)
    final masterMatches = MasterCatalogService.instance.search(barcodeToScan, limit: 12);
    if (masterMatches.isNotEmpty) {
      _showMasterCatalogSuggestionModal(masterMatches, multiplier: multiplier, query: barcodeToScan);
      return;
    }

    // 6. Not found anywhere
    SoundService.playWarning();
    SnackbarHelper.showWarning(
      context,
      '${context.tr("product_not_found")}: "$barcodeToScan"',
    );
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Hardware Scanner Wedge rapid typing listener
    final now = DateTime.now();
    final diffMs = now.difference(_lastHardwareKeyTime).inMilliseconds;
    _lastHardwareKeyTime = now;

    if (event.character != null && event.character!.isNotEmpty && event.logicalKey != LogicalKeyboardKey.enter) {
      if (diffMs < 50) {
        _hardwareBarcodeBuffer += event.character!;
      } else {
        _hardwareBarcodeBuffer = event.character!;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.enter && _hardwareBarcodeBuffer.length >= 4) {
      final code = _hardwareBarcodeBuffer;
      _hardwareBarcodeBuffer = '';
      _handleBarcodeSubmit(code);
      return true;
    }

    if (StaffPermissionsService.enableFastKeyboardShortcuts) {
      if ((event.logicalKey == LogicalKeyboardKey.delete ||
              (event.logicalKey == LogicalKeyboardKey.backspace && _barcodeController.text.isEmpty)) &&
          !_barcodeFocusNode.hasFocus) {
        _quickVoidLastItem();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.add || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
        _adjustLastItemQuantity(1);
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
        _adjustLastItemQuantity(-1);
        return true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _barcodeFocusNode.requestFocus();
      _barcodeController.selection = TextSelection(baseOffset: 0, extentOffset: _barcodeController.text.length);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      _handleHoldOrResumeCart();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      _showCustomerSelector();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      _showDiscountModal();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f5) {
      _cyclePriceTier();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f6) {
      _toggleReturnMode();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f7) {
      _showQuickCustomItemModal();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f8) {
      _showPriceChecker();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f9) {
      _showRemoteCartsQueueModal();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f10) {
      _openCashDrawerWithSecurity();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f11) {
      _showRegisterHandoffModal(context.read<BillingBloc>().state);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f12 || 
        (event.logicalKey == LogicalKeyboardKey.space && 
         !_barcodeFocusNode.hasFocus && 
         FocusManager.instance.primaryFocus?.context?.widget is! EditableText)) {
      _triggerCheckout();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _confirmClearCart();
      }
      return true;
    }

    return false;
  }

  Future<void> _quickVoidLastItem() async {
    final billingBloc = context.read<BillingBloc>();
    final items = billingBloc.state.cartItems;
    if (items.isEmpty) return;

    final lastItem = items.last;
    if (StaffPermissionsService.requirePinForVoid) {
      final auth = await SecurityPinHelper.authenticate(context, title: '${context.tr("cancel")} ${lastItem.product.name}');
      if (!auth || !mounted) return;
    }

    billingBloc.add(RemoveProductFromCartEvent(lastItem.product.id));
    SoundService.playDeleteSound();
    SnackbarHelper.showInfo(context, '✅ ${lastItem.product.name} ' + context.tr('item_deleted_msg'));
  }

  void _adjustLastItemQuantity(int delta) {
    final billingBloc = context.read<BillingBloc>();
    final items = billingBloc.state.cartItems;
    if (items.isEmpty) return;

    final lastItem = items.last;
    final newQty = lastItem.quantity + delta;
    if (newQty <= 0) {
      _quickVoidLastItem();
    } else {
      billingBloc.add(UpdateQuantityEvent(lastItem.product.id, newQty));
      SoundService.playClick();
    }
  }

  void _cyclePriceTier() {
    SoundService.playTabSwitch();
    setState(() {
      if (_activePriceTier == PosPriceTier.detail) {
        _activePriceTier = PosPriceTier.demiGros;
        SnackbarHelper.showWarning(context, context.tr('tier_demi_gros'));
      } else if (_activePriceTier == PosPriceTier.demiGros) {
        _activePriceTier = PosPriceTier.gros;
        SnackbarHelper.showWarning(context, context.tr('tier_gros'));
      } else {
        _activePriceTier = PosPriceTier.detail;
        SnackbarHelper.showSuccess(context, context.tr('tier_detail'));
      }
    });
  }

  void _toggleReturnMode() {
    SoundService.playTabSwitch();
    setState(() {
      _isReturnMode = !_isReturnMode;
    });
    if (_isReturnMode) {
      SoundService.playWarningSound();
      SnackbarHelper.showWarning(context, context.tr('return_mode_active'));
    } else {
      SoundService.playSaveSuccess();
      SnackbarHelper.showSuccess(context, context.tr('return_mode'));
    }
  }

  Future<void> _showDiscountModal() async {
    if (StaffPermissionsService.requirePinForDiscount) {
      final auth = await SecurityPinHelper.authenticate(context, title: context.tr('apply_discount'));
      if (!auth || !mounted) return;
    }
    SoundService.playTabSwitch();
    final discountController = TextEditingController();
    bool isPercent = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.percent_rounded, color: Colors.purple, size: 28),
                const SizedBox(width: 8),
                Text(context.tr('discount')),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.tr('percent_discount')),
                        selected: isPercent,
                        onSelected: (val) => setModalState(() => isPercent = true),
                      ),
                      ChoiceChip(
                        label: Text(context.tr('amount_discount')),
                        selected: !isPercent,
                        onSelected: (val) => setModalState(() => isPercent = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isPercent ? context.tr('discount_percentage') : context.tr('discount_amount'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.discount_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () {
                  final val = double.tryParse(discountController.text.trim()) ?? 0.0;
                  setState(() {
                    _cartDiscountValue = val;
                    _isDiscountPercentage = isPercent;
                  });
                  Navigator.pop(ctx);
                  SoundService.playSaveSuccess();
                  SnackbarHelper.showSuccess(context, context.tr('apply_discount'));
                },
                child: Text(context.tr('apply_discount'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickCustomItemModal() {
    SoundService.playTabSwitch();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: Colors.teal, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('quick_item_no_barcode')),
          ],
        ),
        content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr('item_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('item_price'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('quantity'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final name = nameController.text.trim().isEmpty ? 'Article' : nameController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
              final qty = int.tryParse(qtyController.text.trim()) ?? 1;

              if (price <= 0) {
                SnackbarHelper.showWarning(context, context.tr('enter_valid_amount'));
                return;
              }

              final customProduct = Product(
                id: 'quick_${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                barcode: 'QUICK_${DateTime.now().millisecondsSinceEpoch}',
                price: _isReturnMode ? -price : price,
                costPrice: 0.0,
                stock: 999,
              );

              for (int i = 0; i < qty; i++) {
                context.read<BillingBloc>().add(AddProductToCartEvent(customProduct));
              }

              Navigator.pop(ctx);
              _onItemScanned();
              _barcodeFocusNode.requestFocus();
            },
            child: Text(context.tr('save_and_add_cart'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRemoteCartsQueueModal() {
    SoundService.playTabSwitch();
    final pending = LocalSyncServer.pendingRemoteCarts;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.phonelink_ring_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 8),
                Text('${context.tr('pos_incoming_carts')} (${pending.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550, maxHeight: 400),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
              child: pending.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
                          const SizedBox(height: 12),
                          Text(context.tr('cart_empty'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rc = pending[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(rc.token, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    Text('${rc.senderName} • ${DateFormat('HH:mm').format(rc.timestamp)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text('${rc.totalAmount.toStringAsFixed(2)} DA', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w900, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('(${rc.items.length}): ${rc.items.map((i) => "${i.name} (x${i.quantity})").join(", ")}',
                                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      label: Text(context.tr('delete'), style: const TextStyle(color: Colors.red)),
                                      onPressed: () {
                                        LocalSyncServer.removeRemoteCart(rc.id);
                                        setModalState(() {});
                                        setState(() {
                                          _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                                      label: Text(context.tr('resume_cart'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        for (final item in rc.items) {
                                          final existingProd = HiveDatabase.productBox.values
                                              .where((p) => BarcodeNormalizer.matches(p.barcode, item.barcode))
                                              .firstOrNull;
                                          final prod = existingProd ?? Product(
                                            id: 'remote_${item.barcode}_${DateTime.now().millisecondsSinceEpoch}',
                                            name: item.name,
                                            barcode: item.barcode,
                                            price: item.price,
                                            costPrice: item.costPrice,
                                            stock: 999,
                                          );
                                          for (int q = 0; q < item.quantity; q++) {
                                            UniversalUnitSelectorDialog.showForProduct(context, prod);
                                          }
                                        }
                                        LocalSyncServer.removeRemoteCart(rc.id);
                                        setState(() {
                                          _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
                                        });
                                        Navigator.pop(ctx);
                                        SoundService.playMemberCardScan();
                                        SnackbarHelper.showSuccess(context, 'OK: ${rc.token}');
                                        _barcodeFocusNode.requestFocus();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('close'))),
            ],
          );
        },
      ),
    );
  }

  void _showIncomingHandoffBanner(RemoteIncomingCart cart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.swap_horizontal_circle_rounded, color: Colors.orange, size: 30),
            const SizedBox(width: 8),
            Text('${context.tr("transferred_cart_from")} (${cart.senderName}) 🔀',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr("ticket")}: ${cart.token}  •  ${context.tr("amount")}: ${cart.totalAmount.toStringAsFixed(2)} DA',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.teal)),
            const SizedBox(height: 8),
            Text('${context.tr("contains_items")} (${cart.items.length}): ${cart.items.map((i) => i.name).join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('transferred_cart_desc'),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('postpone_f9')),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            label: Text(context.tr('checkout_now_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _loadRemoteCartIntoActive(cart);
            },
          ),
        ],
      ),
    );
  }

  void _loadRemoteCartIntoActive(RemoteIncomingCart cart) {
    for (final item in cart.items) {
      final existingProd = HiveDatabase.productBox.values
          .where((p) => BarcodeNormalizer.matches(p.barcode, item.barcode))
          .firstOrNull;
      final prod = existingProd ?? Product(
        id: 'handoff_${item.barcode}_${DateTime.now().millisecondsSinceEpoch}',
        name: item.name,
        barcode: item.barcode,
        price: item.price,
        costPrice: item.costPrice,
        stock: 999,
      );
      for (int q = 0; q < item.quantity; q++) {
        UniversalUnitSelectorDialog.showForProduct(context, prod);
      }
    }
    LocalSyncServer.removeRemoteCart(cart.id);
    setState(() {
      _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
    });
    SoundService.playCheckoutSuccess();
    SnackbarHelper.showSuccess(context, '✅ ${cart.token} ' + context.tr('cart_received_success'));
    _barcodeFocusNode.requestFocus();
  }

  void _showRegisterHandoffModal(BillingState state) {
    if (state.cartItems.isEmpty) {
      SnackbarHelper.showWarning(context, context.tr('cart_empty_warning'));
      return;
    }

    final ipController = TextEditingController(
      text: HiveDatabase.settingsBox.get('peer_cashier_ip', defaultValue: '192.168.1.50'),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.swap_horizontal_circle_rounded, color: Colors.indigo, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('transfer_cart_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr("current_cart")}: ${state.cartItems.length} ${context.tr("items")} • ${context.tr("total")}: ${state.totalAmount.toStringAsFixed(2)} DA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal)),
            const SizedBox(height: 12),
            Text(context.tr('enter_peer_ip_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: context.tr('peer_ip_label'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.computer_rounded),
                hintText: '192.168.1.50',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: Text('${context.tr("cashier")} 2 (192.168.1.15)'),
                  onPressed: () => ipController.text = '192.168.1.15',
                ),
                ActionChip(
                  label: Text('${context.tr("cashier")} 3 (192.168.1.20)'),
                  onPressed: () => ipController.text = '192.168.1.20',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(context.tr('transfer_cart_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final targetIp = ipController.text.trim();
              if (targetIp.isEmpty) return;

              await HiveDatabase.settingsBox.put('peer_cashier_ip', targetIp);
              Navigator.pop(ctx);

              final token = '#${DateTime.now().millisecondsSinceEpoch % 900 + 100}';
              final handoffCart = RemoteIncomingCart(
                id: 'handoff_${DateTime.now().millisecondsSinceEpoch}',
                token: token,
                senderName: '${context.tr("cashier")} 1',
                timestamp: DateTime.now(),
                customerName: _selectedCustomerName,
                items: state.cartItems.map((ci) => RemoteCartItem(
                  barcode: ci.product.barcode,
                  name: ci.product.name,
                  price: ci.product.price,
                  costPrice: ci.product.costPrice,
                  quantity: ci.quantity,
                )).toList(),
                totalAmount: state.totalAmount,
              );

              final success = await LocalSyncServer.forwardCartToPeer(
                peerIp: targetIp,
                cart: handoffCart,
              );

              if (success) {
                context.read<BillingBloc>().add(ClearCartEvent());
                setState(() {
                  _cartDiscountValue = 0.0;
                });
                SoundService.playCheckoutSuccess();
                SnackbarHelper.showSuccess(context, '✅ ' + context.tr('cart_transferred_success') + ' ($targetIp)');
                _barcodeFocusNode.requestFocus();
              } else {
                SnackbarHelper.showError(context, '❌ ' + context.tr('cart_transfer_failed') + ' ($targetIp)');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppReceipt(double total, BillingState state) async {
    String? customerPhone;
    if (_selectedCustomerId != null) {
      final cData = HiveDatabase.customersBox.get(_selectedCustomerId);
      if (cData is Map) {
        customerPhone = cData['phone']?.toString();
      }
    }

    final phoneController = TextEditingController(text: customerPhone ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 26),
            const SizedBox(width: 8),
            Text(context.tr('send_digital_receipt_wa'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr("customer")}: $_selectedCustomerName  •  ${context.tr("amount")}: ${total.toStringAsFixed(2)} DA',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: context.tr('customer_phone'),
                hintText: '0661234567 / 0550123456',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_iphone_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(context.tr('send_now_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    var rawPhone = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.startsWith('0')) {
      rawPhone = '213${rawPhone.substring(1)}';
    } else if (!rawPhone.startsWith('213') && rawPhone.isNotEmpty) {
      rawPhone = '213$rawPhone';
    }

    if (rawPhone.length < 11) {
      SnackbarHelper.showError(context, context.tr('invalid_phone'));
      return;
    }

    final shopName = HiveDatabase.settingsBox.get('shop_name', defaultValue: 'Nayli Kiosk');
    final invoiceNumber = '#${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}';
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final itemsSummary = state.cartItems.map((ci) => '• ${ci.product.name} (x${ci.quantity}) = ${(ci.product.price * ci.quantity).toStringAsFixed(0)} DA').join('\n');

    final message = '''
🧾 *وصل مشتريات رقمي - $shopName*
رقم الوصل: $invoiceNumber
التاريخ: $dateStr
الزبون: $_selectedCustomerName
--------------------------------
$itemsSummary
--------------------------------
💰 *المجموع الصافي: ${total.toStringAsFixed(2)} DA*
رصيد الديون المتبقي: ${_customerCreditBalance.toStringAsFixed(2)} DA

شكراً لتعاملكم معنا! • Merci de votre visite!
''';

    final success = await WhatsAppReceiptHelper.sendDirectWhatsAppMessage(
      phone: rawPhone,
      message: message,
    );
    if (mounted) {
      if (success) {
        SoundService.playCheckoutSuccess();
        SnackbarHelper.showSuccess(context, context.tr('receipt_sent_wa'));
      } else {
        SnackbarHelper.showWarning(context, context.tr('receipt_copied_clipboard'));
      }
    }
  }

  void _openCashDrawerWithSecurity() async {
    final isAuthorized = await SecurityPinHelper.authenticate(
      context,
      title: context.tr('pos_open_drawer'),
    );
    if (isAuthorized) {
      await SoundService.playDrawerKick();
      await PrinterHelper.openCashDrawer();
      if (mounted) {
        SnackbarHelper.showSuccess(context, context.tr('pos_open_drawer'));
      }
    }
  }

  void _triggerCheckout() {
    final state = context.read<BillingBloc>().state;
    if (state.cartItems.isEmpty) {
      SoundService.playWarningSound();
      SnackbarHelper.showWarning(context, context.tr('cart_empty'));
      return;
    }
    _showPaymentModal(state);
  }

  void _confirmClearCart() {
    final state = context.read<BillingBloc>().state;
    if (state.cartItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('clear_cart')),
          ],
        ),
        content: Text(context.tr('clear_cart_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              SoundService.playDeleteSound();
              context.read<BillingBloc>().add(ClearCartEvent());
              setState(() {
                _cartDiscountValue = 0.0;
              });
              _barcodeFocusNode.requestFocus();
            },
            child: Text(context.tr('clear_cart'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleHoldOrResumeCart() {
    SoundService.playTabSwitch();
    final billingState = context.read<BillingBloc>().state;
    if (billingState.cartItems.isNotEmpty) {
      context.read<BillingBloc>().add(const ParkCurrentCartEvent());
      SoundService.playSaveSuccess();
      SnackbarHelper.showSuccess(
        context,
        context.tr('cart_held_success'),
      );
      setState(() {
        _cartDiscountValue = 0.0;
        _barcodeController.clear();
      });
      _barcodeFocusNode.requestFocus();
    } else {
      _showHeldCartsModal();
    }
  }

  void _showHeldCartsModal() {
    SoundService.playTabSwitch();
    AdaptiveModalHelper.showAdaptiveModal(
      context: context,
      desktopMaxWidth: 600,
      builder: (ctx) => const HeldCartsModal(),
    );
  }

  void _showCategoryProductsModal(String catKey, String catName) {
    SoundService.playTabSwitch();
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final allProducts = context.read<ProductBloc>().state.products;
            final query = searchController.text.trim().toLowerCase();

            final productsInCat = allProducts.where((p) {
                final catL = p.category.toLowerCase();
                final nameL = p.name.toLowerCase();

                if (catKey == 'all') {
                  // pass
                } else if (catKey == 'tobacco') {
                  final isTob = p.isTobacco ||
                      catL.contains('تبغ') || catL.contains('سجائر') || catL.contains('شمة') || catL.contains('معسل') ||
                      nameL.contains('مارلبورو') || nameL.contains('ريم') || nameL.contains('سجائر') || nameL.contains('دخان');
                  if (!isTob) return false;
                } else if (catKey == 'cold_drinks' || catKey == 'beverages') {
                  final isCD = catL.contains('مشروب') || catL.contains('ماء') || catL.contains('عصير') || catL.contains('غازي') ||
                               nameL.contains('مشروب') || nameL.contains('ماء') || nameL.contains('عصير') || nameL.contains('كوكا') || nameL.contains('حمود');
                  if (!isCD) return false;
                } else if (catKey == 'dairy') {
                  final isDairy = catL.contains('حليب') || catL.contains('لبن') || catL.contains('جبن') || catL.contains('ألبان') || catL.contains('زبادي') ||
                                  nameL.contains('حليب') || nameL.contains('جبن') || nameL.contains('ياغورت');
                  if (!isDairy) return false;
                } else if (catKey == 'coffee_tea' || catKey.contains('قهوة') || catKey.contains('شاي')) {
                  if (p.isBeverage && !catL.contains('قهوة') && !catL.contains('شاي') && !nameL.contains('قهوة') && !nameL.contains('شاي')) return false;
                  if (nameL.contains('ماء معدني') || nameL.contains('قارورة ماء') || nameL.contains('ماء 0.5') || nameL.contains('ماء 1.5') || nameL.contains('جافيل')) return false;
                  final isCT = p.isCoffeeMachineProduct ||
                               catL.contains('قهوة') || catL.contains('شاي') ||
                               nameL.contains('قهوة') || nameL.contains('شاي') || nameL.contains('نسكافيه') || nameL.contains('كبسول');
                  if (!isCT) return false;
                } else if (catKey == 'sweets') {
                  final isSweets = catL.contains('حلو') || catL.contains('شوكولا') || catL.contains('بسكويت') || catL.contains('علك') ||
                                   nameL.contains('شوكولا') || nameL.contains('بسكويت') || nameL.contains('قوفريط') || nameL.contains('حلوى');
                  if (!isSweets) return false;
                } else if (catKey == 'scale') {
                  if (!p.isWeighted && !catL.contains('ميزان') && !nameL.contains('ميزان')) return false;
                } else if (catKey == 'pulses') {
                  final isPulse = catL.contains('عدس') || catL.contains('حمص') || catL.contains('لوبيا') || catL.contains('أرز') || catL.contains('بقول') ||
                                  nameL.contains('عدس') || nameL.contains('حمص') || nameL.contains('لوبيا') || nameL.contains('أرز');
                  if (!isPulse) return false;
                } else if (catKey == 'canned') {
                  final isCanned = catL.contains('طماطم') || catL.contains('زيت') || catL.contains('تونة') || catL.contains('سردين') || catL.contains('معلب') ||
                                   nameL.contains('طماطم') || nameL.contains('زيت') || nameL.contains('تونة');
                  if (!isCanned) return false;
                } else if (catKey == 'bakery') {
                  final isBakery = catL.contains('خبز') || catL.contains('عجين') || catL.contains('مقرونة') || catL.contains('كسكسي') || catL.contains('سميد') || catL.contains('فرينة') ||
                                   nameL.contains('خبز') || nameL.contains('مقرونة') || nameL.contains('كسكسي');
                  if (!isBakery) return false;
                } else if (catKey == 'cleaning') {
                  final isClean = catL.contains('منظف') || catL.contains('جافيل') || catL.contains('غسيل') || catL.contains('أواني') ||
                                  nameL.contains('جافيل') || nameL.contains('إيزيس') || nameL.contains('أومو');
                  if (!isClean) return false;
                } else if (catKey == 'hygiene') {
                  final isHyg = catL.contains('صابون') || catL.contains('شامبو') || catL.contains('معجون') || catL.contains('عناية') ||
                                nameL.contains('صابون') || nameL.contains('شامبو') || nameL.contains('معجون');
                  if (!isHyg) return false;
                } else if (catKey == 'phone_accessories') {
                  final isPhone = catL.contains('هاتف') || catL.contains('شاحن') || catL.contains('كابل') ||
                                  catL.contains('سماع') || catL.contains('إلكترون') || catL.contains('phone') ||
                                  nameL.contains('شاحن') || nameL.contains('كابل') || nameL.contains('سماعة') ||
                                  nameL.contains('ecouteur') || nameL.contains('chargeur') || nameL.contains('cable') ||
                                  nameL.contains('بوشات') || nameL.contains('انكاسابل');
                  if (!isPhone) return false;
                } else if (catKey == 'batteries') {
                  final isBat = catL.contains('بطار') || catL.contains('حجر') || catL.contains('بيل') ||
                                catL.contains('pile') || catL.contains('battery') ||
                                nameL.contains('بطارية') || nameL.contains('حجرة') || nameL.contains('pile');
                  if (!isBat) return false;
                } else if (catKey == 'cosmetics') {
                  final isCosm = catL.contains('كوسميتيك') || catL.contains('تجميل') || catL.contains('مكياج') ||
                                 catL.contains('عطر') || catL.contains('ريحة') || catL.contains('parfum') ||
                                 nameL.contains('عطر') || nameL.contains('شامبو') || nameL.contains('كريم') ||
                                 nameL.contains('ماسك') || nameL.contains('كحل');
                  if (!isCosm) return false;
                } else if (catKey == 'toys') {
                  final isToy = catL.contains('لعب') || catL.contains('jouet') || catL.contains('toy') ||
                                catL.contains('بالون') || catL.contains('هدية') ||
                                nameL.contains('لعبة') || nameL.contains('سيارة لعبة') || nameL.contains('بالون') ||
                                nameL.contains('مفاجأة');
                  if (!isToy) return false;
                } else if (catKey == 'stationery') {
                  final isStat = catL.contains('كراس') || catL.contains('قلم') || catL.contains('دفتر') || catL.contains('مدرس') || catL.contains('مكتب') ||
                                 nameL.contains('كراس') || nameL.contains('قلم') || nameL.contains('دفتر');
                  if (!isStat) return false;
                } else if (catKey == 'produce') {
                  final isProd = catL.contains('خضر') || catL.contains('فواكه') || catL.contains('لحم') || catL.contains('دجاج') || catL.contains('بيض') ||
                                 nameL.contains('تفاح') || nameL.contains('بطاطا') || nameL.contains('بيض');
                  if (!isProd) return false;
                } else if (catKey == 'general_news') {
                  final isGN = catL.contains('عام') || catL.contains('جريد') || catL.contains('مجل') || catL.contains('كشك') ||
                               nameL.contains('عام') || nameL.contains('جريد') || nameL.contains('مجل');
                  if (!isGN) return false;
                } else if (catKey == 'spices') {
                  final isSpices = catL.contains('توابل') || catL.contains('بهارات') || catL.contains('ملح') ||
                                   nameL.contains('توابل') || nameL.contains('بهارات') || nameL.contains('فلفل أسود');
                  if (!isSpices) return false;
                } else {
                  if (p.category != catName && p.category != catKey) return false;
                }

                if (query.isNotEmpty) {
                  return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
                }
                return true;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                width: MediaQuery.of(context).size.width * 0.9,
                height: 560,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.category_rounded, color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${context.tr("category_products")}: ${context.tr(catName)} (${productsInCat.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(context.tr('click_to_add_cart'),
                                  style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('search_category_items'),
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: productsInCat.isEmpty
                          ? Center(
                              child: Text('${context.tr("no_products_in_cat")} $catName',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: productsInCat.length,
                              itemBuilder: (c, idx) {
                                final prod = productsInCat[idx];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    SoundService.playScanBeep();
                                    if (prod.isCoffeeMachineProduct && !_isReturnMode) {
                                      Navigator.pop(ctx);
                                      _showCoffeeSaleDialog(prod, 1);
                                    } else {
                                      UniversalUnitSelectorDialog.showForProduct(context, prod);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        ProductImageDisplay(
                                          imageUrl: prod.imageUrl,
                                          width: 46,
                                          height: 46,
                                          borderRadius: 8,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(prod.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('${prod.price.toStringAsFixed(2)} DA',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                                  Text('${context.tr("stock")}: ${prod.stock}',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: prod.stock > 0 ? Colors.green : Colors.red)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPriceChecker() {
    SoundService.playTabSwitch();
    final checkerController = TextEditingController();
    Product? foundProduct;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.price_check_rounded, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 8),
                Text(context.tr('price_check_f8')),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: checkerController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('search'),
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (code) {
                      final productBloc = context.read<ProductBloc>();
                      final products = productBloc.state.products;
                      final match = products.where((p) => p.barcode == code.trim()).firstOrNull;
                      setModalState(() {
                        foundProduct = match;
                      });
                      if (match != null) {
                        SoundService.playScanBeep();
                      } else {
                        SoundService.playWarningSound();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (foundProduct != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(foundProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${foundProduct!.price.toStringAsFixed(2)} DA',
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 18, fontWeight: FontWeight.bold)),
                              if (foundProduct!.wholesalePrice > 0)
                                Text('${foundProduct!.wholesalePrice.toStringAsFixed(2)} DA',
                                    style: const TextStyle(color: Colors.indigo, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${context.tr('in_stock')}: ${foundProduct!.stock} • ${foundProduct!.category}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('close'))),
            ],
          );
        },
      ),
    );
  }

  void _showCustomerSelector() {
    SoundService.playMemberCardScan();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_pin_rounded, color: Colors.indigo, size: 28),
            const SizedBox(width: 8),
            Text(context.tr('select_customer')),
          ],
        ),
        content: SizedBox(
          width: 450,
          height: 350,
          child: BlocBuilder<CustomerCubit, dynamic>(
            builder: (context, state) {
              final customers = HiveDatabase.customersBox.values.toList();
              return ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person_outline, color: Colors.white)),
                    title: Text(context.tr('زبون عابر (صندوق المبيعات)'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(context.tr('بدون ديون أو وفاء')),
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = null;
                        _selectedCustomerName = 'زبون عابر';
                        _customerCreditBalance = 0.0;
                      });
                      Navigator.pop(ctx);
                      SoundService.playTabSwitch();
                      _barcodeFocusNode.requestFocus();
                    },
                  ),
                  const Divider(),
                  ...customers.map((c) {
                    final name = c['name'] ?? 'Client';
                    final debt = (c['debt'] as num?)?.toDouble() ?? 0.0;
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.badge_rounded, color: Colors.white)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${context.tr('current_debt')}: ${debt.toStringAsFixed(2)} DA',
                          style: TextStyle(color: debt > 0 ? Colors.red : Colors.green)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() {
                          _selectedCustomerId = c['id']?.toString();
                          _selectedCustomerName = name;
                          _customerCreditBalance = debt;
                        });
                        Navigator.pop(ctx);
                        SoundService.playMemberCardScan();
                        SnackbarHelper.showSuccess(context, name);
                        _barcodeFocusNode.requestFocus();
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
        ],
      ),
    );
  }

  void _showPaymentModal(BillingState state) {
    PosPaymentModal.show(
      context: context,
      state: state,
      cartDiscountValue: _cartDiscountValue,
      isDiscountPercentage: _isDiscountPercentage,
      selectedCustomerId: _selectedCustomerId,
      selectedCustomerName: _selectedCustomerName,
      customerCreditBalance: _customerCreditBalance,
      onFinalizeSale: (method, total, tpeRef, {bool printReceipt = true}) =>
          _finalizeSale(method, total, tpeRef, printReceipt: printReceipt),
      onSendWhatsAppReceipt: (total, billingState) =>
          _sendWhatsAppReceipt(total, billingState),
    );
  }

  Future<void> _finalizeSale(PosPaymentMethod method, double total, String tpeRef, {bool printReceipt = true}) async {
    final billingBloc = context.read<BillingBloc>();
    final isCredit = method == PosPaymentMethod.customerCredit;

    if (method == PosPaymentMethod.tpeCard) {
      await TpePaymentService.processTpePayment(amount: total, manualReference: tpeRef);
    } else {
      await SoundService.playCheckoutSuccess();
    }

    if (method == PosPaymentMethod.cash) {
      await SoundService.playDrawerKick();
      await PrinterHelper.openCashDrawer();
    }

    // 1. Dispatch PrintReceiptEvent to deduct stock and save invoice in invoicesBox
    final shopBox = HiveDatabase.shopBox;
    final shop = shopBox.isNotEmpty ? shopBox.getAt(0) : null;
    final shopName = shop?.name ?? 'Nayli Kiosk';
    final shopPhone = shop?.phoneNumber ?? '';

    billingBloc.add(PrintReceiptEvent(
      shopName: shopName,
      address1: '',
      address2: '',
      phone: shopPhone,
      footer: '',
      customerName: _selectedCustomerName,
      isCredit: isCredit,
      paymentMethod: method == PosPaymentMethod.tpeCard ? 'TPE / Carte' : (isCredit ? 'Crédit' : 'Espèces'),
      paidAmount: isCredit ? 0.0 : total,
      previousDebt: _customerCreditBalance,
      newDebtTotal: isCredit ? (_customerCreditBalance + total) : _customerCreditBalance,
      skipPhysicalPrint: !printReceipt,
    ));

    // 2. If credit, update customer debt in Hive
    if (isCredit && _selectedCustomerId != null) {
      try {
        final cBox = HiveDatabase.customersBox;
        final cData = cBox.get(_selectedCustomerId);
        if (cData is Map) {
          final updatedData = Map<String, dynamic>.from(cData);
          final currentDebt = (updatedData['debt'] as num?)?.toDouble() ?? 0.0;
          updatedData['debt'] = currentDebt + total;
          await cBox.put(_selectedCustomerId, updatedData);
        }
      } catch (e) {
        debugPrint('Error updating customer debt: $e');
      }
    }

    // 3. Clear cart and prepare for next customer
    if (mounted) {
      billingBloc.add(ClearCartEvent());
      setState(() {
        _cartDiscountValue = 0.0;
        _selectedCustomerId = null;
        _selectedCustomerName = context.tr('walk_in_customer');
        _customerCreditBalance = 0.0;
      });
      SnackbarHelper.showSuccess(context, context.tr('printed_success'));
      _barcodeFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
          child: Column(
            children: [
              // Top Header Bar
              _buildTopHeaderBar(),

              // Return Mode / Wholesale Banner if active
              if (_isReturnMode || _activePriceTier != PosPriceTier.detail)
                _buildActiveModeNotice(),

              // Main Dual-Pane POS Body
              Expanded(
                child: Row(
                  children: [
                    // Left Pane: Cart, Totals, Actions (42% width)
                    Expanded(
                      flex: 42,
                      child: _buildLeftCartPane(),
                    ),

                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),

                    // Right Pane: Categories, Quick Products & Keypad (58% width)
                    Expanded(
                      flex: 58,
                      child: _buildRightCatalogPane(),
                    ),
                  ],
                ),
              ),

              // Bottom Hotkeys Reference Bar
              _buildBottomHotkeysBar(),
            ],
          ),
        ),
      );
  }

  Widget _buildActiveModeNotice() {
    final isReturn = _isReturnMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isReturn ? Colors.red.shade700 : Colors.indigo.shade700,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isReturn ? Icons.assignment_return_rounded : Icons.price_change_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                isReturn
                    ? context.tr('return_mode_active')
                    : '⚡ ${_activePriceTier == PosPriceTier.gros ? context.tr("tier_gros") : context.tr("tier_demi_gros")}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          InkWell(
            onTap: isReturn ? _toggleReturnMode : _cyclePriceTier,
            child: const Text('F5 / F6', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderBar() {
    return PosHeaderToolbar(
      isServerRunning: _isServerRunning,
      serverIp: _serverIp,
      pendingRemoteCartsCount: _pendingRemoteCartsCount,
      onOpenDrawer: _openCashDrawerWithSecurity,
      onShowRemoteCartsQueue: _showRemoteCartsQueueModal,
    );
  }

  Widget _buildLeftCartPane() {
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        double currentTotal = state.totalAmount;
        if (_cartDiscountValue > 0) {
          if (_isDiscountPercentage) {
            currentTotal = currentTotal - (currentTotal * (_cartDiscountValue / 100));
          } else {
            currentTotal = (currentTotal - _cartDiscountValue).clamp(0.0, double.infinity);
          }
        }

        return Container(
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              // Customer Bar (F3) & Price Tier Toggle (F5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFFF9FAFB),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _showCustomerSelector,
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: Colors.indigo, size: 22),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr(_selectedCustomerName), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (_customerCreditBalance > 0)
                                Text('${context.tr("current_debt")}: ${_customerCreditBalance.toStringAsFixed(2)} DA',
                                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Price Tier Badge
                    InkWell(
                      onTap: _cyclePriceTier,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _activePriceTier == PosPriceTier.gros ? Colors.indigo.shade50 : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _activePriceTier == PosPriceTier.gros ? Colors.indigo : Colors.teal),
                        ),
                        child: Text(
                          _activePriceTier == PosPriceTier.detail ? context.tr('tier_detail') : (_activePriceTier == PosPriceTier.demiGros ? context.tr('tier_demi_gros') : context.tr('tier_gros')),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _activePriceTier == PosPriceTier.gros ? Colors.indigo : Colors.teal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Barcode / Search Input Box with Touch Numpad toggle
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocusNode,
                        onChanged: _onSearchTextChanged,
                        decoration: InputDecoration(
                          hintText: context.tr('scan_input_hint'),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.teal),
                          suffixIcon: (_barcodeController.text.isNotEmpty || _searchSuggestions.isNotEmpty)
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _barcodeController.clear();
                                      _searchSuggestions = [];
                                    });
                                    _barcodeFocusNode.requestFocus();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onSubmitted: _handleBarcodeSubmit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Touch Numpad Toggle Button
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: _showTouchNumpad ? Colors.teal : Colors.grey.shade200),
                      icon: Icon(Icons.dialpad_rounded, color: _showTouchNumpad ? Colors.white : Colors.black87),
                      tooltip: context.tr('touch_numpad'),
                      onPressed: () {
                        setState(() {
                          _showTouchNumpad = !_showTouchNumpad;
                        });
                        SoundService.playTabSwitch();
                      },
                    ),
                  ],
                ),
              ),

              // Live Search Suggestions Dropdown
              if (_searchSuggestions.isNotEmpty)
                _buildSearchSuggestionsDropdown(),

              // Touch Numpad if toggled on
              if (_showTouchNumpad) _buildTouchNumpad(),

              // Items Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(context.tr('table_product'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text(context.tr('table_qty'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text(context.tr('table_price'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text(context.tr('table_total'), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    const SizedBox(width: 32),
                  ],
                ),
              ),

              // Cart Items List (with smooth touch scroll physics)
              Expanded(
                child: state.cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(context.tr('cart_empty'), style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(context.tr('cart_empty_hint'), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        itemCount: state.cartItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final item = state.cartItems[index];
                          final hasMulti = item.product.hasMultiUnit;
                          return ListTile(
                            dense: true,
                            onTap: hasMulti ? () => UniversalUnitSelectorDialog.showForCartItem(context, item) : null,
                            leading: ProductImageDisplay(
                              imageUrl: item.product.imageUrl,
                              width: 36,
                              height: 36,
                              borderRadius: 6,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasMulti) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => UniversalUnitSelectorDialog.showForCartItem(context, item),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: item.unitLevel == 'piece'
                                                  ? Colors.amber.shade900
                                                  : item.unitLevel == 'carton'
                                                      ? Colors.purple.shade900
                                                      : Colors.blue.shade900,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.black54),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${item.unitPrice.toStringAsFixed(2)} DA' +
                                  (item.unitLevel != 'pack' ? ' [${item.unitDisplayName}]' : ''),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: SizedBox(
                              width: 230,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Generous touch target stepper (-)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      SoundService.playTabSwitch();
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.cartKey, item.quantity - 1));
                                    },
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.remove, size: 20, color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(item.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  // Generous touch target stepper (+)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      SoundService.playScanBeep();
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.cartKey, item.quantity + 1));
                                    },
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, size: 20, color: Colors.green),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('${item.total.toStringAsFixed(2)} DA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                    onPressed: () {
                                      SoundService.playVoidWarning();
                                      context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.cartKey));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Prominently Enlarged Cart Financial Summary Block
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${context.tr("cart_items_count")}: ${state.cartItems.length} (${state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity)})',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            if (_cartDiscountValue > 0)
                              Text('${context.tr("discount")}: ${_cartDiscountValue.toStringAsFixed(0)}${_isDiscountPercentage ? "%" : " DA"}  |  ',
                                  style: const TextStyle(color: Colors.purple, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('${context.tr("total")}: ${state.totalAmount.toStringAsFixed(2)} DA',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Big Enlarged Total Price Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('cart_net_total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70)),
                          Text(
                            '${currentTotal.toStringAsFixed(2)} DA',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: Color(0xFF34D399),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    _buildCartActionButtons(state, currentTotal),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartActionButtons(BillingState state, double currentTotal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 540;
        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 7, child: _buildDiscountButton()),
              const SizedBox(width: 8),
              Expanded(flex: 11, child: _buildHoldButton(state)),
              const SizedBox(width: 8),
              Expanded(flex: 11, child: _buildTransferButton(state)),
              const SizedBox(width: 8),
              Expanded(flex: 15, child: _buildCheckoutButton(state, currentTotal)),
            ],
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(flex: 7, child: _buildDiscountButton()),
                  const SizedBox(width: 8),
                  Expanded(flex: 11, child: _buildHoldButton(state)),
                  const SizedBox(width: 8),
                  Expanded(flex: 11, child: _buildTransferButton(state)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildCheckoutButton(state, currentTotal),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDiscountButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        side: const BorderSide(color: Colors.purple, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 46),
      ),
      onPressed: _showDiscountModal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.percent_rounded, color: Colors.purple, size: 17),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.tr('btn_discount'),
                style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldButton(BillingState state) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              side: const BorderSide(color: Colors.indigo, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(0, 46),
            ),
            onPressed: _handleHoldOrResumeCart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_outline, color: Colors.indigo, size: 17),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.activeHeldCarts.isNotEmpty
                          ? '${context.tr("hold")} (${state.activeHeldCarts.length})'
                          : context.tr("btn_hold"),
                      style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.activeHeldCarts.isNotEmpty)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${state.activeHeldCarts.length}',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransferButton(BillingState state) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        side: const BorderSide(color: Colors.deepOrange, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 46),
      ),
      onPressed: () => _showRegisterHandoffModal(state),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horizontal_circle_rounded, color: Colors.deepOrange, size: 17),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.tr('transfer_f11_btn'),
                style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BillingState state, double currentTotal) {
    final payText = StaffPermissionsService.enableFastKeyboardShortcuts
        ? (context.tr("btn_pay_checkout").contains('F12')
            ? context.tr("btn_pay_checkout")
            : '${context.tr("btn_pay_checkout")} (F12)')
        : context.tr('btn_pay_checkout').replaceAll(' (F12)', '').replaceAll('(F12)', '').trim();

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 50),
      ),
      onPressed: () {
        if (StaffPermissionsService.enableCustomerDisplay) {
          LocalSyncServer.updateCustomerDisplay(
            items: state.cartItems.map((i) => {
              'name': i.product.name,
              'qty': i.quantity,
              'price': i.product.price,
              'total': i.total,
            }).toList(),
            total: currentTotal,
            subtotal: state.totalAmount,
            discount: _cartDiscountValue,
            customerName: _selectedCustomerName,
          );
        }
        _triggerCheckout();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                payText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestionsDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final multiplier = _getCurrentMultiplier();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Colors.teal, size: 16),
                const SizedBox(width: 6),
                Text(
                  'مقترحات سريعة (${_searchSuggestions.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                if (multiplier > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'الكمية: x$multiplier',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _searchSuggestions = [];
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _searchSuggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (ctx, idx) {
                final product = _searchSuggestions[idx];
                double effectivePrice = product.price;
                if (_activePriceTier == PosPriceTier.gros && product.wholesalePrice > 0) {
                  effectivePrice = product.wholesalePrice;
                } else if (_activePriceTier == PosPriceTier.demiGros && product.wholesalePrice > 0) {
                  effectivePrice = (product.price + product.wholesalePrice) / 2;
                }

                final isOutOfStock = product.stock <= 0;

                return InkWell(
                  onTap: () {
                    _addProductToCartWithPricing(product, quantity: multiplier);
                    SnackbarHelper.showSuccess(
                      context,
                      '${context.tr("added_to_cart")}: ${product.name} (x$multiplier)',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: ProductImageDisplay(
                              imageUrl: product.imageUrl,
                              width: 38,
                              height: 38,
                              borderRadius: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (product.barcode.isNotEmpty) ...[
                                    Text(
                                      product.barcode,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'المخزون: ${product.stock}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isOutOfStock ? Colors.red.shade700 : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${effectivePrice.toStringAsFixed(0)} ${context.tr("currency_symbol")}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchNumpad() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3', '*']),
          const SizedBox(height: 6),
          _buildNumpadRow(['4', '5', '6', 'C']),
          const SizedBox(height: 6),
          _buildNumpadRow(['7', '8', '9', 'DEL']),
          const SizedBox(height: 6),
          _buildNumpadRow(['0', '00', '.', 'ENTER']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        final isEnter = k == 'ENTER';
        final isSpecial = k == 'C' || k == 'DEL' || k == '*';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                SoundService.playTabSwitch();
                if (k == 'ENTER') {
                  _handleBarcodeSubmit(_barcodeController.text);
                } else if (k == 'C') {
                  _barcodeController.clear();
                  _onSearchTextChanged('');
                } else if (k == 'DEL') {
                  if (_barcodeController.text.isNotEmpty) {
                    _barcodeController.text = _barcodeController.text.substring(0, _barcodeController.text.length - 1);
                    _onSearchTextChanged(_barcodeController.text);
                  }
                } else {
                  _barcodeController.text += k;
                  _onSearchTextChanged(_barcodeController.text);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isEnter ? Colors.teal : (isSpecial ? Colors.indigo.shade50 : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEnter ? Colors.white : (isSpecial ? Colors.indigo : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRightCatalogPane() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Categories Bar (Horizontally scrollable with left-to-right swipe)
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              scrollDirection: Axis.horizontal,
              children: [
                // Quick Items Title & Manage Button
                InkWell(
                  onTap: _openQuickItemsManager,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(context.tr('customize_toolbar_btn'), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showCategorySettingsModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category_rounded, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(context.tr('تنظيم الأصناف'), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(height: 24, child: VerticalDivider(width: 1)),
                const SizedBox(width: 8),
                ..._getOrderedVisibleCategories().map((cat) {
                  final catName = cat['ar'] as String;
                  final iconStr = cat['icon'] as String;
                  final isCustom = cat['isCustom'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      avatar: Text(iconStr, style: const TextStyle(fontSize: 14)),
                      label: Text(context.tr(catName), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isCustom ? Colors.teal : null)),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isCustom ? Colors.teal.shade300 : Colors.grey.shade300),
                      ),
                      onPressed: () {
                        _showCategoryProductsModal(cat['key']!, catName);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Main Area: Large Quick Sale Items Grid (مع إمكانية إضافة منتج جديد)
          Expanded(
            child: _buildQuickItemsGrid(),
          ),
        ],
      ),
    );
  }

    Product _resolveProductForQuickItem(Map item) {
    final name = item['name']?.toString() ?? '';
    final barcode = item['barcode']?.toString() ?? '';
    final id = item['id']?.toString() ?? barcode;
    final linkedProductId = item['linkedProductId']?.toString() ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final cost = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
    final stock = (item['stock'] as num?)?.toInt() ?? 999;

    // 1. Try finding in productBox
    Product? matched;
    if (linkedProductId.isNotEmpty && HiveDatabase.productBox.containsKey(linkedProductId)) {
      final p = HiveDatabase.productBox.get(linkedProductId);
      if (p is Product) matched = p;
    }
    if (matched == null && barcode.isNotEmpty) {
      for (var p in HiveDatabase.productBox.values) {
        if (p is Product && (p.barcode == barcode || p.packBarcode == barcode || p.id == barcode)) {
          matched = p;
          break;
        }
      }
    }
    if (matched == null && name.isNotEmpty) {
      for (var p in HiveDatabase.productBox.values) {
        if (p is Product && p.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          matched = p;
          break;
        }
      }
    }

    if (matched != null) {
      if (_isReturnMode) {
        return matched.copyWith(
          name: '[${context.tr("return_mode")}] ${matched.name}',
          price: -matched.price.abs(),
        );
      }
      return matched;
    }

    // 2. Smart category and UOM detection
    final detectedSub = CategoryTaxonomy.smartDetect(name);
    final nameL = name.toLowerCase();
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
    final isCoffee = nameL.contains('قهوة') ||
        nameL.contains('شاي') ||
        nameL.contains('كبسول') ||
        nameL.contains('إكسبريسو') ||
        nameL.contains('إسبريسو') ||
        nameL.contains('اسبريسو') ||
        nameL.contains('express') ||
        nameL.contains('coffee') ||
        nameL.contains('tea');

    final effectivePacksPerCarton = isTob ? 10 : (isBev ? 6 : ((item['packsPerCarton'] as num?)?.toInt() ?? 10));
    final effectivePiecesPerPack = isTob ? 20 : ((item['piecesPerPack'] as num?)?.toInt() ?? 1);
    final singlePiecePrice = (item['singlePiecePrice'] as num?)?.toDouble() ??
        (isTob ? (price / 20).ceilToDouble() : 0.0);
    final cartonPrice = (item['cartonPrice'] as num?)?.toDouble() ?? (price * effectivePacksPerCarton);

    return Product(
      id: id,
      name: _isReturnMode ? '[${context.tr("return_mode")}] $name' : name,
      barcode: barcode,
      price: _isReturnMode ? -price.abs() : price,
      costPrice: cost,
      stock: stock,
      category: isTob ? 'المواد التبغية' : (isCoffee ? 'القهوة الجاهزة' : (isBev ? 'المشروبات والعصائر' : detectedSub.titleAr)),
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

  Widget _buildQuickItemsGrid() {
    final box = HiveDatabase.quickItemsBox;
    final items = box.values.toList();
    final List<Map<dynamic, dynamic>> quickList = [];
    for (var it in items) {
      if (it is Map) quickList.add(it);
    }
    quickList.sort((a, b) => ((a['orderIndex'] as num?)?.toInt() ?? 0).compareTo((b['orderIndex'] as num?)?.toInt() ?? 0));

    return GridView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.35,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: quickList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Add new quick item card
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showQuickCustomItemModal,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded, size: 28, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('add_quick_product'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                  ),
                  Text(
                    context.tr('free_item_f7'),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final item = quickList[index - 1];
        final name = item['name']?.toString() ?? '';
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final icon = item['icon']?.toString() ?? '🏷️';
        final barcode = item['barcode']?.toString() ?? '';
        final id = item['id']?.toString() ?? barcode;
        final cost = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
        final stock = (item['stock'] as num?)?.toInt() ?? 999;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _onItemScanned();
            final prod = _resolveProductForQuickItem(item);
            if (prod.isCoffeeMachineProduct && !_isReturnMode) {
              _showCoffeeSaleDialog(prod, 1);
            } else {
              UniversalUnitSelectorDialog.showForProduct(context, prod);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(context.tr('quick_badge'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                  ],
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2)} DA',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.teal),
                    ),
                    const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.teal),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openQuickItemsManager() {
    SoundService.playTabSwitch();
    showDialog(
      context: context,
      builder: (_) => const QuickItemsManagerDialog(),
    ).then((_) => setState(() {}));
  }

  List<Map<String, dynamic>> _getAllCombinedCategories() {
    final List<Map<String, dynamic>> all = [];
    final Set<String> seenKeys = {};

    void addCat(String key, String title, String icon, bool isCustom) {
      final cleanKey = key.trim();
      final cleanTitle = title.trim();
      if (cleanKey.isEmpty || cleanTitle.isEmpty) return;
      if (seenKeys.contains(cleanKey) || seenKeys.contains(cleanTitle)) return;
      seenKeys.add(cleanKey);
      seenKeys.add(cleanTitle);
      all.add({
        'key': cleanKey,
        'ar': cleanTitle,
        'icon': icon,
        'isCustom': isCustom,
      });
    }

    // 1. Preset Categories
    for (var def in _categoriesDef) {
      final trVal = context.tr(def['tr'] ?? '');
      final catName = trVal != (def['tr'] ?? '') && trVal.isNotEmpty ? trVal : (def['ar'] ?? '');
      addCat(def['key'] ?? '', catName, def['icon'] ?? '🏷️', false);
    }

    // Helper: Map arbitrary category string to preset key if matching
    String? resolvePresetKey(String catName) {
      final c = catName.trim().toLowerCase();
      if (c.contains('تبغ') || c.contains('سجائر') || c.contains('شمة')) return 'tobacco';
      if (c.contains('مشروب') || c.contains('عصير') || c.contains('ماء')) return 'cold_drinks';
      if (c.contains('حليب') || c.contains('ألبان') || c.contains('أجبان') || c.contains('جبن')) return 'dairy';
      if (c.contains('قهوة') || c.contains('شاي') || c.contains('ماكينة') || c.contains('كافيتيريا') || c.contains('كابوتشينو') || c.contains('كبسول')) return 'coffee_tea';
      if (c.contains('حلو') || c.contains('شوكولا') || c.contains('بسكويت') || c.contains('سكاكر')) return 'sweets';
      if (c.contains('ميزان')) return 'scale';
      if (c.contains('بقول') || c.contains('عدس') || c.contains('حمص') || c.contains('فريك') || c.contains('لوبيا') || c.contains('أرز')) return 'pulses';
      if (c.contains('معلب') || c.contains('طماطم') || c.contains('تونة') || c.contains('زيت')) return 'canned';
      if (c.contains('مخبوز') || c.contains('عجائن') || c.contains('كسكسي') || c.contains('سميد') || c.contains('فرينة')) return 'bakery';
      if (c.contains('منظف') || c.contains('تطهير') || c.contains('جافيل') || c.contains('صابون')) return 'cleaning';
      if (c.contains('عناية') || c.contains('شامبو') || c.contains('معجون')) return 'hygiene';
      if (c.contains('مدرس') || c.contains('مكتب')) return 'stationery';
      if (c.contains('هاتف') || c.contains('شاحن') || c.contains('كابل') || c.contains('سماع')) return 'phone_accessories';
      if (c.contains('بطار') || c.contains('حجر') || c.contains('بيل')) return 'batteries';
      if (c.contains('كوسميتيك') || c.contains('عطر') || c.contains('تجميل')) return 'cosmetics';
      if (c.contains('لعب') || c.contains('هدية')) return 'toys';
      if (c.contains('خضر') || c.contains('فواكه') || c.contains('لحوم')) return 'produce';
      if (c.contains('عام') || c.contains('جرائد')) return 'general_news';
      if (c.contains('توابل') || c.contains('بهارات')) return 'spices';
      return null;
    }

    // 2. Discover Real Categories from Loaded Products in Store
    final productsState = context.read<ProductBloc>().state;
    if (productsState.status == ProductStatus.loaded) {
      for (final p in productsState.products) {
        final cat = p.category.trim();
        if (cat.isNotEmpty) {
          final preset = resolvePresetKey(cat);
          if (preset == null) {
            addCat(cat, cat, CategoryTaxonomy.getIconForCategory(cat), true);
          }
        }
      }
    }

    // 3. Taxonomy Dropdown Categories (only truly new custom ones)
    for (var cat in CategoryTaxonomy.getDropdownCategories()) {
      final preset = resolvePresetKey(cat);
      if (preset == null) {
        addCat(cat, cat, CategoryTaxonomy.getIconForCategory(cat), true);
      }
    }

    return all;
  }

  List<Map<String, dynamic>> _getOrderedVisibleCategories() {
    final all = _getAllCombinedCategories();
    final hidden = CategoryTaxonomy.getHiddenCategories();
    final order = CategoryTaxonomy.getCategoryOrder();

    // 1. Filter out hidden
    final visible = all.where((c) {
      final key = c['key'] as String;
      final name = c['ar'] as String;
      return !hidden.contains(key) && !hidden.contains(name);
    }).toList();

    // 2. Sort by custom order
    visible.sort((a, b) {
      final keyA = a['key'] as String;
      final keyB = b['key'] as String;
      final nameA = a['ar'] as String;
      final nameB = b['ar'] as String;

      int idxA = order.indexOf(keyA);
      if (idxA == -1) idxA = order.indexOf(nameA);

      int idxB = order.indexOf(keyB);
      if (idxB == -1) idxB = order.indexOf(nameB);

      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return 0;
    });

    return visible;
  }

  void _showCategorySettingsModal() {
    final allCats = _getAllCombinedCategories();
    showDialog<bool>(
      context: context,
      builder: (ctx) {
        return _CategorySettingsDialog(allCategories: allCats);
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildBottomHotkeysBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1F2937),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr('hotkeys_hint'),
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const Text('Nayli POS Engine ⚡', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CategorySettingsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allCategories;
  const _CategorySettingsDialog({Key? key, required this.allCategories}) : super(key: key);

  @override
  State<_CategorySettingsDialog> createState() => _CategorySettingsDialogState();
}

class _CategorySettingsDialogState extends State<_CategorySettingsDialog> {
  late List<Map<String, dynamic>> _orderedCategories;
  late Set<String> _hiddenKeys;

  @override
  void initState() {
    super.initState();
    final savedHidden = CategoryTaxonomy.getHiddenCategories().toSet();
    final savedOrder = CategoryTaxonomy.getCategoryOrder();

    final all = List<Map<String, dynamic>>.from(widget.allCategories);

    all.sort((a, b) {
      final keyA = a['key'] as String;
      final keyB = b['key'] as String;
      final nameA = a['ar'] as String;
      final nameB = b['ar'] as String;

      int idxA = savedOrder.indexOf(keyA);
      if (idxA == -1) idxA = savedOrder.indexOf(nameA);

      int idxB = savedOrder.indexOf(keyB);
      if (idxB == -1) idxB = savedOrder.indexOf(nameB);

      if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
      if (idxA != -1) return -1;
      if (idxB != -1) return 1;
      return 0;
    });

    _orderedCategories = all;
    _hiddenKeys = {};
    for (final cat in all) {
      final k = cat['key'] as String;
      final n = cat['ar'] as String;
      if (savedHidden.contains(k) || savedHidden.contains(n)) {
        _hiddenKeys.add(k);
        _hiddenKeys.add(n);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.category, color: Colors.blue),
          SizedBox(width: 8),
          Text(context.tr('تنظيم وترتيب شريط الأصناف')),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('اسحب لإعادة الترتيب، واستخدم المربعات لتحديد ما يظهر في الشريط الرئيسي.'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _orderedCategories.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex -= 1;
                  setState(() {
                    final item = _orderedCategories.removeAt(oldIndex);
                    _orderedCategories.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final cat = _orderedCategories[index];
                  final key = cat['key'] as String;
                  final name = cat['ar'] as String;
                  final isHidden = _hiddenKeys.contains(key) || _hiddenKeys.contains(name);

                  return Card(
                    key: ValueKey('cat_$key'),
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                    child: CheckboxListTile(
                      secondary: Text(cat['icon'] as String, style: const TextStyle(fontSize: 20)),
                      title: Text(
                        context.tr(name),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: isHidden ? TextDecoration.lineThrough : null,
                          color: isHidden ? Colors.grey : null,
                        ),
                      ),
                      value: !isHidden,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _hiddenKeys.remove(key);
                            _hiddenKeys.remove(name);
                          } else {
                            _hiddenKeys.add(key);
                            _hiddenKeys.add(name);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('إلغاء')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          onPressed: () async {
            final orderList = _orderedCategories.map((c) => c['key'] as String).toList();
            await CategoryTaxonomy.saveCategoryOrder(orderList);
            
            // Rebuild hidden set strictly for current categories
            final Set<String> toSaveHidden = {};
            for (final cat in _orderedCategories) {
              final k = cat['key'] as String;
              final n = cat['ar'] as String;
              if (_hiddenKeys.contains(k) || _hiddenKeys.contains(n)) {
                toSaveHidden.add(k);
                toSaveHidden.add(n);
              }
            }
            await CategoryTaxonomy.saveHiddenCategories(toSaveHidden.toList());
            if (mounted) Navigator.pop(context, true);
          },
          child: Text(context.tr('حفظ التعديلات'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}





