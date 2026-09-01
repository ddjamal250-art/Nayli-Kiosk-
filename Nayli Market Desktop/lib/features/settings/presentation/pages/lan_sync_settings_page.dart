import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../core/data/local_sync_server.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/sound_service.dart';

class LanSyncSettingsPage extends StatefulWidget {
  const LanSyncSettingsPage({super.key});

  @override
  State<LanSyncSettingsPage> createState() => _LanSyncSettingsPageState();
}

class _LanSyncSettingsPageState extends State<LanSyncSettingsPage> {
  String _localIp = '127.0.0.1';
  bool _isLoadingIp = true;
  bool _isServerRunning = false;
  String _pingStatus = '';
  bool _isTestingPing = false;

  @override
  void initState() {
    super.initState();
    _isServerRunning = LocalSyncServer.isRunning;
    _refreshNetwork();
  }

  Future<void> _refreshNetwork() async {
    setState(() => _isLoadingIp = true);
    final ip = await LocalSyncServer.getLocalIp();
    if (mounted) {
      setState(() {
        _localIp = ip;
        _isLoadingIp = false;
        _isServerRunning = LocalSyncServer.isRunning;
      });
    }
  }

  Future<void> _toggleServer(bool value) async {
    SoundService.playTabSwitch();
    if (value) {
      final started = await LocalSyncServer.startServer();
      if (started) {
        SoundService.playSaveSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تشغيل سيرفر المزامنة والشبكة المحلية بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await LocalSyncServer.stopServer();
      SoundService.playDeleteSound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 تم إيقاف سيرفر المزامنة المحلي.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    setState(() {
      _isServerRunning = LocalSyncServer.isRunning;
    });
  }

  Future<void> _testPing() async {
    setState(() {
      _isTestingPing = true;
      _pingStatus = '';
    });
    SoundService.playScanBeep();

    try {
      final url = Uri.parse('http://$_localIp:${LocalSyncServer.port}/api/status');
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        setState(() {
          _pingStatus = '✅ الاتصال بالسيرفر المحلي ممتاز (HTTP 200 OK) - المنفذ متاح وخالٍ من الحجب!';
        });
        SoundService.playSaveSuccess();
      } else {
        setState(() {
          _pingStatus = '⚠️ استجاب السيرفر برمز: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _pingStatus = '❌ تعذر الاتصال بالسيرفر المحلي: تأكد من تشغيل السيرفر ومن عدم حجب المنفذ في جدار الحماية (Firewall).';
      });
      SoundService.playVoidWarning();
    } finally {
      if (mounted) setState(() => _isTestingPing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = jsonEncode({
      'app': 'nayli_pos',
      'action': 'pair',
      'ip': _localIp,
      'port': LocalSyncServer.port,
      'name': 'Nayli POS Master',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة الشبكة المحلية والمزامنة (LAN & Wi-Fi)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'تحديث بيانات الشبكة',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshNetwork,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Master Server Toggle Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isServerRunning ? Colors.green.shade50 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isServerRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: _isServerRunning ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'سيرفر المزامنة والربط المحلي (Master POS)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isServerRunning ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _isServerRunning ? Colors.green.shade200 : Colors.red.shade200),
                                ),
                                child: Text(
                                  _isServerRunning ? 'نشط ويعمل 🟢' : 'متوقف 🔴',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isServerRunning ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'يتيح لهواتف العمال وأجهزة الكاشير الفرعية مسح السلع وإرسال السلات والمزامنة الفورية عبر الشبكة المحلية أو الـ Wi-Fi دون الحاجة لإنترنت خارجي.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isServerRunning,
                      activeColor: Colors.green,
                      onChanged: _toggleServer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Dual Pane: QR Code Pairing & Network Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Big QR Code for Instant Mobile Pairing
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, color: Colors.indigo, size: 20),
                              SizedBox(width: 6),
                              Text('كود المسح للربط الفوري (QR Pair)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Crisp QR Code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
                              ],
                            ),
                            child: QrImageView(
                              data: qrPayload,
                              version: QrVersions.auto,
                              size: 190,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'افتح تطبيق نايلي ماركت على هاتف العامل، واضغط على "مسح QR للربط"، ثم وجّه الكاميرا نحو هذا الرمز للاتصال التبادلي فوراً!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right Pane: Network Details & Diagnostics
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إحداثيات الاتصال المحلي (Endpoint)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 12),

                              _buildInfoRow('عنوان الـ IP المحلي:', _isLoadingIp ? 'جاري الفحص...' : _localIp, Icons.laptop_windows_rounded),
                              const Divider(height: 16),
                              _buildInfoRow('منفذ الاتصال (Port):', '${LocalSyncServer.port}', Icons.electrical_services_rounded),
                              const Divider(height: 16),
                              _buildInfoRow('رابط الشبكة الكامل:', 'http://$_localIp:${LocalSyncServer.port}', Icons.link_rounded, isUrl: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Diagnostics & Ping Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('فحص واختبار الشبكة (Diagnostics)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _isTestingPing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.speed_rounded, size: 18),
                                label: Text(
                                  _isTestingPing ? 'جاري الفحص...' : 'فحص استجابة السيرفر المحلي (Ping Test)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                onPressed: _isTestingPing || !_isServerRunning ? null : _testPing,
                              ),
                              if (_pingStatus.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _pingStatus,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _pingStatus.startsWith('✅') ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Connected Clients Stream & Queue
              StreamBuilder<int>(
                stream: LocalSyncServer.clientsStream,
                initialData: LocalSyncServer.connectedClients,
                builder: (context, snapshot) {
                  final clients = snapshot.data ?? 0;
                  final pending = LocalSyncServer.pendingRemoteCarts.length;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('الهواتف الموصولة حالياً', '$clients', Icons.phone_android_rounded, Colors.teal),
                        Container(height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatBox('السلات الواردة المعلقة (F9)', '$pending', Icons.shopping_bag_outlined, Colors.indigo),
                        Container(height: 40, width: 1, color: Colors.grey.shade200),
                        _buildStatBox('نوع البروتوكول', 'REST / HTTP Local', Icons.security_rounded, Colors.purple),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isUrl = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace'),
          ),
        ),
        if (isUrl)
          IconButton(
            tooltip: 'نسخ الرابط',
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.indigo),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              SoundService.playSaveSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 تم نسخ الرابط بنجاح!'), duration: Duration(seconds: 1)),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }
}
