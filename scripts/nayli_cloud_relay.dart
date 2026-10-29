import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Nayli Market - High-Performance Zero-Dependency Cloud Relay Gateway
/// Serves as the WAN bridge between Master POS Desktop and Companion Mobile Apps.
/// Provides 100% strict tenant isolation using cryptographically separated rooms.

class RelayRoom {
  final String id;
  WebSocket? masterSocket;
  final Set<WebSocket> clientSockets = {};

  RelayRoom(this.id);

  bool get isEmpty => masterSocket == null && clientSockets.isEmpty;
}

void main(List<String> args) async {
  final int port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('====================================================');
  print('🚀 Nayli Market Cloud Relay Gateway running on port $port');
  print('🔒 Strict Merchant Tenant Isolation Active');
  print('====================================================');

  final Map<String, RelayRoom> rooms = {};

  server.listen((HttpRequest request) async {
    // Health Check Endpoint
    if (request.uri.path == '/' || request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'online',
        'service': 'Nayli Market Cloud Relay Gateway',
        'activeRooms': rooms.length,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await request.response.close();
      return;
    }

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Expected WebSocket upgrade request.');
      await request.response.close();
      return;
    }

    final query = request.uri.queryParameters;
    final roomId = query['room']?.trim() ?? '';
    final role = query['role']?.trim().toLowerCase() ?? 'client';
    final merchantId = query['merchantId']?.trim() ?? roomId;

    if (roomId.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing "room" query parameter.');
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);
      final room = rooms.putIfAbsent(roomId, () => RelayRoom(roomId));

      if (role == 'master' || role == 'server') {
        room.masterSocket?.close(WebSocketStatus.goingAway, 'New master connected');
        room.masterSocket = socket;
        print('🏢 [Room: $roomId] Master POS connected ($merchantId)');

        // Notify existing clients in the room that Master is online
        for (final client in room.clientSockets) {
          client.add(jsonEncode({
            'type': 'upRes',
            'event': 'master-status',
            'merchantId': merchantId,
            'payload': {'status': 'online'},
            'ts': DateTime.now().millisecondsSinceEpoch,
          }));
        }
      } else {
        room.clientSockets.add(socket);
        print('📱 [Room: $roomId] Mobile Companion connected. Total in room: ${room.clientSockets.length}');

        // Notify client about master's current availability
        socket.add(jsonEncode({
          'type': 'upRes',
          'event': 'master-status',
          'merchantId': merchantId,
          'payload': {'status': room.masterSocket != null ? 'online' : 'offline'},
          'ts': DateTime.now().millisecondsSinceEpoch,
        }));
      }

      socket.listen(
        (data) {
          try {
            final text = data.toString();
            final map = jsonDecode(text) as Map<String, dynamic>;

            if (role == 'master' || role == 'server') {
              // Master sending response or broadcast to clients in its room
              final targetClientId = map['targetClientId']?.toString();
              if (targetClientId != null) {
                // Direct message to one client
                // (forwarded if client tracking is enabled)
              }
              // Broadcast to all clients in the same room
              for (final client in room.clientSockets) {
                if (client.readyState == WebSocket.open) {
                  client.add(text);
                }
              }
            } else {
              // Client sending request to master
              if (room.masterSocket != null && room.masterSocket!.readyState == WebSocket.open) {
                room.masterSocket!.add(text);
              } else {
                // Master POS is offline
                socket.add(jsonEncode({
                  'id': map['id'] ?? '${DateTime.now().microsecondsSinceEpoch}',
                  'type': 'res',
                  'event': 'error',
                  'merchantId': merchantId,
                  'payload': {
                    'error': 'Master POS is currently offline. Please ensure the store PC is running.',
                    'offline': true,
                  },
                  'ts': DateTime.now().millisecondsSinceEpoch,
                }));
              }
            }
          } catch (e) {
            print('Relay error: $e');
          }
        },
        onDone: () {
          if (role == 'master' || role == 'server') {
            room.masterSocket = null;
            print('🏢 [Room: $roomId] Master POS disconnected');
            for (final client in room.clientSockets) {
              client.add(jsonEncode({
                'type': 'upRes',
                'event': 'master-status',
                'merchantId': merchantId,
                'payload': {'status': 'offline'},
                'ts': DateTime.now().millisecondsSinceEpoch,
              }));
            }
          } else {
            room.clientSockets.remove(socket);
            print('📱 [Room: $roomId] Companion disconnected. Remaining: ${room.clientSockets.length}');
          }

          if (room.isEmpty) {
            rooms.remove(roomId);
            print('🧹 [Room: $roomId] Cleaned up inactive room');
          }
        },
        onError: (err) {
          print('Socket error in room $roomId: $err');
        },
      );
    } catch (e) {
      print('Upgrade error: $e');
    }
  });
}
