import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/hive_database.dart';
import '../utils/license_service.dart';
import '../../features/shop/data/models/shop_model.dart';

class CrashReport {
  final String id;
  final DateTime timestamp;
  final String errorMessage;
  final String stackTrace;
  final String contextName;
  final String machineId;
  final String storeName;
  final String appVersion;
  final bool isFatal;

  CrashReport({
    required this.id,
    required this.timestamp,
    required this.errorMessage,
    required this.stackTrace,
    required this.contextName,
    required this.machineId,
    required this.storeName,
    this.appVersion = '1.4.0',
    this.isFatal = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'errorMessage': errorMessage,
    'stackTrace': stackTrace,
    'contextName': contextName,
    'machineId': machineId,
    'storeName': storeName,
    'appVersion': appVersion,
    'isFatal': isFatal,
  };

  factory CrashReport.fromMap(Map<String, dynamic> map) => CrashReport(
    id: map['id']?.toString() ?? '',
    timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    errorMessage: map['errorMessage']?.toString() ?? '',
    stackTrace: map['stackTrace']?.toString() ?? '',
    contextName: map['contextName']?.toString() ?? '',
    machineId: map['machineId']?.toString() ?? '',
    storeName: map['storeName']?.toString() ?? '',
    appVersion: map['appVersion']?.toString() ?? '1.4.0',
    isFatal: map['isFatal'] == true,
  );

  String toFormattedTelegramMessage() {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final topStack = stackTrace.split('\n').take(5).join('\n');
    return '''⚠️ *تقرير خطأ من تطبيق نايل كشك (Nayli POS)*
───────────────────
🏢 *المتجر:* $storeName
💻 *كود الجهاز:* `$machineId`
📱 *الإصدار:* V$appVersion
⏰ *التوقيت:* $timeStr
📍 *الواجهة/السياق:* $contextName
───────────────────
❌ *الخطأ:*
`$errorMessage`

📜 *مسار التتبع (Stack):*
```
$topStack
```
───────────────────
_تم تسجيل التقرير وتأمينه تلقائياً._''';
  }
}

class CrashReportingService {
  static const String _crashesStorageKey = 'app_crash_reports_history';
  static const String _telegramBotTokenKey = 'crash_telegram_bot_token';
  static const String _telegramChatIdKey = 'crash_telegram_chat_id';

  /// Default Telegram Developer username / channel fallback
  static const String defaultDeveloperTelegram = 'MARKI_JW0';

  static String get _logFilePath {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isNotEmpty) {
        return '$userProfile\\Documents\\nayli_kiosk_data\\crash_reports.log';
      }
    } catch (_) {}
    return 'crash_reports.log';
  }

  /// Record and persist crash report
  static Future<CrashReport> recordCrash(
    dynamic error,
    StackTrace? stack, {
    String contextName = 'Global/UI',
    bool isFatal = false,
  }) async {
    final now = DateTime.now();
    final id = 'CRASH_${now.millisecondsSinceEpoch}';
    final errStr = error.toString();
    final stackStr = stack?.toString() ?? '';

    String storeName = 'متجر نايل كشك';
    try {
      final shopBox = HiveDatabase.shopBox;
      if (shopBox.isNotEmpty) {
        final ShopModel? s = shopBox.getAt(0);
        if (s != null && s.name.isNotEmpty) {
          storeName = s.name;
        }
      }
    } catch (_) {}

    String machineId = 'UNKNOWN';
    try {
      machineId = LicenseService.getCleanMachineId();
    } catch (_) {}

    final report = CrashReport(
      id: id,
      timestamp: now,
      errorMessage: errStr,
      stackTrace: stackStr,
      contextName: contextName,
      machineId: machineId,
      storeName: storeName,
      isFatal: isFatal,
    );

    // 1. Write to local persistent file
    _writeToFile(report);

    // 2. Save in Hive list (keep last 50)
    _saveToHive(report);

    // 3. Attempt silent background dispatch if configured
    _dispatchSilentTelegram(report);

    return report;
  }

  static void _writeToFile(CrashReport report) {
    try {
      final file = File(_logFilePath);
      file.parent.createSync(recursive: true);
      final logEntry = '==============================\n'
          '[${report.timestamp.toIso8601String()}] ID: ${report.id} (Fatal: ${report.isFatal})\n'
          'Store: ${report.storeName} | Machine: ${report.machineId} | Context: ${report.contextName}\n'
          'Error: ${report.errorMessage}\n'
          'Stack:\n${report.stackTrace}\n\n';
      file.writeAsStringSync(logEntry, mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to write crash to file: $e');
    }
  }

  static void _saveToHive(CrashReport report) {
    try {
      final box = HiveDatabase.settingsBox;
      final rawList = box.get(_crashesStorageKey, defaultValue: []) as List;
      final list = List<Map<String, dynamic>>.from(rawList.map((e) => Map<String, dynamic>.from(e as Map)));
      list.insert(0, report.toMap());
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      box.put(_crashesStorageKey, list);
    } catch (e) {
      debugPrint('Failed to save crash to Hive: $e');
    }
  }

  static Future<void> _dispatchSilentTelegram(CrashReport report) async {
    try {
      final box = HiveDatabase.settingsBox;
      final token = box.get(_telegramBotTokenKey) as String?;
      final chatId = box.get(_telegramChatIdKey) as String?;

      if (token != null && token.isNotEmpty && chatId != null && chatId.isNotEmpty) {
        final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': chatId,
            'text': report.toFormattedTelegramMessage(),
            'parse_mode': 'Markdown',
          }),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  /// Send crash report via 1-click Telegram to Developer
  static Future<void> openTelegramReport(CrashReport report) async {
    final text = report.toFormattedTelegramMessage();
    // Copy to clipboard first to guarantee safety
    await Clipboard.setData(ClipboardData(text: text));

    final url = Uri.parse('https://t.me/$defaultDeveloperTelegram?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Get all stored crash reports
  static List<CrashReport> getStoredReports() {
    try {
      final box = HiveDatabase.settingsBox;
      final rawList = box.get(_crashesStorageKey, defaultValue: []) as List;
      return rawList.map((e) => CrashReport.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear stored crash reports
  static Future<void> clearReports() async {
    try {
      await HiveDatabase.settingsBox.delete(_crashesStorageKey);
    } catch (_) {}
  }
}
