import '../data/hive_database.dart';

/// خدمة إدارة صلاحيات الكاشير والتحكم الميداني الصارم
/// كافة الخيارات اختيارية 100% ويتم تفعيلها أو تعطيلها حسب رغبة المدير
class StaffPermissionsService {
  static const String _keyStrictStaff = 'pref_strict_staff_mode';
  static const String _keyHideCostProfit = 'pref_hide_cost_and_profit';
  static const String _keyPinForDiscount = 'pref_pin_for_discount';
  static const String _keyPinForVoid = 'pref_pin_for_void';
  static const String _keyPinForReports = 'pref_pin_for_reports';
  static const String _keyScaleBarcode = 'pref_enable_scale_barcode';
  static const String _keyScalePrefix = 'pref_scale_barcode_prefix';
  static const String _keyKeyboardShortcuts = 'pref_enable_fast_shortcuts';
  static const String _keyCustomerDisplay = 'pref_enable_customer_display';
  static const String _keyExpiryTracking = 'pref_enable_expiry_tracking';

  // 1. الوضع المشدد الشامل
  static bool get isStrictStaffMode =>
      HiveDatabase.settingsBox.get(_keyStrictStaff, defaultValue: false) == true;

  static Future<void> setStrictStaffMode(bool value) async {
    await HiveDatabase.settingsBox.put(_keyStrictStaff, value);
  }

  // 2. إخفاء أسعار الشراء وهوامش الربح
  static bool get hideCostAndProfit =>
      isStrictStaffMode || HiveDatabase.settingsBox.get(_keyHideCostProfit, defaultValue: false) == true;

  static Future<void> setHideCostAndProfit(bool value) async {
    await HiveDatabase.settingsBox.put(_keyHideCostProfit, value);
  }

  // 3. طلب رمز المدير عند تطبيق تخفيض
  static bool get requirePinForDiscount =>
      isStrictStaffMode || HiveDatabase.settingsBox.get(_keyPinForDiscount, defaultValue: false) == true;

  static Future<void> setRequirePinForDiscount(bool value) async {
    await HiveDatabase.settingsBox.put(_keyPinForDiscount, value);
  }

  // 4. طلب رمز المدير عند إلغاء سلعة أو تصفير السلة
  static bool get requirePinForVoid =>
      isStrictStaffMode || HiveDatabase.settingsBox.get(_keyPinForVoid, defaultValue: false) == true;

  static Future<void> setRequirePinForVoid(bool value) async {
    await HiveDatabase.settingsBox.put(_keyPinForVoid, value);
  }

  // 5. حماية التقارير المالية برمز المدير
  static bool get requirePinForReports =>
      isStrictStaffMode || HiveDatabase.settingsBox.get(_keyPinForReports, defaultValue: false) == true;

  static Future<void> setRequirePinForReports(bool value) async {
    await HiveDatabase.settingsBox.put(_keyPinForReports, value);
  }

  // 6. تفعيل باركود موازين الخضر واللحوم (EAN-13 Scale Barcode)
  static bool get enableScaleBarcode =>
      HiveDatabase.settingsBox.get(_keyScaleBarcode, defaultValue: true) == true;

  static Future<void> setEnableScaleBarcode(bool value) async {
    await HiveDatabase.settingsBox.put(_keyScaleBarcode, value);
  }

  static List<String> get scaleBarcodePrefixes {
    final raw = HiveDatabase.settingsBox.get(_keyScalePrefix, defaultValue: '20,21,22,28');
    return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Future<void> setScaleBarcodePrefixes(String prefixesCommaSeparated) async {
    await HiveDatabase.settingsBox.put(_keyScalePrefix, prefixesCommaSeparated);
  }

  // 7. اختصارات الكيبورد السريعة وشارات الأزرار
  static bool get enableFastKeyboardShortcuts =>
      HiveDatabase.settingsBox.get(_keyKeyboardShortcuts, defaultValue: true) == true;

  static Future<void> setEnableFastKeyboardShortcuts(bool value) async {
    await HiveDatabase.settingsBox.put(_keyKeyboardShortcuts, value);
  }

  // 8. شاشة الزبون الثانية (Customer Facing Display)
  static bool get enableCustomerDisplay =>
      HiveDatabase.settingsBox.get(_keyCustomerDisplay, defaultValue: false) == true;

  static Future<void> setEnableCustomerDisplay(bool value) async {
    await HiveDatabase.settingsBox.put(_keyCustomerDisplay, value);
  }

  // 9. تتبع الصلاحية وتنبيهات التيليغرام
  static bool get enableExpiryTracking =>
      HiveDatabase.settingsBox.get(_keyExpiryTracking, defaultValue: true) == true;

  static Future<void> setEnableExpiryTracking(bool value) async {
    await HiveDatabase.settingsBox.put(_keyExpiryTracking, value);
  }
}
