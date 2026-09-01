import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/online_license_service.dart';
import '../../../../core/data/hive_database.dart';
import '../../../shop/data/models/shop_model.dart';
import '../widgets/developer_master_portal.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _errorMessage;
  bool _isCheckingOnline = false;

  @override
  void initState() {
    super.initState();
    _loadExistingShopInfo();
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
    _storeNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final deviceId = LicenseService.getDeviceId();

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
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo with graceful fallback
                    Container(
                      width: 84,
                      height: 84,
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
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.point_of_sale_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Nayli Market DZ 🇩🇿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
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
                    const SizedBox(height: 20),

                    // Main Form Card
                    Container(
                      padding: const EdgeInsets.all(22),
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
                                    'تفعيل ترخيص النسخة الرسمية',
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
                          const SizedBox(height: 16),

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
                                          fontSize: 14,
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
                          const SizedBox(height: 16),

                          // Store Name Input
                          TextField(
                            controller: _storeNameController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'اسم المحل التجاري * (مثال: سوبرماركت البركة)',
                              labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                              prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 20),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                    prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF38BDF8), size: 18),
                                    filled: true,
                                    fillColor: const Color(0xFF0F172A),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF38BDF8), size: 18),
                                    filled: true,
                                    fillColor: const Color(0xFF0F172A),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF475569))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // 100% PURE Online Cloud Activation Button (NO LOCAL BACKDOOR)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            icon: _isCheckingOnline
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 22),
                            label: Text(
                              _isCheckingOnline ? 'جاري الاتصال والتحقق السحابي...' : '🚀 تفعيل وترخيص النسخة أونلاين (Cloud Activate)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            onPressed: _isCheckingOnline ? null : _activateOnline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discreet Developer Master Onsite Button
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                      label: const Text(
                        'بوابة المطور الميداني المباشر (Master Admin)',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () async {
                        await DeveloperMasterPortal.show(context);
                        if (LicenseService.isActivated() && mounted) {
                          context.go('/');
                        }
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
}
}