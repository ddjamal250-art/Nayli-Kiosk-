import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hive_database.dart';
import 'cloud_sync_service.dart';
import '../../features/product/data/models/product_model.dart';
import '../utils/sound_service.dart';

class LocalSyncClient {
  static const String _serverIpKey = 'sync_server_ip';
  static const String _autoSyncKey = 'auto_sync_enabled';

  static bool _isConnected = false;
  static bool get isConnected => _isConnected;

  static String getServerIp() {
    try {
      return HiveDatabase.settingsBox.get(_serverIpKey, defaultValue: '') as String;
    } catch (_) {
      return '';
    }
  }

  static Future<void> setServerIp(String ip) async {
    await HiveDatabase.settingsBox.put(_serverIpKey, ip.trim());
  }

  static bool isAutoSyncEnabled() {
    try {
      return HiveDatabase.settingsBox.get(_autoSyncKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAutoSyncEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_autoSyncKey, enabled);
  }

  /// Test connection to Master Desktop POS Server
  static Future<bool> testConnection(String ipWithPort) async {
    try {
      String url = ipWithPort.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (!url.contains(':') && !url.endsWith('/')) {
        url = '$url:8080';
      }

      final uri = Uri.parse('$url/api/status');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await utf8.decoder.bind(response).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        _isConnected = (data['status'] == 'online');
        if (_isConnected) {
          await setServerIp(ipWithPort);
          await SoundService.playSaveSuccess();
        }
        return _isConnected;
      }
    } catch (e) {
      debugPrint('Sync Client connection error: $e');
    }
    _isConnected = false;
    return false;
  }

  /// Pull latest products from Master Desktop Server to Mobile
  static Future<int> pullProductsFromMaster() async {
    final serverIp = getServerIp();
    if (serverIp.isEmpty) return 0;

    try {
      String url = serverIp;
      if (!url.startsWith('http://')) url = 'http://$url';
      if (!url.contains(':8080') && !url.contains(':')) url = '$url:8080';

      final uri = Uri.parse('$url/api/products');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await utf8.decoder.bind(response).join();
        final List list = jsonDecode(body) as List;

        int updatedCount = 0;
    if (serverIp.isNotEmpty) {
      try {
        String url = serverIp;
        if (!url.startsWith('http://')) url = 'http://$url';
        if (!url.contains(':8080') && !url.contains(':')) url = '$url:8080';

        final uri = Uri.parse('$url/api/products');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 6);

        final request = await client.getUrl(uri);
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await utf8.decoder.bind(response).join();
          final List list = jsonDecode(body) as List;

          int updatedCount = 0;
          for (var item in list) {
            final p = ProductModel.fromJson(item as Map<String, dynamic>);
            await HiveDatabase.productBox.put(p.barcode, p);
            updatedCount++;
          }
          await SoundService.playRestockSound();
          return updatedCount;
        }
      } catch (e) {
        debugPrint('Error pulling products from master LAN: $e');
      }
    }

    // Cloud Fallback: Pull from isolated merchant cloud channel
    return await CloudSyncService.pullProductsFromCloud();
  }

  /// Push a completed mobile sale to Master Desktop Server (with Cloud Fallback)
  static Future<bool> pushSaleToMaster(Map<String, dynamic> saleData) async {
    final serverIp = getServerIp();
    if (serverIp.isNotEmpty) {
      try {
        String url = serverIp;
        if (!url.startsWith('http://')) url = 'http://$url';
        if (!url.contains(':8080') && !url.contains(':')) url = '$url:8080';

        final uri = Uri.parse('$url/api/sales');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);

        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(saleData));

        final response = await request.close();
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint('LAN push sale failed, attempting Cloud fallback: $e');
      }
    }

    // Cloud Fallback: If phone is outside shop (on 4G) or LAN is blocked, push via Cloud!
    return await CloudSyncService.pushSaleToCloud(saleData);
  }
}
