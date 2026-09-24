import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SingleInstanceService {
  static const String _lockFileName = 'nayli_kiosk.lock';
  static File? _lockFile;

  /// يرجع true إذا هذا هو الـ instance الأول
  /// يرجع false ويحضر النافذة الموجودة إذا كان في instance شغال
  static Future<bool> acquireSingleInstance() async {
    if (!Platform.isWindows) return true;
    
    try {
      final appData = await getApplicationSupportDirectory();
      final lockPath = '${appData.path}\\$_lockFileName';
      _lockFile = File(lockPath);
      
      // إذا الملف موجود، تحقق من الـ PID
      if (await _lockFile!.exists()) {
        final content = await _lockFile!.readAsString();
        final oldPid = int.tryParse(content.trim());
        
        if (oldPid != null && _isProcessRunning(oldPid)) {
          // Instance موجود ➜ أحضره للواجهة
          await _bringExistingToFront(oldPid);
          return false; // أغلق هذا الـ instance
        }
      }
      
      // اكتب الـ PID الحالي
      await _lockFile!.writeAsString('${pid}');
      return true; // هذا الـ instance الأول
      
    } catch (e) {
      debugPrint('SingleInstance check error: $e');
      return true; // fail-safe
    }
  }
  
  static bool _isProcessRunning(int targetPid) {
    try {
      // على Windows: نرسل signal 0 للـ process (في dart نستعمل sigusr1 أو نتحقق من powershell)
      // الأفضل والأضمن على الويندوز هو استدعاء powershell لفحص الـ ID
      final result = Process.runSync('powershell', [
        '-Command',
        'Get-Process -Id $targetPid -ErrorAction SilentlyContinue'
      ]);
      return result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  
  static Future<void> _bringExistingToFront(int targetPid) async {
    // استخدام Windows API عبر shell command
    try {
      await Process.run('powershell', [
        '-Command',
        '(Get-Process -Id $targetPid).MainWindowHandle | '
        'ForEach-Object { if (\$_ -ne 0) { [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms"); [void][Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic"); [Microsoft.VisualBasic.Interaction]::AppActivate($targetPid) } }'
      ]);
    } catch (_) {}
  }
  
  static Future<void> releaseLock() async {
    try {
      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
      }
    } catch (_) {}
  }
}
