import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/hive_database.dart';
import 'telegram_service.dart';

class AuditLogEntry {
  final String id;
  final String action; // 'void_invoice', 'large_discount', 'manual_drawer_kick', 'supervisor_call', 'price_override', 'supervisor_override'
  final String station; // e.g. 'كاشير 01'
  final String staffName;
  final double amount;
  final String details;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.station,
    required this.staffName,
    this.amount = 0.0,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action,
        'station': station,
        'staffName': staffName,
        'amount': amount,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditLogEntry.fromMap(Map<dynamic, dynamic> map) => AuditLogEntry(
        id: map['id']?.toString() ?? '',
        action: map['action']?.toString() ?? 'unknown',
        station: map['station']?.toString() ?? 'كاشير',
        staffName: map['staffName']?.toString() ?? 'العامل',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        details: map['details']?.toString() ?? '',
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AuditLogService {
  static const String _boxKey = 'security_audit_logs';

  /// Log a security event and optionally notify Telegram
  static Future<void> logEvent({
    required String action,
    required String station,
    required String staffName,
    double amount = 0.0,
    required String details,
    bool notifyTelegram = true,
  }) async {
    try {
      final entry = AuditLogEntry(
        id: 'audit_',
        action: action,
        station: station,
        staffName: staffName,
        amount: amount,
        details: details,
      );

      final box = HiveDatabase.settingsBox;
      final rawList = box.get(_boxKey, defaultValue: []) as List;
      final logs = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      logs.insert(0, entry.toMap());

      // Keep up to 200 recent entries to avoid bloat
      if (logs.length > 200) {
        logs.removeRange(200, logs.length);
      }
      await box.put(_boxKey, logs);

      // Instant Telegram Alert for High-Risk Actions
      if (notifyTelegram) {
        final botToken = TelegramService.getBotToken();
        final chatId = TelegramService.getChatId();
        if (botToken.isNotEmpty && chatId.isNotEmpty) {
          String icon = '⚠️';
          String actionAr = action;
          if (action == 'void_invoice') {
            icon = '🚨';
            actionAr = 'إلغاء فاتورة / سلة مبيعات';
          } else if (action == 'supervisor_call') {
            icon = '🔔';
            actionAr = 'نداء المشرف العام';
          } else if (action == 'large_discount') {
            icon = '🏷️';
            actionAr = 'تخفيض استثنائي';
          } else if (action == 'manual_drawer_kick') {
            icon = '💵';
            actionAr = 'فتح الدرج يدوياً بدون بيع';
          }

          final amountStr = amount > 0 ? ' د.ج' : 'غير محدد';
          final timeStr = DateFormat('HH:mm - yyyy/MM/dd').format(entry.timestamp);

          final msg = ' <b>تنبيه أمني فوري في المتجر (Nayli Audit)</b>\n'
              '━━━━━━━━━━━━━━━━━\n'
              '🏬 <b>الجهاز:</b> \n'
              '👤 <b>الموظف:</b> \n'
              '⚡ <b>العملية:</b> \n'
              '💰 <b>المبلغ المعني:</b> \n'
              '📝 <b>التفاصيل:</b> \n'
              '⏰ <b>الوقت:</b> \n'
              '━━━━━━━━━━━━━━━━━';

          TelegramService.sendTextMessage(
            customToken: botToken,
            customChatId: chatId,
            text: msg,
          );
        }
      }
    } catch (e) {
      debugPrint('AuditLogService error: ');
    }
  }

  /// Retrieve recent security logs
  static List<AuditLogEntry> getRecentLogs() {
    try {
      final box = HiveDatabase.settingsBox;
      final rawList = box.get(_boxKey, defaultValue: []) as List;
      return rawList.map((e) => AuditLogEntry.fromMap(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
