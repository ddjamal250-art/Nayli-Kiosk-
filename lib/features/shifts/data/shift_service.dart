import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/data/hive_database.dart';
import '../../../core/utils/security_pin_helper.dart';
import '../../../core/utils/sound_service.dart';
import '../../../core/utils/online_license_service.dart';
import '../../backup/data/backup_service.dart';
import '../../../core/utils/telegram_service.dart';

class CashDrawerMovement {
  final String id;
  final String type; // 'in' (إيداع/صرف), 'out' (سحب/مصاريف)
  final double amount;
  final String reason;
  final DateTime timestamp;
  final String cashierName;

  CashDrawerMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.timestamp,
    required this.cashierName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'amount': amount,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
    'cashierName': cashierName,
  };

  factory CashDrawerMovement.fromMap(Map<dynamic, dynamic> map) => CashDrawerMovement(
    id: map['id']?.toString() ?? 'mov_${DateTime.now().millisecondsSinceEpoch}',
    type: map['type']?.toString() ?? 'in',
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    reason: map['reason']?.toString() ?? '',
    timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
    cashierName: map['cashierName']?.toString() ?? 'الكاشير',
  );
}

class CashierShift {
  final String id;
  final String workerName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double floatAmount; // Fond de caisse initial (صرف البداية)
  final double cashSales; // مبيعات نقدية صافية
  final double tpeSales; // مبيعات TPE وبطاقة بنكية
  final double creditSales; // مبيعات كريدي (آجل)
  final double actualCashAtClose;
  final bool isClosed;
  final String? notes;
  final double cashIn; // إيداعات إضافية مباشرة في الدرج
  final double cashOut; // سحوبات مباشرة من الدرج
  final double debtCollections; // تحصيلات ديون الزبائن نقداً
  final double expenses; // مصاريف نقدية مسجلة من الدرج
  final int invoiceCount; // عدد الفواتير المنجزة في المناوبة

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
    this.cashIn = 0.0,
    this.cashOut = 0.0,
    this.debtCollections = 0.0,
    this.expenses = 0.0,
    this.invoiceCount = 0,
  });

  double get totalSales => cashSales + tpeSales + creditSales;
  
  /// المبلغ المتوقع في الدرج الآن بدقة متناهية:
  /// صرف البداية + المبيعات النقدية + إيداعات الدرج + تحصيلات الديون - سحوبات الدرج - مصاريف المحل
  double get expectedTotalCashInDrawer =>
      floatAmount + cashSales + cashIn + debtCollections - cashOut - expenses;
      
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
    'cashIn': cashIn,
    'cashOut': cashOut,
    'debtCollections': debtCollections,
    'expenses': expenses,
    'invoiceCount': invoiceCount,
  };

  factory CashierShift.fromMap(Map<dynamic, dynamic> map) => CashierShift(
    id: map['id']?.toString() ?? 'shift_',
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
    cashIn: (map['cashIn'] as num?)?.toDouble() ?? 0.0,
    cashOut: (map['cashOut'] as num?)?.toDouble() ?? 0.0,
    debtCollections: (map['debtCollections'] as num?)?.toDouble() ?? 0.0,
    expenses: (map['expenses'] as num?)?.toDouble() ?? 0.0,
    invoiceCount: (map['invoiceCount'] as num?)?.toInt() ?? 0,
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

  /// حساب حالة الصندوق المباشرة واللحظية للمناوبة بدقة متناهية
  static Future<CashierShift> computeLiveShift(CashierShift shift) async {
    bool _isTimeInShift(DateTime t) {
      if (t.isBefore(shift.openedAt) && !t.isAtSameMomentAs(shift.openedAt)) return false;
      if (shift.closedAt != null && t.isAfter(shift.closedAt!) && !t.isAtSameMomentAs(shift.closedAt!)) return false;
      return true;
    }

    double cashSales = 0.0;
    double tpeSales = 0.0;
    double creditSales = 0.0;
    int invoiceCount = 0;

    // 1. مبيعات الفواتير الخاصة بهذه المناوبة
    try {
      final invBox = HiveDatabase.invoicesBox;
      for (final key in invBox.keys) {
        final inv = invBox.get(key);
        if (inv is Map) {
          final invTime = DateTime.tryParse(inv['timestamp']?.toString() ?? '');
          final shiftId = inv['shiftId']?.toString();
          
          final isThisShift = (shiftId != null && shiftId == shift.id) ||
              (invTime != null && _isTimeInShift(invTime));

          final isReturned = inv['isReturned'] == true;
          final returnDate = DateTime.tryParse(inv['returnDate']?.toString() ?? '');
          final isReturnedInThisShift = isReturned && returnDate != null && _isTimeInShift(returnDate);

          final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final rawPaid = (inv['paidAmount'] as num?)?.toDouble();
          final method = inv['paymentMethod']?.toString() ?? 'Espèces';
          final isCredit = inv['isCredit'] == true;
          final isCardOrDigital = method.contains('TPE') ||
              method.contains('Card') ||
              method.contains('Carte') ||
              method.contains('BaridiPay') ||
              method.contains('Baridi');

          double saleCash = 0.0;
          double saleTpe = 0.0;
          double saleCredit = 0.0;

          if (isCardOrDigital) {
            saleTpe = total;
          } else if (isCredit) {
            // الدفع بالكريدي (آجل) مع إمكانية تسبيق نقدي (Acompte)
            final paid = rawPaid ?? 0.0;
            final cashPart = (paid > 0) ? (paid > total ? total : paid) : 0.0;
            final creditPart = (total - cashPart).clamp(0.0, double.infinity);
            saleCash = cashPart;
            saleCredit = creditPart;
          } else {
            // الدفع نقداً (كاش):
            // تصحيح جذري: إذا أدخل التاجر ورقة نقدية كبيرة (مثل 2000 دج) لفاتورة قيمتها 400 دج لحساب الصرف،
            // فإن ما يستقر في الدرج فعلياً هو قيمة الفاتورة فقط (400 دج)، لأن الباقي (1600 دج) أُرجع للزبون من الدرج.
            final paid = rawPaid ?? total;
            if (total >= 0) {
              final effectiveCash = (paid > 0 && paid < total) ? paid : total;
              saleCash = effectiveCash;
            } else {
              // وصل إرجاع مباشر سالب (total < 0)
              final absTotal = total.abs();
              final absPaid = paid.abs();
              final effectiveRefund = (absPaid > 0 && absPaid < absTotal) ? absPaid : absTotal;
              saleCash = -effectiveRefund;
            }
          }

          if (isThisShift) {
            invoiceCount++;
            cashSales += saleCash;
            tpeSales += saleTpe;
            creditSales += saleCredit;
          }

          if (isReturnedInThisShift) {
            cashSales -= saleCash;
            tpeSales -= saleTpe;
            creditSales -= saleCredit;
          }
        }
      }
    } catch (e) {
      debugPrint('Error computing shift invoices: $e');
    }

    // 2. حركات الدرج النقدية (إيداع وسحب)
    double shiftCashIn = 0.0;
    double shiftCashOut = 0.0;
    try {
      final movements = await getDrawerMovements();
      for (var m in movements) {
        if (_isTimeInShift(m.timestamp)) {
          if (m.type == 'in') {
            shiftCashIn += m.amount;
          } else {
            shiftCashOut += m.amount;
          }
        }
      }
    } catch (e) {
      debugPrint('Error computing drawer movements: $e');
    }

    // 3. تحصيلات ديون الزبائن نقداً في الصندوق
    double shiftDebtCollections = 0.0;
    try {
      final debtsBox = HiveDatabase.customerDebtsBox;
      for (final key in debtsBox.keys) {
        final val = debtsBox.get(key);
        if (val is Map) {
          final type = val['type']?.toString().toUpperCase();
          if (type == 'PAYMENT') {
            final ts = DateTime.tryParse(val['timestamp']?.toString() ?? '');
            if (ts != null && _isTimeInShift(ts)) {
              shiftDebtCollections += (val['amount'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error computing debt payments: $e');
    }

    // 4. مصاريف المحل النقدية المسجلة من الصندوق
    double shiftExpenses = 0.0;
    try {
      final expBox = HiveDatabase.expensesBox;
      for (final key in expBox.keys) {
        final exp = expBox.get(key);
        if (exp is Map) {
          final d = DateTime.tryParse(exp['date']?.toString() ?? '');
          if (d != null && _isTimeInShift(d)) {
            shiftExpenses += (exp['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (e) {
      debugPrint('Error computing expenses: $e');
    }

    return CashierShift(
      id: shift.id,
      workerName: shift.workerName,
      openedAt: shift.openedAt,
      closedAt: shift.closedAt,
      floatAmount: shift.floatAmount,
      cashSales: cashSales,
      tpeSales: tpeSales,
      creditSales: creditSales,
      actualCashAtClose: shift.actualCashAtClose,
      isClosed: shift.isClosed,
      notes: shift.notes,
      cashIn: shiftCashIn,
      cashOut: shiftCashOut,
      debtCollections: shiftDebtCollections,
      expenses: shiftExpenses,
      invoiceCount: invoiceCount,
    );
  }

  /// إصلاح وتدقيق الحسابات والمبيعات السابقة بأثر رجعي لجميع التجار
  /// يصحح أخطاء الأوراق النقدية والفرّاطة (الصرف) في الفواتير والورديات القديمة
  static Future<Map<String, dynamic>> repairHistoricalData() async {
    int repairedInvoicesCount = 0;
    int repairedShiftsCount = 0;

    try {
      final invBox = HiveDatabase.invoicesBox;
      final shiftsB = await box;

      // 1. تصحيح وتدقيق الفواتير السابقة في invoicesBox
      for (final key in invBox.keys) {
        final inv = invBox.get(key);
        if (inv is Map) {
          final total = (inv['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final rawPaid = (inv['paidAmount'] as num?)?.toDouble();
          final rawReceived = (inv['receivedAmount'] as num?)?.toDouble();
          final rawChange = (inv['changeAmount'] as num?)?.toDouble();
          final isCredit = inv['isCredit'] == true;
          final method = inv['paymentMethod']?.toString() ?? 'Espèces';
          final isCardOrDigital = method.contains('TPE') ||
              method.contains('Card') ||
              method.contains('Carte') ||
              method.contains('BaridiPay') ||
              method.contains('Baridi');

          bool changed = false;
          final updated = Map<String, dynamic>.from(inv);

          if (!isCredit && !isCardOrDigital) {
            // فاتورة كاش نقدية
            if (rawPaid != null && rawPaid > total.abs() && total.abs() > 0) {
              // تم تسجيل الورقة النقدية المدخلة لحساب الصرف (مثل 2000 دج) بدلاً من صافي الفاتورة (400 دج)
              final received = rawPaid;
              final change = (rawPaid - total.abs()).clamp(0.0, double.infinity);
              updated['receivedAmount'] = received;
              updated['changeAmount'] = change;
              updated['paidAmount'] = total; // تصحيح المبلغ المدفوع ليكون صافي قيمة الفاتورة المقبوضة
              changed = true;
            } else {
              if (rawReceived == null && rawPaid != null) {
                updated['receivedAmount'] = rawPaid;
                changed = true;
              }
              if (rawChange == null) {
                updated['changeAmount'] = 0.0;
                changed = true;
              }
            }
          } else if (isCredit) {
            // فاتورة كريدي
            if (rawPaid != null && rawPaid > total.abs() && total.abs() > 0) {
              final received = rawPaid;
              final change = (rawPaid - total.abs()).clamp(0.0, double.infinity);
              updated['receivedAmount'] = received;
              updated['changeAmount'] = change;
              updated['paidAmount'] = total;
              changed = true;
            }
          }

          if (changed) {
            await invBox.put(key, updated);
            repairedInvoicesCount++;
          }
        }
      }

      // 2. إعادة احتساب وتحديث جميع الورديات المسجلة (المفتوحة والسابقة) في cashier_shifts_box
      for (final key in shiftsB.keys) {
        final sMap = shiftsB.get(key);
        if (sMap is Map) {
          final rawShift = CashierShift.fromMap(sMap);
          final recalculated = await computeLiveShift(rawShift);

          final updatedShift = CashierShift(
            id: rawShift.id,
            workerName: rawShift.workerName,
            openedAt: rawShift.openedAt,
            closedAt: rawShift.closedAt,
            floatAmount: rawShift.floatAmount,
            cashSales: recalculated.cashSales,
            tpeSales: recalculated.tpeSales,
            creditSales: recalculated.creditSales,
            actualCashAtClose: rawShift.actualCashAtClose,
            isClosed: rawShift.isClosed,
            notes: rawShift.notes,
            cashIn: recalculated.cashIn,
            cashOut: recalculated.cashOut,
            debtCollections: recalculated.debtCollections,
            expenses: recalculated.expenses,
            invoiceCount: recalculated.invoiceCount,
          );

          await shiftsB.put(key, updatedShift.toMap());
          repairedShiftsCount++;
        }
      }

      debugPrint('✅ تم بنجاح تدقيق وإصلاح $repairedInvoicesCount فاتورة و $repairedShiftsCount وردية بأثر رجعي!');
    } catch (e) {
      debugPrint('❌ خطأ أثناء التدقيق والإصلاح بأثر رجعي: $e');
    }

    return {
      'repairedInvoices': repairedInvoicesCount,
      'repairedShifts': repairedShiftsCount,
    };
  }

  /// Get current active open shift (with live recalculated cash status)
  static Future<CashierShift?> getActiveShift({bool computeLive = true}) async {
    final b = await box;
    for (var key in b.keys) {
      final map = b.get(key);
      if (map is Map && (map['isClosed'] == false || map['isClosed'] == null)) {
        final rawShift = CashierShift.fromMap(map);
        if (computeLive) {
          return await computeLiveShift(rawShift);
        }
        return rawShift;
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
    final live = await computeLiveShift(activeShift);

    final closedShift = CashierShift(
      id: live.id,
      workerName: live.workerName,
      openedAt: live.openedAt,
      closedAt: DateTime.now(),
      floatAmount: live.floatAmount,
      cashSales: live.cashSales,
      tpeSales: live.tpeSales,
      creditSales: live.creditSales,
      actualCashAtClose: actualCashInDrawer,
      isClosed: true,
      notes: notes,
      cashIn: live.cashIn,
      cashOut: live.cashOut,
      debtCollections: live.debtCollections,
      expenses: live.expenses,
      invoiceCount: live.invoiceCount,
    );

    await b.put(closedShift.id, closedShift.toMap());

    // Dispatch Telegram Daily Z-Report directly to merchant's phone
    try {
      OnlineLicenseService.sendDailyReportToMerchant(
        totalSales: closedShift.totalSales,
        cashInDrawer: actualCashInDrawer,
        tpeSales: closedShift.tpeSales,
        creditSales: closedShift.creditSales,
        invoiceCount: closedShift.invoiceCount,
        estimatedNetProfit: closedShift.totalSales * 0.22,
      );
    } catch (_) {}

    // Auto-backup if enabled
    final autoBackup = HiveDatabase.settingsBox.get('auto_backup_on_shift_close', defaultValue: true);
    if (autoBackup) {
      try {
        final backupFile = await BackupService.createFullBackupZip(customNote: 'نسخة ختام الوردية: ${closedShift.id}');
        final token = TelegramService.getBotToken();
        final chatId = TelegramService.getChatId();
        if (token.isNotEmpty && chatId.isNotEmpty) {
          await BackupService.sendToTelegramBot(backupFile: backupFile, botToken: token, chatId: chatId);
        }
      } catch (_) {}
    }

    return closedShift;
  }

  /// Record cash drawer movement (إيداع صرف أو سحب كاش ومصاريف)
  static Future<void> recordDrawerMovement({
    required String type, // 'in' (إيداع) or 'out' (سحب)
    required double amount,
    required String reason,
    required String cashierName,
  }) async {
    final b = await box;
    final raw = b.get('drawer_movements', defaultValue: []);
    final list = (raw is List)
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final mov = CashDrawerMovement(
      id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
      cashierName: cashierName,
    );
    list.insert(0, mov.toMap());
    await b.put('drawer_movements', list);
  }

  /// Get all recorded drawer movements
  static Future<List<CashDrawerMovement>> getDrawerMovements() async {
    final b = await box;
    final raw = b.get('drawer_movements', defaultValue: []);
    if (raw is! List) return [];
    return raw.map((e) => CashDrawerMovement.fromMap(e as Map)).toList();
  }

  /// Get today's recorded drawer movements
  static Future<List<CashDrawerMovement>> getTodayDrawerMovements() async {
    final all = await getDrawerMovements();
    final now = DateTime.now();
    return all.where((m) =>
      m.timestamp.year == now.year &&
      m.timestamp.month == now.month &&
      m.timestamp.day == now.day
    ).toList();
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

