import 'package:flutter/material.dart';

extension AppSnackBarExtension on BuildContext {
  void showAppSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF1E293B),
    Duration duration = const Duration(milliseconds: 1200),
    int? durationMs,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.clearSnackBars();
    final effectiveBg = isError ? const Color(0xFFDC2626) : backgroundColor;
    final effectiveIcon = icon ?? (isError ? Icons.error_outline : null);
    final screenWidth = MediaQuery.of(this).size.width;
    final isDesktop = screenWidth >= 650;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (effectiveIcon != null) ...[
              Icon(effectiveIcon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'إغلاق',
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.amber,
                onPressed: onAction ?? () {},
              )
            : null,
        backgroundColor: effectiveBg,
        duration: durationMs != null ? Duration(milliseconds: durationMs) : (duration.inMilliseconds < 2000 ? const Duration(milliseconds: 2200) : duration),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        width: isDesktop ? 480 : null,
        margin: isDesktop ? null : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),
    );
  }
}

class SnackbarHelper {
  static void showSuccess(BuildContext context, String message) {
    context.showAppSnackBar(message, backgroundColor: const Color(0xFF059669), icon: Icons.check_circle_outline);
  }

  static void showWarning(BuildContext context, String message) {
    context.showAppSnackBar(message, backgroundColor: const Color(0xFFD97706), icon: Icons.warning_amber_rounded);
  }

  static void showError(BuildContext context, String message) {
    context.showAppSnackBar(message, backgroundColor: const Color(0xFFDC2626), icon: Icons.error_outline);
  }

  static void showInfo(BuildContext context, String message) {
    context.showAppSnackBar(message, backgroundColor: const Color(0xFF2563EB), icon: Icons.info_outline);
  }
}
