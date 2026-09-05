import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../data/hive_database.dart';
import 'online_license_service.dart';
import 'whatsapp_helper.dart';

class TelegramService {
  static const String defaultBotUsername = 'nayli_pos_dz_bot';

  static String getBotToken() {
    final customToken = HiveDatabase.settingsBox.get('telegram_bot_token', defaultValue: '') as String;
    if (customToken.trim().isNotEmpty) {
      return customToken.trim();
    }
    return OnlineLicenseService.defaultBotToken;
  }

  static String getChatId() {
    final chatId = HiveDatabase.settingsBox.get('telegram_chat_id', defaultValue: '') as String;
    return chatId.trim();
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
    if (chatId != null) await box.put('telegram_chat_id', chatId.trim());
    if (whatsAppPhone != null) await box.put('merchant_whatsapp_phone', whatsAppPhone.trim());
  }

  /// كشف معرف التلغرام (Chat ID) تلقائياً عبر استعلام آخر رسالة أرسلها التاجر للبوت
  static Future<Map<String, dynamic>?> autoDiscoverChatId({String? customToken}) async {
    final token = (customToken != null && customToken.trim().isNotEmpty)
        ? customToken.trim()
        : getBotToken();

    try {
      final uri = Uri.parse('https://api.telegram.org/bot' + token + '/getUpdates?limit=10&offset=-10');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['ok'] == true && data['result'] is List) {
          final List updates = data['result'];
          if (updates.isNotEmpty) {
            for (int i = updates.length - 1; i >= 0; i--) {
              final update = updates[i];
              final message = update['message'] ?? update['channel_post'];
              if (message != null && message['chat'] != null) {
                final chat = message['chat'] as Map<String, dynamic>;
                final chatId = chat['id'].toString();
                final firstName = chat['first_name'] ?? chat['title'] ?? 'مدير المحل';
                final username = chat['username'] ?? '';

                await HiveDatabase.settingsBox.put('telegram_chat_id', chatId);

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

    if (chatId.isEmpty) return false;

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
  static Future<bool> launchBotChat({String? botUsername}) async {
    final username = botUsername ?? defaultBotUsername;
    final url = 'https://t.me/' + username + '?start=nayli_pos_pairing';
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
