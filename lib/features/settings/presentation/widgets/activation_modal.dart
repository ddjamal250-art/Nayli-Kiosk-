import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/online_license_service.dart';
import '../../../../core/utils/adaptive_modal_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../../shop/data/models/shop_model.dart';

class ActivationModal extends StatefulWidget {
  const ActivationModal({super.key});

  static Future<void> show(BuildContext context) {
    return AdaptiveModalHelper.showAdaptiveModal(
      context: context,
      desktopMaxWidth: 560,
      builder: (ctx) => const ActivationModal(),
    );
  }

  @override
  State<ActivationModal> createState() => _ActivationModalState();
}

class _ActivationModalState extends State<ActivationModal> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _errorMessage;
  bool _isSuccess = false;
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
        setState(() => _isSuccess = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.green[800],
            duration: const Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        final deviceId = LicenseService.getDeviceId();
        final cleanStore = fullStoreInfo;
        final cleanPhone = phone;
        final directTelegramSent = res.telegramDirectSent;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  directTelegramSent ? Icons.cloud_done_rounded : Icons.send_rounded,
                  color: directTelegramSent ? Colors.green : Colors.indigo,
                  size: 26,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('طلب تفعيل النسخة 📡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    directTelegramSent
                        ? '✅ تم إرسال بيانات المتجر ومعرف الجهاز آلياً إلى خادم وتيليجرام المطور.'
                        : 'تم تسجيل طلبك في السيرفر السحابي. لتسريع الاعتماد الفوري في ثانية، اضغط أدناه لإرسال الكود للمطور عبر تيليجرام:',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Colors.indigo, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            deviceId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ الكود',
                          icon: const Icon(Icons.copy, size: 16, color: Colors.indigo),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📋 تم نسخ كود الجهاز بنجاح!'), backgroundColor: Colors.teal),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1-Click Telegram Direct Launch Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'إرسال للمطور عبر تيليجرام 📱',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () async {
                      final text = '🔔 طلب تفعيل ترخيص جديد (Nayli POS)\n'
                          '━━━━━━━━━━━━━━━━━\n'
                          '🏬 المحل: ${cleanStore.isEmpty ? "متجر تجاري" : cleanStore}\n'
                          '📱 الهاتف: ${cleanPhone.isEmpty ? "غير مسجل" : cleanPhone}\n'
                          '💻 كود الجهاز: $deviceId\n'
                          '━━━━━━━━━━━━━━━━━\n'
                          'أرجو تفعيل هذا الجهاز.';
                      final uri = Uri.parse('https://t.me/MARKI_JW0?text=${Uri.encodeComponent(text)}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 8),

                  // Bot Direct Link
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.smart_toy_rounded, size: 18),
                    label: const Text(
                      'أو فتح بوت التفعيل الرسمي 🤖',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('https://t.me/nayli_pos_dz_bot?start=act_${Uri.encodeComponent(deviceId)}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app, color: Colors.indigo, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'بمجرد أن يوافق المطور على طلبك، اضغط على زر "تفعيل أونلاين" مرة أخرى وسيتم فتح نسختك فوراً!',
                            style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً، فهمت', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final isActivated = LicenseService.isActivated();
    final remainingDays = LicenseService.getRemainingDays();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isActivated ? Icons.verified_user_rounded : Icons.vpn_key_rounded,
                      color: isActivated ? Colors.green : AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'معلومات المتجر والتفعيل السحابي 🔒',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Status Badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActivated
                    ? Colors.green.withOpacity(0.08)
                    : (remainingDays > 0 ? Colors.orange.withOpacity(0.08) : Colors.red.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActivated
                      ? Colors.green.withOpacity(0.3)
                      : (remainingDays > 0 ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActivated
                        ? Icons.check_circle
                        : (remainingDays > 0 ? Icons.timer_outlined : Icons.lock_outline),
                    color: isActivated
                        ? Colors.green
                        : (remainingDays > 0 ? Colors.orange : Colors.red),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActivated
                              ? '✅ النسخة الأصلية مفعلة سحابياً مدى الحياة'
                              : (remainingDays > 0
                                  ? '⏳ فترة تجريبية مجانية (متبقي $remainingDays أيام)'
                                  : '🔒 غير مفعل - يتطلب التفعيل السحابي أونلاين'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isActivated
                                ? Colors.green[800]
                                : (remainingDays > 0 ? Colors.orange[900] : Colors.red[900]),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isActivated
                              ? 'الترخيص مقترن بهذا الحاسوب رسمياً ويعمل أوفلاين للأبد'
                              : 'املأ بيانات المحل واضغط على زر التفعيل السحابي',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Device ID & Offline Machine Code Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'كود تعريف جهازك (Machine Code):',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        icon: const Icon(Icons.copy, size: 13, color: Color(0xFF38BDF8)),
                        label: const Text('نسخ كود الجهاز 📋', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                        onPressed: () {
                          final cleanId = LicenseService.getCleanMachineId();
                          Clipboard.setData(ClipboardData(text: cleanId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('📋 تم نسخ كود الجهاز ($cleanId)!'), backgroundColor: Colors.teal),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    LicenseService.getCleanMachineId(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (!isActivated) ...[
              // Store Info Inputs
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront, size: 18, color: Colors.blueGrey),
                        SizedBox(width: 6),
                        Text('بيانات المحل التجاري (لإعداد الفواتير والترخيص):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _storeNameController,
                      decoration: InputDecoration(
                        labelText: 'اسم المحل أو السوبرماركت *',
                        hintText: 'مثال: سوبرماركت الهناء',
                        prefixIcon: const Icon(Icons.store),
                        border: const OutlineInputBorder(),
                        errorText: _errorMessage,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم هاتف المحل',
                              hintText: '0661xxxxxx',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'الولاية / المدينة',
                              hintText: 'مثال: الجلفة',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 100% Pure Online Cloud Activation Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isCheckingOnline
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
                label: Text(
                  _isCheckingOnline ? 'جاري التحقق وإرسال الطلب...' : '🚀 تفعيل وترخيص النسخة عبر الإنترنت (Cloud Activate)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isCheckingOnline ? null : _activateOnline,
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}