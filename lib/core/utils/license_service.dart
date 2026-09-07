import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/hive_database.dart';

class LicenseService {
  static const String _deviceIdKey = 'app_device_hardware_id';
  static const String _licenseTypeKey = 'app_license_type';
  static const String _licenseExpiryKey = 'app_license_expiry';
  static const String _licenseSigKey = 'app_license_signature';
  static String get _salt {
    const List<int> _o = [100, 107, 115, 102, 107, 117, 106, 101, 121, 117, 127, 102, 126, 120, 107, 117, 121, 99, 105, 127, 120, 99, 117, 24, 26, 24, 16, 117, 106, 9];
    return String.fromCharCodes(_o.map((e) => e ^ 42));
  }

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

    // Permanent cloud license or Companion terminal license linked to Master PC
    if (type == 'permanent' || type == 'companion') return true;

    final expiryStr = box.get(_licenseExpiryKey) as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;

    return DateTime.now().isBefore(expiry);
  }

  /// Check if current license is permanent
  static bool isPermanent() {
    if (!isActivated()) return false;
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    return type == 'permanent';
  }

  /// Check if current license is a companion terminal of a Master POS
  static bool isCompanion() {
    if (!isActivated()) return false;
    final box = HiveDatabase.settingsBox;
    final type = box.get(_licenseTypeKey) as String?;
    return type == 'companion';
  }

  /// Get remaining days until expiry
  static int getRemainingDays() {
    if (isPermanent() || isCompanion()) return 9999;
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
    if (type == 'companion') {
      final store = box.get('licensed_store_name', defaultValue: 'المتجر الرئيسي') as String;
      return 'مرخص كجهاز ملحق بمتجر: $store 📲';
    }
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

  /// Grant Companion License when paired with an Activated Master Desktop POS
  static Future<void> grantCompanionLicense({
    required String storeName,
    required String masterIp,
  }) async {
    final box = HiveDatabase.settingsBox;
    final deviceId = getDeviceId();
    final sig = _computeSignature(deviceId, 'companion');

    await box.put(_licenseTypeKey, 'companion');
    await box.put(_licenseSigKey, sig);
    await box.put('master_pos_ip', masterIp.trim());
    await box.put('sync_server_ip', masterIp.trim());
    await box.put('licensed_store_name', storeName.trim());
    await box.put('shop_name', storeName.trim());
    await box.delete(_licenseExpiryKey);
  }

  /// Grant Permanent Lifetime License via verified OnlineLicenseService
  static Future<void> grantPermanentLicense() async {
    final box = HiveDatabase.settingsBox;
    final deviceId = getDeviceId();
    final sig = _computeSignature(deviceId, 'permanent');

    await box.put(_licenseTypeKey, 'permanent');
    await box.put(_licenseSigKey, sig);
    await box.delete(_licenseExpiryKey);
  }

  /// Grant Custom Days Trial / Subscription via verified OnlineLicenseService
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

  /// Generates a signed, time-limited (15 mins) barcode token to activate a desktop PC via barcode douchette
  static Map<String, dynamic> generateDouchetteActivationData() {
    final box = HiveDatabase.settingsBox;
    final storeName = box.get('licensed_store_name', defaultValue: box.get('shop_name', defaultValue: 'Nayli Kiosk')) as String;
    final phoneId = getDeviceId();
    final plan = box.get(_licenseTypeKey, defaultValue: 'permanent') as String;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // 15 minutes expiry to prevent replay attacks
    final expiryTimestamp = timestamp + (15 * 60 * 1000);

    // Compute signature for this activation payload
    final raw = '$storeName:$phoneId:$plan:$expiryTimestamp:$_salt';
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    for (int i = 0; i < raw.length; i++) {
      int code = raw.codeUnitAt(i);
      hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
      hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
    }
    final sig = '${hash1.toRadixString(16).padLeft(8, '0')}-${hash2.toRadixString(16).padLeft(8, '0')}';

    // 6-digit short fallback PIN
    final pinSeed = ((hash1 ^ hash2).abs() % 900000 + 100000).toString();
    final shortPin = 'NY-$pinSeed';

    final payloadMap = {
      'app': 'nayli_act',
      'store': storeName,
      'phoneId': phoneId,
      'plan': plan,
      'exp': expiryTimestamp,
      'pin': shortPin,
      'sig': sig,
    };

    final barcodeString = 'NAYLI_ACT:${base64Url.encode(utf8.encode(jsonEncode(payloadMap)))}';

    return {
      'barcode': barcodeString,
      'shortPin': shortPin,
      'storeName': storeName,
      'expiry': expiryTimestamp,
    };
  }

  /// Verifies a scanned douchette barcode or manual PIN and activates this device
  static Future<Map<String, dynamic>> verifyAndApplyDouchetteToken(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return {'success': false, 'message': 'الرمز فارغ'};
    }

    try {
      Map<String, dynamic>? data;

      if (input.startsWith('NAYLI_ACT:')) {
        final b64 = input.substring('NAYLI_ACT:'.length);
        final jsonStr = utf8.decode(base64Url.decode(b64));
        data = jsonDecode(jsonStr) as Map<String, dynamic>;
      } else if (input.startsWith('{' /*}*/) && input.endsWith('}')) {
        data = jsonDecode(input) as Map<String, dynamic>;
      }

      if (data != null) {
        final storeName = data['store']?.toString() ?? 'Nayli Kiosk';
        final phoneId = data['phoneId']?.toString() ?? '';
        final plan = data['plan']?.toString() ?? 'permanent';
        final exp = (data['exp'] as num?)?.toInt() ?? 0;
        final sig = data['sig']?.toString() ?? '';

        // 1. Check expiration (within 15 minutes)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now > exp) {
          return {
            'success': false,
            'message': '❌ انتهت صلاحية هذا الرمز (أكثر من 15 دقيقة). يرجى فتح الشاشة من الهاتف وتوليد رمز حديث.',
          };
        }

        // 2. Verify cryptographic signature
        final raw = '$storeName:$phoneId:$plan:$exp:$_salt';
        int hash1 = 0x811c9dc5;
        int hash2 = 0x55555555;
        for (int i = 0; i < raw.length; i++) {
          int code = raw.codeUnitAt(i);
          hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
          hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
        }
        final expectedSig = '${hash1.toRadixString(16).padLeft(8, '0')}-${hash2.toRadixString(16).padLeft(8, '0')}';

        if (sig != expectedSig) {
          return {
            'success': false,
            'message': '❌ رمز التفعيل غير صالح أو تم التلاعب به!',
          };
        }

        // 3. Grant Permanent License to this Desktop PC!
        await grantPermanentLicense();
        await HiveDatabase.settingsBox.put('licensed_store_name', storeName);
        await HiveDatabase.settingsBox.put('shop_name', storeName);

        return {
          'success': true,
          'message': '🎉 تم تفعيل هذا الحاسوب بنجاح عبر قارئ الباركود! مرحباً بك في $storeName',
          'storeName': storeName,
        };
      }

      // Check if it matches a 19-character encrypted offline key
      final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (clean.length == 19 && clean.startsWith('NK')) {
        return await verifyAndApplyOfflineKey(clean);
      }

      return {'success': false, 'message': '❌ صيغة الكود غير معترف بها. يرجى إدخال مفتاح ترخيص صالح أو مسح رمز التفعيل.'};
    } catch (e) {
      return {'success': false, 'message': '❌ خطأ أثناء معالجة الرمز: $e'};
    }
  }

  /// Generates a clean 12-character alphanumeric hardware code (no spaces, no dashes) for offline activation
  static String getCleanMachineId() {
    final raw = getDeviceId().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.length >= 12) {
      return raw.substring(0, 12);
    }
    return raw.padRight(12, '0');
  }

  /// Cryptographic signature for offline alphanumeric activation key using HMAC-SHA256
  static String _computeOfflineSignature(String cleanMachineId, String planCode) {
    final key = utf8.encode(_salt);
    final bytes = utf8.encode('$cleanMachineId:$planCode:NAYLI_OFFLINE_SECRET_2026');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString().toUpperCase().substring(0, 16);
  }

  /// Generates a valid 19-character alphanumeric offline activation key (no dashes, no spaces)
  static String generateOfflineKey(String cleanMachineId, {String plan = 'P'}) {
    final cleanId = cleanMachineId.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final effectiveId = cleanId.length >= 12 ? cleanId.substring(0, 12) : cleanId.padRight(12, '0');
    final p = plan.trim().toUpperCase();
    final planCode = (p == 'Y' || p == 'S' || p == 'M') ? p : 'P';
    final sig = _computeOfflineSignature(effectiveId, planCode);
    return 'NK$planCode$sig';
  }

  /// Verifies a 19-character alphanumeric offline key and activates this device immediately
  static Future<Map<String, dynamic>> verifyAndApplyOfflineKey(String rawKey, {String? storeName}) async {
    final key = rawKey.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (key.length != 19 || !key.startsWith('NK')) {
      return {
        'success': false,
        'message': '❌ صيغة المفتاح غير صحيحة. يجب أن يتكون من 19 حرف ورقم يبدأ بـ NK.',
      };
    }

    final planCode = key[2];
    if (planCode != 'P' && planCode != 'Y' && planCode != 'S' && planCode != 'M') {
      return {
        'success': false,
        'message': '❌ نوع الباقة في المفتاح غير معترف به.',
      };
    }

    final signature = key.substring(3);
    final myMachineId = getCleanMachineId();
    final expectedSig = _computeOfflineSignature(myMachineId, planCode);

    if (signature != expectedSig) {
      return {
        'success': false,
        'message': '❌ مفتاح التفعيل غير مطابق لهذا الجهاز أو غير صالح!',
      };
    }

    // Apply the plan
    String planLabel = 'دائم مدى الحياة';
    if (planCode == 'P') {
      await grantPermanentLicense();
      planLabel = 'نسخة أصلية دائمة مدى الحياة 👑';
    } else if (planCode == 'Y') {
      await grantCustomPlan(days: 365, isSubscription: true);
      planLabel = 'اشتراك سنوي (365 يوم) 📅';
    } else if (planCode == 'S') {
      await grantCustomPlan(days: 180, isSubscription: true);
      planLabel = 'اشتراك 6 أشهر (180 يوم) ⏳';
    } else if (planCode == 'M') {
      await grantCustomPlan(days: 30, planType: 'trial_month');
      planLabel = 'فترة شهر تجريبي (30 يوم) ⏱️';
    }

    if (storeName != null && storeName.trim().isNotEmpty) {
      await HiveDatabase.settingsBox.put('licensed_store_name', storeName.trim());
      await HiveDatabase.settingsBox.put('shop_name', storeName.trim());
    }

    return {
      'success': true,
      'message': '🎉 تم تفعيل البرنامج بنجاح بدون إنترنت!\nنوع الترخيص: $planLabel',
      'plan': planCode,
      'planLabel': planLabel,
    };
  }

  /// Local bypass is strictly disabled - all activations must pass through cloud or Master pairing
  static bool activate(String key) {
    return false;
  }
}