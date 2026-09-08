import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/header_branding_cubit.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/sound_service.dart';

class PhotoshopColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const PhotoshopColorPickerDialog({super.key, required this.initialColor});

  static Future<Color?> show(BuildContext context, Color currentColor) {
    SoundService.playTabSwitch();
    return showDialog<Color>(
      context: context,
      builder: (ctx) => PhotoshopColorPickerDialog(initialColor: currentColor),
    );
  }

  @override
  State<PhotoshopColorPickerDialog> createState() => _PhotoshopColorPickerDialogState();
}

class _PhotoshopColorPickerDialogState extends State<PhotoshopColorPickerDialog> {
  late double _hue; // 0..360
  late double _saturation; // 0..1
  late double _value; // 0..1
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _onHexChanged(String hex) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) {
        final col = Color(0xFF000000 | val);
        final hsv = HSVColor.fromColor(col);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark ? const BorderSide(color: Color(0xFF1E293B)) : BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _currentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.colorize_rounded, color: _currentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دائرة الألوان الاحترافية (Color Wheel)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                      ),
                      const Text(
                        'اختر أي درجة لونية مخصصة لشريط الكاشير وهوية المحل',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Interactive Color Wheel
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: GestureDetector(
                  onPanDown: (details) => _handleWheelTouch(details.localPosition, 220),
                  onPanUpdate: (details) => _handleWheelTouch(details.localPosition, 220),
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: _ColorWheelPainter(
                      currentHue: _hue,
                      currentSaturation: _saturation,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Brightness / Value Slider
            Row(
              children: [
                const Icon(Icons.brightness_6_rounded, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _value,
                      min: 0.1,
                      max: 1.0,
                      activeColor: _currentColor,
                      inactiveColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
                      onChanged: (v) {
                        setState(() {
                          _value = v;
                          _hexController.text = _colorToHex(_currentColor);
                        });
                      },
                    ),
                  ),
                ),
                Text(
                  '${(_value * 100).toInt()}%',
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Live Preview and Hex Input
            Row(
              children: [
                // Color Preview Box
                Container(
                  width: 52,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _currentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Hex Code Input
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      labelText: 'كود اللون (HEX)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: _onHexChanged,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('cancel')),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentColor,
                    foregroundColor: _currentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('تطبيق وحفظ اللون', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final chosen = _currentColor;
                    final accent = chosen == const Color(0xFFFFFFFF)
                        ? const Color(0xFF06325C)
                        : (chosen.computeLuminance() < 0.2 ? const Color(0xFF38BDF8) : const Color(0xFFFF6600));

                    context.read<HeaderBrandingCubit>().setCustomColors(
                          headerColor: chosen,
                          accentColor: accent,
                        );
                    SoundService.playSaveSuccess();
                    Navigator.pop(context, chosen);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleWheelTouch(Offset pos, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final radius = size / 2;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Calculate angle in degrees (0..360)
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    // Saturation based on distance from center (clamped 0..1)
    final sat = (dist / radius).clamp(0.0, 1.0);

    setState(() {
      _hue = angle;
      _saturation = sat;
      _hexController.text = _colorToHex(_currentColor);
    });
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double currentHue;
  final double currentSaturation;

  _ColorWheelPainter({required this.currentHue, required this.currentSaturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw SweepGradient Hue Wheel
    final gradient = SweepGradient(
      colors: [
        for (int i = 0; i <= 360; i += 30)
          HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor(),
      ],
    );

    final wheelPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, wheelPaint);

    // Draw radial white overlay for saturation
    final satGradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withOpacity(0.0),
      ],
    );
    final satPaint = Paint()
      ..shader = satGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, satPaint);

    // Draw Thumb on current selection
    final angleRad = currentHue * math.pi / 180;
    final dist = currentSaturation * radius;
    final thumbX = center.dx + dist * math.cos(angleRad);
    final thumbY = center.dy + dist * math.sin(angleRad);

    final thumbCenter = Offset(thumbX, thumbY);
    canvas.drawCircle(
      thumbCenter,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );
    canvas.drawCircle(
      thumbCenter,
      8,
      Paint()
        ..color = HSVColor.fromAHSV(1.0, currentHue, currentSaturation, 1.0).toColor()
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.currentHue != currentHue || oldDelegate.currentSaturation != currentSaturation;
  }
}
