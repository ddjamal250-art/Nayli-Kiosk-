import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Standard Event Channels for Nayli Market Sync Protocol
class SyncEvents {
  // Authentication & Handshake
  static const String auth = 'auth';
  static const String ping = 'ping';
  static const String pong = 'pong';

  // Remote Barcode Scanner (Douchette Sans Fil)
  static const String scanBarcode = 'scan-barcode';

  // Catalog & Products
  static const String loadCatalog = 'load-catalog';
  static const String inventoryChange = 'inventory-change';
  static const String productUpdated = 'product-updated';

  // Sales & Carts
  static const String handoffCart = 'handoff-cart';
  static const String pushSale = 'push-sale';
  static const String saleCreated = 'sale-created';

  // Images
  static const String getImage = 'get-image';

  // Customer Display & Kiosk
  static const String customerDisplayUpdate = 'customer-display-update';
}

/// Message types matching the event architecture:
/// req   -> Request from Client to Server
/// res   -> Direct Response from Server to the Requesting Client
/// upRes -> Broadcast Update from Server to ALL Connected Clients
enum SyncMessageType { req, res, upRes }

/// Unified envelope for all WebSocket messages across LAN and WAN
class SyncMessage {
  final String id;
  final SyncMessageType type;
  final String event;
  final String merchantId;
  final String? token;
  final dynamic payload;
  final bool compressed;
  final int timestamp;

  SyncMessage({
    required this.id,
    required this.type,
    required this.event,
    required this.merchantId,
    this.token,
    this.payload,
    this.compressed = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'event': event,
    'merchantId': merchantId,
    if (token != null) 'token': token,
    'payload': payload,
    'compressed': compressed,
    'ts': timestamp,
  };

  String toJson() => jsonEncode(toMap());

  factory SyncMessage.fromMap(Map<String, dynamic> map) {
    SyncMessageType parsedType = SyncMessageType.req;
    final tStr = map['type']?.toString();
    if (tStr == 'res') {
      parsedType = SyncMessageType.res;
    } else if (tStr == 'upRes' || tStr == 'up-res') {
      parsedType = SyncMessageType.upRes;
    }

    return SyncMessage(
      id: map['id']?.toString() ?? '${DateTime.now().microsecondsSinceEpoch}',
      type: parsedType,
      event: map['event']?.toString() ?? '',
      merchantId: map['merchantId']?.toString() ?? '',
      token: map['token']?.toString(),
      payload: map['payload'],
      compressed: map['compressed'] == true,
      timestamp: (map['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory SyncMessage.fromJson(String jsonStr) {
    return SyncMessage.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}

/// Helper for Gzip Compression & Decompression of payloads (e.g. large product lists, images)
class SyncCompressionHelper {
  /// Compresses a string or JSON map into Base64-encoded Gzip bytes
  static String compressJson(dynamic data) {
    try {
      final jsonString = data is String ? data : jsonEncode(data);
      final rawBytes = utf8.encode(jsonString);
      final compressedBytes = gzip.encode(rawBytes);
      return base64Encode(compressedBytes);
    } catch (e) {
      debugPrint('Compression error: $e');
      return data is String ? data : jsonEncode(data);
    }
  }

  /// Decompresses a Base64-encoded Gzip string back into raw decoded object
  static dynamic decompressJson(String base64String) {
    try {
      final compressedBytes = base64Decode(base64String);
      final decompressedBytes = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressedBytes);
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint('Decompression error: $e');
      return null;
    }
  }

  /// Compresses raw image bytes to Base64 Gzip
  static String compressImageBytes(Uint8List bytes) {
    final compressedBytes = gzip.encode(bytes);
    return base64Encode(compressedBytes);
  }

  /// Decompresses Base64 Gzip back to raw image bytes
  static Uint8List decompressImageBytes(String base64String) {
    final compressedBytes = base64Decode(base64String);
    final decompressedBytes = gzip.decode(compressedBytes);
    return Uint8List.fromList(decompressedBytes);
  }
}
