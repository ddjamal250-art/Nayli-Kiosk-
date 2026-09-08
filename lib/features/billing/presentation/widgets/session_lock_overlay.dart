import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';

class SessionLockOverlay extends StatefulWidget {
  const SessionLockOverlay({super.key});

  static Future<void> show(BuildContext context) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: SessionLockOverlay(),
      ),
    );
  }

  @override
  State<SessionLockOverlay> createState() => _SessionLockOverlayState();
}

class _SessionLockOverlayState extends State<SessionLockOverlay> {
  late final DateTime _startTime;
  int _secondsPassed = 0;
  Timer? _timer;
  String _enteredPin = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsPassed++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onNumberTap(String n) {
    if (_enteredPin.length < 6) {
      setState(() {
        _errorMessage = null;
        _enteredPin += n;
      });
      SoundService.playKeyTap();
      if (_enteredPin.length >= 4) {
        _checkUnlock();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
      SoundService.playKeyTap();
    }
  }

  void _checkUnlock() {
    final pin = _enteredPin.trim();
    bool authorized = false;

    // 1. Check Manager PIN
    if (SecurityPinHelper.verifyPin(pin)) {
      authorized = true;
    }

    // 2. Check if Staff PIN matches
    if (!authorized) {
      final staffBox = HiveDatabase.staffBox;
      for (var key in staffBox.keys) {
        final staff = staffBox.get(key);
        if (staff is Map && (staff['pin']?.toString() == pin || staff['password']?.toString() == pin)) {
          authorized = true;
          break;
        }
      }
    }

    // 3. Fallback: if PIN protection is completely disabled in settings
    if (!authorized && !SecurityPinHelper.isPinEnabled()) {
      authorized = true;
    }

    if (authorized) {
      SoundService.playSaveSuccess();
      Navigator.pop(context);
    } else {
      SoundService.playDeleteSound();
      setState(() {
        _errorMessage = 'الرمز غير صحيح! أدخل رمز الكاشير أو رمز المدير';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xEE090D16),
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pause Icon & Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.shade400, width: 2),
                ),
                child: const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'جلسة البيع متوقفة مؤقتاً',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'الكاشير في فترة استراحة • السلة والبيانات مؤمنة 🔒',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Timer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'مدة الاستراحة: ${_formatDuration(_secondsPassed)}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // PIN Input Dots
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
                      color: isFilled ? AppTheme.primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isFilled ? AppTheme.primaryColor : Colors.grey.shade600,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              // Virtual Numpad
              _buildNumpad(),

              const SizedBox(height: 14),

              // Direct Resume Button (if PIN not set)
              if (!SecurityPinHelper.isPinEnabled())
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent),
                  label: const Text(
                    'استئناف الجلسة مباشرة (بدون رمز)',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['clear', '0', 'back'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key == 'clear') {
                  return _buildKeyBtn(
                    child: const Text('مسح', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    onTap: () => setState(() => _enteredPin = ''),
                  );
                }
                if (key == 'back') {
                  return _buildKeyBtn(
                    child: const Icon(Icons.backspace_outlined, color: Colors.grey, size: 20),
                    onTap: _onBackspace,
                  );
                }
                return _buildKeyBtn(
                  child: Text(key, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  onTap: () => _onNumberTap(key),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildKeyBtn({required Widget child, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 72,
      height: 48,
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
