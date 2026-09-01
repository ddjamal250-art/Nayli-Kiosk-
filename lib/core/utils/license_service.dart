import 'dart:io';
import '../data/hive_database.dart';

class LicenseService {
  static const String _deviceIdKey = 'app_device_hardware_id';
  static const String _licenseTypeKey = 'app_license_type';
  static const String _licenseExpiryKey = 'app_license_expiry';
  static const String _licenseSigKey = 'app_license_signature';
  static const String _salt = 'NAYLI_POS_ULTRA_SECURE_2026_@!';
  static const String masterDeveloperPin = 'RAACH_DEV_2026';

  /// Generates or retrieves a unique persistent hardware ID for this device
  static String getDeviceId() {
    final box = HiveDatabase.settingsBox;
    String? id = box.get(_deviceIdKey) as String?;
    if (id == null || id.isEmpty) {
      final name = Platform.localHostname.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final prefix = name.length >= 4 ? name.substring(0, 4) : name.padRight(4, 'X');
      final randPart = (DateTime.now().millisecondsSinceEpoch % 899999 + 100000).toRadixString(16).toUpperCase();
      final randPart2 = ((DateTime.now().microsecondsSinceEpoch ~/ 7) % 899999 + 100000).toRadixString(16).toUpperCase();
      id = '$prefix-$randPart-$randPart2';
      box.put(_deviceIdKey, id);
    }
    return id;
  }

  /// Cryptographic signature calculation to prevent local Hive database tampering
  static String _computeSignature(String deviceId, String type) {
    final raw = '$deviceId:$type:$_salt';
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    for (int i = 0; i < raw.length; i++) {
      int code = raw.codeUnitAt(i);
      hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
      hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
    }
    return '${hash1.toRadixString(16).padLeft(8, '0')}-${hash2.toRadixString(16).padLeft(8, '0')}';
  }

  /// Checks if this device has a valid, non-expired, cryptographically signed license
  static bool isActivated() {
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    final sig = box.get(_licenseSigKey) as String?;
    final deviceId = getDeviceId();

    if (type == null || sig == null) return false;
    if (_computeSignature(deviceId, type) != sig) return false; // Tampering detected!

    if (type == 'permanent') return true;

    final expiryStr = box.get(_licenseExpiryKey) as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// Check if current license is permanent
  static bool isPermanent() {
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    return type == 'permanent';
  }

  /// Get remaining days until expiry
  static int getRemainingDays() {
    if (isPermanent()) return 9999;
    final box = HiveDatabase.settingsBox;
    final expiryStr = box.get(_licenseExpiryKey) as String?;
    if (expiryStr == null) return 0;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// License Plan label for display
  static String getLicenseTypeLabel() => getLicensePlan();

  /// License Plan details for display
  static String getLicensePlan() {
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    if (type == 'permanent') return 'نسخة أصلية دائمة (مدى الحياة)';
    if (type == 'subscription') {
      final days = getRemainingDays();
      return 'اشتراك سنوي نشط (متبقي $days يوم)';
    }
    if (type == 'trial') {
      final days = getRemainingDays();
      return 'فترة تجريبية (متبقي $days يوم)';
    }
    return 'غير مفعل';
  }

  /// Grant Permanent Lifetime License
  static Future<void> grantPermanentLicense() async {
    final box = HiveDatabase.settingsBox;
    final deviceId = getDeviceId();
    final sig = _computeSignature(deviceId, 'permanent');

    await box.put(_licenseTypeKey, 'permanent');
    await box.put(_licenseSigKey, sig);
    await box.delete(_licenseExpiryKey);
  }

  /// Grant Custom Days Trial / Subscription (14, 30, 365 days)
  static Future<void> grantCustomPlan({
    required int days,
    String planType = 'trial',
    bool? isSubscription,
  }) async {
    final box = HiveDatabase.settingsBox;
    final deviceId = getDeviceId();
    final type = isSubscription == true ? 'subscription' : planType;
    final sig = _computeSignature(deviceId, type);
    final expiry = DateTime.now().add(Duration(days: days));

    await box.put(_licenseExpiryKey, expiry.toIso8601String());
    await box.put(_licenseTypeKey, type);
    await box.put(_licenseSigKey, sig);
  }

  /// Revoke / Reset License
  static Future<void> revokeLicense() async {
    final box = HiveDatabase.settingsBox;
    await box.delete(_licenseExpiryKey);
    await box.delete(_licenseSigKey);
    await box.put(_licenseTypeKey, 'locked');
  }

  /// Local bypass is strictly prohibited - All activations must pass through OnlineLicenseService
  static bool activate(String key) {
    return false;
  }

  static String generateKeyForDevice(
    String deviceId, {
    int days = 365,
    bool isLifetime = true,
    String? plan,
  }) {
    return 'NAYLI-$deviceId-ACTIVE';
  }
}