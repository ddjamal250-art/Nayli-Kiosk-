import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/online_license_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_client.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _douchetteController = TextEditingController();
  final FocusNode _douchetteFocusNode = FocusNode();

  String? _errorMessage;
  bool _isCheckingOnline = false;

  // Master PC Pairing State
  bool _isPairingWithMaster = false;
  String? _pairingStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingShopInfo();
    HardwareKeyboard.instance.addHandler(_handleDouchetteHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _douchetteFocusNode.requestFocus();
    });
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
    _storeNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _douchetteController.dispose();
    _douchetteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDouchetteActivation(String rawInput) async {
    final normalized = BarcodeNormalizer.normalizeAzertyInput(rawInput.trim());
    if (normalized.isEmpty) return;

    setState(() {
      _pairingStatusMessage = 'جاري التحقق من كود الباركود...';
    });

    final result = await LicenseService.verifyAndApplyDouchetteToken(normalized);
    if (result['success'] == true) {
      SoundService.playCheckoutSuccess();
      HapticFeedback.heavyImpact();
      if (mounted) {
        context.showAppSnackBar(
          result['message']?.toString() ?? '🎉 تم تفعيل هذا الحاسوب بنجاح!',
          backgroundColor: Colors.green.shade800,
          icon: Icons.verified_rounded,
        );
        context.go('/');
      }
    } else {
      SoundService.playVoidWarning();
      setState(() {
        _pairingStatusMessage = result['message']?.toString() ?? '❌ كود غير صالح';
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.green[800],
            duration: const Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) context.go('/');
        });
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  'تم إرسال معلومات المحل وكود الجهاز مباشرة إلى المطور عبر التلغرام.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بمجرد أن يوافق المطور على طلبك، اضغط على زر "تفعيل وترخيص النسخة أونلاين" مرة أخرى وسيتم الدخول فوراً!',
                          style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
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
                child: const Text('حسناً فهمت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
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
      _pairingStatusMessage = 'جاري الاتصال والتحقق من كاشير الكمبيوتر...';
    });

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

      if (ip.isEmpty || ip == '127.0.0.1') {
        setState(() {
          _pairingStatusMessage = '❌ لم يتم العثور على عنوان IP صالح في الكود.';
        });
        SoundService.playVoidWarning();
        return;
      }

      final url = Uri.parse('http://$ip:$port/api/status');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

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
              '🎉 تم التحقق من ترخيص المتجر بنجاح! مرحباً بك في $masterShopName',
              backgroundColor: Colors.green.shade800,
              icon: Icons.verified_rounded,
            );
            context.go('/');
          }
        } else {
          setState(() {
            _pairingStatusMessage = '⚠️ تم الاتصال بالكمبيوتر، ولكن البرنامج على الكمبيوتر غير مفعّل بعد! يرجى تفعيل نسخة الكمبيوتر أولاً.';
          });
          SoundService.playVoidWarning();
        }
      } else {
        setState(() {
          _pairingStatusMessage = '⚠️ استجاب السيرفر برمز غير متوقع: ${res.statusCode}';
        });
        SoundService.playVoidWarning();
      }
    } catch (e) {
      setState(() {
        _pairingStatusMessage = '❌ تعذر الاتصال بكاشير الكمبيوتر: تأكد من اتصالهما بنفس شبكة الواي فاي (Wi-Fi).';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.point_of_sale_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Nayli Market DZ 🇩🇿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'منظومة الفوترة والمخزون والتجارة الذكية للمحلات والسوبرماركت',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 18),

                    // Main Container Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'تفعيل ترخيص المنظومة',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  'غير مفعل 🔒',
                                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Device ID Box with 1-Click Copy
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF475569)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'معرف هذا الجهاز (Hardware ID):',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                                      ),
                                      const SizedBox(height: 2),
                                      SelectableText(
                                        deviceId,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'نسخ المعرف',
                                  icon: const Icon(Icons.copy, size: 16, color: Color(0xFF38BDF8)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: deviceId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('📋 تم نسخ معرف الجهاز بنجاح!'),
                                        backgroundColor: Colors.teal,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // ==========================================
                          // OPTION A: DOUCHETTE BARCODE SCANNER ACTIVATION (DESKTOP PC)
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF0284C7).withOpacity(0.22),
                                  const Color(0xFF0369A1).withOpacity(0.10),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.45)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 22),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'تفعيل فوري بقارئ الباركود (Douchette) 🔫 📲',
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'إذا كنت قد فعّلت التطبيق على هاتفك أولاً، افتح من هاتفك: (عرض كود تفعيل الحاسوب 🔫)، ثم وجّه قارئ الباركود الموصول بالحاسوب نحو شاشة هاتفك واضغط الزناد (BEEP) لتفعيل هذا الحاسوب فوراً!',
                                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                                ),
                                const SizedBox(height: 12),

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
                                          hintText: 'امسح بالدوشيت أو اكتب الرمز المختصر (مثال: NY-123456)...',
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ==========================================
                          // OPTION B: MASTER PC CAMERA SCANNING (PHONE)
                          // ==========================================
                          if (!isDesktop) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0F766E).withOpacity(0.25),
                                    const Color(0xFF0D9488).withOpacity(0.12),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2DD4BF), size: 22),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'أو ربط وتفعيل فوري عبر كاشير الحاسوب 📲 ↔️ 🖥️',
                                          style: TextStyle(
                                            color: Color(0xFF2DD4BF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'إذا كنت قد فعّلت برنامج الكاشير على جهاز الكمبيوتر، وجّه كاميرا الهاتف نحو كود الربط (QR) المعروض على شاشة الكمبيوتر لتفعيل وفتح التطبيق فوراً!',
                                    style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F766E),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 2,
                                          ),
                                          icon: _isPairingWithMaster
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : const Icon(Icons.camera_alt_rounded, size: 18),
                                          label: const Text(
                                            'مسح كود الكمبيوتر (QR) 📸',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                          ),
                                          onPressed: _isPairingWithMaster ? null : _scanMasterQrCode,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF38BDF8),
                                            side: const BorderSide(color: Color(0xFF38BDF8)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: const Icon(Icons.edit_rounded, size: 14),
                                          label: const Text('إدخال IP ✍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                          onPressed: _isPairingWithMaster ? null : _showManualIpDialog,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_pairingStatusMessage != null) ...[
                            Text(
                              _pairingStatusMessage!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _pairingStatusMessage!.startsWith('✅') || _pairingStatusMessage!.startsWith('🎉')
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ==========================================
                          // OPTION C: UNLIMITED CUSTOMER PRICE-CHECKER KIOSK (مجاني وغير محدود)
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4F46E5).withOpacity(0.22),
                                  const Color(0xFF4338CA).withOpacity(0.10),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.45)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.tv_rounded, color: Color(0xFF818CF8), size: 22),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'تشغيل كـ كشك زبائن لفحص الأسعار (مجاني وغير محدود) 🛍️ 🆓',
                                        style: TextStyle(
                                          color: Color(0xFF818CF8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'إذا كان هذا الجهاز عبارة عن شاشة معلقة أو تابلت في ممرات السوبرماركت ليفحص الزبائن أسعار السلع وعروضها الترويجية، يمكنك تشغيله فوراً بدون أي قيود ودون استهلاك رخص الكاشير!',
                                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                  label: const Text(
                                    'تشغيل وضع فاحص الأسعار (Kiosk Mode) 🚀',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () async {
                                    await HiveDatabase.settingsBox.put('device_role', 'customer_kiosk');
                                    SoundService.playCheckoutSuccess();
                                    if (mounted) {
                                      context.go('/kiosk');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFF334155))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'أو تفعيل النسخة أونلاين عبر السحابة',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                              ),
                              const Expanded(child: Divider(color: Color(0xFF334155))),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ==========================================
                          // OPTION C: STANDALONE CLOUD ACTIVATION
                          // ==========================================
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
                                    labelText: 'رقم الهاتف (للتواصل)',
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

                          // Pure Online Cloud Activation Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            icon: _isCheckingOnline
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 20),
                            label: Text(
                              _isCheckingOnline ? 'جاري الاتصال والتحقق السحابي...' : '🚀 طلب تفعيل النسخة أونلاين (Cloud Activate)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            onPressed: _isCheckingOnline ? null : _activateOnline,
                          ),
                        ],
                      ),
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
}
