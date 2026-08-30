import '../../../../core/data/hive_database.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/debt_record.dart';

class CustomerRepository {
  List<Customer> getAllCustomers() {
    final box = HiveDatabase.customersBox;
    final List<Customer> list = [];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data is Map) {
        list.add(Customer.fromMap(data));
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Customer? getCustomerById(String id) {
    final data = HiveDatabase.customersBox.get(id);
    if (data != null && data is Map) {
      return Customer.fromMap(data);
    }
    return null;
  }

  Future<void> saveCustomer(Customer customer) async {
    await HiveDatabase.customersBox.put(customer.id, customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await HiveDatabase.customersBox.delete(id);
  }

  Future<Customer> addCreditToCustomer({
    required String customerId,
    required double creditAmount,
    String? invoiceId,
    String note = '',
  }) async {
    final customer = getCustomerById(customerId);
    if (customer == null) throw Exception('Customer not found');

    final newDebt = customer.currentDebt + creditAmount;
    final updated = customer.copyWith(
      currentDebt: newDebt,
      updatedAt: DateTime.now(),
    );

    await saveCustomer(updated);

    // Save debt transaction record
    final recordId = '${DateTime.now().millisecondsSinceEpoch}_cr';
    final record = DebtRecord(
      id: recordId,
      customerId: customerId,
      amount: creditAmount,
      type: DebtTransactionType.purchaseCredit,
      timestamp: DateTime.now(),
      invoiceId: invoiceId,
      note: note.isNotEmpty ? note : 'مشتريات بالكريدي',
      remainingDebtAfter: newDebt,
    );

    await HiveDatabase.customerDebtsBox.put(recordId, record.toMap());
    return updated;
  }

  Future<Customer> recordDebtPayment({
    required String customerId,
    required double paymentAmount,
    String note = '',
  }) async {
    final customer = getCustomerById(customerId);
    if (customer == null) throw Exception('Customer not found');

    final newDebt = (customer.currentDebt - paymentAmount).clamp(0.0, double.infinity);
    final updated = customer.copyWith(
      currentDebt: newDebt,
      updatedAt: DateTime.now(),
    );

    await saveCustomer(updated);

    // Save debt payment record
    final recordId = '${DateTime.now().millisecondsSinceEpoch}_pay';
    final record = DebtRecord(
      id: recordId,
      customerId: customerId,
      amount: paymentAmount,
      type: DebtTransactionType.payment,
      timestamp: DateTime.now(),
      note: note.isNotEmpty ? note : 'تسديد دين',
      remainingDebtAfter: newDebt,
    );

    await HiveDatabase.customerDebtsBox.put(recordId, record.toMap());
    return updated;
  }

  List<DebtRecord> getCustomerDebtHistory(String customerId) {
    final box = HiveDatabase.customerDebtsBox;
    final List<DebtRecord> list = [];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null && data is Map) {
        final record = DebtRecord.fromMap(data);
        if (record.customerId == customerId) {
          list.add(record);
        }
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}
