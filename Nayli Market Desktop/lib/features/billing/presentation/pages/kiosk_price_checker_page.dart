import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/kiosk_service.dart';

enum _KioskState { idle, found, notFound }

class KioskPriceCheckerPage extends StatefulWidget {
  const KioskPriceCheckerPage({super.key});

  @override
  State<KioskPriceCheckerPage> createState() => _KioskPriceCheckerPageState();
}

class _KioskPriceCheckerPageState extends State<KioskPriceCheckerPage>
    with TickerProviderStateMixin {
  _KioskState _state = _KioskState.idle;
  KioskProductResult? _currentResult;

  late AnimationController _arrowAnimCtrl;
  late Animation<double> _arrowPulse;

  Timer? _dismissTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 10;
  int _displayDuration = 10;
  String _arrowDirection = 'down';
  String _greetingTitle = 'مرحباً بكم في متجرنا';
  String _greetingSubtitle = 'مرر باركود السلعة تحت الماسح لمعرفة السعر';

  // تجميع نقرات الباركود العتادية (Hardware Buffer) دون فقدان التركيز
  String _buffer = '';
  DateTime _lastKeyTime = DateTime.now();

  // عداد نقرات الخروج السري للمدير
  int _secretTapCount = 0;
  Timer? _secretTapResetTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _arrowAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _arrowPulse = Tween<double>(begin: 0.88, end: 1.15).animate(
      CurvedAnimation(parent: _arrowAnimCtrl, curve: Curves.easeInOut),
    );

    // تسجيل المستمع العتادي العام (Global Hardware Listener)
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);

    // فرض ملء الشاشة التام للكشك وإخفاء أشرطة النظام (Immersive Sticky Fullscreen)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(true);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    // استعادة وضع الشاشة العادي عند الخروج
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final isFull = HiveDatabase.settingsBox.get('is_app_fullscreen', defaultValue: false) == true;
      if (!isFull) {
        windowManager.setFullScreen(false);
      }
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _arrowAnimCtrl.dispose();
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    _secretTapResetTimer?.cancel();
    super.dispose();
  }

  void _loadSettings() {
    final cfg = KioskService.getSettings();
    setState(() {
      _displayDuration = cfg['productDisplayDuration'] as int? ?? 10;
      _secondsLeft = _displayDuration;
      _arrowDirection = cfg['arrowDirection'] as String? ?? 'down';
      _greetingTitle = cfg['greetingTitle'] as String? ?? 'مرحباً بكم في متجرنا';
      _greetingSubtitle = cfg['greetingSubtitle'] as String? ??
          'مرر باركود السلعة تحت الماسح لمعرفة السعر';
    });
  }

  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (now.difference(_lastKeyTime).inMilliseconds > 200) {
        _buffer = '';
      }
      _lastKeyTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final code = _buffer.trim();
        _buffer = '';
        if (code.length >= 3) {
          _lookup(code);
        }
        return true;
      }

      final char = event.character;
      if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
        _buffer += char;
      }
    }
    return false;
  }

  void _lookup(String barcode) {
    final result = KioskService.lookupBarcode(barcode);

    _dismissTimer?.cancel();
    _countdownTimer?.cancel();

    if (result.found) {
      SoundService.playBarcodeBeep();
      setState(() {
        _state = _KioskState.found;
        _currentResult = result;
        _secondsLeft = _displayDuration;
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _secondsLeft--;
          if (_secondsLeft <= 0) {
            timer.cancel();
            _returnToIdle();
          }
        });
      });

      _dismissTimer = Timer(Duration(seconds: _displayDuration), () {
        if (mounted) _returnToIdle();
      });
    } else {
      SoundService.playWarning();
      setState(() {
        _state = _KioskState.notFound;
        _currentResult = result;
      });

      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) _returnToIdle();
      });
    }
  }

  void _returnToIdle() {
    _dismissTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _state = _KioskState.idle;
      _currentResult = null;
      _secondsLeft = _displayDuration;
    });
  }

  void _handleSecretTap() async {
    _secretTapCount++;
    _secretTapResetTimer?.cancel();
    _secretTapResetTimer = Timer(const Duration(seconds: 2), () {
      _secretTapCount = 0;
    });

    if (_secretTapCount >= 3) {
      _secretTapCount = 0;
      final auth = await SecurityPinHelper.authenticate(
        context,
        title: '🔐 خروج المشرف من وضع الكشك',
        message: 'أدخل رمز المشرف العام للتحكم في هذا الجهاز أو تغيير دوره',
      );
      if (auth && mounted) {
        final isKioskRole = HiveDatabase.settingsBox.get('device_role') == 'customer_kiosk';
        if (isKioskRole) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('خيارات خروج المشرف من الكشك'),
              content: const Text(
                'هل تريد الخروج مؤقتاً، أم إلغاء وضع الكشك لهذا الجهاز وتحويله إلى كاشير عادي؟',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('خروج مؤقت للرئيسية'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    await HiveDatabase.settingsBox.put('device_role', 'cashier');
                    Navigator.pop(ctx);
                    SoundService.playSaveSuccess();
                    context.go('/activation');
                  },
                  child: const Text('إلغاء وضع الكشك (تحويل لكاشير)', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // الخلفية الفاخرة ذات التدرج الضوئي
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.7, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1E1B4B),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),

          // الهيدر العلوي مع الشعار المخفي للنقر
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleSecretTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: Color(0xFF818CF8), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _greetingTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'كشك فاحص الأسعار الذكي',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // المحتوى التفاعلي الرئيسي
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  );
                },
                child: _buildCurrentView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_state) {
      case _KioskState.idle:
        return _buildIdleView();
      case _KioskState.found:
        return _buildFoundView();
      case _KioskState.notFound:
        return _buildNotFoundView();
    }
  }

  Widget _buildIdleView() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // أيقونة المحل والترحيب
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4F46E5).withOpacity(0.15),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.3),
                blurRadius: 35,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF818CF8), size: 68),
        ),
        const SizedBox(height: 28),

        // العنوان الترحيبي العريض
        Text(
          _greetingTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF8FAFC),
            shadows: [
              Shadow(color: Color(0xFF4F46E5), blurRadius: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // التعليمات التوجيهية
        Text(
          _greetingSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            color: Colors.blueGrey.shade300,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 38),

        // سهم إرشاد موقع الماسح المتحرك النابض
        _buildScannerPointer(),
      ],
    );
  }

  Widget _buildScannerPointer() {
    IconData icon;
    String label = 'وجه الباركود إلى هنا لمعرفة السعر';

    switch (_arrowDirection) {
      case 'front':
        icon = Icons.radio_button_checked_rounded;
        label = 'وجه الباركود أمام الماسح مباشرة';
        break;
      case 'left':
        icon = Icons.arrow_back_rounded;
        label = 'الماسح على جهة اليسار ⬅️';
        break;
      case 'right':
        icon = Icons.arrow_forward_rounded;
        label = 'الماسح على جهة اليمين ➡️';
        break;
      case 'down':
      default:
        icon = Icons.arrow_downward_rounded;
        label = 'وجه الباركود تحت الشاشة للأسفل ⬇️';
        break;
    }

    return ScaleTransition(
      scale: _arrowPulse,
      child: Column(
        children: [
          Icon(
            icon,
            size: 58,
            color: const Color(0xFFF59E0B),
            shadows: const [
              Shadow(color: Color(0xFFF59E0B), blurRadius: 20),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundView() {
    final p = _currentResult;
    if (p == null) return const SizedBox();

    return Container(
      key: const ValueKey('found'),
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شارة التوفر والقسم
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'متوفر على الرف ✅',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (p.category != null && p.category!.isNotEmpty)
                Text(
                  p.category!,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // اسم السلعة
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              p.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // حاوية السعر الضخم عالي التباين
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF6366F1), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  blurRadius: 25,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  p.price.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF38BDF8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'DA',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF818CF8),
                  ),
                ),
              ],
            ),
          ),

          // تفاصيل الميزان إن كان وزناً
          if (p.isWeighed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.4)),
              ),
              child: Text(
                'الوزن:  كغ  •  سعر الكيلوغرام:  DA',
                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],

          // عرض سعر الحزمة / الفاردو التوفيري
          if (p.packPrice > 0 && p.packMultiplier > 1) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Text(
                '🌟 متوفر أيضاً كـ  x بسعر  DA' +
                    (p.savings > 0 ? ' (توفير  DA!)' : ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // مؤشر العد التنازلي للعودة لشاشة العروض
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: _secondsLeft / (_displayDuration > 0 ? _displayDuration : 1),
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'يعود لوضع العروض بعد  ثوانٍ',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Container(
      key: const ValueKey('notFound'),
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withOpacity(0.28),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline_rounded, color: Color(0xFFFCA5A5), size: 62),
          const SizedBox(height: 18),
          const Text(
            'عذراً! هذا المنتج غير مسجل بعد في النظام',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFEE2E2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تم إشعار الكاشير بنسيان إضافة السلعة، تفضل بسؤال موظف المحل لمساعدتك فوراً 🤝',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.red.shade100,
            ),
          ),
        ],
      ),
    );
  }
}
