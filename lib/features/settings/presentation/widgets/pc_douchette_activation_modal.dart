import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/license_service.dart';
import '../../../../core/utils/sound_service.dart';

class PcDouchetteActivationModal extends StatefulWidget {
  const PcDouchetteActivationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PcDouchetteActivationModal(),
    );
  }

  @override
  State<PcDouchetteActivationModal> createState() => _PcDouchetteActivationModalState();
}

class _PcDouchetteActivationModalState extends State<PcDouchetteActivationModal> {
  late Map<String, dynamic> _tokenData;
  Timer? _countdownTimer;
  int _secondsRemaining = 15 * 60; // 15 minutes

  @override
  void initState() {
    super.initState();
    _refreshToken();
    _startTimer();
  }

  void _refreshToken() {
    setState(() {
      _tokenData = LicenseService.generateDouchetteActivationData();
      final exp = _tokenData['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      _secondsRemaining = ((exp - now) / 1000).clamp(0, 15 * 60).toInt();
    });
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _refreshToken(); // Auto-refresh when expired
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final barcodeStr = _tokenData['barcode']?.toString() ?? '';
    final shortPin = _tokenData['shortPin']?.toString() ?? '';
    final storeName = _tokenData['storeName']?.toString() ?? 'متجر كاشير';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF38BDF8), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفعيل الحاسوب بقارئ الباركود (Douchette) 🔫',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ترخيص معتمد لمتجر: $storeName',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instruction Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'وجّه قارئ الباركود (الدوشيت) الموصول بالحاسوب نحو الرمز أدناه واضغط الزناد (BEEP) لتفعيل برنامج الحاسوب فوراً!',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // High-Contrast QR Code Card
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: barcodeStr,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Theme.of(context).cardColor,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Short PIN Box (Fallback for 1D laser scanners)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كود التفعيل المختصر (إذا تعذر مسح الشاشة):',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10.5),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        shortPin,
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'نسخ الكود',
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shortPin));
                      SoundService.playSaveSuccess();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 تم نسخ الكود المختصر!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Expiry countdown & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'صلاحية الرمز: ${_formatTime(_secondsRemaining)} دقيقة',
                      style: const TextStyle(color: Colors.orange, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('تحديث الرمز', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                  onPressed: () {
                    SoundService.playTabSwitch();
                    _refreshToken();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
