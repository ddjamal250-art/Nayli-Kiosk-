import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/tpe_payment_service.dart';
import '../../../customer/presentation/cubit/customer_cubit.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/cart_item.dart';
import '../bloc/billing_bloc.dart';
import '../widgets/held_carts_modal.dart';

class DesktopPosPage extends StatefulWidget {
  const DesktopPosPage({super.key});

  @override
  State<DesktopPosPage> createState() => _DesktopPosPageState();
}

class _DesktopPosPageState extends State<DesktopPosPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _globalKeyboardFocusNode = FocusNode();

  String _selectedCategory = 'الكل';
  String? _selectedCustomerId;
  String _selectedCustomerName = 'زبون عابر (Détail)';
  double _customerCreditBalance = 0.0;

  // Costco IPM Speedometer tracking
  int _scannedItemsCount = 0;
  DateTime _sessionStartTime = DateTime.now();
  double _currentIpm = 0.0;
  Timer? _ipmTimer;

  // Local Master Server Status
  String _serverIp = 'جاري التحديد...';
  bool _isServerRunning = false;

  @override
  void initState() {
    super.initState();
    _initLocalServer();
    _startIpmCalculator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    _globalKeyboardFocusNode.dispose();
    _ipmTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocalServer() async {
    final started = await LocalSyncServer.startServer();
    final ip = await LocalSyncServer.getLocalIp();
    if (mounted) {
      setState(() {
        _isServerRunning = started;
        _serverIp = ip;
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

  void _handleBarcodeSubmit(String rawBarcode) {
    if (rawBarcode.trim().isEmpty) return;
    final barcode = rawBarcode.trim();
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();

    _onItemScanned();
    context.read<BillingBloc>().add(ScanBarcodeEvent(barcode));
  }

  void _handleHotkeys(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _barcodeFocusNode.requestFocus();
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      _showHeldCartsModal();
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      _showCustomerSelector();
    } else if (event.logicalKey == LogicalKeyboardKey.f8) {
      _showPriceChecker();
    } else if (event.logicalKey == LogicalKeyboardKey.f10) {
      _openCashDrawerWithSecurity();
    } else if (event.logicalKey == LogicalKeyboardKey.f12 || event.logicalKey == LogicalKeyboardKey.space) {
      _triggerCheckout();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _confirmClearCart();
    }
  }

  void _openCashDrawerWithSecurity() async {
    final isAuthorized = await SecurityPinHelper.authenticate(
      context,
      title: 'فتح درج النقود بدون بيع (No Sale Drawer Kick)',
    );
    if (isAuthorized) {
      await SoundService.playDrawerKick();
      await PrinterHelper.openCashDrawer();
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'تم فتح درج النقود بنجاح');
      }
    }
  }

  void _triggerCheckout() {
    final state = context.read<BillingBloc>().state;
    if (state.cartItems.isEmpty) {
      SoundService.playWarningSound();
      SnackbarHelper.showWarning(context, 'السلة فارغة، يرجى مسح المنتجات أولاً');
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('إلغاء السلة الحالية'),
          ],
        ),
        content: const Text('هل أنت متأكد من تفريغ وحذف جميع المنتجات من السلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              SoundService.playDeleteSound();
              context.read<BillingBloc>().add(ClearCartEvent());
              _barcodeFocusNode.requestFocus();
            },
            child: const Text('نعم، تفريغ السلة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHeldCartsModal() {
    SoundService.playTabSwitch();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const HeldCartsModal(),
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
            title: const Row(
              children: [
                Icon(Icons.price_check_rounded, color: Colors.blueAccent, size: 28),
                SizedBox(width: 8),
                Text('التحقق من السعر (Price Checker - F8)'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: checkerController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'امسح الباركود أو اكتبه هنا...',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Column(
                        children: [
                          Text(foundProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('${foundProduct!.price.toStringAsFixed(2)} د.ج',
                              style: const TextStyle(color: Color(0xFF059669), fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('المخزون المتوفر: ${foundProduct!.stock} قطعة', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
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
        title: const Row(
          children: [
            Icon(Icons.person_pin_rounded, color: Colors.indigo, size: 28),
            SizedBox(width: 8),
            Text('اختيار العميل / بطاقة العضوية (F3)'),
          ],
        ),
        content: SizedBox(
          width: 450,
          height: 350,
          child: BlocBuilder<CustomerCubit, dynamic>(
            builder: (context, state) {
              final customers = HiveDatabase.customersBox.values.toList();
              return ListView(
                children: [
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person_outline, color: Colors.white)),
                    title: const Text('زبون عابر (Détail - أسعار التجزئة)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('بدون حساب ديون أو نقاط ولاء'),
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = null;
                        _selectedCustomerName = 'زبون عابر (Détail)';
                        _customerCreditBalance = 0.0;
                      });
                      Navigator.pop(ctx);
                      SoundService.playTabSwitch();
                      _barcodeFocusNode.requestFocus();
                    },
                  ),
                  const Divider(),
                  ...customers.map((c) {
                    final name = c['name'] ?? 'زبون';
                    final debt = (c['debt'] as num?)?.toDouble() ?? 0.0;
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.badge_rounded, color: Colors.white)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الرصيد / الكريدي: ${debt.toStringAsFixed(2)} د.ج',
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
                        SnackbarHelper.showSuccess(context, 'تم ربط العميل: $name');
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  void _showPaymentModal(BillingState state) {
    SoundService.playTabSwitch();
    PosPaymentMethod paymentMethod = PosPaymentMethod.cash;
    double receivedAmount = state.totalAmount;
    final manualTpeRefController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = state.totalAmount;
          final change = (receivedAmount - total).clamp(0.0, 999999.0);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: Colors.teal, size: 30),
                const SizedBox(width: 8),
                const Text('إتمام الدفع والفوترة (F12)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('المبلغ الإجمالي المستحق:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${total.toStringAsFixed(2)} د.ج',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.teal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Selector
                  const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                            decoration: const InputDecoration(
                              labelText: 'المبلغ المستلم من الزبون (د.ج)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.money),
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
                              const Text('الفكة / الصرف للزبون:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${change.toStringAsFixed(2)} د.ج',
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
                            label: Text('+$bill د.ج'),
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
                              Text('جهاز الدفع الإلكتروني TPE (CIB / الذهبية)', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: manualTpeRefController,
                            decoration: const InputDecoration(
                              labelText: 'رقم المعاملة / كود التذكرة (SATIM Ref - اختياري)',
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
                          const Text('امسح الرمز عبر تطبيق BaridiMob (بريدي باي)',
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
                              'سيتم تسجيل مبلغ ${total.toStringAsFixed(2)} د.ج في حساب: $_selectedCustomerName',
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                label: const Text('تأكيد وطباعة الفاتورة (Enter)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    if (method == PosPaymentMethod.tpeCard) {
      await TpePaymentService.processTpePayment(amount: total, manualReference: tpeRef);
    } else {
      await SoundService.playCheckoutSuccess();
    }

    if (method == PosPaymentMethod.cash) {
      await SoundService.playDrawerKick();
      await PrinterHelper.openCashDrawer();
    }

    // Clear cart and prepare for next customer
    if (mounted) {
      context.read<BillingBloc>().add(ClearCartEvent());
      SnackbarHelper.showSuccess(context, 'تمت الفوترة والطباعة بنجاح! شكراً لزيارتكم.');
      _barcodeFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _globalKeyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleHotkeys,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Bar
              _buildTopHeaderBar(),

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
      ),
    );
  }

  Widget _buildTopHeaderBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          // Logo & Name
          Image.asset(AppConstants.appLogoPath, height: 36, errorBuilder: (_, __, ___) => const Icon(Icons.storefront, color: Colors.teal, size: 36)),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nayli Market POS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1F2937))),
              Text('نظام الفوترة ونقاط البيع السريعة', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(width: 24),

          // Master Server Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isServerRunning ? const Color(0xFF10B981).withOpacity(0.1) : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isServerRunning ? const Color(0xFF10B981) : Colors.amber),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, size: 16, color: _isServerRunning ? const Color(0xFF10B981) : Colors.amber),
                const SizedBox(width: 6),
                Text('Master Server: $_serverIp:8080', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isServerRunning ? const Color(0xFF065F46) : Colors.amber.shade900)),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Costco IPM Speedometer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                Text('سرعة الكاشير: ${_currentIpm.toStringAsFixed(0)} IPM ⚡',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
          ),

          const Spacer(),

          // Navigation Shortcuts
          IconButton(
            tooltip: 'تعليق السلات (F2)',
            icon: const Icon(Icons.pause_circle_outline_rounded, color: Colors.indigo),
            onPressed: _showHeldCartsModal,
          ),
          IconButton(
            tooltip: 'فحص الأسعار (F8)',
            icon: const Icon(Icons.price_check_rounded, color: Colors.blue),
            onPressed: _showPriceChecker,
          ),
          IconButton(
            tooltip: 'فتح الدرج الآلي (F10)',
            icon: const Icon(Icons.savings_outlined, color: Colors.amber),
            onPressed: _openCashDrawerWithSecurity,
          ),
          IconButton(
            tooltip: 'التقارير اليومية',
            icon: const Icon(Icons.analytics_outlined, color: Colors.purple),
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            tooltip: 'الإعدادات والعتاد',
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
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Customer Bar (F3)
              InkWell(
                onTap: _showCustomerSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Colors.indigo, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedCustomerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (_customerCreditBalance > 0)
                              Text('الديون السابقة: ${_customerCreditBalance.toStringAsFixed(2)} د.ج',
                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Text('تغيير (F3)', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // Barcode Input Box
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _barcodeController,
                  focusNode: _barcodeFocusNode,
                  decoration: InputDecoration(
                    hintText: 'امسح الباركود هنا (F1)...',
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

              // Items Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF3F4F6),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('السعر', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text('الإجمالي', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    SizedBox(width: 32),
                  ],
                ),
              ),

              // Cart Items List
              Expanded(
                child: state.cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('السلة فارغة', style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('امسح الباركود أو اختر من قائمة المنتجات السريعة', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.cartItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final item = state.cartItems[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${item.product.price.toStringAsFixed(2)} د.ج', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: SizedBox(
                              width: 220,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                                    onPressed: () {
                                      SoundService.playTabSwitch();
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity - 1));
                                    },
                                  ),
                                  Text(item.quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.green),
                                    onPressed: () {
                                      SoundService.playScanBeep();
                                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity + 1));
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${item.total.toStringAsFixed(2)} د.ج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
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

              // Bottom Basket Bulk Reminder
              if (state.cartItems.length >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  color: Colors.amber.shade100,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14, color: Colors.brown),
                      SizedBox(width: 6),
                      Text('تذكير Costco: هل قمت بمسح السلع الكبيرة أسفل العربة؟', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
                    ],
                  ),
                ),

              // Cart Financial Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('عدد المواد: ${state.cartItems.length} (${state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity)} قطع)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('المجموع: ${state.totalAmount.toStringAsFixed(2)} د.ج', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي الصافي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('${state.totalAmount.toStringAsFixed(2)} د.ج',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.teal)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            icon: const Icon(Icons.pause_circle_outline, color: Colors.indigo),
                            label: const Text('تعليق (F2)', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                            onPressed: _showHeldCartsModal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                            label: const Text('دفع وفوترة (F12)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildRightCatalogPane() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        final allProducts = state.products;
        final categories = ['الكل', 'المشروبات', 'البقوليات', 'المنظفات', 'الحلويات', 'الميزان', 'الألبان', 'التوابل'];
        final filteredProducts = _selectedCategory == 'الكل'
            ? allProducts
            : allProducts.where((p) => (p.category).contains(_selectedCategory)).toList();

        return Container(
          color: const Color(0xFFF3F4F6),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Categories Horizontal Scroll
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(cat),
                      selectedColor: Colors.teal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                        SoundService.playTabSwitch();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Products Grid
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Text('لا توجد منتجات مسجلة في هذا القسم',
                            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.15,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return InkWell(
                            onTap: () {
                              _onItemScanned();
                              context.read<BillingBloc>().add(AddProductToCartEvent(product));
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${product.price.toStringAsFixed(2)} د.ج',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.teal)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: product.stock > 5 ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${product.stock}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: product.stock > 5 ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomHotkeysBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1F2937),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('[F1: بحث الباركود]   [F2: تعليق السلة]   [F3: العميل/العضوية]   [F8: فحص السعر]   [F10: فتح الدرج]   [F12 / مسافة: الدفع الفوري]   [Esc: إلغاء]',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          Text('Costco POS Engine Active ⚡', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
