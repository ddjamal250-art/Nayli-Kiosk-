import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/tpe_payment_service.dart';
import '../../../customer/presentation/cubit/customer_cubit.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shifts/data/shift_service.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/billing_bloc.dart';
import '../widgets/held_carts_modal.dart';
import '../widgets/quick_items_manager_dialog.dart';
import '../widgets/printer_selection_dialog.dart';

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
  String _selectedCustomerName = 'زبون عابر (Détail)';
  double _customerCreditBalance = 0.0;

  // Operating Modes
  PosPriceTier _activePriceTier = PosPriceTier.detail;
  bool _isReturnMode = false;
  double _cartDiscountValue = 0.0;
  bool _isDiscountPercentage = false;
  bool _showTouchNumpad = false;

  // Costco IPM Speedometer tracking
  int _scannedItemsCount = 0;
  DateTime _sessionStartTime = DateTime.now();
  double _currentIpm = 0.0;
  Timer? _ipmTimer;

  // Local Master Server Status & Remote Carts Stream
  String _serverIp = '127.0.0.1';
  bool _isServerRunning = false;
  StreamSubscription<RemoteIncomingCart>? _remoteCartSub;
  int _pendingRemoteCartsCount = 0;

  // USB Barcode Wedge Rapid Buffer
  String _hardwareBarcodeBuffer = '';
  DateTime _lastHardwareKeyTime = DateTime.now();

  static const List<Map<String, String>> _categoriesDef = [
    {'key': 'all', 'tr': 'cat_all', 'ar': 'الكل'},
    {'key': 'beverages', 'tr': 'cat_beverages', 'ar': 'المشروبات'},
    {'key': 'pulses', 'tr': 'cat_pulses', 'ar': 'البقوليات'},
    {'key': 'cleaning', 'tr': 'cat_cleaning', 'ar': 'المنظفات'},
    {'key': 'sweets', 'tr': 'cat_sweets', 'ar': 'الحلويات'},
    {'key': 'scale', 'tr': 'cat_scale', 'ar': 'الميزان'},
    {'key': 'dairy', 'tr': 'cat_dairy', 'ar': 'الألبان'},
    {'key': 'spices', 'tr': 'cat_spices', 'ar': 'التوابل'},
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
    _initLocalServer();
    _startIpmCalculator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _globalKeyboardFocusNode.dispose();
    _ipmTimer?.cancel();
    _remoteCartSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocalServer() async {
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

    if (mounted) {
      setState(() {
        _isServerRunning = started;
        _serverIp = ip;
        _pendingRemoteCartsCount = LocalSyncServer.pendingRemoteCarts.length;
      });
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

  void _handleBarcodeSubmit(String rawInput) {
    if (rawInput.trim().isEmpty) return;
    final input = rawInput.trim();
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();

    // Check for quantity multiplier syntax (e.g., "5*6130140001019" or "12*")
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
      final qPrice = (matchedQuickItem['price'] as num?)?.toDouble() ?? 0.0;
      final qCost = (matchedQuickItem['costPrice'] as num?)?.toDouble() ?? 0.0;
      final qName = matchedQuickItem['name']?.toString() ?? 'Article';
      final qBarcode = matchedQuickItem['barcode']?.toString() ?? barcodeToScan;
      final qId = matchedQuickItem['id']?.toString() ?? barcodeToScan;

      final quickProduct = Product(
        id: qId,
        name: _isReturnMode ? '[${context.tr('return_mode')}] $qName' : qName,
        barcode: qBarcode,
        price: _isReturnMode ? -qPrice.abs() : qPrice,
        costPrice: qCost,
        stock: (matchedQuickItem['stock'] as num?)?.toInt() ?? 999,
        category: 'بيع سريع',
      );

      for (int i = 0; i < multiplier; i++) {
        context.read<BillingBloc>().add(AddProductToCartEvent(quickProduct));
      }
      return;
    }

    // 2. Find product in product catalog
    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    final product = products.where((p) => p.barcode == barcodeToScan).firstOrNull;

    if (product != null) {
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
      );

      for (int i = 0; i < multiplier; i++) {
        context.read<BillingBloc>().add(AddProductToCartEvent(itemProduct));
      }
    } else {
      context.read<BillingBloc>().add(ScanBarcodeEvent(barcodeToScan));
    }
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
    } else if (event.logicalKey == LogicalKeyboardKey.f12 || (event.logicalKey == LogicalKeyboardKey.space && !_barcodeFocusNode.hasFocus)) {
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

  void _showDiscountModal() {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('نسبة %'),
                        selected: isPercent,
                        onSelected: (val) => setModalState(() => isPercent = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('مبلغ د.ج'),
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
                      labelText: isPercent ? 'نسبة الخصم (%)' : 'مبلغ الخصم (DA)',
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
        content: SizedBox(
          width: 400,
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
            content: SizedBox(
              width: 550,
              height: 400,
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
                                          final prod = Product(
                                            id: 'remote_${item.barcode}_${DateTime.now().millisecondsSinceEpoch}',
                                            name: item.name,
                                            barcode: item.barcode,
                                            price: item.price,
                                            costPrice: item.costPrice,
                                            stock: 999,
                                          );
                                          for (int q = 0; q < item.quantity; q++) {
                                            context.read<BillingBloc>().add(AddProductToCartEvent(prod));
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('close'))),
            ],
          );
        },
      ),
    );
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
        '⏸️ تم تعليق السلة بنجاح وحفظها مؤقتاً (F2)',
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              if (catKey != 'all') {
                final def = _categoriesDef.firstWhere((c) => c['key'] == catKey, orElse: () => {'ar': ''});
                final arLabel = def['ar'] ?? '';
                final pCat = p.category.toLowerCase();
                if (!pCat.contains(arLabel.toLowerCase())) return false;
              }
              if (query.isNotEmpty) {
                return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
              }
              return true;
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 720,
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
                              Text('منتجات صنف: $catName (${productsInCat.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text('انقر على أي منتج لإضافته مباشرة إلى السلة الحالية',
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
                        hintText: 'بحث في هذا الصنف بالاسم أو الباركود...',
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
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: productsInCat.isEmpty
                          ? Center(
                              child: Text('لا توجد منتجات مسجلة في صنف $catName',
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
                                    context.read<BillingBloc>().add(AddProductToCartEvent(prod));
                                    SnackbarHelper.showSuccess(context, 'تمت إضافة ${prod.name} للسلة');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(prod.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('${prod.price.toStringAsFixed(2)} DA',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                            Text('مخزون: ${prod.stock}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: prod.stock > 0 ? Colors.green : Colors.red)),
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
                    title: const Text('Client Détail (Comptoir)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sans crédit ni fidélité'),
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = null;
                        _selectedCustomerName = 'Client Détail';
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
    SoundService.playTabSwitch();
    PosPaymentMethod paymentMethod = PosPaymentMethod.cash;
    
    // Calculate final total after discount
    double calculatedTotal = state.totalAmount;
    if (_cartDiscountValue > 0) {
      if (_isDiscountPercentage) {
        calculatedTotal = calculatedTotal - (calculatedTotal * (_cartDiscountValue / 100));
      } else {
        calculatedTotal = (calculatedTotal - _cartDiscountValue).clamp(0.0, double.infinity);
      }
    }

    double receivedAmount = calculatedTotal;
    final manualTpeRefController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = calculatedTotal;
          final change = (receivedAmount - total).clamp(0.0, 999999.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: Colors.teal, size: 30),
                const SizedBox(width: 8),
                Text(context.tr('btn_pay_checkout'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('cart_net_total'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            if (_cartDiscountValue > 0)
                              Text('${context.tr("discount")}: ${_cartDiscountValue.toStringAsFixed(1)}${_isDiscountPercentage ? "%" : " DA"}',
                                  style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('${total.toStringAsFixed(2)} DA',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.teal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Selector
                  Text(context.tr('payment_mode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PosPaymentMethod.values.map((method) {
                      final isSelected = paymentMethod == method;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text('${method.icon} ${method.titleAr}'),
                        selectedColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              paymentMethod = method;
                            });
                            SoundService.playTabSwitch();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Content based on method
                  if (paymentMethod == PosPaymentMethod.cash) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.tr('paid_amount'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.money),
                            ),
                            onChanged: (val) {
                              final numVal = double.tryParse(val) ?? 0.0;
                              setModalState(() {
                                receivedAmount = numVal;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(context.tr('change_due'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${change.toStringAsFixed(2)} DA',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: change >= 0 ? Colors.green : Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Bill Buttons
                    Row(
                      children: [500, 1000, 2000, 5000].map((bill) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text('+$bill DA'),
                            onPressed: () {
                              setModalState(() {
                                receivedAmount = bill.toDouble();
                              });
                              SoundService.playTabSwitch();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.tpeCard) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card_rounded, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('TPE (CIB / Edahabia)', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: manualTpeRefController,
                            decoration: const InputDecoration(
                              labelText: 'SATIM Ref / Ticket Code',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.baridiPayQr) ...[
                    Center(
                      child: Column(
                        children: [
                          QrImageView(
                            data: TpePaymentService.generateBaridiPayQrPayload(
                              amount: total,
                              invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            version: QrVersions.auto,
                            size: 160.0,
                          ),
                          const SizedBox(height: 8),
                          const Text('BaridiMob (BaridiPay QR)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ],
                      ),
                    ),
                  ] else if (paymentMethod == PosPaymentMethod.customerCredit) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${context.tr("remaining_to_credit")} ${total.toStringAsFixed(2)} DA ($_selectedCustomerName)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('cancel'))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                label: Text(context.tr('confirm_and_print'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _finalizeSale(paymentMethod, total, manualTpeRefController.text);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _finalizeSale(PosPaymentMethod method, double total, String tpeRef) async {
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
    final shopName = shop?.name ?? 'Nayli Market';
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
        _selectedCustomerName = 'زبون عابر (Détail)';
        _customerCreditBalance = 0.0;
      });
      SnackbarHelper.showSuccess(context, context.tr('printed_success'));
      _barcodeFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.42,
                      child: _buildLeftCartPane(),
                    ),

                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),

                    // Right Pane: Categories, Quick Products & Keypad (58% width)
                    Expanded(
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          // Brand Logo with elegant rounded container
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                AppConstants.appLogoPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, color: Colors.teal, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Nayli Market POS',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A), letterSpacing: 0.3),
                  ),
                  SizedBox(width: 6),
                  Text('🇩🇿', style: TextStyle(fontSize: 14)),
                ],
              ),
              Text(
                context.tr('pos_title'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Customer-Facing Professional Welcome Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Text(context.tr('pos_welcome'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Discreet LAN Network Sync Indicator for Cashier (Tooltip only)
          Tooltip(
            message: _isServerRunning ? 'LAN OK: $_serverIp:8080' : 'LAN Standby',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isServerRunning ? Colors.green.shade50 : Colors.amber.shade50,
                border: Border.all(color: _isServerRunning ? Colors.green : Colors.amber),
              ),
              child: Icon(
                _isServerRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: _isServerRunning ? Colors.green.shade700 : Colors.amber.shade800,
              ),
            ),
          ),

          if (_pendingRemoteCartsCount > 0) ...[
            const SizedBox(width: 8),
            // Incoming Remote Carts Queue Button (F9)
            InkWell(
              onTap: _showRemoteCartsQueueModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phonelink_ring_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${context.tr("pos_incoming_carts")}: $_pendingRemoteCartsCount (F9)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Cash Drawer Quick Kick with Bank Icon (F10)
          IconButton(
            tooltip: context.tr('pos_open_drawer'),
            icon: const Icon(Icons.account_balance_rounded, color: Colors.amber, size: 22),
            onPressed: _openCashDrawerWithSecurity,
          ),

          // Navigation Shortcuts (Documents, Backups, Shifts, Catalog, Products, Reports, Settings)
          IconButton(
            tooltip: context.tr('pos_commercial_docs'),
            icon: const Icon(Icons.description_outlined, color: Colors.teal),
            onPressed: () => context.push('/documents'),
          ),
          IconButton(
            tooltip: context.tr('pos_backup_sync'),
            icon: const Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent),
            onPressed: () => context.push('/backups'),
          ),
          IconButton(
            tooltip: context.tr('pos_shifts_zreport'),
            icon: const Icon(Icons.badge_rounded, color: Colors.indigo),
            onPressed: () => context.push('/shifts'),
          ),
          IconButton(
            tooltip: context.tr('pos_master_catalog'),
            icon: const Icon(Icons.library_books_rounded, color: Colors.deepOrange),
            onPressed: () => context.push('/master-catalog'),
          ),
          IconButton(
            tooltip: context.tr('pos_inventory'),
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.green),
            onPressed: () => context.push('/products'),
          ),
          IconButton(
            tooltip: context.tr('pos_reports'),
            icon: const Icon(Icons.analytics_outlined, color: Colors.purple),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            tooltip: 'طابعات ويندوز (الوصولات والمستندات)',
            icon: const Icon(Icons.print_outlined, color: Colors.teal),
            onPressed: () => PrinterSelectionDialog.show(context),
          ),
          IconButton(
            tooltip: 'إدارة الشبكة والمزامنة المحلية (LAN & Wi-Fi)',
            icon: const Icon(Icons.wifi_tethering_rounded, color: Colors.indigo),
            onPressed: () => context.push('/lan-sync'),
          ),
          IconButton(
            tooltip: context.tr('pos_settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
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
          color: Colors.white,
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
                              Text(_selectedCustomerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

              // Barcode Input Box with Touch Numpad toggle
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeController,
                        focusNode: _barcodeFocusNode,
                        decoration: InputDecoration(
                          hintText: context.tr('scan_input_hint'),
                          prefixIcon: const Icon(Icons.barcode_reader, color: Colors.teal),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _barcodeController.clear(),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
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
                      tooltip: 'لوحة الأرقام اللمسية (Touch Numpad)',
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

              // Touch Numpad if toggled on
              if (_showTouchNumpad) _buildTouchNumpad(),

              // Items Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF3F4F6),
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
                          return ListTile(
                            dense: true,
                            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${item.product.price.toStringAsFixed(2)} DA', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity - 1));
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
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity + 1));
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
                                      context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
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

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            icon: const Icon(Icons.percent_rounded, color: Colors.purple, size: 18),
                            label: Text(context.tr('btn_discount'), style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: _showDiscountModal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Colors.indigo, width: 1.2),
                                  ),
                                  icon: const Icon(Icons.pause_circle_outline, color: Colors.indigo, size: 18),
                                  label: Text(
                                    state.activeHeldCarts.isNotEmpty
                                        ? 'تعليق (${state.activeHeldCarts.length})'
                                        : 'تعليق (F2)',
                                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  onPressed: _handleHoldOrResumeCart,
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
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                            label: Text(context.tr('btn_pay_checkout'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: _triggerCheckout,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                } else if (k == 'DEL') {
                  if (_barcodeController.text.isNotEmpty) {
                    _barcodeController.text = _barcodeController.text.substring(0, _barcodeController.text.length - 1);
                  }
                } else {
                  _barcodeController.text += k;
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
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Categories Bar (with Modal on click) + Customize Quick Items button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
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
                    child: const Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: Colors.teal),
                        SizedBox(width: 4),
                        Text('ترتيب وتخصيص ⚙️', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(height: 24, child: VerticalDivider(width: 1)),
                const SizedBox(width: 8),

                // Categories chips
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categoriesDef.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final cat = _categoriesDef[index];
                        final catName = context.tr(cat['tr']!);

                        return ActionChip(
                          avatar: const Icon(Icons.category_outlined, size: 14, color: Colors.teal),
                          label: Text(catName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onPressed: () {
                            _showCategoryProductsModal(cat['key']!, catName);
                          },
                        );
                      },
                    ),
                  ),
                ),
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
                color: Colors.white,
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
                  const Text(
                    '+ إضافة منتج سريع',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                  ),
                  const Text(
                    'سلعة حرة بدون باركود (F7)',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
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
            final prod = Product(
              id: id,
              name: _isReturnMode ? '[${context.tr("return_mode")}] $name' : name,
              barcode: barcode,
              price: _isReturnMode ? -price.abs() : price,
              costPrice: cost,
              stock: stock,
              category: 'بيع سريع',
            );
            context.read<BillingBloc>().add(AddProductToCartEvent(prod));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      child: const Text('سريع ⚡', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                  ],
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
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

