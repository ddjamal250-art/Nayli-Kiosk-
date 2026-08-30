import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'hive_database.dart';
import '../../features/product/data/models/product_model.dart';

class LocalSyncServer {
  static HttpServer? _server;
  static int port = 8080;
  static bool _isRunning = false;
  static final StreamController<String> _logController = StreamController<String>.broadcast();
  static final StreamController<int> _clientsController = StreamController<int>.broadcast();
  static int _connectedClients = 0;

  static bool get isRunning => _isRunning;
  static Stream<String> get logStream => _logController.stream;
  static Stream<int> get clientsStream => _clientsController.stream;
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
      _logController.add('Server started at http://$ip:$port');

      _server!.listen((HttpRequest request) async {
        // Enable CORS
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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
          } else if (path == '/api/sales' && request.method == 'POST') {
            await _handlePostSale(request);
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
        
        final product = HiveDatabase.productBox.values.firstWhere(
          (p) => p.barcode == barcode,
          orElse: () => ProductModel(barcode: '', name: '', price: 0, costPrice: 0, stock: 0),
        );

        if (product.barcode.isNotEmpty) {
          final updatedProduct = product.copyWith(stock: product.stock - qty);
          await HiveDatabase.productBox.put(product.barcode, updatedProduct);
        }
      }
    }

    _logController.add('Received sale $invoiceId from mobile terminal');
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true, 'invoiceId': invoiceId}));
    await request.response.close();
  }
}

