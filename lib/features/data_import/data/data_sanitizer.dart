import 'dart:convert';

/// ينظف ويعقم البيانات المستوردة لمنع الأخطاء والحروف المشوهة.
class DataSanitizer {
  /// تنظيف اسم شخص أو منتج
  static String sanitizeName(dynamic raw) {
    if (raw == null) return '';
    String text = _fixEncoding(raw.toString());
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 200) text = text.substring(0, 200);
    return text;
  }

  /// تنظيف رقم هاتف — يحتفظ بالأرقام فقط + علامة +
  static String sanitizePhone(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    // احتفظ بالأرقام و + فقط
    final cleaned = text.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return '';
    // تصحيح: إذا يبدأ بـ 213 بدون + ، نضيف 0
    if (cleaned.length == 12 && cleaned.startsWith('213')) {
      return '0${cleaned.substring(3)}';
    }
    return cleaned;
  }

  /// تنظيف عنوان
  static String sanitizeAddress(dynamic raw) {
    if (raw == null) return '';
    String text = _fixEncoding(raw.toString());
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 300) text = text.substring(0, 300);
    return text;
  }

  /// تنظيف سعر — يرجع 0.0 إذا فاسد أو سالب
  static double sanitizePrice(dynamic raw) {
    if (raw == null) return 0.0;
    try {
      final val = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
      if (val < 0) return 0.0;
      if (val > 999999999) return 0.0; // حماية من قيم خيالية
      return val;
    } catch (_) {
      return 0.0;
    }
  }

  /// تنظيف كمية
  static double sanitizeQuantity(dynamic raw) {
    if (raw == null) return 0.0;
    try {
      final val = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
      if (val < 0) return 0.0;
      return val;
    } catch (_) {
      return 0.0;
    }
  }

  /// تنظيف دين — يقبل القيم الموجبة فقط + حد أقصى 100 مليون
  static double sanitizeDebt(dynamic raw) {
    if (raw == null) return 0.0;
    try {
      final val = (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
      if (val < 0) return 0.0;
      if (val > 100000000) return 0.0; // حماية من خطأ حسابي
      return val;
    } catch (_) {
      return 0.0;
    }
  }

  /// تنظيف باركود
  static String sanitizeBarcode(dynamic raw) {
    if (raw == null) return '';
    String text = raw.toString().trim();
    text = text.replaceAll(RegExp(r'\s'), '');
    if (text.length > 50) text = text.substring(0, 50);
    return text;
  }

  /// تحليل تاريخ من عدة صيغ ممكنة
  static DateTime sanitizeDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    final text = raw.toString().trim();
    if (text.isEmpty) return DateTime.now();

    // محاولة 1: ISO 8601
    final d1 = DateTime.tryParse(text);
    if (d1 != null) return d1;

    // محاولة 2: "2025-05-23 08:34:37.367 +00:00" (صيغة Graviola)
    final d2 = DateTime.tryParse(text.replaceAll(RegExp(r'\s\+\d{2}:\d{2}$'), ''));
    if (d2 != null) return d2;

    // محاولة 3: dd/MM/yyyy
    final parts = text.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      try {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        if (day <= 31 && month <= 12) {
          return DateTime(year < 100 ? year + 2000 : year, month, day);
        }
      } catch (_) {}
    }

    return DateTime.now();
  }

  /// تنظيف حقل نصي عام (RC, NIF, AI, NIS)
  static String? sanitizeOptionalField(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  /// اكتشاف وإصلاح ترميز النص
  static String _fixEncoding(String text) {
    // كشف علامات الترميز الخاطئ
    if (text.contains('\uFFFD') || // Replacement character
        text.contains('Ø') && text.contains('§') || // Arabic as Latin-1
        text.contains('Ã') && text.contains('©')) {
      try {
        final bytes = latin1.encode(text);
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {}
    }
    return text;
  }

  /// هل الاسم صالح للاستيراد؟
  static bool isValidName(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return false;
    if (cleaned.length < 1) return false;
    // تحقق أنه ليس مجرد أرقام أو رموز
    if (RegExp(r'^[\d\s\-_.]+$').hasMatch(cleaned)) return false;
    return true;
  }
}
