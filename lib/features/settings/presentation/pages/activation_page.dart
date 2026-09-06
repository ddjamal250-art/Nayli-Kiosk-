import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/online_license_service.dart';
import '../../../../core/utils/merchant_context_service.dart';
import '../../../../core/data/cloud_sync_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_client.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _douchetteController = TextEditingController();
  final TextEditingController _manualKeyController = TextEditingController();
  final FocusNode _douchetteFocusNode = FocusNode();

  String? _errorMessage;
  bool _isCheckingOnline = false;

  // Master PC Pairing State
  bool _isPairingWithMaster = false;
  String? _pairingStatusMessage;
  String _localIp = '127.0.0.1';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadExistingShopInfo();
    _loadLocalIp();
    HardwareKeyboard.instance.addHandler(_handleDouchetteHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        _douchetteFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadLocalIp() async {
    try {
      final ip = await LocalSyncServer.getLocalIp();
      if (mounted) setState(() => _localIp = ip);
    } catch (_) {}
  }

  bool _handleDouchetteHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final text = _douchetteController.text.trim();
      if (text.isNotEmpty) {
        _handleDouchetteActivation(text);
        return true;
      }
    }
    return false;
  }

  void _loadExistingShopInfo() {
    try {
      final box = HiveDatabase.shopBox;
      if (box.isNotEmpty) {
        final ShopModel? shop = box.getAt(0);
        if (shop != null) {
          _storeNameController.text = shop.name;
          _phoneController.text = shop.phoneNumber;
          _cityController.text = shop.addressLine1;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleDouchetteHardwareKey);
    _tabController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _douchetteController.dispose();
    _manualKeyController.dispose();
    _douchetteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDouchetteActivation(String rawInput) async {
    final normalized = BarcodeNormalizer.normalizeAzertyInput(rawInput.trim());
    if (normalized.isEmpty) return;

    setState(() {
      _pairingStatusMessage = 'جاري التحقق من كود التفعيل...';
    });

    final result = await LicenseService.verifyAndApplyDouchetteToken(normalized);
    if (result['success'] == true) {
      SoundService.playCheckoutSuccess();
      HapticFeedback.heavyImpact();
      if (mounted) {
        context.showAppSnackBar(
          result['message']?.toString() ?? '🎉 تم تفعيل هذا الجهاز بنجاح!',
          backgroundColor: Colors.green.shade800,
          icon: Icons.verified_rounded,
        );
        context.go('/');
      }
    } else {
      SoundService.playVoidWarning();
      final err = result['message']?.toString() ?? '❌ كود غير صالح أو منتهي الصلاحية';
      setState(() {
        _pairingStatusMessage = err;
      });
      if (mounted) {
        context.showAppSnackBar(
          err,
          backgroundColor: Colors.red.shade800,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _saveShopDetailsLocally() async {
    final storeName = _storeNameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    if (storeName.isNotEmpty) {
      final shop = ShopModel(
        name: storeName,
        phoneNumber: phone,
        addressLine1: city,
        addressLine2: '',
        upiId: '',
        footerText: 'شكراً لزيارتكم • مرحباً بكم دائماً',
      );
      final box = HiveDatabase.shopBox;
      if (box.isEmpty) {
        await box.add(shop);
      } else {
        await box.putAt(0, shop);
      }
    }
  }

  Future<void> _activateOnline() async {
    final storeName = _storeNameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    if (storeName.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة اسم المحل التجاري للمتابعة');
      return;
    }

    setState(() {
      _isCheckingOnline = true;
      _errorMessage = null;
    });

    await _saveShopDetailsLocally();

    final fullStoreInfo = city.isNotEmpty ? '$storeName ($city)' : storeName;
    final res = await OnlineLicenseService.checkAndActivateOnline(
      storeName: fullStoreInfo,
      phone: phone.isEmpty ? 'غير مسجل' : phone,
    );

    if (mounted) {
      setState(() => _isCheckingOnline = false);

      if (res.isSuccess) {
        SoundService.playCheckoutSuccess();
        context.showAppSnackBar(
          res.message,
          backgroundColor: Colors.green.shade800,
          icon: Icons.verified_user_rounded,
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) context.go('/');
        });
      } else {
        _showPendingOnlineApprovalDialog();
      }
    }
  }

  void _showPendingOnlineApprovalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Text('تم إرسال طلب التفعيل بنجاح 📡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تم إرسال بيانات المتجر ومعرف الجهاز إلى خادم التراخيص للموافقة السريعة.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      LicenseService.getDeviceId(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'نسخ الكود',
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: LicenseService.getDeviceId()));
                      context.showAppSnackBar('📋 تم نسخ كود الجهاز بنجاح!');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بمجرد اعتماد طلبك، اضغط على زر "طلب تفعيل النسخة أونلاين" مرة أخرى وسيتم الدخول فوراً!',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
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
            child: const Text('حسناً، سأنتظر التفعيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _scanMasterQrCode() async {
    SoundService.playTabSwitch();
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      await _processMasterPairing(result);
    }
  }

  Future<void> _processMasterPairing(String rawCode) async {
    setState(() {
      _isPairingWithMaster = true;
      _pairingStatusMessage = 'جاري الاتصال والتحقق الذكي من كاشير الكمبيوتر...';
    });

    String ip = '';
    String port = '8080';
    String shopName = 'كاشير الكمبيوتر الرئيسي';
    String merchantId = '';
    String masterDeviceId = '';

    try {
      final trimmed = rawCode.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final data = jsonDecode(trimmed) as Map<String, dynamic>;
        ip = data['ip']?.toString() ?? '';
        port = data['port']?.toString() ?? '8080';
        shopName = data['name']?.toString() ?? data['shopName']?.toString() ?? 'Nayli POS Master';
        merchantId = data['merchantId']?.toString() ?? '';
        masterDeviceId = data['deviceId']?.toString() ?? '';
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
      } else if (trimmed.isNotEmpty) {
        if (trimmed.toUpperCase().startsWith('SHOP-') || (trimmed.length >= 6 && !trimmed.contains('.'))) {
          merchantId = trimmed.toUpperCase();
        } else {
          ip = trimmed;
        }
      }

      ip = ip.trim();
      port = port.trim();

      if (merchantId.isNotEmpty) {
        await MerchantContextService.setMerchantId(merchantId);
      }

      // Step 1: Attempt Direct Local LAN Wi-Fi Ping First
      if (ip.isNotEmpty && ip != '127.0.0.1') {
        try {
          final url = Uri.parse('http://$ip:$port/api/status');
          final res = await http.get(url).timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final bool isMasterActivated = data['isActivated'] == true;
            final String masterShopName = data['shopName']?.toString() ?? shopName;

            if (isMasterActivated) {
              await LicenseService.grantCompanionLicense(
                storeName: masterShopName,
                masterIp: ip,
              );
              await LocalSyncClient.setServerIp('$ip:$port');

              SoundService.playCheckoutSuccess();
              HapticFeedback.heavyImpact();

              try {
                final count = await LocalSyncClient.pullProductsFromMaster();
                if (count > 0 && mounted) {
                  context.read<ProductBloc>().add(LoadProducts());
                }
              } catch (_) {}

              if (mounted) {
                context.showAppSnackBar(
                  '🎉 تم التحقق والربط بنجاح! مرحباً بك في $masterShopName',
                  backgroundColor: Colors.green.shade800,
                  icon: Icons.verified_rounded,
                );
                context.go('/');
                return;
              }
            }
          }
        } catch (_) {
          debugPrint('Local Wi-Fi ping timed out, switching seamlessly to Cloud Pairing Fallback...');
        }
      }

      // Step 2: Automatic Dual-Mode Cloud Fallback (Works on 4G, Firewall, or AP Isolation)
      if (ip.isNotEmpty || merchantId.isNotEmpty) {
        final result = await CloudSyncService.pairDeviceViaCloud(
          merchantId: merchantId.isNotEmpty ? merchantId : MerchantContextService.getMerchantId(),
          masterDeviceId: masterDeviceId,
          storeName: shopName,
          masterIp: ip,
          port: port,
        );

        SoundService.playCheckoutSuccess();
        HapticFeedback.heavyImpact();

        if (mounted) {
          context.showAppSnackBar(
            '🎉 تم التفعيل والربط السحابي للمتجر ($shopName)!',
            backgroundColor: Colors.teal.shade800,
            icon: Icons.cloud_done_rounded,
          );
          context.go('/');
        }
      } else {
        setState(() {
          _pairingStatusMessage = '❌ لم يتم العثور على رمز اقتران صالح في كود QR.';
        });
        SoundService.playVoidWarning();
      }
    } catch (e) {
      setState(() {
        _pairingStatusMessage = '❌ حدث خطأ أثناء الاقتران: تأكد من تشغيل كاشير الحاسوب.';
      });
      SoundService.playVoidWarning();
    } finally {
      if (mounted) setState(() => _isPairingWithMaster = false);
    }
  }

  void _showManualIpDialog() {
    final ipCtrl = TextEditingController(text: '192.168.1.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('إدخال عنوان IP الكمبيوتر يدوياً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اكتب عنوان IP المعروض في برنامج الكمبيوتر (مثال: 192.168.1.15 أو 192.168.1.15:8080):',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '192.168.1.15:8080',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.computer_rounded, color: Color(0xFF38BDF8)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('اتصال وتحقق'),
            onPressed: () {
              Navigator.pop(ctx);
              _processMasterPairing(ipCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = LicenseService.getDeviceId();
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final merchantId = MerchantContextService.getMerchantId();

    final qrPayload = jsonEncode(
      MerchantContextService.generatePairingPayload(
        localIp: _localIp,
        port: LocalSyncServer.port,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Badge with Subtle Aura
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.45),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.point_of_sale_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'نايلي كيوسك • Nayli Kiosk DZ 🇩🇿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'منظومة الفوترة والمخزون والتجارة الذكية الهجينة (Offline & Cloud Sync)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDesktop ? const Color(0xFF0284C7).withOpacity(0.18) : const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDesktop ? const Color(0xFF38BDF8).withOpacity(0.4) : const Color(0xFF34D399).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDesktop ? Icons.desktop_windows_rounded : Icons.smartphone_rounded,
                            size: 14,
                            color: isDesktop ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDesktop ? 'نسخة الحاسوب (Windows Desktop POS)' : 'نسخة الهاتف (Android Mobile Cashier)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDesktop ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Main Container Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C2E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF24324D)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Status & Device ID Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F172A),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 20),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('كود الجهاز (Hardware ID):', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                        SelectableText(
                                          deviceId,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: 'نسخ الكود',
                                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF38BDF8)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: deviceId));
                                    context.showAppSnackBar('📋 تم نسخ كود الجهاز بنجاح!');
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Modern Tab Bar
                          Container(
                            color: const Color(0xFF162238),
                            child: TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.center,
                              indicatorColor: const Color(0xFF38BDF8),
                              indicatorWeight: 3,
                              labelColor: const Color(0xFF38BDF8),
                              unselectedLabelColor: Colors.grey[400],
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              tabs: const [
                                Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18), text: 'الاقتران السريع 📲'),
                                Tab(icon: Icon(Icons.cloud_sync_rounded, size: 18), text: 'تفعيل أونلاين 🚀'),
                                Tab(icon: Icon(Icons.dialpad_rounded, size: 18), text: 'تفعيل أوفلاين 🔑'),
                                Tab(icon: Icon(Icons.tv_rounded, size: 18), text: 'كشك الأسعار 🛍️'),
                              ],
                            ),
                          ),

                          // Tab View Contents
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: SizedBox(
                              height: isDesktop ? 430 : 390,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // TAB 1: SMART QR PAIRING (DUAL MODE)
                                  _buildSmartPairingTab(isDesktop, qrPayload, merchantId),

                                  // TAB 2: ONLINE CLOUD ACTIVATION
                                  _buildOnlineCloudTab(),

                                  // TAB 3: OFFLINE & DOUCHETTE ACTIVATION
                                  _buildOfflineDouchetteTab(),

                                  // TAB 4: FREE PRICE CHECKER KIOSK
                                  _buildKioskModeTab(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp / Developer Support Button
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF34D399)),
                      icon: const Icon(Icons.support_agent_rounded, size: 20),
                      label: const Text(
                        'هل تحتاج إلى مساعدة أو ترخيص؟ تواصل مع المطور مباشرة',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse('https://wa.me/213550000000?text=مرحباً، أود تفعيل برنامج Nayli Kiosk لكود الجهاز: $deviceId');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// TAB 1: Dual-Mode Smart Pairing (On Mobile: Camera Scanner / On Desktop: Master QR Display)
  Widget _buildSmartPairingTab(bool isDesktop, String qrPayload, String merchantId) {
    if (isDesktop) {
      // Desktop View: Show Shop's Master QR Code for companions to scan + Option to link as Caisse 2
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 165.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'وجّه كاميرا الهاتف نحو هذا الكود لاقترانه فوراً! 📸',
              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              'IP السيرفر المحلي: $_localIp:8080 • المعرف: $merchantId',
              style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'monospace'),
            ),

            if (_pairingStatusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _pairingStatusMessage!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _pairingStatusMessage!.startsWith('✅') || _pairingStatusMessage!.startsWith('🎉')
                      ? const Color(0xFF34D399)
                      : const Color(0xFFF87171),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155)),
            const SizedBox(height: 6),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isPairingWithMaster
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                  : const Icon(Icons.link_rounded, size: 16),
              label: const Text(
                'هل هذا الجهاز كاشير فرعي؟ اربطه بالحاسوب الرئيسي (Caisse 2) 🖥️ ↔️ 🖥️',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: _isPairingWithMaster ? null : _showManualIpDialog,
            ),
          ],
        ),
      );
    }

    // Mobile View: Camera Scanner Button + Manual Fallback
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.35)),
          ),
          child: const Column(
            children: [
              Icon(Icons.wifi_tethering_rounded, color: Color(0xFF38BDF8), size: 36),
              SizedBox(height: 8),
              Text(
                'الاقتران الذكي بكاشير الحاسوب 📲 ↔️ 🖥️',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              SizedBox(height: 6),
              Text(
                'امسح رمز QR المعروض على شاشة الكمبيوتر. سيتم الاتصال فورا عبر الواي فاي أو السحابة تلقائياً دون أي إعدادات معقدة!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_pairingStatusMessage != null) ...[
          Text(
            _pairingStatusMessage!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _pairingStatusMessage!.startsWith('✅') || _pairingStatusMessage!.startsWith('🎉')
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: _isPairingWithMaster
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('مسح كود الكمبيوتر (QR) 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _isPairingWithMaster ? null : _scanMasterQrCode,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('إدخال IP ✍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _isPairingWithMaster ? null : _showManualIpDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// TAB 2: Online Cloud Activation Tab
  Widget _buildOnlineCloudTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _storeNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'اسم المحل التجاري * (مثال: سوبرماركت البركة)',
              labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
              prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 18),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF38BDF8), size: 17),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'المدينة / الولاية',
                    labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF38BDF8), size: 17),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            icon: _isCheckingOnline
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_done_rounded, size: 20),
            label: Text(
              _isCheckingOnline ? 'جاري التحقق السحابي...' : '🚀 طلب تفعيل النسخة أونلاين (Cloud Activate)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            onPressed: _isCheckingOnline ? null : _activateOnline,
          ),
        ],
      ),
    );
  }

  /// TAB 3: Offline Barcode Gun & Manual Key Tab
  Widget _buildOfflineDouchetteTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تفعيل فوري بقارئ الباركود (Douchette) 🔫',
            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'إذا وصلتك بطاقة التفعيل المطبوعة، امسح الباركود مباشرة بقارئ الباركود لتفعيل البرنامج في ثانية:',
            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _douchetteController,
                  focusNode: _douchetteFocusNode,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  onSubmitted: (val) => _handleDouchetteActivation(val),
                  decoration: InputDecoration(
                    hintText: 'امسح بالدوشيت أو اكتب الكود (مثال: NY-123456)...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF38BDF8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('تفعيل ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _handleDouchetteActivation(_douchetteController.text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 10),

          const Text(
            'أو كتابة كود التفعيل السري يدوياً ✍️',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualKeyController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  onSubmitted: (val) => _handleDouchetteActivation(val),
                  decoration: InputDecoration(
                    hintText: 'أدخل مفتاح الترخيص (Licence Key)...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF38BDF8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: const Text('تحقق 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _handleDouchetteActivation(_manualKeyController.text),
              ),
            ],
          ),

          if (_pairingStatusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _pairingStatusMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _pairingStatusMessage!.startsWith('✅') || _pairingStatusMessage!.startsWith('🎉')
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.phone_android_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '💡 لديك هاتف مفعل؟ افتح الإعدادات في الهاتف واضغط "تفعيل حاسوب بالباركود"، ثم امسح الكود الظاهر على شاشة الهاتف بقارئ الباركود (Douchette)!',
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// TAB 4: Free Customer Price Checker Kiosk Tab
  Widget _buildKioskModeTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.35)),
          ),
          child: const Column(
            children: [
              Icon(Icons.tv_rounded, color: Color(0xFF818CF8), size: 36),
              SizedBox(height: 8),
              Text(
                'تشغيل كـ كشك فاحص أسعار للزبائن (مجاني 100%) 🛍️ 🆓',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 6),
              Text(
                'إذا كان هذا الجهاز عبارة عن شاشة معلقة أو تابلت في ممرات السوبرماركت ليفحص الزبائن الأسعار والعروض، يمكنك تشغيله فوراً بدون استهلاك رخص الكاشير!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: const Text(
            'تشغيل وضع فاحص الأسعار (Kiosk Mode) 🚀',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
          onPressed: () async {
            await HiveDatabase.settingsBox.put('device_role', 'customer_kiosk');
            SoundService.playCheckoutSuccess();
            if (mounted) context.go('/kiosk');
          },
        ),
      ],
    );
  }
}
