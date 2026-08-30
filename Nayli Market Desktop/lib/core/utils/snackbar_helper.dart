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
  }) {
    final messenger = ScaffoldMessenger.of(this);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
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
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.amber,
                onPressed: onAction ?? () {},
              )
            : null,
        backgroundColor: backgroundColor,
        duration: durationMs != null ? Duration(milliseconds: durationMs) : duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
      ),
    );
  }
}
