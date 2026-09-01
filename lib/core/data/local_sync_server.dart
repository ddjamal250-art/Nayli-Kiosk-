import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hive_database.dart';
import '../../features/product/data/models/product_model.dart';

class RemoteCartItem {
  final String barcode;
  final String name;
  final double price;
  final double costPrice;
  final int quantity;
  final String? unit;

  RemoteCartItem({
    required this.barcode,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.unit = 'قطعة',
  });

  Map<String, dynamic> toMap() => {
    'barcode': barcode,
    'name': name,
    'price': price,
    'costPrice': costPrice,
    'quantity': quantity,
    'unit': unit,
  };

  factory RemoteCartItem.fromMap(Map<String, dynamic> map) => RemoteCartItem(
    barcode: map['barcode']?.toString() ?? '',
    name: map['name']?.toString() ?? 'سلعة',
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
    quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    unit: map['unit']?.toString() ?? 'قطعة',
  );
}

class RemoteIncomingCart {
  final String id;
  final String token; // Short customer ticket code, e.g. #101
  final String senderName; // e.g. "هاتف المدير" / "البائع المتنقل"
  final DateTime timestamp;
  final String? customerName;
  final List<RemoteCartItem> items;
  final double totalAmount;

  RemoteIncomingCart({
    required this.id,
    required this.token,
    required this.senderName,
    required this.timestamp,
    this.customerName,
    required this.items,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'token': token,
    'senderName': senderName,
    'timestamp': timestamp.toIso8601String(),
    'customerName': customerName,
    'items': items.map((i) => i.toMap()).toList(),
    'totalAmount': totalAmount,
  };

  factory RemoteIncomingCart.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List? ?? [];
    final itemsList = rawItems.map((i) => RemoteCartItem.fromMap(i as Map<String, dynamic>)).toList();
    final double total = (map['totalAmount'] as num?)?.toDouble() ??
        itemsList.fold<double>(0.0, (double s, i) => s + (i.price * i.quantity));
    
    return RemoteIncomingCart(
      id: map['id']?.toString() ?? 'rc_${DateTime.now().millisecondsSinceEpoch}',
      token: map['token']?.toString() ?? '#${DateTime.now().millisecond % 900 + 100}',
      senderName: map['senderName']?.toString() ?? 'هاتف المحل المتنقل',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      customerName: map['customerName']?.toString(),
      items: itemsList,
      totalAmount: total,
    );
  }
}

class LocalSyncServer {
  static HttpServer? _server;
  static int port = 8080;
  static bool _isRunning = false;
  
  static final StreamController<String> _logController = StreamController<String>.broadcast();
  static final StreamController<int> _clientsController = StreamController<int>.broadcast();
  static final StreamController<RemoteIncomingCart> _remoteCartStreamController = StreamController<RemoteIncomingCart>.broadcast();
  
  static final List<RemoteIncomingCart> pendingRemoteCarts = [];
  static int _connectedClients = 0;

  static bool get isRunning => _isRunning;
  static Stream<String> get logStream => _logController.stream;
  static Stream<int> get clientsStream => _clientsController.stream;
  static Stream<RemoteIncomingCart> get remoteCartStream => _remoteCartStreamController.stream;
  static int get connectedClients => _connectedClients;

  /// Get local machine Wi-Fi / Ethernet IPv4 address
  static Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding local IP: $e');
    }
    return '127.0.0.1';
  }

  /// Start Embedded Master Server
  static Future<bool> startServer({int customPort = 8080}) async {
    if (_isRunning) return true;
    port = customPort;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;
      final ip = await getLocalIp();
      _logController.add('Master POS Server started at http://$ip:$port');

      _server!.listen((HttpRequest request) async {
        // Enable CORS
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        final path = request.uri.path;
        try {
          if (path == '/api/status' && request.method == 'GET') {
            await _handleStatus(request);
          } else if (path == '/api/products' && request.method == 'GET') {
            await _handleGetProducts(request);
          } else if (path == '/api/customers' && request.method == 'GET') {
            await _handleGetCustomers(request);
          } else if (path == '/api/documents' && request.method == 'GET') {
            await _handleGetDocuments(request);
          } else if (path == '/api/documents' && request.method == 'POST') {
            await _handlePostDocument(request);
          } else if (path == '/api/sales' && request.method == 'POST') {
            await _handlePostSale(request);
          } else if (path == '/api/remote-cart' && request.method == 'POST') {
            await _handlePostRemoteCart(request);
          } else if (path == '/api/remote-carts' && request.method == 'GET') {
            await _handleGetRemoteCarts(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(jsonEncode({'error': 'Endpoint not found'}));
            await request.response.close();
          }
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(jsonEncode({'error': e.toString()}));
          await request.response.close();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Failed to start LocalSyncServer: $e');
      _isRunning = false;
      return false;
    }
  }

  static Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _isRunning = false;
      _logController.add('Server stopped.');
    }
  }

  static Future<void> _handleStatus(HttpRequest request) async {
    final ip = await getLocalIp();
    final data = {
      'status': 'online',
      'server': 'Nayli Market Master Server',
      'version': '2.0.0',
      'ip': ip,
      'port': port,
      'pendingCartsCount': pendingRemoteCarts.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  static Future<void> _handleGetProducts(HttpRequest request) async {
    final products = HiveDatabase.productBox.values.map((p) => p.toJson()).toList();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(products));
    await request.response.close();
  }

  static Future<void> _handleGetCustomers(HttpRequest request) async {
    final customers = HiveDatabase.customersBox.values.toList();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(customers));
    await request.response.close();
  }

  /// Handle incoming pre-scanned basket sent from floor seller/manager mobile
  static Future<void> _handlePostRemoteCart(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final remoteCart = RemoteIncomingCart.fromMap(data);
    pendingRemoteCarts.insert(0, remoteCart);
    _remoteCartStreamController.add(remoteCart);
    _logController.add('New Remote Cart received from ${remoteCart.senderName} (${remoteCart.token})');

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'token': remoteCart.token,
      'message': 'Cart successfully forwarded to Cashier Register',
    }));
    await request.response.close();
  }

  static Future<void> _handleGetRemoteCarts(HttpRequest request) async {
    final list = pendingRemoteCarts.map((c) => c.toMap()).toList();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(list));
    await request.response.close();
  }

  static Future<void> _handleGetDocuments(HttpRequest request) async {
    final docs = HiveDatabase.commercialDocsBox.values.whereType<Map>().toList();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(docs));
    await request.response.close();
  }

  static Future<void> _handlePostDocument(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final docId = data['id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}';
    await HiveDatabase.commercialDocsBox.put(docId, data);

    _logController.add('Synced commercial document $docId (${data['documentNumber']}) from mobile device');
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true, 'id': docId}));
    await request.response.close();
  }

  static Future<void> _handlePostSale(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Save invoice to local box
    final invoiceId = data['id'] ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    await HiveDatabase.invoicesBox.put(invoiceId, data);

    // Decrement stock for items
    if (data['items'] is List) {
      final items = data['items'] as List;
      for (var item in items) {
        final barcode = item['barcode'];
        final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        
        final product = HiveDatabase.productBox.values.where((p) => p.barcode == barcode).firstOrNull;

        if (product != null) {
          final newStock = (product.stock - qty.toInt()).clamp(0, 999999);
          final updatedProduct = ProductModel(
            id: product.id,
            name: product.name,
            barcode: product.barcode,
            price: product.price,
            costPrice: product.costPrice,
            stock: newStock,
            category: product.category,
            isWeighted: product.isWeighted,
            wholesalePrice: product.wholesalePrice,
            expiryDate: product.expiryDate,
          );
          await HiveDatabase.productBox.put(product.id, updatedProduct);
        }
      }
    }

    _logController.add('Received completed sale $invoiceId from mobile terminal');
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true, 'invoiceId': invoiceId}));
    await request.response.close();
  }

  /// Remove a pending remote cart after it is processed/loaded by cashier
  static void removeRemoteCart(String cartId) {
    pendingRemoteCarts.removeWhere((c) => c.id == cartId);
  }
}

