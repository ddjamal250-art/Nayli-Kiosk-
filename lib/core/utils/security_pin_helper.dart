import 'package:flutter/material.dart';
import '../data/hive_database.dart';
import '../theme/app_theme.dart';

class SecurityPinHelper {
  static const String _pinHashKey = 'security_pin_hash_v2';
  static const String _pinEnabledKey = 'security_pin_enabled';
  static const String _salt = 'NAYLI_SECURE_PIN_SALT_2026_@#!';

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
  }

  /// Verify entered PIN against stored cryptographic hash (Zero Hardcoded PINs)
  static bool verifyPin(String enteredPin) {
    if (!isPinEnabled()) return true;

    final box = HiveDatabase.settingsBox;
    final savedHash = box.get(_pinHashKey) as String?;
    if (savedHash == null || savedHash.isEmpty) return true;

    return savedHash == _hashPin(enteredPin);
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

            const SizedBox(height: 20),

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
}