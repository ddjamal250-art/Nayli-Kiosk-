import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../billing/data/kiosk_service.dart';

class KioskSettingsPage extends StatefulWidget {
  const KioskSettingsPage({super.key});

  @override
  State<KioskSettingsPage> createState() => _KioskSettingsPageState();
}

class _KioskSettingsPageState extends State<KioskSettingsPage> {
  final TextEditingController _greetingTitleCtrl = TextEditingController();
  final TextEditingController _greetingSubtitleCtrl = TextEditingController();

  int _displayDuration = 10;
  String _arrowDirection = 'down';
  String _serverIp = '127.0.0.1';
  int _serverPort = 8080;

  List<Map<String, dynamic>> _unlistedScans = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUnlistedScans();
    _fetchServerInfo();
  }

  @override
  void dispose() {
    _greetingTitleCtrl.dispose();
    _greetingSubtitleCtrl.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final cfg = KioskService.getSettings();
    setState(() {
      _displayDuration = cfg['productDisplayDuration'] as int? ?? 10;
      _arrowDirection = cfg['arrowDirection'] as String? ?? 'down';
      _greetingTitleCtrl.text = cfg['greetingTitle'] as String? ?? 'مرحباً بكم في متجرنا';
      _greetingSubtitleCtrl.text = cfg['greetingSubtitle'] as String? ?? 'مرر باركود السلعة تحت الماسح لمعرفة السعر';
    });
  }

  void _loadUnlistedScans() {
    setState(() {
      _unlistedScans = KioskService.getUnlistedScans();
    });
  }

  void _fetchServerInfo() async {
    final ip = await LocalSyncServer.getLocalIp();
    setState(() {
      _serverIp = ip;
      _serverPort = LocalSyncServer.port;
    });
  }

  Future<void> _save() async {
    await KioskService.saveSettings(
      productDisplayDuration: _displayDuration,
      arrowDirection: _arrowDirection,
      greetingTitle: _greetingTitleCtrl.text.trim(),
      greetingSubtitle: _greetingSubtitleCtrl.text.trim(),
    );
    SoundService.playCheckoutSuccess();
    if (mounted) {
      SnackbarHelper.showSuccess(context, '✅ تم حفظ إعدادات الكشك وشاشات العروض بنجاح');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kioskWebUrl = 'http://' + _serverIp + ':' + _serverPort.toString() + '/kiosk';

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات كشك فاحص الأسعار وشاشات العروض 🛍️'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.fullscreen_rounded, size: 20),
            label: const Text('تشغيل الكشك الآن 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => context.push('/kiosk'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tv_rounded, color: Color(0xFF818CF8), size: 28),
                    SizedBox(width: 10),
                    Text(
                      'ربط الشاشات الذكية وأجهزة Android TV Box بالشبكة 🌐',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'افتح متصفح الويب على أي شاشة ذكية أو جهاز TV Box في الرواق واكتب الرابط المباشر أدناه ليعمل كشك فاحص الأسعار فورياً دون تثبيت أي برامج:',
                  style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade300.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          kioskWebUrl,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                        tooltip: 'تجربة في المتصفح',
                        onPressed: () => launchUrlString(kioskWebUrl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. التخصيص العام والرسائل الترحيبية ✍️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _greetingTitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الترحيب الرئيسي',
                      hintText: 'مثلاً: مرحباً بكم في سوبرماركت البركة',
                      prefixIcon: Icon(Icons.title_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _greetingSubtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'التعليمات الإرشادية للزبون',
                      hintText: 'مثلاً: مرر باركود السلعة تحت الماسح لمعرفة السعر',
                      prefixIcon: Icon(Icons.info_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مدة بقاء السلعة على الشاشة (ثوانٍ) ⏱️',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('الوقت الذي تبقى فيه تفاصيل السلعة قبل الرجوع لوضع العروض',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          _displayDuration.toString() + ' ثانية',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _displayDuration.toDouble(),
                    min: 3,
                    max: 45,
                    divisions: 42,
                    label: _displayDuration.toString() + ' ثانية',
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (val) {
                      setState(() {
                        _displayDuration = val.round();
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  const Text('2. اتجاه سهم إرشاد موقع الماسح ⬇️',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('حدد الموضع الفعلي لقارئ الباركود نسبةً للشاشة ليدل السهم الزبائن بدقة:',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    children: [
                      ChoiceChip(
                        label: const Text('⬇️ نحو الأسفل (تحت الشاشة)'),
                        selected: _arrowDirection == 'down',
                        onSelected: (sel) => setState(() => _arrowDirection = 'down'),
                      ),
                      ChoiceChip(
                        label: const Text('⏺️ نحو الزبون مباشرة'),
                        selected: _arrowDirection == 'front',
                        onSelected: (sel) => setState(() => _arrowDirection = 'front'),
                      ),
                      ChoiceChip(
                        label: const Text('⬅️ على جهة اليسار'),
                        selected: _arrowDirection == 'left',
                        onSelected: (sel) => setState(() => _arrowDirection = 'left'),
                      ),
                      ChoiceChip(
                        label: const Text('➡️ على جهة اليمين'),
                        selected: _arrowDirection == 'right',
                        onSelected: (sel) => setState(() => _arrowDirection = 'right'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('حفظ الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notification_important_rounded, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Text(
                            'سجل السلع المنسية غير المسجلة (' + _unlistedScans.length.toString() + ') ⚠️',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      if (_unlistedScans.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                          label: const Text('مسح السجل', style: TextStyle(color: Colors.red, fontSize: 12)),
                          onPressed: () async {
                            await KioskService.clearAllUnlistedScans();
                            _loadUnlistedScans();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'قائمة الباركودات التي مسحها الزبائن في أروقة المحل ولم تكن مسجلة في المخزون. يمكنك إضافتها بنقرة واحدة فوراً:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  if (_unlistedScans.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.done_all_rounded, color: Colors.teal.shade300, size: 42),
                          const SizedBox(height: 8),
                          const Text(
                            'ممتاز! لا توجد سلع ممسوحة غير مسجلة حالياً',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _unlistedScans.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = _unlistedScans[idx];
                        final barcode = item['barcode']?.toString() ?? '';
                        final count = item['scanCount'] ?? 1;
                        final lastTime = DateTime.tryParse(item['lastScanned']?.toString() ?? '');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepOrange.shade50,
                            child: Text(
                              count.toString(),
                              style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                barcode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('مسحت ' + count.toString() + ' مرات', style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            lastTime != null
                                ? 'آخر مسح: ' + DateFormat('yyyy/MM/dd HH:mm').format(lastTime)
                                : '',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('أضف السلعة الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  await context.push('/add-product?barcode=' + barcode);
                                  await KioskService.removeUnlistedScan(barcode);
                                  _loadUnlistedScans();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                tooltip: 'تجاهل',
                                onPressed: () async {
                                  await KioskService.removeUnlistedScan(barcode);
                                  _loadUnlistedScans();
                                },
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
        ],
      ),
    );
  }
}
