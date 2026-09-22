import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/snackbar_helper.dart';
import '../utils/sound_service.dart';
import '../data/hive_database.dart';
import '../../features/billing/domain/entities/held_cart.dart';
import '../../features/billing/presentation/bloc/billing_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// كائن يحمل تفاصيل الإصدار الجديد من GitHub Releases
class GitHubReleaseInfo {
  final String tagName;
  final String cleanVersion;
  final String title;
  final String changelog;
  final String downloadUrl;
  final String assetName;
  final int sizeBytes;
  final DateTime? publishedAt;
  final bool isPrerelease;

  const GitHubReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.assetName,
    required this.sizeBytes,
    this.publishedAt,
    this.isPrerelease = false,
  });

  String get sizeFormatted {
    if (sizeBytes <= 0) return '';
    final double mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميغابايت';
  }
}

/// محرك التحديث السحابي الشامل عبر GitHub Releases
/// يعمل على كل من Windows Desktop و Android
/// وقابل للنسخ المباشر وإعادة الاستخدام في أي مشروع Flutter
class GitHubUpdateService {
  // =========================================================================
  // ⚙️ إعدادات المستودع (قابلة للتغيير في أي مشروع آخر بتعديل هذين السطرين فقط)
  // =========================================================================
  static const String repoOwner = 'ddjamal250-art';
  static const String repoName = 'Nayli-Kiosk-';

  /// رقم الإصدار الحالي المضمن في التطبيق لضمان دقة الفحص على الويندوز
  static const String currentAppVersion = '2.0.2';

  static bool _isChecking = false;
  static bool _hasAutoChecked = false;

  /// الحصول على رقم الإصدار الحالي للتطبيق بدقة مع بديل مضمون
  static Future<String> getAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final ver = packageInfo.version.trim();
      if (ver.isNotEmpty && ver != '1.0.0' && ver != '0.0.0') {
        return ver;
      }
    } catch (_) {}
    return currentAppVersion;
  }

  /// مقارنة ذكية ودقيقة لأرقام الإصدارات بحسب نظام Semantic Versioning
  /// ترجع true إذا كان remoteVersion أعلى من currentVersion
  static bool isNewerVersion(String currentVersion, String remoteVersion) {
    try {
      final cleanCurrent = currentVersion
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;

      final cleanRemote = remoteVersion
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split('+')
          .first
          .split('-')
          .first;

      if (cleanCurrent == cleanRemote) return false;

      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remoteParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = currentParts.length > remoteParts.length ? currentParts.length : remoteParts.length;

      for (int i = 0; i < maxLen; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// استعلام أحدث إصدار من واجهة GitHub Releases الرسمية المجانية
  static Future<GitHubReleaseInfo?> fetchLatestRelease() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Nayli-Kiosk-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final tagName = (data['tag_name'] ?? '').toString().trim();
      final cleanVer = tagName.replaceFirst(RegExp(r'^[vV]'), '');
      final title = (data['name'] ?? tagName).toString().trim();
      final body = (data['body'] ?? '').toString().trim();
      final publishedAtStr = data['published_at']?.toString();
      final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;
      final isPrerelease = data['prerelease'] == true;

      // مطابقة الملف المناسب لنظام التشغيل الحالي
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      String downloadUrl = '';
      String assetName = '';
      int sizeBytes = 0;

      if (Platform.isWindows) {
        for (final a in assets) {
          final name = (a['name'] ?? '').toString();
          if (name.toLowerCase().endsWith('.exe')) {
            assetName = name;
            downloadUrl = a['browser_download_url']?.toString() ?? '';
            sizeBytes = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      } else if (Platform.isAndroid) {
        for (final a in assets) {
          final name = (a['name'] ?? '').toString();
          if (name.toLowerCase().endsWith('.apk')) {
            assetName = name;
            downloadUrl = a['browser_download_url']?.toString() ?? '';
            sizeBytes = (a['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      // إذا لم يكن هناك ملف تثبيت جاهز ومطابق لنظام التشغيل الحالي، لا نقترح التحديث حتى يكتمل رفعه رسمياً
      if (downloadUrl.isEmpty) {
        return null;
      }

      return GitHubReleaseInfo(
        tagName: tagName,
        cleanVersion: cleanVer,
        title: title.isNotEmpty ? title : 'الإصدار $cleanVer',
        changelog: _cleanChangelog(body),
        downloadUrl: downloadUrl,
        assetName: assetName,
        sizeBytes: sizeBytes,
        publishedAt: publishedAt,
        isPrerelease: isPrerelease,
      );
    } catch (e) {
      debugPrint('⚠️ GitHubUpdateService error: $e');
      return null;
    }
  }

  /// تنقية وتطهير سجل التغييرات من أي مصطلحات برمجية أو روابط خارجية
  static String _cleanChangelog(String raw) {
    if (raw.trim().isEmpty) {
      return '• تحسينات عامة في أداء واستقرار النظام.\n• تحديثات لواجهة الكاشير وسرعة الاستجابة.\n• أيقونات وشعارات رسمية جديدة عالية الدقة.';
    }

    final lines = raw.split('\n');
    final cleaned = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      if (lower.contains('github') ||
          lower.contains('ota') ||
          lower.contains('commit') ||
          lower.contains('workflow') ||
          lower.contains('actions') ||
          lower.contains('repo') ||
          lower.contains('http://') ||
          lower.contains('https://') ||
          lower.contains('sha')) {
        continue;
      }

      cleaned.add(trimmed);
    }

    if (cleaned.isEmpty) {
      return '• تحسينات عامة في أداء واستقرار النظام.\n• تحديثات لواجهة الكاشير وسرعة الاستجابة.\n• أيقونات وشعارات رسمية جديدة عالية الدقة.';
    }

    return cleaned.join('\n');
  }

  /// حفظ السلة الحالية المفتوحة في قاعدة البيانات المحلية قبل إجراء أي تحديث
  static Future<void> saveActiveCartBeforeUpdate(BuildContext context) async {
    try {
      final billingBloc = context.read<BillingBloc>();
      final items = billingBloc.state.cartItems;
      if (items.isNotEmpty) {
        final held = HeldCart(
          id: 'auto_saved_${DateTime.now().millisecondsSinceEpoch}',
          label: 'سلة محفوظة تلقائياً قبل التحديث',
          parkedAt: DateTime.now(),
          items: List.from(items),
        );
        await HiveDatabase.settingsBox.put('auto_saved_cart_before_update', held.toMap());
        debugPrint('[GitHubUpdateService] Active cart (${items.length} items) saved to Hive');
      }
    } catch (e) {
      debugPrint('[GitHubUpdateService] Could not auto-save cart: $e');
    }
  }

  /// التحقق من التحديثات
  /// [silent]: إذا كانت true (مثل عند بدء تشغيل البرنامج) لا تظهر أي رسالة إذا لم يكن هناك تحديث.
  /// إذا كانت false (عند ضغط المستخدم على زر الفحص في الإعدادات) تظهر رسالة تفيد بنتيجة الفحص.
  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    if (_isChecking) return;
    _isChecking = true;

    if (!silent) {
      SnackbarHelper.showInfo(context, 'جاري التحقق من وجود تحديثات رسمية جديدة عبر السحابة...');
    }

    try {
      final currentVersion = await getAppVersion();
      final latestRelease = await fetchLatestRelease();

      if (!context.mounted) return;

      if (latestRelease != null && isNewerVersion(currentVersion, latestRelease.cleanVersion)) {
        SoundService.playRestockSound();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _UpdateDialog(
            currentVersion: currentVersion,
            releaseInfo: latestRelease,
          ),
        );
      } else {
        if (!silent) {
          SoundService.playSaveSuccess();
          SnackbarHelper.showSuccess(
            context,
            'أنت تستخدم أحدث إصدار متاح حالياً (v$currentVersion) ✅',
          );
        }
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      if (!silent && context.mounted) {
        SnackbarHelper.showWarning(context, 'تعذر الاتصال بسيرفر التحديثات، تحقق من اتصال الإنترنت.');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// فحص تلقائي صامت عند بدء تشغيل التطبيق (مع مهلة تأخير 5 ثوانٍ لعدم إبطاء الإقلاع)
  static void runStartupCheck(BuildContext context) {
    if (_hasAutoChecked) return;
    _hasAutoChecked = true;

    Future.delayed(const Duration(seconds: 5), () async {
      if (!context.mounted) return;

      final lastInstalledTag = HiveDatabase.settingsBox.get('last_installed_update_tag') as String?;
      final lastDismissedTag = HiveDatabase.settingsBox.get('last_dismissed_update_tag') as String?;
      final lastDismissedTimeStr = HiveDatabase.settingsBox.get('last_dismissed_update_time') as String?;

      final latestRelease = await fetchLatestRelease();
      if (latestRelease == null) return;

      final currentVersion = await getAppVersion();

      // إذا كان الإصدار المثبت يطابق أو أحدث من الإصدار السحابي، نوقف الفحص فوراً
      if (!isNewerVersion(currentVersion, latestRelease.cleanVersion)) {
        return;
      }

      // منع التكرار إذا كان هذا الإصدار قد تم تثبيته بالفعل
      if (lastInstalledTag != null && (lastInstalledTag == latestRelease.tagName || lastInstalledTag == 'v$currentVersion')) {
        return;
      }

      // عدم إزعاج الكاشير إذا طلب التذكير لاحقاً خلال آخر 24 ساعة
      if (lastDismissedTag != null && lastDismissedTag == latestRelease.tagName && lastDismissedTimeStr != null) {
        final lastDismissed = DateTime.tryParse(lastDismissedTimeStr);
        if (lastDismissed != null && DateTime.now().difference(lastDismissed).inHours < 24) {
          return;
        }
      }

      if (context.mounted) {
        SoundService.playRestockSound();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _UpdateDialog(
            currentVersion: currentVersion,
            releaseInfo: latestRelease,
          ),
        );
      }
    });
  }
}

/// نافذة التحديث اللمسية التفاعلية
class _UpdateDialog extends StatefulWidget {
  final String currentVersion;
  final GitHubReleaseInfo releaseInfo;

  const _UpdateDialog({
    required this.currentVersion,
    required this.releaseInfo,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _statusText;
  http.Client? _httpClient;

  Future<void> _startDownloadAndInstall() async {
    final downloadUrl = widget.releaseInfo.downloadUrl;
    if (downloadUrl.isEmpty) return;

    // 1. حفظ السلة الحالية المفتوحة فوراً في Hive لضمان عدم ضياع أي بيانات تحت أي ظرف
    await GitHubUpdateService.saveActiveCartBeforeUpdate(context);

    // على نظام أندرويد: فتح رابط التحميل المباشر للـ APK عبر المتصفح/مثبت النظام
    if (Platform.isAndroid) {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // على نظام ويندوز: تحميل الملف داخل البرنامج مع شريط النسبة واستئناف التحميل التلقائي
    setState(() {
      _isDownloading = true;
      _statusText = 'جاري الاتصال بخادم التحديثات...';
    });

    File? targetFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.releaseInfo.assetName.isNotEmpty
          ? widget.releaseInfo.assetName
          : 'nayli-kiosk-update.exe';
      targetFile = File('${tempDir.path}/$fileName');

      // إذا كان الملف محملاً بالكامل ومطابقاً للحجم المطلوب مسبقاً، لا داعي لإعادة تحميله
      if (targetFile.existsSync()) {
        final existingLength = await targetFile.length();
        if (widget.releaseInfo.sizeBytes > 0 && existingLength == widget.releaseInfo.sizeBytes) {
          if (mounted) {
            await _launchInstallerAndExit(targetFile);
          }
          return;
        } else if (widget.releaseInfo.sizeBytes > 0 && existingLength > widget.releaseInfo.sizeBytes) {
          // ملف قديم غير متطابق
          await targetFile.delete();
        }
      }
    } catch (e) {
      debugPrint('[UpdateDownloader] Target file prep error: $e');
    }

    if (targetFile == null) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'تعذر إنشاء مسار التحميل، يرجى التأكد من توفر مساحة كافية على القرص.';
        });
      }
      return;
    }

    // حلقة التحميل مع الاستئناف التلقائي (Resumable Download with HTTP Range)
    int received = targetFile.existsSync() ? await targetFile.length() : 0;
    int retryCount = 0;
    const maxRetries = 5;
    bool completed = false;

    while (!completed && retryCount <= maxRetries && mounted) {
      IOSink? sink;
      try {
        _httpClient?.close();
        _httpClient = http.Client();

        final request = http.Request('GET', Uri.parse(downloadUrl));
        // استئناف التحميل من البايت الحالي لتوفير البيانات والوقت
        if (received > 0) {
          request.headers['Range'] = 'bytes=$received-';
          if (mounted) {
            setState(() {
              _statusText = 'جاري استئناف التحميل من ${((received / (1024 * 1024))).toStringAsFixed(1)} ميغابايت...';
            });
          }
        }

        final streamedResponse = await _httpClient!.send(request).timeout(const Duration(seconds: 30));

        // 200 = ملف كامل، 206 = استئناف جزئي (Partial Content)
        if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
          throw Exception('HTTP Status: ${streamedResponse.statusCode}');
        }

        // إذا أرجع السيرفر 200 بدلاً من 206 بينما كنا طلبنا Range، نبدأ من الصفر
        if (streamedResponse.statusCode == 200 && received > 0) {
          received = 0;
          if (targetFile.existsSync()) await targetFile.delete();
        }

        final contentLength = streamedResponse.contentLength ?? 0;
        final totalExpected = (streamedResponse.statusCode == 206)
            ? received + contentLength
            : (contentLength > 0 ? contentLength : widget.releaseInfo.sizeBytes);

        if (mounted) {
          setState(() {
            _totalBytes = totalExpected;
            _statusText = 'جاري تنزيل ملف التحديث...';
          });
        }

        sink = targetFile.openWrite(mode: received > 0 ? FileMode.append : FileMode.write);

        await streamedResponse.stream.listen((chunk) {
          received += chunk.length;
          sink?.add(chunk);
          if (mounted) {
            setState(() {
              _downloadedBytes = received;
              if (_totalBytes > 0) {
                _downloadProgress = (received / _totalBytes).clamp(0.0, 1.0);
              }
            });
          }
        }).asFuture().timeout(const Duration(seconds: 60));

        await sink.flush();
        await sink.close();
        sink = null;

        completed = true;
      } catch (e) {
        debugPrint('[UpdateDownloader] Download error (attempt $retryCount): $e');
        try {
          await sink?.flush();
          await sink?.close();
        } catch (_) {}

        retryCount++;
        if (retryCount <= maxRetries && mounted) {
          setState(() {
            _statusText = 'انقطع الاتصال مؤقتاً، جاري إعادة المحاولة ($retryCount من $maxRetries)...';
          });
          await Future.delayed(Duration(seconds: 2 * retryCount));
        } else {
          break;
        }
      }
    }

    if (!mounted) return;

    if (completed) {
      await _launchInstallerAndExit(targetFile);
    } else {
      setState(() {
        _isDownloading = false;
        _statusText = 'تعذر إكمال التحميل بسبب انقطاع الاتصال. يمكنك الضغط على "استئناف التحميل" للمتابعة.';
      });
      SnackbarHelper.showWarning(context, 'تعذر إكمال التحميل التلقائي، يمكنك استئناف التحميل بالضغط على الزر.');
    }
  }

  /// تشغيل برنامج التثبيت وإغلاق التطبيق الحالي بأمان
  Future<void> _launchInstallerAndExit(File file) async {
    setState(() {
      _downloadProgress = 1.0;
      _statusText = 'اكتمل التحميل بنجاح! جاري تشغيل برنامج التثبيت...';
    });

    // تسجيل أن هذا الإصدار تم تثبيته لمنع تكرار الإشعار
    await HiveDatabase.settingsBox.put('last_installed_update_tag', widget.releaseInfo.tagName);

    // تشغيل برنامج التثبيت
    await Future.delayed(const Duration(milliseconds: 600));
    if (Platform.isWindows) {
      await Process.start(file.path, []);
      exit(0); // إغلاق البرنامج الحالي ليتمكن المثبت من استبدال الملفات
    } else {
      final fileUri = Uri.file(file.path);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int activeCartItemsCount = 0;
    try {
      activeCartItemsCount = context.read<BillingBloc>().state.cartItems.length;
    } catch (_) {}

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان والأيقونة
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Colors.teal, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'يتوفر تحديث رسمي جديد للبرنامج 🎉',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'الحالي: v${widget.currentVersion}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.teal),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'الجديد: v${widget.releaseInfo.cleanVersion}',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // تنبيه السلة المفتوحة (إذا كانت هناك سلع ممسوحة)
            if (activeCartItemsCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تنبيه: لديك $activeCartItemsCount سلع في السلة الحالية. سيتم حفظها تلقائياً واستعادتها فور إعادة فتح البرنامج.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // قائمة التغييرات والمزايا
            const Text(
              'ما الجديد في هذا التحديث:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.releaseInfo.changelog,
                  style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                ),
              ),
            ),

            if (widget.releaseInfo.sizeFormatted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.folder_zip_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'حجم التحديث: ${widget.releaseInfo.sizeFormatted}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // شريط التقدم أثناء التحميل
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.teal.shade50,
                color: Colors.teal,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusText ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                  if (_totalBytes > 0)
                    Text(
                      '${(_downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(_downloadProgress * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // الأزرار
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading) ...[
                  TextButton(
                    onPressed: () async {
                      // تحديد هذا الإصدار كأنه "مثبت" لكي لا يظهر مجددا أبدا
                      await HiveDatabase.settingsBox.put('last_installed_update_tag', widget.releaseInfo.tagName);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('مُحدَّث بالفعل', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await HiveDatabase.settingsBox.put('last_dismissed_update_tag', widget.releaseInfo.tagName);
                      await HiveDatabase.settingsBox.put('last_dismissed_update_time', DateTime.now().toIso8601String());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('ذكرني لاحقاً'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _startDownloadAndInstall,
                    icon: Icon(_downloadedBytes > 0 ? Icons.refresh_rounded : Icons.download_rounded),
                    label: Text(_downloadedBytes > 0 ? 'استئناف التحميل' : 'تحديث وتثبيت الآن'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () async {
                      _httpClient?.close();
                      await HiveDatabase.settingsBox.put('last_dismissed_update_tag', widget.releaseInfo.tagName);
                      await HiveDatabase.settingsBox.put('last_dismissed_update_time', DateTime.now().toIso8601String());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('إلغاء التحميل', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
