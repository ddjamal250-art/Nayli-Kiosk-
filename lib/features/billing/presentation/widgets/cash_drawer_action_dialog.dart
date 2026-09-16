import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/audit_log_service.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../shifts/data/shift_service.dart';

class CashDrawerActionDialog extends StatefulWidget {
  final VoidCallback? onDone;

  const CashDrawerActionDialog({super.key, this.onDone});

  static Future<void> show(BuildContext context, {VoidCallback? onDone}) {
    SoundService.playTabSwitch();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CashDrawerActionDialog(onDone: onDone),
    );
  }

  @override
  State<CashDrawerActionDialog> createState() => _CashDrawerActionDialogState();
}

class _CashDrawerActionDialogState extends State<CashDrawerActionDialog> {
  String _actionType = 'in'; // 'in' = إيداع صرف, 'out' = سحب مصاريف
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  bool _openDrawerHardware = true;
  bool _isProcessing = false;
  CashierShift? _activeShift;
  double _currentDrawerCash = 0.0;

  final List<String> _commonInReasons = [
    'صرف البداية (Monnaie de caisse)',
    'إضافة صرف إضافي للدرج',
    'إيداع يدوي من صاحب المحل',
    'تسوية رصيد الصندوق',
    'سبب آخر',
  ];

  final List<String> _commonOutReasons = [
    'سحب يدوي لصاحب المحل',
    'شراء لوازم ومصاريف للمحل',
    'مصاريف نقل وتوصيل سلع',
    'تسديد فاتورة (ماء / كهرباء)',
    'تسبيق راتب لعامل (Avance)',
    'سبب آخر',
  ];

  @override
  void initState() {
    super.initState();
    _reasonCtrl.text = _commonInReasons.first;
    _loadShiftData();
  }

  Future<void> _loadShiftData() async {
    final shift = await ShiftService.getActiveShift();
    if (mounted) {
      setState(() {
        _activeShift = shift;
        _currentDrawerCash = shift != null ? shift.expectedTotalCashInDrawer : 0.0;
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _amountFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _addQuickAmount(double val) {
    SoundService.playKeyTap();
    final current = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final updated = current + val;
    setState(() {
      _amountCtrl.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(0);
    });
  }

  Future<void> _submit() async {
    if (_isProcessing) return;
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      SoundService.playWarningSound();
      context.showAppSnackBar('⚠️ يرجى إدخال مبلغ صحيح أكبر من الصفر!', backgroundColor: Colors.amber.shade900);
      _amountFocusNode.requestFocus();
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      SoundService.playWarningSound();
      context.showAppSnackBar('⚠️ يرجى تحديد أو كتابة سبب الحركة!', backgroundColor: Colors.amber.shade900);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cashierName = _activeShift?.workerName ?? 'الكاشير';

      await ShiftService.recordDrawerMovement(
        type: _actionType,
        amount: amt,
        reason: reason,
        cashierName: cashierName,
      );

      AuditLogService.logEvent(
        action: _actionType == 'in' ? 'CASH_DRAWER_IN' : 'CASH_DRAWER_OUT',
        station: 'كاشير',
        staffName: cashierName,
        amount: amt,
        details: 'سبب: $reason',
      );

      if (_openDrawerHardware) {
        try {
          await PrinterHelper.openCashDrawer();
        } catch (_) {}
      }

      SoundService.playSaveSuccess();
      if (mounted) {
        context.showAppSnackBar(
          _actionType == 'in'
              ? '✅ تم إيداع $amt دج بالصندوق بنجاح! ($reason)'
              : '📤 تم سحب $amt دج من الصندوق بنجاح! ($reason)',
          backgroundColor: _actionType == 'in' ? Colors.teal.shade800 : Colors.indigo.shade800,
        );
        Navigator.pop(context);
        widget.onDone?.call();
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('حدث خطأ أثناء حفظ الحركة: $e', backgroundColor: Colors.red.shade800);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final afterBalance = _actionType == 'in' ? (_currentDrawerCash + amt) : (_currentDrawerCash - amt);

    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _submit();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _actionType == 'in' ? Colors.teal.shade50 : Colors.deepOrange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _actionType == 'in' ? Icons.south_west_rounded : Icons.north_east_rounded,
                          color: _actionType == 'in' ? Colors.teal : Colors.deepOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'حركة درج النقود والكاشير 💵',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _activeShift != null ? 'الوردية الحالية: ${_activeShift!.workerName}' : 'تسجيل حركة كاش بالصندوق',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Action Type (In vs Out)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'in',
                    label: Text('📥 إيداع صرف / كاش داخل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                  ButtonSegment(
                    value: 'out',
                    label: Text('📤 سحب مصاريف / كاش خارج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ],
                selected: {_actionType},
                onSelectionChanged: (set) {
                  SoundService.playTabSwitch();
                  setState(() {
                    _actionType = set.first;
                    _reasonCtrl.text = _actionType == 'in' ? _commonInReasons.first : _commonOutReasons.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Amount Input
              Text(
                _actionType == 'in' ? 'المبلغ المودع بالصندوق (دج) *' : 'المبلغ المسحوب من الصندوق (دج) *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                focusNode: _amountFocusNode,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'دج',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // Quick Amount Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0].map((v) {
                  return ActionChip(
                    label: Text('+${v.toInt()} دج', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300),
                    onPressed: () => _addQuickAmount(v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Predefined Reasons
              const Text('السبب أو الوجهة *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: (_actionType == 'in' ? _commonInReasons : _commonOutReasons).contains(_reasonCtrl.text)
                    ? _reasonCtrl.text
                    : null,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                hint: const Text('اختر سبب العملية', style: TextStyle(fontSize: 12)),
                items: (_actionType == 'in' ? _commonInReasons : _commonOutReasons)
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _reasonCtrl.text = val);
                },
              ),
              if (_reasonCtrl.text == 'سبب آخر' ||
                  !(_actionType == 'in' ? _commonInReasons : _commonOutReasons).contains(_reasonCtrl.text)) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل سبب العملية هنا...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Live Drawer Impact Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رصيد الصندوق الحالي:', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
                        Text('${_currentDrawerCash.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.blueGrey.shade400, size: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('الرصيد بعد العملية:', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
                        Text(
                          '${afterBalance.toStringAsFixed(0)} دج',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: afterBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Open Hardware Drawer Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _openDrawerHardware,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _openDrawerHardware = v ?? true),
                  ),
                  const Text('فتح درج النقود إلكترونياً (Tiroir-caisse)', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء (Esc)', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _actionType == 'in' ? Colors.teal : Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing ? null : _submit,
                      child: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _actionType == 'in' ? 'تأكيد الإيداع بالصندوق (Enter)' : 'تأكيد السحب من الصندوق (Enter)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
