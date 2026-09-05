import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const String _versionUrl = 'https://raw.githubusercontent.com/YourUsername/Nayli-Kiosk/main/version.json';
  static bool _hasChecked = false;

  static Future<void> checkForUpdates(BuildContext context) async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String remoteVersionStr = data['version'];
        final String updateUrl = data['url'];

        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String localVersionStr = packageInfo.version;

        if (_isRemoteNewer(localVersionStr, remoteVersionStr)) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersionStr, updateUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
  }

  static bool _isRemoteNewer(String localVersion, String remoteVersion) {
    List<int> localParts = localVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> remoteParts = remoteVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int local = i < localParts.length ? localParts[i] : 0;
      int remote = i < remoteParts.length ? remoteParts[i] : 0;

      if (remote > local) return true;
      if (remote < local) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('تحديث جديد متاح'),
          content: Text('تم إصدار نسخة جديدة من نايلي كيوسك (الإصدار $version).
هل ترغب في تحميلها الآن مجاناً؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
            ElevatedButton(
              onPressed: () async {
                final Uri url = Uri.parse(updateUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('تحميل التحديث'),
            ),
          ],
        );
      },
    );
  }
}