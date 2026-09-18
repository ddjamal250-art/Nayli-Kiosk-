import 'package:flutter/material.dart';
import '../services/github_update_service.dart';

/// واجهة فحص التحديثات المرجعية لتوافق المشاريع السابقة
class UpdateChecker {
  /// التحقق من وجود تحديثات جديدة
  static Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
    await GitHubUpdateService.checkForUpdates(context, silent: silent);
  }

  /// فحص تلقائي صامت عند الإقلاع
  static void runStartupCheck(BuildContext context) {
    GitHubUpdateService.runStartupCheck(context);
  }
}