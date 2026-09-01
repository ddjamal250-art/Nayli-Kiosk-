import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/staff_permissions_service.dart';
import '../../../../core/utils/expiry_tracker_service.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/data/local_sync_server.dart';
import '../../../product/presentation/pages/expiry_monitor_page.dart';

class AdvancedPosSettingsPage extends StatefulWidget {
  const AdvancedPosSettingsPage({super.key});

  @override
  State<AdvancedPosSettingsPage> createState() => _AdvancedPosSettingsPageState();
}

class _AdvancedPosSettingsPageState extends State<AdvancedPosSettingsPage> {
  late bool _strictStaff;
  late bool _hideCostProfit;
  late bool _pinForDiscount;
  late bool _pinForVoid;
  late bool _pinForReports;
  late bool _scaleBarcode;
  late String _scalePrefixes;
  late bool _fastShortcuts;
  late bool _customerDisplay;
  late bool _expiryTracking;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _strictStaff = StaffPermissionsService.isStrictStaffMode;
    _hideCostProfit = StaffPermissionsService.hideCostAndProfit;
    _pinForDiscount = StaffPermissionsService.requirePinForDiscount;
    _pinForVoid = StaffPermissionsService.requirePinForVoid;
    _pinForReports = StaffPermissionsService.requirePinForReports;
    _scaleBarcode = StaffPermissionsService.enableScaleBarcode;
    _scalePrefixes = StaffPermissionsService.scaleBarcodePrefixes.join(',');
    _fastShortcuts = StaffPermissionsService.enableFastKeyboardShortcuts;
    _customerDisplay = StaffPermissionsService.enableCustomerDisplay;
    _expiryTracking = StaffPermissionsService.enableExpiryTracking;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إعدادات نمط التشغيل المتقدم (اختياري 100%) 🎛️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.indigo, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هذه الخيارات تتيح لك تخصيص البرنامج بحرية كاملة؛ يمكنك تفعيل ما يناسب متجرك وإلغاء ما لا تحتاجه بنقرة واحدة.',
                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 1: ELECTRONIC SCALES
          _buildSectionHeader('1. موازين الخضر واللحوم الإلكترونية ⚖️', 'تكامل موازين السوبرماركت (Dibal, CAS, Bizerba, Aclas)'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل قراءة باركود الميزان التلقائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('استخراج الوزن أو السعر تلقائياً من الباركود (EAN-13 يبدأ بـ 20 أو 21) دون إدخال يدوي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _scaleBarcode,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _scaleBarcode = v);
                    await StaffPermissionsService.setEnableScaleBarcode(v);
                  },
                ),
                if (_scaleBarcode) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Text('بادئات الميزان المعتمدة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _scalePrefixes,
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                        TextButton(
                          onPressed: _editScalePrefixesDialog,
                          child: const Text('تعديل البادئات', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 2: KEYBOARD SHORTCUTS & QUICK VOID
          _buildSectionHeader('2. اختصارات الكيبورد السريعة وشارات الأزرار ⌨️', 'العمل بأقصى سرعة في أوقات الذروة دون لمس الفأرة'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل اختصارات لوحة المفاتيح والشارات المرئية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('عرض شارات [F1 - F12] وزر Delete لحذف السلعة فوراً وزري [+] و [-] لتغيير الكمية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _fastShortcuts,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _fastShortcuts = v);
                    await StaffPermissionsService.setEnableFastKeyboardShortcuts(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 3: STRICT STAFF PERMISSIONS
          _buildSectionHeader('3. صلاحيات الكاشير والتحكم الميداني الصارم 🔒', 'حماية أسرار المحل (أسعار الشراء، رأس المال، التخفيضات)'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الوضع المشدد الصارم الشامل (Strict Staff Mode)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange)),
                  subtitle: const Text('تفعيل كافة قيود الحماية دفعة واحدة بنقرة واحدة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _strictStaff,
                  activeColor: Colors.deepOrange,
                  onChanged: (v) async {
                    setState(() {
                      _strictStaff = v;
                      if (v) {
                        _hideCostProfit = true;
                        _pinForDiscount = true;
                        _pinForVoid = true;
                        _pinForReports = true;
                      }
                    });
                    await StaffPermissionsService.setStrictStaffMode(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('إخفاء سعر الشراء وهوامش الأرباح في الكاسة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('منع الكاشير أو العمال من رؤية فائدة السلع ورأس المال', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _hideCostProfit,
                  onChanged: (v) async {
                    setState(() => _hideCostProfit = v);
                    await StaffPermissionsService.setHideCostAndProfit(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('طلب رمز المدير (PIN) عند إجراء تخفيض', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('منع تقديم خصومات للزبائن إلا بعد إدخال رمز المدير', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _pinForDiscount,
                  onChanged: (v) async {
                    setState(() => _pinForDiscount = v);
                    await StaffPermissionsService.setRequirePinForDiscount(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('طلب رمز المدير (PIN) عند حذف سلعة أو تصفير السلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('منع التلاعبات وإلغاء السلع المسحوبة إلا بموافقة المسؤول', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _pinForVoid,
                  onChanged: (v) async {
                    setState(() => _pinForVoid = v);
                    await StaffPermissionsService.setRequirePinForVoid(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('قفل الداشبورد وتقارير الأرباح برمز المدير', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('منع فتح شاشات الأرباح والمصروفات إلا برمز PIN', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _pinForReports,
                  onChanged: (v) async {
                    setState(() => _pinForReports = v);
                    await StaffPermissionsService.setRequirePinForReports(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 4: CUSTOMER DISPLAY
          _buildSectionHeader('4. شاشة الزبون الثانية (Customer Facing Display) 🖥️', 'عرض مشتريات الزبون ومجموع الحساب أمامه مباشرة'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل شاشة الزبون (بث الويب المحلي)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('بث السلة المباشرة إلى شاشة ثانية HDMI أو أي تابلات / هاتف متصل بنفس الويفي', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _customerDisplay,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _customerDisplay = v);
                    await StaffPermissionsService.setEnableCustomerDisplay(v);
                  },
                ),
                if (_customerDisplay) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('رابط فتح شاشة الزبون في أي متصفح بالشبكة المحلية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 18, color: Colors.indigo),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('http://localhost:8080/display', style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  SnackbarHelper.showInfo(context, 'افتح هذا الرابط على شاشة الزبون أو التابلات المواجهة له.');
                                },
                                child: const Text('تعليمات', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 5: EXPIRY MONITORING
          _buildSectionHeader('5. تتبع الصلاحية وتنبيهات التلغرام ⏳', 'مراقبة السلع المقتربة من تاريخ النهاية لتفادي الخسائر'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('تفعيل نظام مراقبة الصلاحية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('حساب الأيام المتبقية وتنبيه التاجر قبل انتهاء السلع بـ 7 و 15 و 30 يوماً', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _expiryTracking,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) async {
                    setState(() => _expiryTracking = v);
                    await StaffPermissionsService.setEnableExpiryTracking(v);
                  },
                ),
                if (_expiryTracking) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.table_chart_outlined, color: Colors.white, size: 18),
                            label: const Text('فتح شاشة مراقبة الصلاحية', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpiryMonitorPage())),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: const Text('إرسال للتلغرام', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final ok = await ExpiryTrackerService.sendExpiryAlertToTelegram();
                            if (mounted) {
                              if (ok) {
                                SnackbarHelper.showSuccess(context, 'تم إرسال التقرير بنجاح إلى التلغرام!');
                              } else {
                                SnackbarHelper.showWarning(context, 'يرجى ربط التلغرام أو لا توجد سلع قاربت الصلاحية.');
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _editScalePrefixesDialog() {
    final ctrl = TextEditingController(text: _scalePrefixes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بادئات ميزان الباركود', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'البادئات مفصولة بفاصلة (مثال: 20,21,22,28)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() => _scalePrefixes = val);
                await StaffPermissionsService.setScaleBarcodePrefixes(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
