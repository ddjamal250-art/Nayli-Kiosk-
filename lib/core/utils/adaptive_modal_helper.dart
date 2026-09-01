import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// أداة ذكية لعرض النوافذ المنبثقة بشكل متكيف:
/// - على الديسكتوب (Windows / Web / الشاشات العريضة >= 650px): تظهر كنافذة حوارية وسطية أنيقة (Centered Dialog).
/// - على الهواتف الذكية (الشاشات الصغيرة): تظهر كنافذة منبثقة من الأسفل (Modal BottomSheet).
class AdaptiveModalHelper {
  /// عرض نافذة متكيفة مع نوع الجهاز
  static Future<T?> showAdaptiveModal<T>({
    required BuildContext context,
    required Widget Function(BuildContext ctx) builder,
    double desktopMaxWidth = 540,
    double? desktopMaxHeight,
    bool isScrollControlled = true,
    Color backgroundColor = Colors.white,
    BorderRadius? borderRadius,
    bool barrierDismissible = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ||
        screenWidth >= 650;

    if (isDesktop) {
      final defaultRadius = borderRadius ?? BorderRadius.circular(20);
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (ctx) => Dialog(
          backgroundColor: backgroundColor,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktopMaxWidth,
              maxHeight: desktopMaxHeight ?? (MediaQuery.of(ctx).size.height * 0.85),
            ),
            child: ClipRRect(
              borderRadius: defaultRadius,
              child: Material(
                color: backgroundColor,
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    } else {
      final defaultRadius = borderRadius ?? const BorderRadius.vertical(top: Radius.circular(24));
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: barrierDismissible,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: defaultRadius),
        builder: builder,
      );
    }
  }
}

