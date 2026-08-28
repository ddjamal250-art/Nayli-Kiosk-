import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/debt_record.dart';

abstract class CustomerState extends Equatable {
  const CustomerState();

  @override
  List<Object?> get props => [];
}

class CustomerInitial extends CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  final List<Customer> customers;
  final List<Customer> filteredCustomers;
  final String searchQuery;
  final double totalDebtsSum;

  const CustomerLoaded({
    required this.customers,
    required this.filteredCustomers,
    this.searchQuery = '',
    required this.totalDebtsSum,
  });

  @override
  List<Object?> get props => [customers, filteredCustomers, searchQuery, totalDebtsSum];
}

class CustomerOperationSuccess extends CustomerState {
  final String message;
  final Customer? customer;

  const CustomerOperationSuccess(this.message, {this.customer});

  @override
  List<Object?> get props => [message, customer];
}

class CustomerError extends CustomerState {
  final String message;

  const CustomerError(this.message);

  @override
  List<Object?> get props => [message];
}
