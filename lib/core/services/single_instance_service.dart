import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class SingleInstanceService {
  static ServerSocket? _serverSocket;
  static const int _singleInstancePort = 48721;

  /// Returns true if this is the primary instance.
  /// Returns false if another instance is already running (and activates it).
  static Future<bool> acquireSingleInstance() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return true;
    }

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _singleInstancePort,
      );

      // Listen for activation requests from subsequent instances
      _serverSocket!.listen((Socket client) {
        client.listen((data) async {
          final message = String.fromCharCodes(data).trim();
          if (message == 'ACTIVATE') {
            try {
              if (await windowManager.isMinimized()) {
                await windowManager.restore();
              }
              await windowManager.show();
              await windowManager.focus();
            } catch (e) {
              debugPrint('Error activating existing window: $e');
            }
          }
        });
      });

      return true; // We are the primary instance
    } catch (_) {
      // Port is already occupied -> Another instance is running!
      try {
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _singleInstancePort,
          timeout: const Duration(milliseconds: 500),
        );
        client.write('ACTIVATE\n');
        await client.flush();
        await client.close();
        return false; // Exit this instance ONLY because the active instance was notified!
      } catch (_) {
        // If connecting to the port failed, no instance is actually alive!
        // The port might have been in TIME_WAIT or dead. Proceed as primary!
        return true;
      }
    }
  }

  static Future<void> release() async {
    try {
      await _serverSocket?.close();
    } catch (_) {}
  }
}
