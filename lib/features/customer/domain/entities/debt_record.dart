import 'package:equatable/equatable.dart';

enum DebtTransactionType { purchaseCredit, payment }

class DebtRecord extends Equatable {
  final String id;
  final String customerId;
  final double amount;
  final DebtTransactionType type;
  final DateTime timestamp;
  final String note;
  final String? invoiceId;
  final double remainingDebtAfter;

  const DebtRecord({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.note = '',
    this.invoiceId,
    required this.remainingDebtAfter,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'amount': amount,
      'type': type == DebtTransactionType.purchaseCredit ? 'PURCHASE_CREDIT' : 'PAYMENT',
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'invoiceId': invoiceId,
      'remainingDebtAfter': remainingDebtAfter,
    };
  }

  factory DebtRecord.fromMap(Map<dynamic, dynamic> map) {
    return DebtRecord(
      id: map['id']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] == 'PAYMENT'
          ? DebtTransactionType.payment
          : DebtTransactionType.purchaseCredit,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      note: map['note']?.toString() ?? '',
      invoiceId: map['invoiceId']?.toString(),
      remainingDebtAfter: (map['remainingDebtAfter'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        amount,
        type,
        timestamp,
        note,
        invoiceId,
        remainingDebtAfter,
      ];
}
