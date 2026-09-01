import 'package:intl/intl.dart';
import '../data/hive_database.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/product/data/models/product_model.dart';
import 'telegram_service.dart';
import 'staff_permissions_service.dart';

enum ExpiryStatus { expired, critical7Days, warning30Days, safe }

class ExpiryProductInfo {
  final Product product;
  final DateTime expiryDate;
  final int daysRemaining;
  final ExpiryStatus status;

  ExpiryProductInfo({
    required this.product,
    required this.expiryDate,
    required this.daysRemaining,
    required this.status,
  });
}

class ExpiryTrackerService {
  /// تحليل تاريخ انتهاء الصلاحية من مختلف التنسيقات (yyyy-MM-dd أو dd/MM/yyyy)
  static DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim();

    try {
      if (clean.contains('-')) {
        return DateTime.parse(clean);
      } else if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  /// استخراج كافة السلع التي لها تاريخ صلاحية مع تصنيف حالتها
  static List<ExpiryProductInfo> getExpiringProducts({List<Product>? productsList}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = <ExpiryProductInfo>[];

    final products = productsList ??
        HiveDatabase.productBox.values.map((m) => m as Product).toList();

    for (final p in products) {
      if (p.expiryDate == null || p.expiryDate!.trim().isEmpty) continue;
      final parsed = parseDate(p.expiryDate);
      if (parsed == null) continue;

      final diffDays = parsed.difference(today).inDays;
      ExpiryStatus status;
      if (diffDays <= 0) {
        status = ExpiryStatus.expired;
      } else if (diffDays <= 7) {
        status = ExpiryStatus.critical7Days;
      } else if (diffDays <= 30) {
        status = ExpiryStatus.warning30Days;
      } else {
        status = ExpiryStatus.safe;
      }

      results.add(ExpiryProductInfo(
        product: p,
        expiryDate: parsed,
        daysRemaining: diffDays,
        status: status,
      ));
    }

    // فرز الأقرب انتهاءً أولاً
    results.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return results;
  }

  /// إرسال تقرير الصلاحية والتوالف القادمة إلى التلغرام تلقائياً
  static Future<bool> sendExpiryAlertToTelegram() async {
    if (!StaffPermissionsService.enableExpiryTracking) return false;

    final items = getExpiringProducts();
    final urgent = items.where((i) => i.daysRemaining <= 15).toList();

    if (urgent.isEmpty) return false;

    final buffer = StringBuffer();
    buffer.writeln('⏳ <b>تقرير مراقبة صلاحية السلع - Nayli Market</b>');
    buffer.writeln('📅 التاريخ: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('⚠️ السلع التي تحتاج تدخلاً عاجلاً (${urgent.length} سلعة):');
    buffer.writeln('-----------------------------------');

    for (int i = 0; i < urgent.length && i < 15; i++) {
      final item = urgent[i];
      final p = item.product;
      final statusLabel = item.daysRemaining <= 0
          ? '❌ منتهية الصلاحية!'
          : '⚠️ متبقي ${item.daysRemaining} يوم';

      buffer.writeln('${i + 1}. <b>${p.name}</b>');
      buffer.writeln('   • الحالة: $statusLabel (المخزون: ${p.stock})');
      buffer.writeln('   • تاريخ النهاية: ${DateFormat('dd/MM/yyyy').format(item.expiryDate)}');
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('💡 <i>نصيحة: اعرض السلع في التخفيضات أو أعدها للموردين بـ Bon de Retour.</i>');

    return await TelegramService.sendTextMessage(text: buffer.toString());
  }
}
