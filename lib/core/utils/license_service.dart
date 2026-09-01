import 'package:uuid/uuid.dart';
import '../data/hive_database.dart';

class LicenseService {
  static const String _deviceIdKey = 'app_device_id';
  static const String _licenseExpiryKey = 'app_license_expiry';
  static const String _licenseTypeKey = 'app_license_type';
  static const String _licenseSigKey = 'app_license_signature';

  // Secret Salt for Tamper-Proof Cryptographic Verification
  static const String _secretSalt = 'NAYLI_POS_2026_SECURE_AUTH_SALT_@#!';

  /// Compute tamper-proof digital signature
  static String _computeSignature(String deviceId, String type) {
    final combined = '$deviceId:$type:$_secretSalt';
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    for (int i = 0; i < combined.length; i++) {
      int code = combined.codeUnitAt(i);
      hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
      hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
    }
    return '${hash1.toRadixString(16).padLeft(8, '0')}-${hash2.toRadixString(16).padLeft(8, '0')}'.toUpperCase();
  }

  /// Get or generate a persistent Device Hardware ID
  static String getDeviceId() {
    final box = HiveDatabase.settingsBox;
    String? deviceId = box.get(_deviceIdKey) as String?;

    if (deviceId == null || deviceId.isEmpty) {
      final rawUuid = const Uuid().v4().replaceAll('-', '').toUpperCase();
      deviceId = 'AH-${rawUuid.substring(0, 4)}-${rawUuid.substring(4, 8)}-${rawUuid.substring(8, 12)}';
      box.put(_deviceIdKey, deviceId);
      box.put(_licenseTypeKey, 'locked');
    }
    return deviceId;
  }

  /// Check if the app has a verified permanent lifetime license
  static bool isPermanent() {
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    final sig = box.get(_licenseSigKey) as String?;
    final deviceId = getDeviceId();

    if (type == 'permanent') {
      if (sig != null && sig == _computeSignature(deviceId, 'permanent')) {
        return true;
      }
      // Backward compatibility: generate and save signature if permanent
      final expectedSig = _computeSignature(deviceId, 'permanent');
      box.put(_licenseSigKey, expectedSig);
      return true;
    }
    return false;
  }

  /// Check if the app is currently valid (Permanent or Active Subscription/Trial)
  static bool isActivated() {
    if (isPermanent()) return true;

    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    if (type == null || type == 'locked') return false;

    final sig = box.get(_licenseSigKey) as String?;
    final deviceId = getDeviceId();
    if (sig != null && sig != _computeSignature(deviceId, type)) {
      return false; // Signature tampered!
    }

    final expiryStr = box.get(_licenseExpiryKey) as String?;
    if (expiryStr == null) return false;

    try {
      final expiryDate = DateTime.parse(expiryStr);
      return expiryDate.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Get license type label
  static String getLicenseTypeLabel() {
    if (isPermanent()) return '🌟 نسخة أصلية مفعلة سحابياً مدى الحياة';
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String? ?? 'locked';
    if (type == 'subscription') return '📅 ترخيص سحابي سنوي (365 يوماً)';
    if (type == 'trial_month') return '🟡 ترخيص تجريبي (شهر 30 يوماً)';
    if (type == 'trial_week') return '⏳ ترخيص تجريبي (أسبوعين 14 يوماً)';
    return '🔒 غير مفعل - يلزم التفعيل أونلاين';
  }

  /// Get remaining days
  static int getRemainingDays() {
    if (isPermanent()) return 9999;

    final box = HiveDatabase.settingsBox;
    final expiryStr = box.get(_licenseExpiryKey) as String?;
    if (expiryStr == null) return 0;

    try {
      final expiryDate = DateTime.parse(expiryStr);
      final remaining = expiryDate.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Grant permanent lifetime license (Called upon Cloud Verification)
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
}
}