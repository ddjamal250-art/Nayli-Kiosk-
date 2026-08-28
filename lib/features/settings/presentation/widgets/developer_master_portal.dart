import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/theme/app_theme.dart';

class DeveloperMasterPortal extends StatefulWidget {
  const DeveloperMasterPortal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const DeveloperMasterPortal(),
    );
  }

  @override
  State<DeveloperMasterPortal> createState() => _DeveloperMasterPortalState();
}

class _DeveloperMasterPortalState extends State<DeveloperMasterPortal> with SingleTickerProviderStateMixin {
  bool _isUnlocked = false;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _remoteIdController = TextEditingController();
  String? _generatedRemoteKey;
  String? _pinError;
  int _selectedTab = 0;
  String _selectedRemotePlan = 'P';

  @override
  void dispose() {
    _pinController.dispose();
    _remoteIdController.dispose();
    super.dispose();
  }

  void _verifyMasterPin() {
    if (_pinController.text.trim() == LicenseService.masterDeveloperPin) {
      setState(() {
        _isUnlocked = true;
        _pinError = null;
      });
    } else {
      setState(() {
        _pinError = '❌ رمز المطور السري غير صحيح!';
      });
    }
  }

  void _generateRemoteKey() {
    final rawId = _remoteIdController.text.trim();
    if (rawId.isEmpty) return;

    final key = LicenseService.generateKeyForDevice(rawId, plan: _selectedRemotePlan);
    setState(() {
      _generatedRemoteKey = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = LicenseService.getDeviceId();
    final isPerm = LicenseService.isPermanent();
    final remainingDays = LicenseService.getRemainingDays();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'لوحة تحكم وتوليد الرخص 🛠️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_isUnlocked) ...[
            const Text(
              'أدخل رمز المطور السري للوصول للوحة التفعيل وتوليد الأكواد:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'رمز المطور السري (Master PIN)',
                hintText: '2026',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _pinError,
                prefixIcon: const Icon(Icons.shield_outlined),
              ),
              onSubmitted: (_) => _verifyMasterPin(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _verifyMasterPin,
              child: const Text('دخول لوحة المطور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            // Tab Switcher
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.purple : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⚡ تفعيل هذا الهاتف',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 0 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.purple : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🧮 مُولّد أكواد لزبون عن بُعد',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 1 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              // TAB 0: Onsite Activation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('معرف هذا الهاتف: $deviceId', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('الحالة: ${LicenseService.getLicenseTypeLabel()}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    if (!isPerm) ...[
                      Text('المتبقي: $remainingDays يوم', style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildOptionCard(
                title: '🌟 تفعيل دائم مدى الحياة (Permanent Pro)',
                subtitle: 'فتح كافة الميزات لهذا الهاتف بنقرة واحدة',
                color: Colors.green,
                icon: Icons.verified_rounded,
                onTap: () async {
                  await LicenseService.grantPermanentLicense();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🎉 تم تفعيل التطبيق بشكل دائم مدى الحياة!'), backgroundColor: Colors.green),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),

              _buildOptionCard(
                title: '📅 ترخيص سنوي (1 سنة - 365 يوماً)',
                subtitle: 'اشتراك صالح لمدة عام كامل من اليوم',
                color: Colors.blue,
                icon: Icons.calendar_month_rounded,
                onTap: () async {
                  await LicenseService.grantCustomPlan(days: 365, isSubscription: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📅 تم تفعيل ترخيص سنوي (365 يوماً)!'), backgroundColor: Colors.blue),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),

              _buildOptionCard(
                title: '🟡 تجريبي لمدة شهر (30 يوماً)',
                subtitle: 'صالح لمدة 30 يوماً',
                color: Colors.orange,
                icon: Icons.timelapse_rounded,
                onTap: () async {
                  await LicenseService.grantCustomPlan(days: 30, isSubscription: false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🟡 تم تفعيل فترة تجريبية 30 يوماً!'), backgroundColor: Colors.orange),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),

              _buildOptionCard(
                title: '🔒 قفل التطبيق / إنهاء الصلاحية',
                subtitle: 'إلغاء التفعيل فوراً',
                color: Colors.red,
                icon: Icons.block_rounded,
                onTap: () async {
                  await LicenseService.revokeLicense();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔒 تم قفل التطبيق وإلغاء التفعيل!'), backgroundColor: Colors.red),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ] else ...[
              // TAB 1: Remote Key Generator
              const Text(
                'اختر الخطة وألصق معرّف هاتف الزبون لتوليد كود التفعيل المخصص:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // Plan Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRemotePlan,
                decoration: InputDecoration(
                  labelText: 'نوع الخطة / الترخيص',
                  prefixIcon: const Icon(Icons.stars_rounded, color: Colors.purple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'P', child: Text('🌟 تفعيل دائم مدى الحياة (Permanent Pro)')),
                  DropdownMenuItem(value: 'Y', child: Text('📅 اشتراك سنوي (1 سنة - 365 يوماً)')),
                  DropdownMenuItem(value: 'M', child: Text('🟡 تجريبي لمدة شهر (30 يوماً)')),
                  DropdownMenuItem(value: 'W', child: Text('⏳ تجريبي لمدة أسبوعين (14 يوماً)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRemotePlan = val;
                      _generatedRemoteKey = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _remoteIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'معرّف هاتف الزبون (Device ID)',
                  hintText: 'مثال: AH-8924-4B19-7F02',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        setState(() => _remoteIdController.text = data!.text!.trim());
                      }
                    },
                  ),
                ),
                onChanged: (_) => setState(() => _generatedRemoteKey = null),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.key, color: Colors.white),
                label: const Text('توليد كود التفعيل المخصص', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: _generateRemoteKey,
              ),

              if (_generatedRemoteKey != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'كود التفعيل الدائم المخصص لهذا الزبون:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _generatedRemoteKey!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                        label: const Text('نسخ الكود لإرساله عبر واتساب', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedRemoteKey!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('📋 تم نسخ كود التفعيل! يمكنك إرساله للزبون في واتساب'), backgroundColor: Colors.teal),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}