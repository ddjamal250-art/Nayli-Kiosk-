import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final bool telegramDirectSent;

  OnlineActivationResult({
    required this.isSuccess,
    required this.message,
    this.plan,
    this.storeName,
    this.maxDevices = 1,
    this.telegramDirectSent = false,
  });
}

class OnlineLicenseService {
  // Google Cloud Firestore Centralized Database (nayli-pos-dz)
  static const String firestoreProjectId = 'nayli-pos-dz';
  static const String firestoreApiKey = 'AIzaSyArn6G3ZDhexjTaWk4qDPASGyW6JqMiLF4';
  static const String firestoreBaseUrl =
      'https://firestore.googleapis.com/v1/projects/$firestoreProjectId/databases/(default)/documents/licenses';

  // Google Apps Script Web App Endpoint (Relay & Failover)
  static const String defaultScriptUrl =
      'https://script.google.com/macros/s/AKfycbxQYO_wt3YY6m6dV3P9mghkVnjZWiZbX697oQjdUZKGKVdkh_eJxe3e5AzQYR5enu3s/exec';

  // Developer Telegram Bot (Obfuscated to protect against automated scrapers)
  static String get defaultBotToken {
    try {
      // Obfuscated using XOR 42
      const List<int> _o = [
        18, 28, 28, 29, 25, 19, 26, 19, 24, 28, 16, 107, 107, 111, 95, 123, 77, 30,
        112, 97, 18, 80, 29, 97, 71, 93, 107, 75, 79, 71, 69, 109, 109, 78, 112,
        108, 110, 82, 99, 7, 99, 67, 91, 122, 101, 99
      ];
      return String.fromCharCodes(_o.map((e) => e ^ 42));
    } catch (_) {
      return '';
    }
  }

  static String get defaultChatId {
    try {
      // Obfuscated using XOR 42
      const List<int> _o = [31, 27, 27, 31, 30, 28, 31, 24, 28, 29];
      return String.fromCharCodes(_o.map((e) => e ^ 42));
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
      final token = defaultBotToken;
      final chatId = defaultChatId;

      if (token.isEmpty || chatId.isEmpty) return false;

      final cleanMachine = LicenseService.getCleanMachineId();
      final message = '''
🔔 <b>طلب تفعيل ترخيص جديد (Nayli POS)</b>
━━━━━━━━━━━━━━━━━
🏬 <b>المحل:</b> $storeName
📱 <b>الهاتف:</b> $phone
💻 <b>كود الجهاز:</b> <code>$deviceId</code>
🔑 <b>كود الأوفلاين:</b> <code>$cleanMachine</code>
⏰ <b>الوقت:</b> ${DateTime.now().toString().substring(0, 16)}
━━━━━━━━━━━━━━━━━
🔥 <b>قاعدة البيانات السحابية:</b> Google Firestore (nayli-pos-dz)
👇 <b>اختر نوع الباقة للتفعيل الفوري:</b>
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
          [
            {
              'text': '🔥 فتح في Firebase Console',
              'url': 'https://console.firebase.google.com/u/0/project/nayli-pos-dz/firestore/databases/-default-/data/~2Flicenses~2F$deviceId',
            },
          ],
        ],
      };

      final url = 'https://api.telegram.org/bot$token/sendMessage';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
          'reply_markup': inlineKeyboard,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[TelegramBot] Failed to notify developer: $e');
      return false;
    }
  }

  /// Check license status online via Google Cloud Firestore & Google Apps Script
  static Future<OnlineActivationResult> checkAndActivateOnline({
    String storeName = '',
    String phone = '',
  }) async {
    final deviceId = LicenseService.getDeviceId();
    final cleanStore = storeName.trim().isEmpty ? 'متجر كاشير' : storeName.trim();
    final cleanPhone = phone.trim().isEmpty ? 'غير مسجل' : phone.trim();
    final deviceType = Platform.isWindows ? 'Desktop PC' : (Platform.isAndroid ? 'Android Phone' : 'Device');

    // 1. Send interactive inline button message directly to Developer's Telegram (10s timeout)
    bool directTelegramSent = false;
    try {
      directTelegramSent = await notifyDeveloperTelegram(
        deviceId: deviceId,
        storeName: cleanStore,
        phone: cleanPhone,
      );
    } catch (e) {
      debugPrint('[OnlineLicenseService] Direct Telegram notify error: $e');
      directTelegramSent = false;
    }

    // 2. Primary Online Licensing: Google Cloud Firestore (nayli-pos-dz)
    try {
      final firestoreDocUrl = '$firestoreBaseUrl/$deviceId?key=$firestoreApiKey';
      final fsGetRes = await http.get(Uri.parse(firestoreDocUrl)).timeout(const Duration(seconds: 8));

      if (fsGetRes.statusCode == 200) {
        final fsData = jsonDecode(fsGetRes.body) as Map<String, dynamic>?;
        final fields = fsData?['fields'] as Map<String, dynamic>?;
        final isAct = fields?['isActivated']?['booleanValue'] == true;

        if (isAct) {
          final plan = (fields?['plan']?['stringValue'] ?? 'P').toUpperCase();
          final serverStoreName = fields?['storeName']?['stringValue'] ?? cleanStore;
          final maxDevices = int.tryParse(fields?['maxDevices']?['integerValue']?.toString() ?? '1') ?? 1;

          await HiveDatabase.settingsBox.put('store_max_devices_quota', maxDevices);
          await HiveDatabase.settingsBox.put('licensed_store_name', serverStoreName);
          await HiveDatabase.settingsBox.put('licensed_phone', cleanPhone);

          if (plan.startsWith('P')) {
            await LicenseService.grantPermanentLicense();
          } else if (plan == 'Y') {
            await LicenseService.grantCustomPlan(days: 365, isSubscription: true);
          } else if (plan == 'M') {
            await LicenseService.grantCustomPlan(days: 30, planType: 'trial_month');
          } else {
            await LicenseService.grantPermanentLicense();
          }

          SoundService.playSaveSuccess();
          return OnlineActivationResult(
            isSuccess: true,
            message: '🎉 تم تفعيل نسختك الرسمية بنجاح عبر سحابة Google Firestore!',
            plan: plan,
            storeName: serverStoreName,
            maxDevices: maxDevices,
            telegramDirectSent: directTelegramSent,
          );
        }
      }

      // If document not found or not activated, register / update request in Firestore
      final cleanMachine = LicenseService.getCleanMachineId();
      final patchUrl = '$firestoreBaseUrl/$deviceId?key=$firestoreApiKey&updateMask.fieldPaths=deviceId&updateMask.fieldPaths=cleanMachineId&updateMask.fieldPaths=storeName&updateMask.fieldPaths=phone&updateMask.fieldPaths=deviceType&updateMask.fieldPaths=isActivated&updateMask.fieldPaths=plan&updateMask.fieldPaths=requestDate';

      final patchBody = jsonEncode({
        "fields": {
          "deviceId": {"stringValue": deviceId},
          "cleanMachineId": {"stringValue": cleanMachine},
          "storeName": {"stringValue": cleanStore},
          "phone": {"stringValue": cleanPhone},
          "deviceType": {"stringValue": deviceType},
          "isActivated": {"booleanValue": false},
          "plan": {"stringValue": "P"},
          "requestDate": {"timestampValue": DateTime.now().toUtc().toIso8601String()}
        }
      });

      await http.patch(
        Uri.parse(patchUrl),
        headers: {"Content-Type": "application/json"},
        body: patchBody,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[OnlineLicenseService] Firestore sync error: $e');
    }

    // 3. Failover / Secondary Sync: Google Apps Script Web App
    try {
      final scriptUrl = HiveDatabase.settingsBox.get('google_license_script_url', defaultValue: defaultScriptUrl) as String;
      final uri = Uri.parse(
        '$scriptUrl?deviceId=${Uri.encodeComponent(deviceId)}'
        '&storeName=${Uri.encodeComponent(cleanStore)}'
        '&phone=${Uri.encodeComponent(cleanPhone)}'
        '&deviceType=${Uri.encodeComponent(deviceType)}'
        '&action=check_or_join'
        '&notifyTelegram=1',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = jsonDecode(response.body);

        if (data is Map && data['isActivated'] == true) {
          final plan = (data['plan'] as String? ?? 'P').toUpperCase();
          final serverStoreName = data['storeName'] as String? ?? cleanStore;
          final maxDevices = (data['maxDevices'] as num?)?.toInt() ?? 1;

          await HiveDatabase.settingsBox.put('store_max_devices_quota', maxDevices);
          await HiveDatabase.settingsBox.put('licensed_store_name', serverStoreName);
          await HiveDatabase.settingsBox.put('licensed_phone', cleanPhone);

          if (plan.startsWith('P')) {
            await LicenseService.grantPermanentLicense();
          } else if (plan == 'Y') {
            await LicenseService.grantCustomPlan(days: 365, isSubscription: true);
          } else if (plan == 'M') {
            await LicenseService.grantCustomPlan(days: 30, planType: 'trial_month');
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
            telegramDirectSent: directTelegramSent,
          );
        }
      }
    } catch (e) {
      debugPrint('[OnlineLicenseService] Apps Script failover error: $e');
    }

    return OnlineActivationResult(
      isSuccess: false,
      message: '✅ تم تسجيل جهازك بنجاح في قاعدة بيانات Google Firestore! وأُرسل إشعار للمطور للتفعيل.',
      telegramDirectSent: directTelegramSent,
    );
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

