import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../utils/barcode_normalizer.dart';
import '../utils/merchant_context_service.dart';
import '../utils/license_service.dart';
import '../utils/sound_service.dart';
import 'local_sync_server.dart';
import 'sync_message_protocol.dart';

enum SyncConnectionMode { disconnected, lanConnecting, lanConnected, wanConnecting, wanConnected }

class SmartSyncClient {
  static WebSocket? _socket;
  static SyncConnectionMode _connectionMode = SyncConnectionMode.disconnected;
  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  static bool _autoReconnect = true;
  static int _reconnectAttempts = 0;

  // Stream Controllers
  static final StreamController<SyncConnectionMode> _stateController = StreamController<SyncConnectionMode>.broadcast();
  static final StreamController<String> _barcodeStreamController = StreamController<String>.broadcast();
  static final StreamController<List<Map<String, dynamic>>> _inventoryChangeController = StreamController<List<Map<String, dynamic>>>.broadcast();
  static final StreamController<RemoteIncomingCart> _cartStreamController = StreamController<RemoteIncomingCart>.broadcast();
  static final StreamController<String> _logController = StreamController<String>.broadcast();

  // Pending Request-Response Callbacks
  static final Map<String, Completer<SyncMessage>> _pendingRequests = {};

  // Public Getters
  static SyncConnectionMode get connectionMode => _connectionMode;
  static bool get isConnected =>
      _connectionMode == SyncConnectionMode.lanConnected || _connectionMode == SyncConnectionMode.wanConnected;
  static Stream<SyncConnectionMode> get stateStream => _stateController.stream;
  static Stream<String> get barcodeStream => _barcodeStreamController.stream;
  static Stream<List<Map<String, dynamic>>> get inventoryChangeStream => _inventoryChangeController.stream;
  static Stream<RemoteIncomingCart> get cartStream => _cartStreamController.stream;
  static Stream<String> get logStream => _logController.stream;

  // Storage Keys
  static const String _serverIpKey = 'sync_server_ip';
  static const String _cloudRelayUrlKey = 'cloud_relay_url';
  static const String _cloudRoomKey = 'cloud_room_key';

  static String getServerIp() {
    return HiveDatabase.settingsBox.get(_serverIpKey, defaultValue: '') as String;
  }

  static Future<void> setServerIp(String ip) async {
    await HiveDatabase.settingsBox.put(_serverIpKey, ip.trim());
  }

  static String getCloudRelayUrl() {
    return HiveDatabase.settingsBox.get(
      _cloudRelayUrlKey,
      defaultValue: 'wss://relay.naylimarket.app/tunnel',
    ) as String;
  }

  static Future<void> setCloudRelayUrl(String url) async {
    await HiveDatabase.settingsBox.put(_cloudRelayUrlKey, url.trim());
  }

  /// Initialize Client and Auto-Start LAN Discovery & Connection
  static Future<void> initialize() async {
    _autoReconnect = true;
    startUdpDiscovery();
    
    // If a saved IP is present, attempt fast direct connection
    final savedIp = getServerIp();
    if (savedIp.isNotEmpty) {
      connectToLan(savedIp);
    }
  }

  // --- UDP Auto-Discovery with Merchant Isolation ---
  static RawDatagramSocket? _discoverySocket;
  static bool _isDiscovering = false;

  static Future<void> startUdpDiscovery() async {
    if (_isDiscovering) return;
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8889,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _discoverySocket?.broadcastEnabled = true;
      _isDiscovering = true;
      _logController.add('🔍 Listening for Master POS Beacons on LAN...');

      _discoverySocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final map = jsonDecode(text) as Map<String, dynamic>;

              if (map['app'] == 'nayli_pos_lan') {
                final beaconMerchantId = map['merchantId']?.toString() ?? '';
                final currentMerchantId = MerchantContextService.getMerchantId();

                // Strict Merchant Isolation: Ignore beacons from different merchants
                if (currentMerchantId.isNotEmpty &&
                    currentMerchantId != 'SHOP-DEFAULT' &&
                    beaconMerchantId.isNotEmpty &&
                    beaconMerchantId != currentMerchantId) {
                  return; // Mismatched store, ignore silently
                }

                final ip = map['serverIp']?.toString() ?? datagram.address.address;
                final port = (map['port'] as num?)?.toInt() ?? 8080;
                final storeName = map['storeName']?.toString() ?? 'Nayli POS Master';

                _logController.add('📍 Discovered Master POS: $storeName ($ip:$port)');

                // Auto-pair merchant context if not set yet
                if (currentMerchantId == 'SHOP-DEFAULT' && beaconMerchantId.isNotEmpty) {
                  MerchantContextService.setMerchantId(beaconMerchantId);
                }

                // If disconnected or in error, connect immediately to this discovered server
                if (!isConnected && _connectionMode != SyncConnectionMode.lanConnecting) {
                  connectToLan('$ip:$port');
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting UDP discovery listener: $e');
    }
  }

  static void stopUdpDiscovery() {
    _discoverySocket?.close();
    _discoverySocket = null;
    _isDiscovering = false;
  }

  // --- LAN WebSocket Connection ---
  static Future<bool> connectToLan(String ipWithPort) async {
    if (isConnected && _connectionMode == SyncConnectionMode.lanConnected) return true;

    try {
      _setConnectionMode(SyncConnectionMode.lanConnecting);
      _logController.add('Connecting to Master POS via LAN ($ipWithPort)...');

      String host = ipWithPort.trim();
      host = host.replaceAll('http://', '').replaceAll('https://', '').replaceAll('ws://', '').replaceAll('wss://', '');
      if (!host.contains(':')) host = '$host:8080';

      final wsUri = Uri.parse('ws://$host/ws');
      final socket = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 4));

      _onSocketConnected(socket, SyncConnectionMode.lanConnected);
      await setServerIp(ipWithPort);
      _reconnectAttempts = 0;
      return true;
    } catch (e) {
      _logController.add('LAN Connection failed: $e');
      _setConnectionMode(SyncConnectionMode.disconnected);
      _scheduleReconnect();
      return false;
    }
  }

  // --- WAN Cloud Relay Connection ---
  static Future<bool> connectToWan({String? customRoomKey}) async {
    if (isConnected && _connectionMode == SyncConnectionMode.wanConnected) return true;

    try {
      _setConnectionMode(SyncConnectionMode.wanConnecting);
      final merchantId = MerchantContextService.getMerchantId();
      final room = customRoomKey ?? merchantId;
      final relayUrl = getCloudRelayUrl();

      _logController.add('Connecting to Cloud Relay ($relayUrl) Room: $room...');

      final uri = Uri.parse('$relayUrl?room=$room&role=client&merchantId=$merchantId');
      final socket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 8));

      _onSocketConnected(socket, SyncConnectionMode.wanConnected);
      _reconnectAttempts = 0;
      return true;
    } catch (e) {
      _logController.add('Cloud Relay Connection failed: $e');
      _setConnectionMode(SyncConnectionMode.disconnected);
      _scheduleReconnect();
      return false;
    }
  }

  static void _onSocketConnected(WebSocket socket, SyncConnectionMode mode) {
    _socket = socket;
    _setConnectionMode(mode);
    _logController.add('✅ Socket connected successfully (${mode.name})');
    SoundService.playSaveSuccess();

    // Perform initial authentication handshake
    _sendAuth();

    // Start 15-second heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendPing());

    // Listen to messages
    _socket!.listen(
      (data) {
        try {
          final text = data.toString();
          final msg = SyncMessage.fromJson(text);
          _handleIncomingMessage(msg);
        } catch (e) {
          debugPrint('Client socket parse error: $e');
        }
      },
      onDone: () {
        _logController.add('Socket connection closed by remote peer.');
        _onSocketDisconnected();
      },
      onError: (err) {
        _logController.add('Socket error: $err');
        _onSocketDisconnected();
      },
    );
  }

  static void _onSocketDisconnected() {
    _socket?.close();
    _socket = null;
    _heartbeatTimer?.cancel();
    _setConnectionMode(SyncConnectionMode.disconnected);
    _failPendingRequests('Connection closed');
    _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _reconnectTimer?.cancel();

    // Exponential backoff capped at 10 seconds
    final delaySeconds = (_reconnectAttempts < 5 ? (_reconnectAttempts + 1) * 2 : 10);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!isConnected) {
        final ip = getServerIp();
        if (ip.isNotEmpty) {
          connectToLan(ip);
        }
      }
    });
  }

  static void _setConnectionMode(SyncConnectionMode mode) {
    _connectionMode = mode;
    _stateController.add(mode);
  }

  // --- Incoming Message Dispatcher ---
  static void _handleIncomingMessage(SyncMessage msg) {
    // 1. Check if this is a response to a pending request
    if (msg.type == SyncMessageType.res && _pendingRequests.containsKey(msg.id)) {
      _pendingRequests.remove(msg.id)?.complete(msg);
      return;
    }

    // 2. Handle Broadcast Events (upRes)
    switch (msg.event) {
      case SyncEvents.scanBarcode:
        final barcode = (msg.payload is Map ? msg.payload['barcode'] : msg.payload)?.toString() ?? '';
        if (barcode.isNotEmpty) {
          _barcodeStreamController.add(barcode);
          SoundService.playBarcodeBeep();
        }
        break;

      case SyncEvents.inventoryChange:
        if (msg.payload is Map && msg.payload['items'] is List) {
          final items = (msg.payload['items'] as List).cast<Map<String, dynamic>>();
          _inventoryChangeController.add(items);
          _applyLocalInventoryChanges(items);
        }
        break;

      case SyncEvents.handoffCart:
        if (msg.payload is Map) {
          final cart = RemoteIncomingCart.fromMap(msg.payload as Map<String, dynamic>);
          _cartStreamController.add(cart);
          SoundService.playRestockSound();
        }
        break;

      case SyncEvents.pong:
        // Heartbeat ACK
        break;

      default:
        debugPrint('Unhandled broadcast event: ${msg.event}');
    }
  }

  /// Automatically updates local Hive cache when inventory changes occur on Master POS
  static Future<void> _applyLocalInventoryChanges(List<Map<String, dynamic>> items) async {
    try {
      final box = HiveDatabase.productBox;
      for (final it in items) {
        final id = it['id']?.toString();
        final newStock = (it['newStock'] as num?)?.toDouble();
        if (id != null && newStock != null && box.containsKey(id)) {
          final prod = box.get(id);
          if (prod is ProductModel) {
            final updated = prod.copyWith(stock: newStock);
            await box.put(id, updated);
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating local stock cache: $e');
    }
  }

  // --- Request-Response Pattern ---
  static Future<SyncMessage> sendRequest(
    String event,
    dynamic payload, {
    bool compressed = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!isConnected || _socket == null) {
      throw Exception('Not connected to Master POS');
    }

    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final msg = SyncMessage(
      id: id,
      type: SyncMessageType.req,
      event: event,
      merchantId: MerchantContextService.getMerchantId(),
      payload: payload,
      compressed: compressed,
    );

    final completer = Completer<SyncMessage>();
    _pendingRequests[id] = completer;

    try {
      _socket!.add(msg.toJson());
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(id);
          throw TimeoutException('Request $event timed out after ${timeout.inSeconds}s');
        },
      );
    } catch (e) {
      _pendingRequests.remove(id);
      rethrow;
    }
  }

  static void _failPendingRequests(String error) {
    for (final c in _pendingRequests.values) {
      if (!c.isCompleted) {
        c.completeError(Exception(error));
      }
    }
    _pendingRequests.clear();
  }

  // --- Protocol Actions ---

  static void _sendAuth() {
    try {
      final msg = SyncMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        type: SyncMessageType.req,
        event: SyncEvents.auth,
        merchantId: MerchantContextService.getMerchantId(),
        payload: {
          'deviceId': LicenseService.getDeviceId(),
          'storeName': MerchantContextService.getStoreName(),
        },
      );
      _socket?.add(msg.toJson());
    } catch (_) {}
  }

  static void _sendPing() {
    if (!isConnected || _socket == null) return;
    try {
      final msg = SyncMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        type: SyncMessageType.req,
        event: SyncEvents.ping,
        merchantId: MerchantContextService.getMerchantId(),
      );
      _socket?.add(msg.toJson());
    } catch (_) {}
  }

  /// Sends a scanned barcode from mobile camera directly to Master POS cashier invoice!
  static Future<bool> sendScannedBarcode(String barcode) async {
    final clean = BarcodeNormalizer.normalize(barcode);
    if (clean.isEmpty) return false;

    try {
      final response = await sendRequest(
        SyncEvents.scanBarcode,
        {'barcode': clean},
        timeout: const Duration(seconds: 4),
      );
      return response.payload?['success'] == true;
    } catch (e) {
      debugPrint('Failed to send scanned barcode: $e');
      return false;
    }
  }

  /// Sends a complete remote shopping cart to Master Desktop POS
  static Future<Map<String, dynamic>> sendRemoteCart(RemoteIncomingCart cart) async {
    try {
      final response = await sendRequest(
        SyncEvents.handoffCart,
        cart.toMap(),
        timeout: const Duration(seconds: 8),
      );
      return response.payload as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Full Catalog Pull: pulls complete inventory from Master POS with decompression
  static Future<int> pullCatalog() async {
    try {
      _logController.add('📥 Pulling catalog from Master POS...');
      final response = await sendRequest(
        SyncEvents.loadCatalog,
        {},
        compressed: true,
        timeout: const Duration(seconds: 15),
      );

      final payload = response.payload;
      if (payload == null || payload is! Map) return 0;

      dynamic rawProducts = payload['products'];
      if (response.compressed && rawProducts is String) {
        rawProducts = SyncCompressionHelper.decompressJson(rawProducts);
      }

      if (rawProducts is! List) return 0;

      final box = HiveDatabase.productBox;
      int updatedCount = 0;

      for (var item in rawProducts) {
        if (item is Map) {
          final p = ProductModel.fromJson(Map<String, dynamic>.from(item));
          await box.put(p.id, p);
          updatedCount++;
        }
      }

      _logController.add('✅ Successfully synced $updatedCount products from Master POS');
      await SoundService.playRestockSound();
      return updatedCount;
    } catch (e) {
      _logController.add('❌ Failed to pull catalog: $e');
      return 0;
    }
  }

  /// Fetches an image from Master POS over WebSocket with decompression
  static Future<Uint8List?> fetchImageOverSocket(String imageName) async {
    try {
      final response = await sendRequest(
        SyncEvents.getImage,
        {'name': imageName},
        timeout: const Duration(seconds: 6),
      );

      final payload = response.payload;
      if (payload is Map && payload['found'] == true && payload['data'] != null) {
        final base64Gzip = payload['data'].toString();
        return SyncCompressionHelper.decompressImageBytes(base64Gzip);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching image over socket: $e');
      return null;
    }
  }

  static void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _socket = null;
    _setConnectionMode(SyncConnectionMode.disconnected);
    stopUdpDiscovery();
  }
}
