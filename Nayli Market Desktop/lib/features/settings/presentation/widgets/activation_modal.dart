import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'developer_master_portal.dart';

class ActivationModal extends StatefulWidget {
  const ActivationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ActivationModal(),
    );
  }

  @override
  State<ActivationModal> createState() => _ActivationModalState();
}

class _ActivationModalState extends State<ActivationModal> {
  final TextEditingController _keyController = TextEditingController();
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _activateApp() {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال مفتاح التفعيل');
      return;
    }

    final success = LicenseService.activate(key);
    if (success) {
      setState(() {
        _isSuccess = true;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 مبروك! تم تفعيل التطبيق بشكل دائم على هذا الجهاز!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      setState(() {
        _errorMessage = '❌ مفتاح التفعيل غير صحيح أو لا يطابق معرّف هذا الهاتف!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = LicenseService.getDeviceId();
    final isActivated = LicenseService.isActivated();
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
              Row(
                children: [
                  Icon(
                    isActivated ? Icons.verified_user_rounded : Icons.vpn_key_rounded,
                    color: isActivated ? Colors.green : AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'تفعيل وترخيص التطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActivated
                  ? Colors.green.withOpacity(0.08)
                  : (remainingDays > 0 ? Colors.orange.withOpacity(0.08) : Colors.red.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActivated
                    ? Colors.green.withOpacity(0.3)
                    : (remainingDays > 0 ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActivated
                      ? Icons.check_circle
                      : (remainingDays > 0 ? Icons.timer_outlined : Icons.lock_outline),
                  color: isActivated
                      ? Colors.green
                      : (remainingDays > 0 ? Colors.orange : Colors.red),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActivated
                            ? '✅ النسخة الأصلية مفعلة مدى الحياة'
                            : (remainingDays > 0
                                ? '⏳ فترة تجريبية مجانية (متبقي $remainingDays أيام)'
                                : '❌ انتهت الفترة التجريبية'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isActivated
                              ? Colors.green[800]
                              : (remainingDays > 0 ? Colors.orange[900] : Colors.red[900]),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isActivated
                            ? 'الترخيص مقترن بهذا الهاتف رسمياً'
                            : 'أدخل مفتاح التفعيل لفتح التطبيق بشكل دائم',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Device ID Display Box
          const Text(
            'معرّف هذا الهاتف (Hardware ID):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  deviceId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('نسخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: deviceId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 تم نسخ معرّف الجهاز! أرسله للمطور لتوليد كود التفعيل'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!isActivated) ...[
            // Key Input
            const Text(
              'أدخل مفتاح التفعيل (Activation Key):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _keyController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'مثال: A1B2-C3D4-E5F6-G7H8',
                prefixIcon: const Icon(Icons.key, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _activateApp,
              child: const Text(
                'تفعيل التطبيق الآن (Activate)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Discreet Developer Onsite Access
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
              label: const Text(
                'تفعيل المطور الميداني السريع (Master Admin)',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () {
                Navigator.pop(context);
                DeveloperMasterPortal.show(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}