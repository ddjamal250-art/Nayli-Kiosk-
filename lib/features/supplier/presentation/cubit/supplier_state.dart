import 'package:equatable/equatable.dart';
import '../../domain/entities/supplier.dart';

abstract class SupplierState extends Equatable {
  const SupplierState();
  @override
  List<Object?> get props => [];
}

class SupplierInitial extends SupplierState {}
class SupplierLoading extends SupplierState {}
class SupplierLoaded extends SupplierState {
  final List<Supplier> suppliers;
  const SupplierLoaded(this.suppliers);
  @override
  List<Object?> get props => [suppliers];
}
class SupplierError extends SupplierState {
  final String message;
  const SupplierError(this.message);
  @override
  List<Object?> get props => [message];
}
