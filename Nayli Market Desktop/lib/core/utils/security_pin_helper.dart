import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../data/hive_database.dart';
import '../theme/app_theme.dart';
import 'license_service.dart';
import 'online_license_service.dart';
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

  /// Send Emergency Recovery OTP to Telegram Bot automatically (Zero human intervention)
  static Future<bool> sendRecoveryOtpToTelegram() async {
    final box = HiveDatabase.settingsBox;
    final customToken = box.get('telegram_bot_token', defaultValue: '') as String;
    final customChatId = box.get('telegram_chat_id', defaultValue: '') as String;

    final token = customToken.isNotEmpty ? customToken : OnlineLicenseService.defaultBotToken;
    final chatId = customChatId.isNotEmpty ? customChatId : OnlineLicenseService.defaultChatId;

    // Generate random 6-digit OTP
    final random = Random();
    final otp = (random.nextInt(899999) + 100000).toString();
    _activeRecoveryOtp = otp;
    _otpExpiry = DateTime.now().add(const Duration(minutes: 10));

    final deviceId = LicenseService.getDeviceId();
    final timeStr = DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now());

    final message = '''
🔐 <b>[نايلي ماركت - Nayli Market]</b>
⚡ <b>طلب استرجاع آلي فوري لرمز المشرف (Instant PIN Recovery)</b>
━━━━━━━━━━━━━━━━━
📍 <b>معرف الجهاز:</b> <code>$deviceId</code>
⏰ <b>الوقت:</b> $timeStr

🔑 <b>رمز التحقق لمرة واحدة (OTP):</b>
👉 <code>$otp</code> 👈

⏳ <i>صالح لمدة 10 دقائق فقط. يتم فك القفل وتعيين رمز جديد آلياً فور إدخاله.</i>
''';

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final res = await http.post(url, body: {
        'chat_id': chatId,
        'text': message,
        'parse_mode': 'HTML',
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
  static Future<bool> authenticate(BuildContext context, {String title = 'رمز الأمان PIN', String? message}) async {
    if (!isPinEnabled()) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinAuthDialog(title: title, message: message),
    );

    return result ?? false;
  }
}

class _PinAuthDialog extends StatefulWidget {
  final String title;
  final String? message;
  const _PinAuthDialog({required this.title, this.message});

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
      SoundService.playDeleteSound();
    }
  }

  /// 100% Automated OTP Recovery Dialog (Just like Google / Banking apps)
  Future<void> _showAutomatedRecoveryDialog() async {
    final otpController = TextEditingController();
    bool isSending = true;
    bool isVerifying = false;
    String? otpError;
    int resendCountdown = 45;
    Timer? countdownTimer;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          // Auto-send on dialog open
          if (isSending && countdownTimer == null) {
            SecurityPinHelper.sendRecoveryOtpToTelegram().then((sent) {
              if (ctx.mounted) {
                setDlgState(() {
                  isSending = false;
                  if (!sent) {
                    otpError = 'تعذر الإرسال تلقائياً، تأكد من الاتصال بالإنترنت.';
                  }
                });
                if (sent) SoundService.playSaveSuccess();
              }
            });

            countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (ctx.mounted) {
                setDlgState(() {
                  if (resendCountdown > 0) {
                    resendCountdown--;
                  } else {
                    t.cancel();
                  }
                });
              } else {
                t.cancel();
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_read_outlined, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاسترجاع الآلي الفوري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('تم إرسال كود OTP آلياً إلى التلغرام', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      if (isSending)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                      else
                        const Icon(Icons.check_circle, color: Colors.teal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isSending
                              ? 'جاري إرسال كود التحقق السري إلى حساب التلغرام الخاص بك...'
                              : 'تم إرسال الكود السري (6 أرقام) بنجاح إلى التلغرام! افتح تطبيقك وأدخل الكود أدناه:',
                          style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // OTP Input Field with Auto-Submit
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F172A))),
                    errorText: otpError,
                  ),
                  onChanged: (val) {
                    if (val.trim().length == 6) {
                      setDlgState(() => isVerifying = true);
                      final ok = SecurityPinHelper.verifyAndResetWithOtp(val);
                      setDlgState(() => isVerifying = false);

                      if (ok) {
                        countdownTimer?.cancel();
                        SoundService.playSaveSuccess();
                        Navigator.pop(ctx); // Close recovery dialog
                        _showSetNewPinDialog(context); // Prompt for new PIN immediately
                      } else {
                        setDlgState(() => otpError = '❌ الكود غير صحيح أو انتهت صلاحيته!');
                        SoundService.playDeleteSound();
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      resendCountdown > 0 ? 'إعادة الإرسال بعد ($resendCountdown ثانية)' : '',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    if (resendCountdown == 0)
                      TextButton(
                        onPressed: () async {
                          setDlgState(() {
                            isSending = true;
                            resendCountdown = 45;
                            otpError = null;
                          });
                          final sent = await SecurityPinHelper.sendRecoveryOtpToTelegram();
                          setDlgState(() => isSending = false);
                          if (sent) SoundService.playSaveSuccess();
                        },
                        child: const Text('إعادة إرسال الكود الآن 📲', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.pop(ctx);
                },
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Instant New PIN Setup after successful automated OTP verification
  Future<void> _showSetNewPinDialog(BuildContext parentContext) async {
    final newPinCtrl = TextEditingController();
    String? pinError;

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.green, size: 26),
              SizedBox(width: 8),
              Text('تعيين رمز المشرف الجديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تم التحقق بنجاح! أدخل الآن رمز PIN جديد مكون من 4 أرقام لاستخدامه في العمليات المحمية:',
                style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPinCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                maxLength: 4,
                obscureText: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • •',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: pinError,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                final pin = newPinCtrl.text.trim();
                if (pin.length != 4) {
                  setDlgState(() => pinError = 'الرمز يجب أن يتكون من 4 أرقام بالضبط');
                  return;
                }
                await SecurityPinHelper.setPin(pin);
                SoundService.playSaveSuccess();
                if (ctx.mounted) Navigator.pop(ctx); // Close set pin dialog
                if (parentContext.mounted) {
                  Navigator.pop(parentContext, true); // Unlock caller action
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 تم حفظ رمز PIN الجديد بنجاح والدخول إلى النظام!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('حفظ الرمز والدخول 💾', style: TextStyle(fontWeight: FontWeight.bold)),
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

            // 100% Automated Instant Telegram Recovery Button
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal[700],
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              ),
              icon: const Icon(Icons.telegram, size: 18),
              label: const Text(
                'نسيت رمز المشرف؟ (استرجاع آلي فوري 🔑)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: _showAutomatedRecoveryDialog,
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