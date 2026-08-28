import 'package:flutter/material.dart';
import '../data/hive_database.dart';
import '../theme/app_theme.dart';

class SecurityPinHelper {
  static const String _pinKey = 'security_pin_code';
  static const String _pinEnabledKey = 'security_pin_enabled';

  static bool isPinEnabled() {
    final box = HiveDatabase.settingsBox;
    return box.get(_pinEnabledKey, defaultValue: false) as bool;
  }

  static String? getSavedPin() {
    final box = HiveDatabase.settingsBox;
    return box.get(_pinKey) as String?;
  }

  static Future<void> setPin(String pin) async {
    final box = HiveDatabase.settingsBox;
    await box.put(_pinKey, pin);
    await box.put(_pinEnabledKey, true);
  }

  static Future<void> disablePin() async {
    final box = HiveDatabase.settingsBox;
    await box.put(_pinEnabledKey, false);
  }

  static bool verifyPin(String enteredPin) {
    final saved = getSavedPin();
    if (saved == null || saved.isEmpty) return true;
    return saved == enteredPin;
  }

  /// Shows a PIN authentication bottom sheet or dialog
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 8),
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل الرمز السري (4 أرقام) للوصول لهذه الصفحة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? AppTheme.primaryColor : Colors.grey[300],
                  ),
                );
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),

            // Numpad (1 to 9, C, 0, DEL)
            Column(
              children: [
                _buildRow(['1', '2', '3']),
                const SizedBox(height: 8),
                _buildRow(['4', '5', '6']),
                const SizedBox(height: 8),
                _buildRow(['7', '8', '9']),
                const SizedBox(height: 8),
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
        final isSpecial = k == 'C' || k == 'DEL';
        return InkWell(
          onTap: () {
            if (k == 'C') {
              setState(() => _enteredPin = '');
            } else if (k == 'DEL') {
              _onDelete();
            } else {
              _onKeyPress(k);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSpecial ? Colors.grey[100] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: k == 'DEL'
                ? const Icon(Icons.backspace_outlined, size: 18, color: Colors.red)
                : Text(
                    k,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: k == 'C' ? Colors.red : Colors.black87,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }
}