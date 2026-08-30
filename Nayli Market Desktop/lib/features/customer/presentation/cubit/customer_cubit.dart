import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/debt_record.dart';
import 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  final CustomerRepository repository;

  CustomerCubit({required this.repository}) : super(CustomerInitial());

  void loadCustomers({String query = ''}) {
    try {
      emit(CustomerLoading());
      final all = repository.getAllCustomers();
      final filtered = query.trim().isEmpty
          ? all
          : all.where((c) {
              final q = query.trim().toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  c.phoneNumber.toLowerCase().contains(q) ||
                  c.address.toLowerCase().contains(q);
            }).toList();

      final totalSum = all.fold<double>(0.0, (sum, c) => sum + c.currentDebt);

      emit(CustomerLoaded(
        customers: all,
        filteredCustomers: filtered,
        searchQuery: query,
        totalDebtsSum: totalSum,
      ));
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  void search(String query) {
    if (state is CustomerLoaded) {
      final current = state as CustomerLoaded;
      final filtered = query.trim().isEmpty
          ? current.customers
          : current.customers.where((c) {
              final q = query.trim().toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  c.phoneNumber.toLowerCase().contains(q) ||
                  c.address.toLowerCase().contains(q);
            }).toList();

      emit(CustomerLoaded(
        customers: current.customers,
        filteredCustomers: filtered,
        searchQuery: query,
        totalDebtsSum: current.totalDebtsSum,
      ));
    } else {
      loadCustomers(query: query);
    }
  }

  Future<void> addCustomer({
    required String name,
    required String phoneNumber,
    String address = '',
    double initialDebt = 0.0,
    double maxDebtLimit = 50000.0,
  }) async {
    try {
      final customer = Customer(
        id: const Uuid().v4(),
        name: name.trim(),
        phoneNumber: phoneNumber.trim(),
        address: address.trim(),
        currentDebt: initialDebt,
        maxDebtLimit: maxDebtLimit,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveCustomer(customer);
      if (initialDebt > 0) {
        await repository.addCreditToCustomer(
          customerId: customer.id,
          creditAmount: initialDebt,
          note: 'دين أولي مسجل',
        );
      }
      loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await repository.saveCustomer(customer.copyWith(updatedAt: DateTime.now()));
      loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await repository.deleteCustomer(id);
      loadCustomers();
    } catch (e) {
      emit(CustomerError(e.toString()));
    }
  }

  Future<Customer> recordPayment({
    required String customerId,
    required double paymentAmount,
    String note = '',
  }) async {
    final updated = await repository.recordDebtPayment(
      customerId: customerId,
      paymentAmount: paymentAmount,
      note: note,
    );
    loadCustomers();
    return updated;
  }

  Future<Customer> addCredit({
    required String customerId,
    required double creditAmount,
    String? invoiceId,
    String note = '',
  }) async {
    final updated = await repository.addCreditToCustomer(
      customerId: customerId,
      creditAmount: creditAmount,
      invoiceId: invoiceId,
      note: note,
    );
    loadCustomers();
    return updated;
  }

  List<DebtRecord> getCustomerHistory(String customerId) {
    return repository.getCustomerDebtHistory(customerId);
  }
}
