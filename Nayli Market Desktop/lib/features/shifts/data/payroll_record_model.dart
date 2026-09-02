/// Enterprise Payroll & Compensation Record
/// Tracks cash advances, grocery purchases on credit, bonuses, deductions, and monthly salary payouts
class PayrollRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String type; // advance_cash, advance_goods, bonus, deduction, salary_payout
  final double amount;
  final DateTime date;
  final String monthStr; // e.g. 2026-09
  final String notes;
  final bool isSettled; // true once factored into a finalized salary settlement
  final String? linkedInvoiceId;
  final String? linkedExpenseId;

  PayrollRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.type,
    required this.amount,
    required this.date,
    required this.monthStr,
    this.notes = '',
    this.isSettled = false,
    this.linkedInvoiceId,
    this.linkedExpenseId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'staffId': staffId,
        'staffName': staffName,
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'monthStr': monthStr,
        'notes': notes,
        'isSettled': isSettled,
        'linkedInvoiceId': linkedInvoiceId,
        'linkedExpenseId': linkedExpenseId,
      };

  factory PayrollRecord.fromMap(Map<dynamic, dynamic> map) => PayrollRecord(
        id: map['id']?.toString() ?? '',
        staffId: map['staffId']?.toString() ?? '',
        staffName: map['staffName']?.toString() ?? '',
        type: map['type']?.toString() ?? 'advance_cash',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        monthStr: map['monthStr']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
        isSettled: map['isSettled'] as bool? ?? false,
        linkedInvoiceId: map['linkedInvoiceId']?.toString(),
        linkedExpenseId: map['linkedExpenseId']?.toString(),
      );
}
