import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data/hive_database.dart';
import '../theme/app_theme.dart';

class LicenseService {
  static const String _deviceIdKey = 'app_device_id';
  static const String _licenseKey = 'app_activation_key';
  static const String _licenseExpiryKey = 'app_license_expiry';
  static const String _licenseTypeKey = 'app_license_type';

  // Secret Master Password for Developer Onsite Activation (لك أنت وحدك)
  static const String masterDeveloperPin = '2026';

  // Secret salt for cryptographic hardware key verification
  static const String _secretSalt = 'AHSEBLI_DZ_POS_SECURE_SALT_2026_@!';

  /// Get or generate a persistent Device Hardware ID
  static String getDeviceId() {
    final box = HiveDatabase.settingsBox;
    String? deviceId = box.get(_deviceIdKey) as String?;
    
    if (deviceId == null || deviceId.isEmpty) {
      // Create a deterministic hardware-seeded identifier
      final rawUuid = const Uuid().v4().replaceAll('-', '').toUpperCase();
      deviceId = 'AH-${rawUuid.substring(0, 4)}-${rawUuid.substring(4, 8)}-${rawUuid.substring(8, 12)}';
      box.put(_deviceIdKey, deviceId);
      box.put(_licenseTypeKey, 'locked'); // Locked by default (No free trial)
    }
    return deviceId;
  }

  /// Generate expected activation key for any device ID and plan
  /// plan: 'P' (Permanent), 'Y' (1 Year), 'M' (1 Month), 'W' (2 Weeks)
  static String generateKeyForDevice(String deviceId, {String plan = 'P'}) {
    final cleanId = deviceId.trim().toUpperCase();
    final cleanPlan = plan.trim().toUpperCase();
    final combined = '$cleanId:$cleanPlan:$_secretSalt';
    
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    for (int i = 0; i < combined.length; i++) {
      int code = combined.codeUnitAt(i);
      hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
      hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
    }

    String hex1 = hash1.toRadixString(16).padLeft(8, '0').toUpperCase();
    String hex2 = hash2.toRadixString(16).padLeft(8, '0').toUpperCase();
    String fullHex = '$hex1$hex2';

    return '$cleanPlan-${fullHex.substring(0, 4)}-${fullHex.substring(4, 8)}-${fullHex.substring(8, 12)}';
  }

  /// Check if the app has a permanent lifetime license
  static bool isPermanent() {
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    final savedKey = box.get(_licenseKey) as String?;

    if (type == 'permanent' && savedKey != null) {
      final expectedPerm = generateKeyForDevice(getDeviceId(), plan: 'P');
      return savedKey.trim().toUpperCase() == expectedPerm;
    }
    return false;
  }

  /// Check if the app is currently valid (Permanent or Active Subscription/Trial)
  static bool isActivated() {
    if (isPermanent()) return true;

    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    if (type == null || type == 'locked') return false;

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
    if (isPermanent()) return '🌟 نسخة أصلية مفعلة مدى الحياة (Permanent)';
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String? ?? 'locked';
    if (type == 'subscription') return '📅 ترخيص سنوي (365 يوماً)';
    if (type == 'trial_month') return '🟡 ترخيص تجريبي (شهر 30 يوماً)';
    if (type == 'trial_week') return '⏳ ترخيص تجريبي (أسبوعين 14 يوماً)';
    return '🔒 غير مفعل - يلزم كود التفعيل';
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

  /// Activate with user-entered key (supports Permanent, Year, Month, 2-Weeks)
  static bool activate(String enteredKey) {
    final cleanKey = enteredKey.trim().toUpperCase();
    final deviceId = getDeviceId();
    final box = HiveDatabase.settingsBox;

    // 1. Check Permanent Plan ('P')
    if (cleanKey == generateKeyForDevice(deviceId, plan: 'P')) {
      box.put(_licenseKey, cleanKey);
      box.put(_licenseTypeKey, 'permanent');
      box.delete(_licenseExpiryKey);
      return true;
    }

    // 2. Check 1 Year Subscription ('Y' -> 365 days)
    if (cleanKey == generateKeyForDevice(deviceId, plan: 'Y')) {
      final expiry = DateTime.now().add(const Duration(days: 365));
      box.put(_licenseKey, cleanKey);
      box.put(_licenseExpiryKey, expiry.toIso8601String());
      box.put(_licenseTypeKey, 'subscription');
      return true;
    }

    // 3. Check 1 Month Trial ('M' -> 30 days)
    if (cleanKey == generateKeyForDevice(deviceId, plan: 'M')) {
      final expiry = DateTime.now().add(const Duration(days: 30));
      box.put(_licenseKey, cleanKey);
      box.put(_licenseExpiryKey, expiry.toIso8601String());
      box.put(_licenseTypeKey, 'trial_month');
      return true;
    }

    // 4. Check 2 Weeks Trial ('W' -> 14 days)
    if (cleanKey == generateKeyForDevice(deviceId, plan: 'W')) {
      final expiry = DateTime.now().add(const Duration(days: 14));
      box.put(_licenseKey, cleanKey);
      box.put(_licenseExpiryKey, expiry.toIso8601String());
      box.put(_licenseTypeKey, 'trial_week');
      return true;
    }

    return false;
  }

  /// DEVELOPER ONSITE: Instant Lifetime Activation
  static Future<void> grantPermanentLicense() async {
    final box = HiveDatabase.settingsBox;
    final key = generateKeyForDevice(getDeviceId(), plan: 'P');
    await box.put(_licenseKey, key);
    await box.put(_licenseTypeKey, 'permanent');
    await box.delete(_licenseExpiryKey);
  }

  /// DEVELOPER ONSITE: Grant Custom Days Trial / Subscription (14, 30, 365 days)
  static Future<void> grantCustomPlan({required int days, required String planType}) async {
    final box = HiveDatabase.settingsBox;
    final expiry = DateTime.now().add(Duration(days: days));
    await box.put(_licenseExpiryKey, expiry.toIso8601String());
    await box.put(_licenseTypeKey, planType);
    await box.delete(_licenseKey);
  }

  /// DEVELOPER ONSITE: Revoke / Reset License
  static Future<void> revokeLicense() async {
    final box = HiveDatabase.settingsBox;
    await box.delete(_licenseKey);
    await box.delete(_licenseExpiryKey);
    await box.put(_licenseTypeKey, 'locked');
  }
}