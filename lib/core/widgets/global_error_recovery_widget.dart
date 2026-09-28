import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/crash_reporting_service.dart';
import '../theme/app_theme.dart';

class GlobalErrorRecoveryWidget extends StatefulWidget {
  final FlutterErrorDetails errorDetails;

  const GlobalErrorRecoveryWidget({
    super.key,
    required this.errorDetails,
  });

  @override
  State<GlobalErrorRecoveryWidget> createState() => _GlobalErrorRecoveryWidgetState();
}

class _GlobalErrorRecoveryWidgetState extends State<GlobalErrorRecoveryWidget> {
  bool _showTechnicalDetails = false;
  CrashReport? _recordedReport;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _recordError();
  }

  void _recordError() async {
    final report = await CrashReportingService.recordCrash(
      widget.errorDetails.exceptionAsString(),
      widget.errorDetails.stack,
      contextName: widget.errorDetails.context?.toString() ?? 'Widget Build Failure',
    );
    if (mounted) {
      setState(() {
        _recordedReport = report;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade500.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.shade400, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.shield_rounded, size: 38, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'حدث تنبيه أثناء عرض الواجهة وتم تأمينه 🛡️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'تم حفظ بيانات عملك في أمان تام وتسجيل تقرير الخطأ تلقائياً في سجلات النظام لتصحيحه.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Actions Row
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    // Return to POS Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('الرجوع لنقطة البيع', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        try {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/pos');
                          }
                        } catch (_) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      },
                    ),

                    // Copy & Send to Developer Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0088CC),
                        side: const BorderSide(color: Color(0xFF0088CC), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(_isCopied ? Icons.check_circle_rounded : Icons.telegram, size: 18),
                      label: Text(
                        _isCopied ? 'تم نسخ التقرير!' : 'إرسال التقرير للمطور ✈️',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        if (_recordedReport != null) {
                          await CrashReportingService.openTelegramReport(_recordedReport!);
                          setState(() => _isCopied = true);
                        } else {
                          final text = widget.errorDetails.exceptionAsString();
                          await Clipboard.setData(ClipboardData(text: text));
                          setState(() => _isCopied = true);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Toggle Technical Details
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade500,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: Icon(_showTechnicalDetails ? Icons.expand_less : Icons.expand_more, size: 16),
                  label: Text(_showTechnicalDetails ? 'إخفاء التفاصيل الفنية' : 'عرض التفاصيل الفنية'),
                  onPressed: () => setState(() => _showTechnicalDetails = !_showTechnicalDetails),
                ),

                if (_showTechnicalDetails) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      widget.errorDetails.exceptionAsString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.redAccent,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
