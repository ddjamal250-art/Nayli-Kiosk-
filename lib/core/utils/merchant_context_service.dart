import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'hive_database.dart';
import 'license_service.dart';

class MerchantContextService {
  static const String _merchantIdKey = 'merchant_tenant_id';
  static const String _storeNameKey = 'licensed_store_name';

  /// Returns or generates a unique, isolated Merchant Tenant ID for this shop
  static String getMerchantId() {
    try {
      final box = HiveDatabase.settingsBox;
      String? tenantId = box.get(_merchantIdKey) as String?;
      
      if (tenantId == null || tenantId.trim().isEmpty) {
        final deviceId = LicenseService.getDeviceId();
        // Generate a clean, unique hash-based Tenant Key
        int hash = 0x811c9dc5;
        for (int i = 0; i < deviceId.length; i++) {
          hash = ((hash ^ deviceId.codeUnitAt(i)) * 0x01000193) & 0xFFFFFFFF;
        }
        final hexHash = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
        tenantId = 'SHOP-$hexHash';
        box.put(_merchantIdKey, tenantId);
      }
      return tenantId;
    } catch (e) {
      debugPrint('Error getting merchant ID: $e');
      return 'SHOP-DEFAULT';
    }
  }

  /// Sets the Merchant Tenant ID when pairing a companion phone to a master PC
  static Future<void> setMerchantId(String id) async {
    if (id.trim().isNotEmpty) {
      await HiveDatabase.settingsBox.put(_merchantIdKey, id.trim().toUpperCase());
    }
  }

  /// Returns the configured store name or default
  static String getStoreName() {
    try {
      final box = HiveDatabase.settingsBox;
      final name = box.get('shop_name', defaultValue: '') as String;
      if (name.trim().isNotEmpty) return name.trim();
      return box.get(_storeNameKey, defaultValue: 'نايلي كيوسك POS') as String;
    } catch (_) {
      return 'نايلي كيوسك POS';
    }
  }

  /// Returns payload formatted for QR Code pairing
  static Map<String, dynamic> generatePairingPayload({
    required String localIp,
    int port = 8080,
  }) {
    return {
      'v': 2,
      'merchantId': getMerchantId(),
      'deviceId': LicenseService.getDeviceId(),
      'name': getStoreName(),
      'ip': localIp,
      'port': port,
      'isActivated': LicenseService.isActivated(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
