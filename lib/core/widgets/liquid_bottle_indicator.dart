import 'dart:math';
import 'package:flutter/material.dart';

/// نوع السائل لتحديد نمط ولون العرض الفاخر للقارورة
enum LiquidType { perfume, oilPerfume, cosmetics, hairCare, generic }

/// ويدجت قارورة زجاجية أنيقة ومتحركة توضح مستوى امتلاء السائل الحقيقي في المخزون
class LiquidBottleIndicator extends StatefulWidget {
  final double fillRatio; // 0.0 إلى 1.0 (مستوى الامتلاء)
  final double stockMl; // كمية المخزون بالمليلتر
  final String unitName; // مل، غرام، لتر
  final LiquidType liquidType;
  final bool animate; // تشغيل حركة الأمواج
  final double size; // ارتفاع القارورة الأساسي بالبكسل
  final bool showLabel; // إظهار نص المخزون وشريط النسبة

  const LiquidBottleIndicator({
    super.key,
    required this.fillRatio,
    required this.stockMl,
    this.unitName = 'مل',
    this.liquidType = LiquidType.generic,
    this.animate = true,
    this.size = 110.0,
    this.showLabel = true,
  });

  @override
  State<LiquidBottleIndicator> createState() => _LiquidBottleIndicatorState();
}

class _LiquidBottleIndicatorState extends State<LiquidBottleIndicator>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    // حركة تموج سطح السائل المستمرة
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) {
      _waveController.repeat();
    }

    // حركة انسيابية لتغير مستوى الامتلاء (نزول أو صعود السائل)
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fillAnimation = Tween<double>(
      begin: widget.fillRatio.clamp(0.0, 1.0),
      end: widget.fillRatio.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(LiquidBottleIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fillRatio != widget.fillRatio) {
      _fillAnimation = Tween<double>(
        begin: _fillAnimation.value,
        end: widget.fillRatio.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _fillController,
        curve: Curves.easeOutCubic,
      ));
      _fillController.forward(from: 0.0);
    }

    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  /// ألوان السائل الفاخرة بناءً على نوع السائل ونسبة المخزون المتبقي
  List<Color> get _liquidGradientColors {
    final ratio = widget.fillRatio;
    // تنبيه باللون عند انخفاض المخزون
    if (ratio <= 0.15) {
      return [const Color(0xFFD32F2F), const Color(0xFFFF5252), const Color(0xFFFF8A80)];
    }
    if (ratio <= 0.30) {
      return [const Color(0xFFE65100), const Color(0xFFFF9800), const Color(0xFFFFB74D)];
    }

    switch (widget.liquidType) {
      case LiquidType.perfume:
        // ذهبي وعنبري متلألئ للعطور الأصلية الفاخرة
        return [const Color(0xFFB7791F), const Color(0xFFD69E2E), const Color(0xFFF6E05E)];
      case LiquidType.oilPerfume:
        // أخضر زيتي ونباتي دافئ للعطور الزيتية
        return [const Color(0xFF276749), const Color(0xFF38A169), const Color(0xFF68D391)];
      case LiquidType.hairCare:
        // فيروزي بلوري لمستحضرات الشعر والكيراتين والبروتين
        return [const Color(0xFF007791), const Color(0xFF00A896), const Color(0xFF02C39A)];
      case LiquidType.cosmetics:
        // وردي وأرجواني ملكي لمستحضرات التجميل
        return [const Color(0xFF6B46C1), const Color(0xFF9F7AEA), const Color(0xFFD6BCFA)];
      case LiquidType.generic:
        return [const Color(0xFF004D40), const Color(0xFF00796B), const Color(0xFF4DB6AC)];
    }
  }

  Color get _accentColor => _liquidGradientColors[1];

  @override
  Widget build(BuildContext context) {
    final bottleWidth = widget.size * 0.65;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // القارورة المرسومة بـ CustomPaint
        AnimatedBuilder(
          animation: Listenable.merge([_waveController, _fillAnimation]),
          builder: (context, _) {
            return CustomPaint(
              size: Size(bottleWidth, widget.size),
              painter: _LuxuryBottlePainter(
                fillRatio: _fillAnimation.value,
                wavePhase: _waveController.value * 2 * pi,
                colors: _liquidGradientColors,
                accentColor: _accentColor,
              ),
            );
          },
        ),

        if (widget.showLabel) ...[
          const SizedBox(height: 6),
          // نص المخزون الحالي
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.stockMl < 1000
                    ? widget.stockMl == widget.stockMl.roundToDouble()
                        ? '${widget.stockMl.toInt()}'
                        : widget.stockMl.toStringAsFixed(1)
                    : (widget.stockMl / 1000.0).toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: widget.fillRatio <= 0.15
                      ? Colors.red.shade700
                      : const Color(0xFF004D40),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                widget.stockMl < 1000 ? widget.unitName : 'لتر',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),
          // شريط النسبة المئوية الصغير تحت القارورة
          Container(
            width: bottleWidth,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey.shade200,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: widget.fillRatio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [_liquidGradientColors.first, _liquidGradientColors.last],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// الرسام الهندسي الدقيق للقارورة الزجاجية الفاخرة وانعكاسات الضوء وتموجات السائل
class _LuxuryBottlePainter extends CustomPainter {
  final double fillRatio;
  final double wavePhase;
  final List<Color> colors;
  final Color accentColor;

  _LuxuryBottlePainter({
    required this.fillRatio,
    required this.wavePhase,
    required this.colors,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // === أبعاد أجزاء القارورة ===
    final capHeight = h * 0.14;
    final capWidth = w * 0.44;
    final neckTop = capHeight;
    final neckHeight = h * 0.10;
    final neckWidth = w * 0.28;
    final shoulderTop = neckTop + neckHeight;
    final bodyHeight = h - shoulderTop - (h * 0.04);
    final bodyBottom = h - (h * 0.04);

    // ==========================================
    // 1. المسار الداخلي للقارورة (وعاء السائل)
    // ==========================================
    final innerPath = Path();
    innerPath.moveTo(w * 0.5 - neckWidth * 0.5 + 2, shoulderTop);
    // كتف يسار
    innerPath.quadraticBezierTo(w * 0.12, shoulderTop + h * 0.06, w * 0.08, shoulderTop + h * 0.18);
    // جسم يسار
    innerPath.lineTo(w * 0.08, bodyBottom - h * 0.06);
    // قاع يسار
    innerPath.quadraticBezierTo(w * 0.08, bodyBottom, w * 0.22, bodyBottom);
    // قاع
    innerPath.lineTo(w * 0.78, bodyBottom);
    // قاع يمين
    innerPath.quadraticBezierTo(w * 0.92, bodyBottom, w * 0.92, bodyBottom - h * 0.06);
    // جسم يمين
    innerPath.lineTo(w * 0.92, shoulderTop + h * 0.18);
    // كتف يمين
    innerPath.quadraticBezierTo(w * 0.88, shoulderTop + h * 0.06, w * 0.5 + neckWidth * 0.5 - 2, shoulderTop);
    innerPath.close();

    // ==========================================
    // 2. خلفية الزجاج الشفاف بظل خفيف (Inner shadow)
    // ==========================================
    final glassBgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.40),
          Colors.teal.withOpacity(0.05),
          Colors.white.withOpacity(0.20),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, glassBgPaint);

    // ==========================================
    // 3. رسم السائل الداخلي مع تموجات السطح
    // ==========================================
    if (fillRatio > 0.005) {
      canvas.save();
      // قصر الرسم داخل حدود القارورة الداخلية
      canvas.clipPath(innerPath);

      final liquidTotalHeight = bodyHeight + (h * 0.04);
      final liquidCurrentHeight = liquidTotalHeight * fillRatio.clamp(0.0, 1.0);
      final liquidSurfaceY = bodyBottom - liquidCurrentHeight;

      // سعة الموجة (تخف عند الامتلاء الشديد أو القلة)
      final waveAmp = (fillRatio > 0.05 && fillRatio < 0.95) ? 3.0 : 1.0;

      final liquidPath = Path();
      liquidPath.moveTo(0, h);
      liquidPath.lineTo(0, liquidSurfaceY);

      // رسم سطح الموجة بدالة Sin
      for (double x = 0; x <= w; x += 3) {
        final progress = x / w;
        final waveY = liquidSurfaceY + sin(wavePhase + (progress * 2 * pi)) * waveAmp;
        liquidPath.lineTo(x, waveY);
      }

      liquidPath.lineTo(w, h);
      liquidPath.close();

      // تدرج لوني عمودي فاخر للسائل
      final liquidPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            colors[0].withOpacity(0.92),
            colors[1].withOpacity(0.85),
            colors.length > 2 ? colors[2].withOpacity(0.95) : colors[1].withOpacity(0.95),
          ],
        ).createShader(Rect.fromLTWH(0, liquidSurfaceY, w, liquidCurrentHeight + 10))
        ..style = PaintingStyle.fill;

      canvas.drawPath(liquidPath, liquidPaint);

      // خط بريق خفيف على سطح السائل
      final surfaceLinePaint = Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      final surfacePath = Path();
      for (double x = 0; x <= w; x += 3) {
        final progress = x / w;
        final waveY = liquidSurfaceY + sin(wavePhase + (progress * 2 * pi)) * waveAmp;
        if (x == 0) {
          surfacePath.moveTo(x, waveY);
        } else {
          surfacePath.lineTo(x, waveY);
        }
      }
      canvas.drawPath(surfacePath, surfaceLinePaint);

      canvas.restore();
    }

    // ==========================================
    // 4. المسار الخارجي لجدار الزجاج المزدوج
    // ==========================================
    final outerPath = Path();
    outerPath.moveTo(w * 0.5 - neckWidth * 0.5, neckTop);
    outerPath.lineTo(w * 0.5 - neckWidth * 0.5, shoulderTop);
    // كتف خارجي
    outerPath.quadraticBezierTo(w * 0.08, shoulderTop + h * 0.05, w * 0.04, shoulderTop + h * 0.18);
    // جسم خارجي
    outerPath.lineTo(w * 0.04, bodyBottom - h * 0.05);
    // قاع خارجي سميك
    outerPath.quadraticBezierTo(w * 0.04, bodyBottom + h * 0.03, w * 0.20, bodyBottom + h * 0.03);
    outerPath.lineTo(w * 0.80, bodyBottom + h * 0.03);
    outerPath.quadraticBezierTo(w * 0.96, bodyBottom + h * 0.03, w * 0.96, bodyBottom - h * 0.05);
    outerPath.lineTo(w * 0.96, shoulderTop + h * 0.18);
    outerPath.quadraticBezierTo(w * 0.92, shoulderTop + h * 0.05, w * 0.5 + neckWidth * 0.5, shoulderTop);
    outerPath.lineTo(w * 0.5 + neckWidth * 0.5, neckTop);
    outerPath.close();

    // إطار الزجاج الكريستالي
    final glassOutlinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.9),
          accentColor.withOpacity(0.4),
          const Color(0xFF004D40).withOpacity(0.7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(outerPath, glassOutlinePaint);

    // ==========================================
    // 5. انعكاس وبريق الضوء على الزجاج (Highlights)
    // ==========================================
    final highlightPath = Path();
    highlightPath.moveTo(w * 0.12, shoulderTop + h * 0.16);
    highlightPath.lineTo(w * 0.12, bodyBottom - h * 0.12);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.75),
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.60),
        ],
      ).createShader(Rect.fromLTWH(w * 0.12, shoulderTop, 2, bodyHeight))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(highlightPath, highlightPaint);

    // ==========================================
    // 6. رقبة القارورة وحلقة الذهب / المعدن
    // ==========================================
    final neckRect = Rect.fromCenter(
      center: Offset(w * 0.5, neckTop + neckHeight * 0.5),
      width: neckWidth,
      height: neckHeight,
    );
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD4AF37), Color(0xFFFFF2A1), Color(0xFFAA771C)],
      ).createShader(neckRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(2)),
      ringPaint,
    );

    // ==========================================
    // 7. غطاء القارورة الفاخر (Crystal/Gold Stopper)
    // ==========================================
    final capRect = Rect.fromCenter(
      center: Offset(w * 0.5, capHeight * 0.5),
      width: capWidth,
      height: capHeight,
    );

    final capGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2C3E50),
          const Color(0xFF004D40),
          accentColor.withOpacity(0.8),
          const Color(0xFF1A252F),
        ],
      ).createShader(capRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(5)),
      capGradient,
    );

    // حواف الغطاء المذهبة
    final capBorderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF2A1), Color(0xFFD4AF37), Color(0xFF8C6D14)],
      ).createShader(capRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(5)),
      capBorderPaint,
    );

    // بريق ماسي صغير في وسط الغطاء
    final capGemRect = Rect.fromCenter(
      center: Offset(w * 0.5, capHeight * 0.5),
      width: capWidth * 0.45,
      height: capHeight * 0.45,
    );
    final capGemPaint = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(capGemRect, const Radius.circular(2)),
      capGemPaint,
    );
  }

  @override
  bool shouldRepaint(_LuxuryBottlePainter old) {
    return old.fillRatio != fillRatio ||
        old.wavePhase != wavePhase ||
        old.colors != colors ||
        old.accentColor != accentColor;
  }
}
