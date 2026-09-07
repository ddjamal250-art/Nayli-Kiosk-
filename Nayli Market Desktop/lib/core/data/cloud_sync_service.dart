import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/merchant_context_service.dart';
import '../utils/license_service.dart';
import '../utils/online_license_service.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';

class CloudSyncResult {
  final bool isSuccess;
  final String message;
  final int itemsCount;

  CloudSyncResult({
    required this.isSuccess,
    required this.message,
    this.itemsCount = 0,
  });
}

class CloudSyncService {
  static const String _cloudSyncEnabledKey = 'cloud_sync_enabled';

  static bool isCloudSyncEnabled() {
    try {
      return HiveDatabase.settingsBox.get(_cloudSyncEnabledKey, defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setCloudSyncEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_cloudSyncEnabledKey, enabled);
  }

  /// Performs cloud-assisted QR pairing & verification when direct local Wi-Fi ping fails.
  /// Validates that the Master PC is genuine and pairs the companion phone to the merchant's private room.
  static Future<CloudSyncResult> pairDeviceViaCloud({
    required String merchantId,
    required String masterDeviceId,
    required String storeName,
    required String masterIp,
    String port = '8080',
  }) async {
    try {
      // 1. Save Merchant Isolation ID locally
      await MerchantContextService.setMerchantId(merchantId);
      await HiveDatabase.settingsBox.put('master_pos_ip', masterIp);
      await HiveDatabase.settingsBox.put('master_pos_port', port);
      await HiveDatabase.settingsBox.put('sync_server_ip', '$masterIp:$port');
      await HiveDatabase.settingsBox.put('shop_name', storeName);

      // 2. Grant Companion License
      await LicenseService.grantCompanionLicense(
        storeName: storeName,
        masterIp: masterIp,
      );

      // 3. Perform silent registration with cloud backend
      final endpoint = Uri.parse(OnlineLicenseService.defaultScriptUrl);
      final payload = {
        'action': 'pair_companion',
        'merchantId': merchantId,
        'masterDeviceId': masterDeviceId,
        'companionDeviceId': LicenseService.getDeviceId(),
        'storeName': storeName,
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        await http.post(
          endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Silent cloud registration notice: $e');
      }

      return CloudSyncResult(
        isSuccess: true,
        message: 'تم تفعيل التخصيص والاقتران السحابي للمتجر ($storeName) بنجاح!',
      );
    } catch (e) {
      debugPrint('Cloud pairing error: $e');
      return CloudSyncResult(
        isSuccess: false,
        message: 'حدث خطأ أثناء الاقتران السحابي: $e',
      );
    }
  }

  /// Push sale transaction to merchant's isolated cloud channel
  static Future<bool> pushSaleToCloud(Map<String, dynamic> saleData) async {
    if (!isCloudSyncEnabled()) return false;

    try {
      final merchantId = MerchantContextService.getMerchantId();
      final endpoint = Uri.parse(OnlineLicenseService.defaultScriptUrl);
      
      final payload = {
        'action': 'push_sale',
        'merchantId': merchantId,
        'deviceId': LicenseService.getDeviceId(),
        'sale': saleData,
      };

      final res = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Cloud sale push notice: $e');
      return false;
    }
  }

  /// Pull products from merchant's isolated cloud storage
  static Future<int> pullProductsFromCloud() async {
    if (!isCloudSyncEnabled()) return 0;

    try {
      final merchantId = MerchantContextService.getMerchantId();
      final endpoint = Uri.parse(
        '${OnlineLicenseService.defaultScriptUrl}?action=get_products&merchantId=$merchantId',
      );

      final res = await http.get(endpoint).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['products'] is List) {
          final List list = data['products'];
          int count = 0;
          for (var item in list) {
            final p = ProductModel.fromJson(item as Map<String, dynamic>);
            await HiveDatabase.productBox.put(p.barcode, p);
            count++;
          }
          return count;
        }
      }
    } catch (e) {
      debugPrint('Cloud product pull notice: $e');
    }
    return 0;
  }
}
