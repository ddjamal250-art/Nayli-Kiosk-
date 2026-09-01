import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/billing/data/kiosk_service.dart';
import '../utils/barcode_normalizer.dart';

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
  static final StreamController<RemoteIncomingCart> _posHandoffStreamController = StreamController<RemoteIncomingCart>.broadcast();
  
  static final List<RemoteIncomingCart> pendingRemoteCarts = [];
  static int _connectedClients = 0;

  static bool get isRunning => _isRunning;
  static Stream<String> get logStream => _logController.stream;
  static Stream<int> get clientsStream => _clientsController.stream;
  static Stream<RemoteIncomingCart> get remoteCartStream => _remoteCartStreamController.stream;
  static Stream<RemoteIncomingCart> get posHandoffStream => _posHandoffStreamController.stream;
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

    try {
      final candidatePorts = [customPort, 8081, 8082, 8888, 9090];
      HttpServer? boundServer;
    int boundPort = customPort;

    for (final p in candidatePorts) {
      try {
        boundServer = await HttpServer.bind(InternetAddress.anyIPv4, p);
        boundPort = p;
        break;
      } catch (e) {
        debugPrint('Port $p is busy, trying next...');
      }
    }

    if (boundServer == null) {
      debugPrint('Failed to bind LocalSyncServer to any port');
      _isRunning = false;
      return false;
    }

    port = boundPort;
    _server = boundServer;
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
          } else if (path == '/api/pos-handoff' && request.method == 'POST') {
            await _handlePostPosHandoff(request);
          } else if (path == '/api/remote-carts' && request.method == 'GET') {
            await _handleGetRemoteCarts(request);
          } else if (path == '/api/kiosk-config' && request.method == 'GET') {
            await _handleGetKioskConfig(request);
          } else if (path == '/api/kiosk-config' && request.method == 'POST') {
            await _handlePostKioskConfig(request);
          } else if (path == '/api/kiosk-lookup' && request.method == 'GET') {
            await _handleKioskLookup(request);
          } else if (path == '/kiosk' && request.method == 'GET') {
            await _handleWebKiosk(request);
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

  static Future<void> _handlePostPosHandoff(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final handoffCart = RemoteIncomingCart.fromMap(data);
    pendingRemoteCarts.insert(0, handoffCart);
    _remoteCartStreamController.add(handoffCart);
    _posHandoffStreamController.add(handoffCart);
    _logController.add('POS Register Handoff received from ${handoffCart.senderName} (${handoffCart.token})');

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'success': true,
      'token': handoffCart.token,
      'message': 'Cart successfully received by peer cashier',
    }));
    await request.response.close();
  }

  /// Forward cart to another peer Cashier register on LAN (e.g. when out of change)
  static Future<bool> forwardCartToPeer({
    required String peerIp,
    int peerPort = 8080,
    required RemoteIncomingCart cart,
  }) async {
    try {
      final url = Uri.parse('http://$peerIp:$peerPort/api/pos-handoff');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cart.toMap()),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to forward cart to peer at $peerIp:$peerPort: $e');
      return false;
    }
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
        
        final product = HiveDatabase.productBox.values
            .where((p) => BarcodeNormalizer.matches(p.barcode, barcode?.toString()))
            .firstOrNull;

        if (product != null && product is ProductModel) {
          final newStock = (product.stock - qty.toInt()).clamp(0, 999999);
          final updatedProduct = product.copyWith(stock: newStock);
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

  static Future<void> _handleGetKioskConfig(HttpRequest request) async {
    final config = KioskService.getSettings();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(config));
    await request.response.close();
  }

  static Future<void> _handlePostKioskConfig(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    await KioskService.saveSettings(
      productDisplayDuration: data['productDisplayDuration'] as int?,
      arrowDirection: data['arrowDirection'] as String?,
      greetingTitle: data['greetingTitle'] as String?,
      greetingSubtitle: data['greetingSubtitle'] as String?,
      promoSlides: (data['promoSlides'] as List?)?.cast<String>(),
      soundEnabled: data['soundEnabled'] as bool?,
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
    await request.response.close();
  }

  static Future<void> _handleKioskLookup(HttpRequest request) async {
    final barcode = request.uri.queryParameters['barcode'] ?? '';
    final result = KioskService.lookupBarcode(barcode);
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(result.toJson()));
    await request.response.close();
  }

  static Future<void> _handleWebKiosk(HttpRequest request) async {
    final config = KioskService.getSettings();
    final greetingTitle = config['greetingTitle'] ?? 'Nayli Market';
    final greetingSubtitle = config['greetingSubtitle'] ?? 'مرر باركود السلعة تحت الماسح';
    final duration = config['productDisplayDuration'] ?? 10;
    final arrowDir = config['arrowDirection'] ?? 'down';

    String arrowSymbol = '⬇️';
    if (arrowDir == 'front') arrowSymbol = '⏺️';
    if (arrowDir == 'left') arrowSymbol = '⬅️';
    if (arrowDir == 'right') arrowSymbol = '➡️';

    final html = '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nayli Market - كشك فاحص الأسعار الذكي</title>
  <style>
    :root {
      --primary: #4F46E5;
      --accent: #0D9488;
      --bg: #0F172A;
      --card-bg: rgba(30, 41, 59, 0.88);
      --text: #F8FAFC;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Kufi Arabic', sans-serif; user-select: none; }
    body { background: radial-gradient(circle at top right, #1E1B4B, #0F172A); color: var(--text); height: 100vh; display: flex; flex-direction: column; overflow: hidden; }
    header { padding: 18px 30px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid rgba(255,255,255,0.1); }
    .logo { font-size: 1.4rem; font-weight: 800; display: flex; align-items: center; gap: 10px; color: #818CF8; }
    .status-badge { background: rgba(16,185,129,0.2); color: #34D399; padding: 6px 14px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; }
    main { flex: 1; display: flex; align-items: center; justify-content: center; padding: 20px; position: relative; }
    
    #idle-view { text-align: center; max-width: 800px; width: 100%; }
    .idle-title { font-size: clamp(2rem, 5vw, 3.2rem); font-weight: 900; margin-bottom: 15px; color: #E0E7FF; text-shadow: 0 4px 20px rgba(79,70,229,0.3); }
    .idle-subtitle { font-size: clamp(1.1rem, 2.5vw, 1.6rem); color: #94A3B8; margin-bottom: 40px; }
    
    .scanner-pointer { display: flex; flex-direction: column; align-items: center; gap: 12px; margin-top: 20px; }
    .scanner-text { font-size: 1.2rem; font-weight: bold; color: #38BDF8; }
    .arrow-icon { font-size: 4rem; animation: pulseArrow 1.4s ease-in-out infinite; color: #F59E0B; }
    @keyframes pulseArrow {
      0%, 100% { transform: translateY(0) scale(1); filter: drop-shadow(0 0 10px #F59E0B); }
      50% { transform: translateY(14px) scale(1.15); filter: drop-shadow(0 0 25px #F59E0B); }
    }
    
    #product-card { display: none; background: var(--card-bg); backdrop-filter: blur(16px); border: 2px solid rgba(255,255,255,0.15); border-radius: 28px; padding: 40px; max-width: 750px; width: 100%; text-align: center; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); transform: scale(0.95); transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
    #product-card.active { display: block; transform: scale(1); }
    .product-badge { display: inline-block; background: #0D9488; color: white; padding: 6px 18px; border-radius: 20px; font-weight: bold; font-size: 0.95rem; margin-bottom: 16px; }
    .product-name { font-size: clamp(1.8rem, 4vw, 2.8rem); font-weight: 900; margin-bottom: 20px; line-height: 1.2; }
    .price-container { background: rgba(15,23,42,0.8); border: 2px solid #6366F1; border-radius: 20px; padding: 20px; margin-bottom: 25px; }
    .price-value { font-size: clamp(2.8rem, 7vw, 4.5rem); font-weight: 900; color: #38BDF8; font-variant-numeric: tabular-nums; }
    .price-currency { font-size: 1.5rem; color: #818CF8; margin-right: 8px; }
    .pack-offer { background: rgba(245,158,11,0.15); border: 1px dashed #F59E0B; color: #FBBF24; padding: 12px 18px; border-radius: 14px; font-size: 1.1rem; font-weight: bold; margin-bottom: 20px; }
    .timer-ring { font-size: 0.9rem; color: #64748B; display: flex; align-items: center; justify-content: center; gap: 8px; }
    
    #not-found-card { display: none; background: rgba(185,28,28,0.2); border: 2px solid #EF4444; border-radius: 24px; padding: 35px; max-width: 650px; width: 100%; text-align: center; }
    #not-found-card.active { display: block; }
  </style>
</head>
<body>
  <header>
    <div class="logo">🛍️ <span>Nayli Price Checker</span></div>
    <div class="status-badge">● متصل بالسيرفر المحلي</div>
  </header>

  <main>
    <div id="idle-view">
      <h1 class="idle-title">$greetingTitle</h1>
      <p class="idle-subtitle">$greetingSubtitle</p>
      
      <div class="scanner-pointer">
        <div class="arrow-icon">$arrowSymbol</div>
        <div class="scanner-text">وجه الباركود إلى هنا لمعرفة السعر</div>
      </div>
    </div>

    <div id="product-card">
      <div class="product-badge" id="prod-badge">متوفر في المتجر ✅</div>
      <h2 class="product-name" id="prod-name">اسم السلعة</h2>
      
      <div class="price-container">
        <span class="price-value" id="prod-price">0.00</span>
        <span class="price-currency">DA</span>
      </div>

      <div class="pack-offer" id="prod-pack" style="display:none;"></div>
      <div class="timer-ring">⏳ يعود لوضع العروض بعد <span id="seconds-left">$duration</span> ثوانٍ</div>
    </div>

    <div id="not-found-card">
      <div style="font-size:3.5rem; margin-bottom:15px;">🤝</div>
      <h2 style="font-size:1.8rem; margin-bottom:10px; color:#FCA5A5;">عذراً! هذا المنتج غير مسجل في النظام بعد</h2>
      <p style="color:#E2E8F0; font-size:1.1rem;">تم إشعار الكاشير بنسيان إضافة السلعة، تفضل بسؤال موظف المحل لمساعدتك فوراً</p>
    </div>
  </main>

  <script>
    let duration = $duration;
    let timeoutId = null;
    let intervalId = null;
    let buffer = "";
    let lastKeyTime = Date.now();

    function playChime(freq = 600, duration = 0.15) {
      try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.frequency.value = freq;
        gain.gain.setValueAtTime(0.3, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start();
        osc.stop(ctx.currentTime + duration);
      } catch(e){}
    }

    window.addEventListener("keydown", (e) => {
      const now = Date.now();
      if (now - lastKeyTime > 150) buffer = "";
      lastKeyTime = now;

      if (e.key === "Enter") {
        if (buffer.trim().length >= 3) {
          lookupBarcode(buffer.trim());
        }
        buffer = "";
        return;
      }

      if (e.key.length === 1) {
        buffer += e.key;
      }
    });

    function showIdle() {
      document.getElementById("idle-view").style.display = "block";
      document.getElementById("product-card").classList.remove("active");
      document.getElementById("not-found-card").classList.remove("active");
      if (intervalId) clearInterval(intervalId);
    }

    async function lookupBarcode(barcode) {
      playChime(880, 0.2);
      try {
        const res = await fetch("/api/kiosk-lookup?barcode=" + encodeURIComponent(barcode));
        const data = await res.json();
        
        if (data.found) {
          document.getElementById("idle-view").style.display = "none";
          document.getElementById("not-found-card").classList.remove("active");
          
          document.getElementById("prod-name").textContent = data.name;
          document.getElementById("prod-price").textContent = Number(data.price).toFixed(2);
          
          const packEl = document.getElementById("prod-pack");
          if (data.packPrice > 0 && data.packMultiplier > 1) {
            packEl.style.display = "block";
            packEl.textContent = "🌟 متوفر أيضاً كـ " + (data.packName || "حزمة") + " x" + data.packMultiplier + " بسعر " + Number(data.packPrice).toFixed(2) + " DA";
          } else {
            packEl.style.display = "none";
          }

          document.getElementById("product-card").classList.add("active");

          let left = duration;
          document.getElementById("seconds-left").textContent = left;
          if (intervalId) clearInterval(intervalId);
          intervalId = setInterval(() => {
            left--;
            document.getElementById("seconds-left").textContent = left;
            if (left <= 0) {
              clearInterval(intervalId);
              showIdle();
            }
          }, 1000);

          if (timeoutId) clearTimeout(timeoutId);
          timeoutId = setTimeout(showIdle, duration * 1000);
        } else {
          document.getElementById("idle-view").style.display = "none";
          document.getElementById("product-card").classList.remove("active");
          document.getElementById("not-found-card").classList.add("active");
          
          playChime(300, 0.3);
          if (timeoutId) clearTimeout(timeoutId);
          timeoutId = setTimeout(showIdle, 4500);
        }
      } catch(e) {
        console.error(e);
      }
    }
  </script>
</body>
</html>''';

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }
}

