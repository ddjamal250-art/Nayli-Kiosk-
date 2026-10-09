import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../data/hive_database.dart';
import 'online_license_service.dart';
import 'whatsapp_helper.dart';

class TelegramService {
  static const String defaultBotUsername = 'nayli_pos_dz_bot';

  static String getBotToken({String? customToken}) {
    if (customToken != null && customToken.trim().isNotEmpty) {
      return customToken.trim();
    }
    final savedToken = HiveDatabase.settingsBox.get('telegram_bot_token', defaultValue: '')?.toString() ?? '';
    if (savedToken.trim().isNotEmpty) {
      return savedToken.trim();
    }
    return OnlineLicenseService.defaultBotToken;
  }

  static String getChatId() {
    final chatId = HiveDatabase.settingsBox.get('telegram_chat_id', defaultValue: '')?.toString() ?? '';
    final merchantChatId = HiveDatabase.settingsBox.get('merchant_telegram_chat_id', defaultValue: '')?.toString() ?? '';
    String id = chatId.trim().isNotEmpty ? chatId.trim() : merchantChatId.trim();

    // 🛡️ صمام أمان حاسم: منع استخدام معرف المطور لحساب التاجر إطلاقاً
    final devId = OnlineLicenseService.defaultChatId;
    if (id.isEmpty || id == devId || id == '5115465267') {
      return '';
    }
    return id;
  }

  static String getWhatsAppPhone() {
    final phone = HiveDatabase.settingsBox.get('merchant_whatsapp_phone', defaultValue: '') as String;
    return phone.trim();
  }

  static Future<void> saveSettings({
    String? botToken,
    String? chatId,
    String? whatsAppPhone,
  }) async {
    final box = HiveDatabase.settingsBox;
    if (botToken != null) await box.put('telegram_bot_token', botToken.trim());
    if (chatId != null) {
      final clean = chatId.trim();
      final devId = OnlineLicenseService.defaultChatId;
      // حظر حفظ حساب المطور كحساب للتاجر
      if (clean == devId || clean == '5115465267') {
        await box.delete('telegram_chat_id');
        await box.delete('merchant_telegram_chat_id');
      } else {
        await box.put('telegram_chat_id', clean);
        await box.put('merchant_telegram_chat_id', clean);
      }
    }
    if (whatsAppPhone != null) await box.put('merchant_whatsapp_phone', whatsAppPhone.trim());
  }

  /// كشف معرف التلغرام (Chat ID) تلقائياً مع استبعاد تام لمُعرّف المطور
  static Future<Map<String, dynamic>?> autoDiscoverChatId({
    String? customToken,
    String? expectedPayload,
  }) async {
    final token = (customToken != null && customToken.trim().isNotEmpty)
        ? customToken.trim()
        : getBotToken();

    final devId = OnlineLicenseService.defaultChatId;

    try {
      final uri = Uri.parse('https://api.telegram.org/bot' + token + '/getUpdates?limit=50&offset=-20');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && data['result'] is List) {
          final List updates = data['result'];
          if (updates.isNotEmpty) {
            // أولوية أولى: البحث عن رسالة تطابق كود الربط الخاص بالجهاز (مثل /start pair_xxx)
            if (expectedPayload != null && expectedPayload.isNotEmpty) {
              for (int i = updates.length - 1; i >= 0; i--) {
                final update = updates[i];
                final message = update['message'] ?? update['channel_post'];
                if (message != null && message['chat'] != null) {
                  final text = message['text']?.toString() ?? '';
                  final chat = message['chat'] as Map<String, dynamic>;
                  final chatId = chat['id'].toString().trim();

                  // استبعاد حساب المطور نهائياً!
                  if (chatId == devId || chatId == '5115465267') continue;

                  if (text.contains(expectedPayload)) {
                    final firstName = chat['first_name'] ?? chat['title'] ?? 'مدير المحل';
                    final username = chat['username'] ?? '';

                    await saveSettings(chatId: chatId);
                    _sendPairingConfirmation(token, chatId, firstName);

                    return {
                      'chatId': chatId,
                      'name': firstName,
                      'username': username,
                    };
                  }
                }
              }
            }

            // أولوية ثانية: البحث عن آخر رسالة من أي مستخدم بشرط ألا يكون حساب المطور
            for (int i = updates.length - 1; i >= 0; i--) {
              final update = updates[i];
              final message = update['message'] ?? update['channel_post'];
              if (message != null && message['chat'] != null) {
                final chat = message['chat'] as Map<String, dynamic>;
                final chatId = chat['id'].toString().trim();

                // استبعاد حساب المطور نهائياً!
                if (chatId == devId || chatId == '5115465267') continue;

                final firstName = chat['first_name'] ?? chat['title'] ?? 'مدير المحل';
                final username = chat['username'] ?? '';

                await saveSettings(chatId: chatId);
                _sendPairingConfirmation(token, chatId, firstName);

                return {
                  'chatId': chatId,
                  'name': firstName,
                  'username': username,
                };
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Telegram auto-discovery error: ' + e.toString());
    }
    return null;
  }

  /// إرسال رسالة ترحيبية فورية إلى تلغرام التاجر لتأكيد الربط
  static void _sendPairingConfirmation(String token, String chatId, String name) {
    try {
      final uri = Uri.parse('https://api.telegram.org/bot' + token + '/sendMessage');
      http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': '🎉 <b>مرحباً $name!</b>\n\n'
              '✅ تم ربط برنامج نايل ماركت (Nayli POS) بحسابك الشخصي بنجاح!\n'
              '📦 ستصلك النسخ الاحتياطية السحابية وتقارير المبيعات اليومية هنا مباشرة.\n'
              '🔒 جميع بياناتك مشفرة ومحمية في خزنتك الخاصة.',
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// إرسال رسالة نصية تجريبية للتحقق من الاتصال
  static Future<bool> sendTextMessage({
    required String text,
    String? customToken,
    String? customChatId,
  }) async {
    final token = (customToken != null && customToken.trim().isNotEmpty)
        ? customToken.trim()
        : getBotToken();
    final chatId = (customChatId != null && customChatId.trim().isNotEmpty)
        ? customChatId.trim()
        : getChatId();

    final devId = OnlineLicenseService.defaultChatId;
    if (chatId.isEmpty || chatId == devId || chatId == '5115465267') return false;

    try {
      final uri = Uri.parse('https://api.telegram.org/bot' + token + '/sendMessage');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram sendTextMessage error: ' + e.toString());
      return false;
    }
  }

  /// فتح بوت التلغرام مباشرة في هاتف أو متصفح التاجر
  static Future<bool> launchBotChat({String? botUsername, String? pairingPayload, String? payload}) async {
    final username = botUsername ?? defaultBotUsername;
    final effectivePayload = payload ?? pairingPayload ?? 'nayli_pos_pairing';
    final url = 'https://t.me/' + username + '?start=' + effectivePayload;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// إرسال تقرير إلى رقم هاتف التاجر عبر WhatsApp مباشرة (محاولة فتح التطبيق المكتبي مباشرة)
  static Future<bool> sendWhatsAppReport({
    required String phone,
    required String message,
  }) async {
    return WhatsAppReceiptHelper.sendDirectWhatsAppMessage(
      phone: phone,
      message: message,
    );
  }
}
