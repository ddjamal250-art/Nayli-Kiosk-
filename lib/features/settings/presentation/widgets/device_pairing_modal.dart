import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/data/hive_database.dart';
import '../../../shop/data/models/shop_model.dart';

class DevicePairingModal extends StatelessWidget {
  const DevicePairingModal({super.key});

  static Future<void> show(BuildContext context) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      builder: (ctx) => const DevicePairingModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = LicenseService.getDeviceId();
    final maxQuota = HiveDatabase.settingsBox.get('store_max_devices_quota', defaultValue: 1) as int;
    String shopName = 'سوبرماركت البركة';
    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null && shop.name.isNotEmpty) shopName = shop.name;
    }

    final telegramDeepLink = 'https://t.me/nayli_pos_dz_bot?start=STORE_$deviceId';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Colors.indigo, size: 28),
                      SizedBox(width: 8),
                      Text('ربط الهاتف والتقارير الذكية 📲', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),

              // Device Quota Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices_rounded, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        Text('سعة الأجهزة المسموحة للرخصة: $maxQuota أجهزة',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ],
                    ),
                    const Icon(Icons.verified, size: 16, color: Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Telegram Bot Pairing Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.blue, size: 22),
                        SizedBox(width: 8),
                        Text('1. ربط هاتف صاحب المحل بالتلغرام 🤖',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'امسح الكود بكاميرا هاتفك لتصلك تقارير المبيعات والأرباح اليومية والنسخ السحابي تلقائياً:',
                      style: TextStyle(fontSize: 11.5, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // QR Code
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: QrImageView(
                          data: telegramDeepLink,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text('المحل: $shopName • $deviceId',
                        style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mobile App LAN Companion Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: Colors.teal, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('2. تطبيق الهاتف المتنقل (Nayli Mobile)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          SizedBox(height: 2),
                          Text(
                            'افتح تطبيق Nayli Market على هاتفك وامسح نفس الكود لتحويل الهاتف إلى ماسح باركود لاسلكي وجرد سريع للمخزون عبر الواي فاي.',
                            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),

              // WhatsApp Integration Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat_bubble_rounded, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('3. وصولات الواتساب الرقمية (WhatsApp Receipts) 💬',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                          SizedBox(height: 2),
                          Text(
                            'مفعل تلقائياً عند شاشة الدفع: إرسال تفاصيل الفاتورة ورصيد الديون المتبقي مباشرة إلى واتساب الزبون بضغطة زر وبدون اشتراكات خارجية.',
                            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('تم الربط • إغلاق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

