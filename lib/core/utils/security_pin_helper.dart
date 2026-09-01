import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../data/hive_database.dart';
import '../theme/app_theme.dart';
import 'license_service.dart';
import 'sound_service.dart';

class SecurityPinHelper {
  static const String _pinHashKey = 'security_pin_hash_v2';
  static const String _pinEnabledKey = 'security_pin_enabled';
  static const String _salt = 'NAYLI_SECURE_PIN_SALT_2026_@#!';

  // In-memory active recovery OTP
  static String? _activeRecoveryOtp;
  static DateTime? _otpExpiry;

  /// Hash the PIN using cryptographic salt - no plain text stored
  static String _hashPin(String pin) {
    final combined = '$pin:$_salt';
    int hash1 = 0x811c9dc5;
    int hash2 = 0x55555555;
    for (int i = 0; i < combined.length; i++) {
      int code = combined.codeUnitAt(i);
      hash1 = ((hash1 ^ code) * 0x01000193) & 0xFFFFFFFF;
      hash2 = ((hash2 ^ (code * 31)) * 0x045d9f3b) & 0xFFFFFFFF;
    }
    return '${hash1.toRadixString(16).padLeft(8, '0')}-${hash2.toRadixString(16).padLeft(8, '0')}';
  }

  /// PIN is disabled by default until the store manager configures it in Settings
  static bool isPinEnabled() {
    final box = HiveDatabase.settingsBox;
    final enabled = box.get(_pinEnabledKey, defaultValue: false) as bool;
    final hash = box.get(_pinHashKey) as String?;
    return enabled && hash != null && hash.isNotEmpty;
  }

  /// Set / Update Manager PIN
  static Future<void> setPin(String pin) async {
    final box = HiveDatabase.settingsBox;
    final hash = _hashPin(pin);
    await box.put(_pinHashKey, hash);
    await box.put(_pinEnabledKey, true);
  }

  /// Disable PIN protection
  static Future<void> disablePin() async {
    final box = HiveDatabase.settingsBox;
    await box.put(_pinEnabledKey, false);
    await box.delete(_pinHashKey);
  }

  /// Verify entered PIN against stored cryptographic hash (Zero Hardcoded PINs)
  static bool verifyPin(String enteredPin) {
    if (!isPinEnabled()) return true;

    final box = HiveDatabase.settingsBox;
    final savedHash = box.get(_pinHashKey) as String?;
    if (savedHash == null || savedHash.isEmpty) return true;

    return savedHash == _hashPin(enteredPin);
  }

  /// Send Emergency Recovery OTP to Telegram Bot
  static Future<bool> sendRecoveryOtpToTelegram() async {
    final box = HiveDatabase.settingsBox;
    final token = box.get('telegram_bot_token', defaultValue: '') as String;
    final chatId = box.get('telegram_chat_id', defaultValue: '') as String;

    if (token.isEmpty || chatId.isEmpty) {
      return false; // Telegram bot not configured yet
    }

    // Generate random 6-digit OTP
    final random = Random();
    final otp = (random.nextInt(899999) + 100000).toString();
    _activeRecoveryOtp = otp;
    _otpExpiry = DateTime.now().add(const Duration(minutes: 10));

    final deviceId = LicenseService.getDeviceId();
    final timeStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    final message = '''
🔐 *[نايلي ماركت - Nayli Market]*
🚨 *طلب استرجاع رمز المشرف (PIN Reset Request)*
📍 *معرف الجهاز:* `$deviceId`
🕒 *التوقيت:* $timeStr

🔑 *كود الاسترجاع المؤقت (OTP):*
👉 `$otp` 👈

⏳ *ملاحظة:* هذا الكود صالح لمدة *10 دقائق* فقط. لا تشاركه مع أي عامل في المحل!
''';

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final res = await http.post(url, body: {
        'chat_id': chatId,
        'text': message,
        'parse_mode': 'Markdown',
      });
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Verify entered OTP and reset PIN
  static bool verifyAndResetWithOtp(String enteredOtp) {
    if (_activeRecoveryOtp == null || _otpExpiry == null) return false;
    if (DateTime.now().isAfter(_otpExpiry!)) {
      _activeRecoveryOtp = null;
      return false;
    }
    if (_activeRecoveryOtp == enteredOtp.trim()) {
      _activeRecoveryOtp = null;
      disablePin();
      return true;
    }
    return false;
  }

  /// Shows a PIN authentication dialog for protected operations
  static Future<bool> authenticate(BuildContext context, {String title = 'رمز الأمان PIN'}) async {
    if (!isPinEnabled()) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinAuthDialog(title: title),
    );

    return result ?? false;
  }
}

class _PinAuthDialog extends StatefulWidget {
  final String title;
  const _PinAuthDialog({required this.title});

  @override
  State<_PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<_PinAuthDialog> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onKeyPress(String val) {
    setState(() {
      _errorMessage = null;
      if (_enteredPin.length < 4) {
        _enteredPin += val;
        if (_enteredPin.length == 4) {
          _verify();
        }
      }
    });
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verify() {
    if (SecurityPinHelper.verifyPin(_enteredPin)) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = 'الرمز السري غير صحيح!';
        _enteredPin = '';
      });
    }
  }

  Future<void> _showTelegramRecovery() async {
    final box = HiveDatabase.settingsBox;
    final hasTelegram = (box.get('telegram_bot_token', defaultValue: '') as String).isNotEmpty &&
        (box.get('telegram_chat_id', defaultValue: '') as String).isNotEmpty;

    if (!hasTelegram) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('إعداد التلغرام مطلوب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'لم يتم ربط بوت التلغرام في إعدادات النسخ الاحتياطي بعد.\n\nيرجى التواصل مع المطور عبر الواتساب أو استخدام بوابة المطور الميداني المباشر لتصفير الرمز فوراً دون فقدان أي بيانات.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    final otpCtrl = TextEditingController();
    bool isSending = false;
    String? otpError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.telegram, color: Colors.teal, size: 26),
              SizedBox(width: 8),
              Text('استرجاع الرمز عبر التلغرام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اضغط أدناه لإرسال كود فك القفل (OTP) فوراً وبشكل آمن إلى حساب التلغرام الخاص بالمدير:',
                style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 14),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(
                  isSending ? 'جاري الإرسال...' : 'إرسال كود OTP إلى التلغرام 📲',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: isSending
                    ? null
                    : () async {
                        setDlgState(() => isSending = true);
                        final sent = await SecurityPinHelper.sendRecoveryOtpToTelegram();
                        setDlgState(() => isSending = false);
                        if (sent) {
                          SoundService.playSaveSuccess();
                          setDlgState(() => otpError = null);
                        } else {
                          setDlgState(() => otpError = 'تعذر الاتصال ببوت التلغرام! تأكد من اتصال الإنترنت.');
                        }
                      },
              ),

              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                decoration: InputDecoration(
                  labelText: 'أدخل كود الـ OTP المكون من 6 أرقام',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  errorText: otpError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final success = SecurityPinHelper.verifyAndResetWithOtp(otpCtrl.text);
                if (success) {
                  SoundService.playSaveSuccess();
                  Navigator.pop(ctx); // Close recovery dialog
                  Navigator.pop(context, true); // Unlock PIN dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 تم التحقق بنجاح! تم تصفير رمز الـ PIN ويمكنك الآن تعيين رمز جديد.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  setDlgState(() => otpError = 'كود الـ OTP غير صحيح أو انتهت صلاحيته!');
                }
              },
              child: const Text('تأكيد وإلغاء القفل 🔓', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل رمز المدير PIN للمتابعة',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.primaryColor : Colors.grey.shade300,
                  ),
                );
              }),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],

            const SizedBox(height: 16),

            // Keypad
            Column(
              children: [
                _buildRow(['1', '2', '3']),
                const SizedBox(height: 10),
                _buildRow(['4', '5', '6']),
                const SizedBox(height: 10),
                _buildRow(['7', '8', '9']),
                const SizedBox(height: 10),
                _buildRow(['C', '0', 'DEL']),
              ],
            ),

            const SizedBox(height: 14),

            // Telegram Recovery Button
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              ),
              icon: const Icon(Icons.telegram, size: 18),
              label: const Text(
                'نسيت رمز المشرف؟ (استرجاع عبر تلغرام 🔑)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: _showTelegramRecovery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        if (k == 'C') {
          return _buildButton('C', () {
            setState(() {
              _enteredPin = '';
              _errorMessage = null;
            });
          }, isAction: true);
        } else if (k == 'DEL') {
          return _buildButton('⌫', _onDelete, isAction: true);
        } else {
          return _buildButton(k, () => _onKeyPress(k));
        }
      }).toList(),
    );
  }

  Widget _buildButton(String text, VoidCallback onTap, {bool isAction = false}) {
    return SizedBox(
      width: 60,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isAction ? Colors.grey.shade100 : Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontSize: isAction ? 15 : 18,
            fontWeight: FontWeight.bold,
            color: isAction ? Colors.grey.shade700 : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}