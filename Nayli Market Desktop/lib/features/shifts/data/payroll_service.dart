import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/hive_database.dart';
import 'payroll_record_model.dart';
import 'staff_member_model.dart';

class PayrollService {
  /// Get all records for a specific staff member
  static List<PayrollRecord> getStaffRecords(String staffId, {String? monthStr}) {
    try {
      final box = HiveDatabase.payrollBox;
      final list = <PayrollRecord>[];
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final r = PayrollRecord.fromMap(val);
          if (r.staffId == staffId) {
            if (monthStr == null || r.monthStr == monthStr) {
              list.add(r);
            }
          }
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Get unsettled advances & deductions for a staff member in a specific month
  static List<PayrollRecord> getUnsettledRecords(String staffId, String monthStr) {
    return getStaffRecords(staffId, monthStr: monthStr)
        .where((r) => !r.isSettled && r.type != 'salary_payout')
        .toList();
  }

  /// Record a cash advance, grocery deduction, bonus, or penalty
  static Future<PayrollRecord> addRecord({
    required StaffMember staff,
    required String type, // 'advance_cash', 'advance_goods', 'bonus', 'deduction'
    required double amount,
    String notes = '',
    bool deductFromCashDrawer = true,
  }) async {
    final now = DateTime.now();
    final monthStr = DateFormat('yyyy-MM').format(now);
    final id = 'pay_' + const Uuid().v4().substring(0, 8);

    String? expenseId;

    // If cash advance taken from cash drawer, record expense immediately in expensesBox
    if (type == 'advance_cash' && deductFromCashDrawer && amount > 0) {
      expenseId = 'exp_' + now.millisecondsSinceEpoch.toString();
      try {
        await HiveDatabase.expensesBox.put(expenseId, {
          'id': expenseId,
          'title': 'تسبيق أجر: ' + staff.name,
          'amount': amount,
          'category': 'أجور عمال 👷',
          'date': now.toIso8601String(),
          'notes': 'تسبيق نقدي للراتب - شهر ' + monthStr + ' (' + notes + ')',
        });
      } catch (e) {
        debugPrint('Failed to log expense for advance: ' + e.toString());
      }
    }

    final record = PayrollRecord(
      id: id,
      staffId: staff.id,
      staffName: staff.name,
      type: type,
      amount: amount,
      date: now,
      monthStr: monthStr,
      notes: notes,
      isSettled: false,
      linkedExpenseId: expenseId,
    );

    final box = HiveDatabase.payrollBox;
    await box.put(record.id, record.toMap());
    return record;
  }

  /// Calculate full monthly settlement breakdown
  static Map<String, dynamic> calculateMonthlySettlement(StaffMember staff, String monthStr, {int daysWorked = 30}) {
    final records = getStaffRecords(staff.id, monthStr: monthStr);

    double advancesCash = 0.0;
    double advancesGoods = 0.0;
    double bonuses = 0.0;
    double deductions = 0.0;
    bool alreadySettled = false;
    DateTime? settledAt;

    for (var r in records) {
      if (r.type == 'salary_payout') {
        alreadySettled = true;
        settledAt = r.date;
      } else {
        if (r.type == 'advance_cash') advancesCash += r.amount;
        if (r.type == 'advance_goods') advancesGoods += r.amount;
        if (r.type == 'bonus') bonuses += r.amount;
        if (r.type == 'deduction') deductions += r.amount;
      }
    }

    final baseSalary = staff.salaryType == 'daily'
        ? (staff.baseSalary * daysWorked)
        : staff.baseSalary;

    final totalAdvances = advancesCash + advancesGoods;
    final netPayable = baseSalary + bonuses - totalAdvances - deductions;

    return {
      'staffId': staff.id,
      'staffName': staff.name,
      'monthStr': monthStr,
      'salaryType': staff.salaryType,
      'baseSalary': baseSalary,
      'daysWorked': daysWorked,
      'advancesCash': advancesCash,
      'advancesGoods': advancesGoods,
      'totalAdvances': totalAdvances,
      'bonuses': bonuses,
      'deductions': deductions,
      'netPayable': netPayable > 0 ? netPayable : 0.0,
      'alreadySettled': alreadySettled,
      'settledAt': settledAt,
      'recordsCount': records.length,
    };
  }

  /// Settle and pay monthly salary
  static Future<PayrollRecord> settleMonthlySalary({
    required StaffMember staff,
    required String monthStr,
    required double netPaidAmount,
    int daysWorked = 30,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final box = HiveDatabase.payrollBox;

    // 1. Mark all existing component records for this month as settled
    final records = getStaffRecords(staff.id, monthStr: monthStr);
    for (var r in records) {
      if (!r.isSettled && r.type != 'salary_payout') {
        final updated = PayrollRecord(
          id: r.id,
          staffId: r.staffId,
          staffName: r.staffName,
          type: r.type,
          amount: r.amount,
          date: r.date,
          monthStr: r.monthStr,
          notes: r.notes,
          isSettled: true,
          linkedInvoiceId: r.linkedInvoiceId,
          linkedExpenseId: r.linkedExpenseId,
        );
        await box.put(updated.id, updated.toMap());
      }
    }

    // 2. Automatically record net payout into expensesBox under 'أجور عمال 👷'
    final expenseId = 'exp_salary_' + now.millisecondsSinceEpoch.toString();
    try {
      await HiveDatabase.expensesBox.put(expenseId, {
        'id': expenseId,
        'title': 'تصفية راتب: ' + staff.name + ' (' + monthStr + ')',
        'amount': netPaidAmount,
        'category': 'أجور عمال 👷',
        'date': now.toIso8601String(),
        'notes': 'تصفية الأجر الصافي لشهر ' + monthStr + ' - عمل: ' + daysWorked.toString() + ' يوم (' + notes + ')',
      });
    } catch (e) {
      debugPrint('Failed to log expense for salary payout: ' + e.toString());
    }

    // 3. Create the salary payout record
    final payoutRecord = PayrollRecord(
      id: 'payout_' + const Uuid().v4().substring(0, 8),
      staffId: staff.id,
      staffName: staff.name,
      type: 'salary_payout',
      amount: netPaidAmount,
      date: now,
      monthStr: monthStr,
      notes: notes.isEmpty ? 'تصفية الأجر لشهر ' + monthStr : notes,
      isSettled: true,
      linkedExpenseId: expenseId,
    );

    await box.put(payoutRecord.id, payoutRecord.toMap());
    return payoutRecord;
  }

  /// Generate Thermal Pay Slip (Fiche de Paie) formatted text
  static String formatThermalPaySlip({
    required StaffMember staff,
    required Map<String, dynamic> settlement,
    String shopName = 'Nayli Kiosk',
  }) {
    final monthStr = settlement['monthStr']?.toString() ?? '';
    final base = (settlement['baseSalary'] as num?)?.toDouble() ?? 0.0;
    final advCash = (settlement['advancesCash'] as num?)?.toDouble() ?? 0.0;
    final advGoods = (settlement['advancesGoods'] as num?)?.toDouble() ?? 0.0;
    final bonuses = (settlement['bonuses'] as num?)?.toDouble() ?? 0.0;
    final deductions = (settlement['deductions'] as num?)?.toDouble() ?? 0.0;
    final net = (settlement['netPayable'] as num?)?.toDouble() ?? 0.0;
    final nowStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    return '================================\n' +
        '       ' + shopName + '\n' +
        '  كشف تصفية الراتب (FICHE DE PAIE)\n' +
        '================================\n' +
        'الموظف: ' + staff.name + '\n' +
        'الوظيفة: ' + staff.department + ' - ' + staff.role + '\n' +
        'الشهر: ' + monthStr + '\n' +
        'التاريخ: ' + nowStr + '\n' +
        '--------------------------------\n' +
        'الراتب الأساسي:    ' + base.toStringAsFixed(2) + ' دج\n' +
        '(+) المكافآت:      ' + bonuses.toStringAsFixed(2) + ' دج\n' +
        '(-) التسبيقات نقد:  ' + advCash.toStringAsFixed(2) + ' دج\n' +
        '(-) سحب سلع:       ' + advGoods.toStringAsFixed(2) + ' دج\n' +
        '(-) الخصومات:      ' + deductions.toStringAsFixed(2) + ' دج\n' +
        '--------------------------------\n' +
        'الصافي المدفوع:   ' + net.toStringAsFixed(2) + ' دج\n' +
        '================================\n' +
        'توقيع الإدارة        توقيع الموظف\n\n';
  }
}
