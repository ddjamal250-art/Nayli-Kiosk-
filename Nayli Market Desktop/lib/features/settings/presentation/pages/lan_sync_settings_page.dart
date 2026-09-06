import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_client.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/license_service.dart';
import '../widgets/pc_douchette_activation_modal.dart';
import '../../../product/presentation/bloc/product_bloc.dart';

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

  // Master PC Client Connection State
  String _connectedMasterIp = '';
  String _connectedMasterPort = '8080';
  String _connectedShopName = 'Nayli POS Master';
  bool _isTestingMaster = false;
  String? _masterPingResult;

  @override
  void initState() {
    super.initState();
    _isServerRunning = LocalSyncServer.isRunning;
    _loadMasterInfo();
    _refreshNetwork();
  }

  void _loadMasterInfo() {
    setState(() {
      _connectedMasterIp = HiveDatabase.settingsBox.get('master_pos_ip', defaultValue: '') as String;
      _connectedMasterPort = HiveDatabase.settingsBox.get('master_pos_port', defaultValue: '8080').toString();
      _connectedShopName = HiveDatabase.settingsBox.get('shop_name', defaultValue: 'Nayli POS Master') as String;
    });
  }

  Future<void> _scanMasterQrCode() async {
    SoundService.playTabSwitch();
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      await _processScannedMasterCode(result);
    }
  }

  Future<void> _processScannedMasterCode(String rawCode) async {
    setState(() {
      _isTestingMaster = true;
      _masterPingResult = 'جاري الاتصال والتحقق من كاشير الكمبيوتر...';
    });

    try {
      String ip = '';
      String port = '8080';
      String shopName = 'كاشير الكمبيوتر الرئيسي';

      final trimmed = rawCode.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final data = jsonDecode(trimmed) as Map<String, dynamic>;
        ip = data['ip']?.toString() ?? '';
        port = data['port']?.toString() ?? '8080';
        shopName = data['name']?.toString() ?? data['shopName']?.toString() ?? 'Nayli POS Master';
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final uri = Uri.tryParse(trimmed);
        if (uri != null) {
          ip = uri.host;
          if (uri.port > 0) port = uri.port.toString();
        }
      } else if (trimmed.contains(':')) {
        final parts = trimmed.replaceAll('nayli_lan_pair:', '').trim().split(':');
        if (parts.isNotEmpty) ip = parts[0];
        if (parts.length > 1) port = parts[1];
      }

      ip = ip.trim();
      port = port.trim();

      if (ip.isNotEmpty && ip != '127.0.0.1') {
        final url = Uri.parse('http://$ip:$port/api/status');
        final res = await http.get(url).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          await HiveDatabase.settingsBox.put('master_pos_ip', ip);
          await HiveDatabase.settingsBox.put('master_pos_port', port);
          await HiveDatabase.settingsBox.put('sync_server_ip', '$ip:$port');
          await HiveDatabase.settingsBox.put('shop_name', shopName);
          await LocalSyncClient.setServerIp('$ip:$port');
          await LicenseService.grantCompanionLicense(storeName: shopName, masterIp: ip);

          setState(() {
            _connectedMasterIp = ip;
            _connectedMasterPort = port;
            _connectedShopName = shopName;
            _masterPingResult = '✅ متصل بنجاح مع كاشير الكمبيوتر ($ip:$port)';
          });

          SoundService.playCheckoutSuccess();
          HapticFeedback.heavyImpact();

          if (mounted) {
            context.showAppSnackBar(
              '🎉 تم ربط الهاتف بنجاح مع كاشير: $shopName ($ip:$port)',
              backgroundColor: Colors.green.shade800,
              icon: Icons.wifi_tethering_rounded,
            );
          }

          // Automatically pull products from Master
          final count = await LocalSyncClient.pullProductsFromMaster();
          if (count > 0 && mounted) {
            context.read<ProductBloc>().add(LoadProducts());
            context.showAppSnackBar(
              '🔄 تم جلب وتحديث $count سلعة من الكمبيوتر بنجاح!',
              backgroundColor: Colors.teal.shade800,
              icon: Icons.sync_rounded,
            );
          }
        } else {
          setState(() {
            _masterPingResult = '⚠️ استجاب السيرفر برمز غير متوقع: ${res.statusCode}';
          });
          SoundService.playVoidWarning();
        }
      } else {
        setState(() {
          _masterPingResult = '❌ لم يتم العثور على عنوان IP صالح في الكود الممسوح.';
        });
        SoundService.playVoidWarning();
      }
    } catch (e) {
      setState(() {
        _masterPingResult = '❌ تعذر الوصول لكاشير الكمبيوتر: تأكد من اتصالهما بنفس شبكة الواي فاي (Wi-Fi).';
      });
      SoundService.playVoidWarning();
    } finally {
      if (mounted) setState(() => _isTestingMaster = false);
    }
  }

  void _showManualIpDialog() {
    final ipCtrl = TextEditingController(
      text: _connectedMasterIp.isNotEmpty ? '$_connectedMasterIp:$_connectedMasterPort' : '192.168.1.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('إدخال عنوان IP الكمبيوتر يدوياً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اكتب عنوان IP المنشور في برنامج الكمبيوتر (مثال: 192.168.1.15 أو 192.168.1.15:8080):',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: '192.168.1.15:8080',
                prefixIcon: Icon(Icons.computer_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('اتصال وحفظ'),
            onPressed: () {
              Navigator.pop(ctx);
              _processScannedMasterCode(ipCtrl.text.trim());
            },
          ),
        ],
      ),
    );
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

  Future<void> _fixWindowsFirewall() async {
    if (!Platform.isWindows) return;
    try {
      final port = LocalSyncServer.port;
      final command = 'Start-Process powershell -ArgumentList "-Command \\"netsh advfirewall firewall add rule name=\'Nayli POS Sync\' dir=in action=allow protocol=TCP localport=$port\\"" -Verb RunAs';
      await Process.run('powershell', ['-c', command]);
      setState(() {
        _pingStatus = '✅ تم إرسال طلب فتح منفذ $port في جدار الحماية (وافق على صلاحيات الإدارة إذا ظهرت لك).';
      });
    } catch (e) {
      setState(() {
        _pingStatus = '❌ فشل في تعديل جدار الحماية، يرجى فتحه يدوياً. خطأ: $e';
      });
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة الشبكة والمزامنة (LAN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: !isWide,
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
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. PHONE TO MASTER PC PAIRING SECTION (Scan QR with Camera or Manual IP)
              _buildPhoneToMasterPairingCard(),
              const SizedBox(height: 16),

              // 2. Master Server Toggle Card
              Container(
                padding: const EdgeInsets.all(16),
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
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'سيرفر المزامنة والربط المحلي',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isServerRunning ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _isServerRunning ? Colors.green.shade200 : Colors.red.shade200),
                                ),
                                child: Text(
                                  _isServerRunning ? 'نشط 🟢' : 'متوقف 🔴',
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
                            'يتيح لهواتف العمال مسح السلع وإرسال السلات والمزامنة الفورية عبر الشبكة المحلية (Wi-Fi) دون إنترنت.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, height: 1.4),
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
              const SizedBox(height: 16),

              // 2. Dual Pane: QR Code Pairing & Network Details (Responsive)
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildQrCard(qrPayload)),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: _buildNetworkDetailsAndDiagnostics()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildQrCard(qrPayload),
                    const SizedBox(height: 16),
                    _buildNetworkDetailsAndDiagnostics(),
                  ],
                ),
              const SizedBox(height: 16),

              // 3. Connected Clients Stream & Queue (Responsive Stats Bar)
              StreamBuilder<int>(
                stream: LocalSyncServer.clientsStream,
                initialData: LocalSyncServer.connectedClients,
                builder: (context, snapshot) {
                  final clients = snapshot.data ?? 0;
                  final pending = LocalSyncServer.pendingRemoteCarts.length;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatBox('الهواتف الموصولة', '$clients', Icons.phone_android_rounded, Colors.teal),
                        ),
                        Container(height: 36, width: 1, color: Colors.grey.shade200),
                        Expanded(
                          child: _buildStatBox('السلات المعلقة', '$pending', Icons.shopping_bag_outlined, Colors.indigo),
                        ),
                        Container(height: 36, width: 1, color: Colors.grey.shade200),
                        Expanded(
                          child: _buildStatBox('البروتوكول', 'HTTP Local', Icons.security_rounded, Colors.purple),
                        ),
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

  Widget _buildQrCard(String qrPayload) {
    return Container(
      width: double.infinity,
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
            padding: const EdgeInsets.all(10),
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
              size: 160,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'امسح هذا الرمز من هاتف العامل للربط التلقائي فوراً!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkDetailsAndDiagnostics() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 10),
              _buildInfoRow('منفذ الاتصال (Port):', '${LocalSyncServer.port}', Icons.electrical_services_rounded),
              const SizedBox(height: 10),
              _buildInfoRow('رابط الشبكة الكامل:', 'http://$_localIp:${LocalSyncServer.port}', Icons.link_rounded, isUrl: true),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Diagnostics & Ping Card
        Container(
          width: double.infinity,
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
                  _isTestingPing ? 'جاري الفحص...' : 'فحص استجابة السيرفر المحلي (Ping)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                onPressed: _isTestingPing || !_isServerRunning ? null : _testPing,
              ),
              if (Platform.isWindows && _isServerRunning) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.security, size: 18),
                  label: const Text(
                    'إصلاح جدار الحماية (Windows Firewall)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: _fixWindowsFirewall,
                ),
              ],
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
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isUrl = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.indigo),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                ),
              ),
              if (isUrl) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    SoundService.playSaveSuccess();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📋 تم نسخ الرابط بنجاح!'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: Colors.indigo),
                        SizedBox(width: 4),
                        Text('نسخ', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), textAlign: TextAlign.center, maxLines: 1),
      ],
    );
  }

  Widget _buildPhoneToMasterPairingCard() {
    final isConnected = _connectedMasterIp.isNotEmpty && _connectedMasterIp != '127.0.0.1';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.teal.shade300 : const Color(0xFFE2E8F0),
          width: isConnected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnected ? Colors.teal.withOpacity(0.08) : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.teal.shade50 : Colors.indigo.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.phonelink_ring_rounded : Icons.qr_code_scanner_rounded,
                  color: isConnected ? Colors.teal : Colors.indigo,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ربط الهاتف مع كاشير الكمبيوتر الرئيسي 📲 ↔️ 🖥️',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'امسح كود QR المعروض على شاشة الكمبيوتر لربط الهاتف ونقل السلات والمخزون',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Badge Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isConnected ? Colors.teal.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isConnected ? Colors.teal.shade200 : Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isConnected ? Colors.teal : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'متصل حالياً بكاشير: $_connectedShopName' : 'الهاتف غير مربوط بكاشير الكمبيوتر حالياً',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: isConnected ? Colors.teal.shade900 : Colors.black87,
                        ),
                      ),
                      if (isConnected) ...[
                        const SizedBox(height: 2),
                        Text(
                          'عنوان السيرفر: http://$_connectedMasterIp:$_connectedMasterPort',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.teal),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isConnected)
                  IconButton(
                    tooltip: 'قطع الربط',
                    icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () async {
                      await HiveDatabase.settingsBox.delete('master_pos_ip');
                      await HiveDatabase.settingsBox.delete('sync_server_ip');
                      await LocalSyncClient.setServerIp('');
                      setState(() {
                        _connectedMasterIp = '';
                        _masterPingResult = null;
                      });
                      SoundService.playDeleteSound();
                      if (mounted) {
                        context.showAppSnackBar('تم إلغاء ربط الهاتف بالسيرفر');
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Scan with Camera & Manual IP
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text(
                    'مسح كود الكمبيوتر (QR) 📸',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isTestingMaster ? null : _scanMasterQrCode,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('إدخال IP ✍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _showManualIpDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Douchette Activation Button (Mobile -> PC)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text(
              'عرض رمز تفعيل الحاسوب بقارئ الباركود (Douchette) 🔫 📲',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () => PcDouchetteActivationModal.show(context),
          ),

          // If connected, provide 1-click sync button
          if (isConnected) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade50,
                foregroundColor: Colors.indigo.shade900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.indigo.shade200),
                ),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18, color: Colors.indigo),
              label: const Text(
                '🔄 مزامنة وجلب كافة السلع والأسعار من الكمبيوتر الآن',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () async {
                SoundService.playClick();
                context.showAppSnackBar('جاري مزامنة السلع من كاشير الكمبيوتر...');
                final count = await LocalSyncClient.pullProductsFromMaster();
                if (mounted) {
                  if (count > 0) {
                    context.read<ProductBloc>().add(LoadProducts());
                    SoundService.playSaveSuccess();
                    context.showAppSnackBar(
                      '✅ تمت مزامنة $count منتج بنجاح!',
                      backgroundColor: Colors.teal.shade800,
                    );
                  } else {
                    context.showAppSnackBar('لا توجد سلع جديدة أو تعذر الاتصال بالسيرفر');
                  }
                }
              },
            ),
          ],

          if (_masterPingResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _masterPingResult!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _masterPingResult!.startsWith('✅') ? Colors.teal.shade800 : Colors.red.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

