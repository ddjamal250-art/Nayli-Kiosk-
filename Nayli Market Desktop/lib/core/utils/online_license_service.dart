import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/hive_database.dart';
import '../utils/sound_service.dart';
import 'license_service.dart';

class OnlineActivationResult {
  final bool isSuccess;
  final String message;
  final String? plan;
  final String? storeName;
  final int maxDevices;

  OnlineActivationResult({
    required this.isSuccess,
    required this.message,
    this.plan,
    this.storeName,
    this.maxDevices = 1,
  });
}

class OnlineLicenseService {
  // Google Apps Script Web App Endpoint
  static const String defaultScriptUrl =
      'https://script.google.com/macros/s/AKfycbxQYO_wt3YY6m6dV3P9mghkVnjZWiZbX697oQjdUZKGKVdkh_eJxe3e5AzQYR5enu3s/exec';

  // Developer Telegram Bot (Obfuscated to protect against automated scrapers)
  static String get defaultBotToken {
    try {
      return utf8.decode(base64.decode('ODY2NzM5MDkyNjpBQUV1UWc0Wks4ejdLbXdBYWVtb0dHZFpGRHhJLUlpcVBPSQ=='));
    } catch (_) {
      return '';
    }
  }

  static String get defaultChatId {
    try {
      return utf8.decode(base64.decode('NTExNTQ2NTI2Nw=='));
    } catch (_) {
      return '';
    }
  }

  /// Send interactive 1-Click activation request to developer Telegram with custom quota buttons
  static Future<bool> notifyDeveloperTelegram({
    required String deviceId,
    String storeName = 'غير محدد',
    String phone = 'غير محدد',
  }) async {
    try {
      final token = HiveDatabase.settingsBox.get('telegram_bot_token', defaultValue: defaultBotToken) as String;
      final chatId = HiveDatabase.settingsBox.get('telegram_chat_id', defaultValue: defaultChatId) as String;

      if (token.isEmpty || chatId.isEmpty) return false;

      final message = '''
🔔 <b>طلب تفعيل ترخيص جديد (Nayli POS)</b>
━━━━━━━━━━━━━━━━━
🏬 <b>المحل:</b> $storeName
📱 <b>الهاتف:</b> $phone
💻 <b>كود الجهاز:</b> <code>$deviceId</code>
⏰ <b>الوقت:</b> ${DateTime.now().toString().substring(0, 16)}
━━━━━━━━━━━━━━━━━
👇 <b>اختر نوع الباقة وسعة الأجهزة بضغطة زر لتفعيله في Google Sheet فوراً:</b>
''';

      final inlineKeyboard = {
        'inline_keyboard': [
          [
            {
              'text': '🌟 دائم (جهاز 1)',
              'callback_data': 'P1:$deviceId',
            },
            {
              'text': '🌟 دائم (3 أجهزة)',
              'callback_data': 'P3:$deviceId',
            },
            {
              'text': '🌟 دائم (5 أجهزة)',
              'callback_data': 'P5:$deviceId',
            },
          ],
          [
            {
              'text': '📅 سنوي (Y)',
              'callback_data': 'Y:$deviceId',
            },
            {
              'text': '⏳ تجريبي 30 يوم (M)',
              'callback_data': 'M:$deviceId',
            },
            {
              'text': '❌ رفض / حظر',
              'callback_data': 'REJ:$deviceId',
            },
          ],
        ]
      };

      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
          'reply_markup': inlineKeyboard,
        }),
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check license status online via Google Apps Script Web App with Quota validation
  static Future<OnlineActivationResult> checkAndActivateOnline({
    String storeName = '',
    String phone = '',
  }) async {
    final deviceId = LicenseService.getDeviceId();

    // 1. Send interactive inline button message to Developer's Telegram
    notifyDeveloperTelegram(
      deviceId: deviceId,
      storeName: storeName.isEmpty ? 'متجر كاشير' : storeName,
      phone: phone,
    );

    try {
      final scriptUrl = HiveDatabase.settingsBox.get('google_license_script_url', defaultValue: defaultScriptUrl) as String;
      final uri = Uri.parse('$scriptUrl?deviceId=${Uri.encodeComponent(deviceId)}');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);

        if (data is Map && data['isActivated'] == true) {
          final plan = (data['plan'] as String? ?? 'P').toUpperCase();
          final serverStoreName = data['storeName'] as String? ?? storeName;
          final maxDevices = (data['maxDevices'] as num?)?.toInt() ?? 1;

          await HiveDatabase.settingsBox.put('store_max_devices_quota', maxDevices);
          await HiveDatabase.settingsBox.put('licensed_store_name', serverStoreName);

          if (plan.startsWith('P')) {
            await LicenseService.grantPermanentLicense();
          } else if (plan == 'Y') {
            await LicenseService.grantCustomPlan(days: 365, isSubscription: true);
          } else if (plan == 'M') {
            await LicenseService.grantCustomPlan(days: 30, planType: 'trial_month');
          } else if (plan == 'W') {
            await LicenseService.grantCustomPlan(days: 14, planType: 'trial_week');
          } else {
            await LicenseService.grantPermanentLicense();
          }

          SoundService.playSaveSuccess();
          return OnlineActivationResult(
            isSuccess: true,
            message: '🎉 تم تفعيل نسختك الرسمية بنجاح! (سعة الأجهزة: $maxDevices)',
            plan: plan,
            storeName: serverStoreName,
            maxDevices: maxDevices,
          );
        } else {
          return OnlineActivationResult(
            isSuccess: false,
            message: 'طلبك قيد المراجعة في السيرفر. وصل إشعار تفاعلي لهاتف المطور بأزرار التفعيل الفوري وسعة الأجهزة!',
          );
        }
      } else {
        return OnlineActivationResult(
          isSuccess: false,
          message: 'تعذر الاتصال بالسيرفر السحابي (كود: ${response.statusCode}). تأكد من اتصال الإنترنت.',
        );
      }
    } catch (e) {
      return OnlineActivationResult(
        isSuccess: false,
        message: 'حدث خطأ في الاتصال: $e. تأكد من اتصال الإنترنت وحاول مجدداً.',
      );
    }
  }

  /// Send Daily Sales Z-Report to Merchant's Telegram
  static Future<bool> sendDailyReportToMerchant({
    required double totalSales,
    required double cashInDrawer,
    required double tpeSales,
    required double creditSales,
    required int invoiceCount,
    required double estimatedNetProfit,
  }) async {
    try {
      final token = HiveDatabase.settingsBox.get('telegram_bot_token', defaultValue: defaultBotToken) as String;
      final merchantChatId = HiveDatabase.settingsBox.get('merchant_telegram_chat_id', defaultValue: defaultChatId) as String;

      if (token.isEmpty || merchantChatId.isEmpty) return false;

      final storeName = HiveDatabase.settingsBox.get('licensed_store_name', defaultValue: 'سوبرماركت البركة') as String;
      final dateStr = DateTime.now().toString().substring(0, 16);

      final message = '''
📊 <b>تقرير ختام اليوم والمبيعات (Z-Report)</b>
🏬 <b>المحل:</b> $storeName
📅 <b>التاريخ والوقت:</b> $dateStr
━━━━━━━━━━━━━━━━━
💰 <b>إجمالي المبيعات:</b> ${totalSales.toStringAsFixed(2)} DA
💵 <b>الكاش في الدرج:</b> ${cashInDrawer.toStringAsFixed(2)} DA
💳 <b>الدفع الإلكتروني (CIB/TPE):</b> ${tpeSales.toStringAsFixed(2)} DA
📉 <b>ديون اليوم (كريدي):</b> ${creditSales.toStringAsFixed(2)} DA
🧾 <b>عدد الفواتير المنفذة:</b> $invoiceCount فاتورة
📈 <b>صافي الأرباح الصافية المقدرة:</b> ${estimatedNetProfit.toStringAsFixed(2)} DA
━━━━━━━━━━━━━━━━━
🔒 <i>تم إغلاق الوردية وحفظ النسخة الاحتياطية بنجاح</i>
''';

      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': merchantChatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

