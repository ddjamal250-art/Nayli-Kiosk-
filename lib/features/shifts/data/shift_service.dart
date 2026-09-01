import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/security_pin_helper.dart';
import '../../../../core/utils/sound_service.dart';
import '../../../../core/utils/online_license_service.dart';
import '../backup/data/backup_service.dart';

class CashierShift {
  final String id;
  final String workerName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double floatAmount; // Fond de caisse initial
  final double cashSales;
  final double tpeSales;
  final double creditSales;
  final double actualCashAtClose;
  final bool isClosed;
  final String? notes;

  CashierShift({
    required this.id,
    required this.workerName,
    required this.openedAt,
    this.closedAt,
    required this.floatAmount,
    this.cashSales = 0.0,
    this.tpeSales = 0.0,
    this.creditSales = 0.0,
    this.actualCashAtClose = 0.0,
    this.isClosed = false,
    this.notes,
  });

  double get totalSales => cashSales + tpeSales + creditSales;
  double get expectedTotalCashInDrawer => floatAmount + cashSales;
  double get cashDifference => actualCashAtClose - expectedTotalCashInDrawer;

  Map<String, dynamic> toMap() => {
    'id': id,
    'workerName': workerName,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'floatAmount': floatAmount,
    'cashSales': cashSales,
    'tpeSales': tpeSales,
    'creditSales': creditSales,
    'actualCashAtClose': actualCashAtClose,
    'isClosed': isClosed,
    'notes': notes,
  };

  factory CashierShift.fromMap(Map<dynamic, dynamic> map) => CashierShift(
    id: map['id']?.toString() ?? 'shift_${DateTime.now().millisecondsSinceEpoch}',
    workerName: map['workerName']?.toString() ?? 'الكاشير',
    openedAt: DateTime.tryParse(map['openedAt']?.toString() ?? '') ?? DateTime.now(),
    closedAt: map['closedAt'] != null ? DateTime.tryParse(map['closedAt'].toString()) : null,
    floatAmount: (map['floatAmount'] as num?)?.toDouble() ?? 0.0,
    cashSales: (map['cashSales'] as num?)?.toDouble() ?? 0.0,
    tpeSales: (map['tpeSales'] as num?)?.toDouble() ?? 0.0,
    creditSales: (map['creditSales'] as num?)?.toDouble() ?? 0.0,
    actualCashAtClose: (map['actualCashAtClose'] as num?)?.toDouble() ?? 0.0,
    isClosed: map['isClosed'] as bool? ?? false,
    notes: map['notes']?.toString(),
  );
}

class ShiftService {
  static const String boxName = 'cashier_shifts_box';
  static Box? _box;

  static Future<Box> get box async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(boxName);
    return _box!;
  }

  /// Get current active open shift
  static Future<CashierShift?> getActiveShift() async {
    final b = await box;
    for (var key in b.keys) {
      final map = b.get(key);
      if (map is Map && (map['isClosed'] == false || map['isClosed'] == null)) {
        return CashierShift.fromMap(map);
      }
    }
    return null;
  }

  /// Open new cashier shift
  static Future<CashierShift> openShift({
    required String workerName,
    required double floatAmount,
  }) async {
    final b = await box;
    final id = 'shift_${DateTime.now().millisecondsSinceEpoch}';
    final shift = CashierShift(
      id: id,
      workerName: workerName,
      openedAt: DateTime.now(),
      floatAmount: floatAmount,
      isClosed: false,
    );
    await b.put(id, shift.toMap());
    return shift;
  }

  /// Close shift and generate Z-Report
  static Future<CashierShift> closeShift({
    required CashierShift activeShift,
    required double actualCashInDrawer,
    String? notes,
  }) async {
    final b = await box;

    // Calculate sales during this shift from invoicesBox
    final invoices = HiveDatabase.invoicesBox.values.toList();
    double cash = 0.0;
    double tpe = 0.0;
    double credit = 0.0;

    for (var inv in invoices) {
      if (inv is Map) {
        final invTime = DateTime.tryParse(inv['timestamp']?.toString() ?? '');
        if (invTime != null && invTime.isAfter(activeShift.openedAt)) {
          final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final method = inv['paymentMethod']?.toString() ?? 'Espèces';
          if (inv['isCredit'] == true) {
            credit += total;
          } else if (method.contains('TPE') || method.contains('Card')) {
            tpe += total;
          } else {
            cash += total;
          }
        }
      }
    }

    final closedShift = CashierShift(
      id: activeShift.id,
      workerName: activeShift.workerName,
      openedAt: activeShift.openedAt,
      closedAt: DateTime.now(),
      floatAmount: activeShift.floatAmount,
      cashSales: cash,
      tpeSales: tpe,
      creditSales: credit,
      actualCashAtClose: actualCashInDrawer,
      isClosed: true,
      notes: notes,
    );

    await b.put(closedShift.id, closedShift.toMap());

    // Dispatch Telegram Daily Z-Report directly to merchant's phone
    try {
      OnlineLicenseService.sendDailyReportToMerchant(
        totalSales: closedShift.totalSales,
        cashInDrawer: actualCashInDrawer,
        tpeSales: tpe,
        creditSales: credit,
        invoiceCount: invoices.length,
        estimatedNetProfit: (closedShift.totalSales * 0.22),
      );
    } catch (_) {}

    // Auto-backup if enabled
    final autoBackup = HiveDatabase.settingsBox.get('auto_backup_on_shift_close', defaultValue: true);
    if (autoBackup) {
      try {
        final backupFile = await BackupService.createFullBackupZip(customNote: 'نسخة ختام الوردية: ${closedShift.id}');
        final token = HiveDatabase.settingsBox.get('telegram_bot_token', defaultValue: '');
        final chatId = HiveDatabase.settingsBox.get('telegram_chat_id', defaultValue: '');
        if (token.isNotEmpty && chatId.isNotEmpty) {
          await BackupService.sendToTelegramBot(backupFile: backupFile, botToken: token, chatId: chatId);
        }
      } catch (_) {}
    }

    return closedShift;
  }

  /// Lock screen modal (Pause Déjeuner / Rest)
  static Future<bool> lockScreen(BuildContext context, {String workerName = 'العامل'}) async {
    SoundService.playVoidWarning();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LockScreenDialog(workerName: workerName),
    );
    return result ?? false;
  }
}

class _LockScreenDialog extends StatefulWidget {
  final String workerName;
  const _LockScreenDialog({required this.workerName});

  @override
  State<_LockScreenDialog> createState() => _LockScreenDialogState();
}

class _LockScreenDialogState extends State<_LockScreenDialog> {
  String _pin = '';
  String? _error;

  void _onKey(String k) {
    setState(() {
      _error = null;
      if (_pin.length < 4) {
        _pin += k;
        if (_pin.length == 4) {
          _verify();
        }
      }
    });
  }

  void _verify() {
    if (SecurityPinHelper.verifyPin(_pin)) {
      SoundService.playSaveSuccess();
      Navigator.pop(context, true);
    } else {
      SoundService.playVoidWarning();
      setState(() {
        _error = 'الرمز السري غير صحيح!';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
        body: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, color: Colors.teal, size: 54),
                const SizedBox(height: 12),
                const Text('شاشة الكاشير مقفلة مؤقتاً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('الوردية الحالية: ${widget.workerName} (في استراحة / غداء)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 20),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? Colors.teal : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ],

                const SizedBox(height: 20),

                // Keypad
                Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 8),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 8),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 8),
                    _buildRow(['C', '0', 'DEL']),
                  ],
                ),

                const SizedBox(height: 12),
                // Supervisor Override Trigger
                TextButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.indigo),
                  label: const Text('نسيت الرمز؟ فتح وإعادة تعيين بواسطة المشرف',
                      style: TextStyle(color: Colors.indigo, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: _showSupervisorOverrideDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupervisorOverrideDialog() {
    SoundService.playTabSwitch();
    final masterPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    bool isAuthorized = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: Colors.indigo, size: 28),
                SizedBox(width: 8),
                Text('إلغاء القفل برمز المشرف العام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('أدخل رمز المدير المسجل في الإعدادات لفتح الشاشة فوراً وإعادة تعيين رمز العامل:',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 14),
                  if (!isAuthorized) ...[
                    TextField(
                      controller: masterPinCtrl,
                      obscureText: true,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رمز المدير (Manager PIN)',
                        prefixIcon: Icon(Icons.security),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('تم تأكيد هوية المشرف بنجاح!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'الرمز السري الجديد للعامل (4 أرقام)',
                        prefixIcon: Icon(Icons.password),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              if (!isAuthorized)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    final entered = masterPinCtrl.text.trim();
                    if (SecurityPinHelper.verifyPin(entered)) {
                      SoundService.playSupervisorOverride();
                      setModalState(() => isAuthorized = true);
                    } else {
                      SoundService.playVoidWarning();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('رمز المشرف غير صحيح!'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('تحقق 🔓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    final newPin = newPinCtrl.text.trim();
                    if (newPin.length == 4) {
                      await SecurityPinHelper.setPin(newPin);
                    }
                    Navigator.pop(ctx);
                    SoundService.playSaveSuccess();
                    Navigator.pop(context, true); // Unlock lock screen
                  },
                  child: const Text('فتح وتعيين الرمز 💾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        final isSpecial = k == 'C' || k == 'DEL';
        return InkWell(
          onTap: () {
            if (k == 'C') {
              setState(() => _pin = '');
            } else if (k == 'DEL') {
              if (_pin.isNotEmpty) {
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              }
            } else {
              _onKey(k);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 70,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSpecial ? Colors.grey.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: k == 'DEL'
                ? const Icon(Icons.backspace_outlined, size: 18, color: Colors.red)
                : Text(k, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: k == 'C' ? Colors.red : Colors.black87)),
          ),
        );
      }).toList(),
    );
  }
}

