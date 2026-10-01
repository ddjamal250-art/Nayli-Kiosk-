import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/entities/supplier.dart';
import 'supplier_state.dart';

class SupplierCubit extends Cubit<SupplierState> {
  final SupplierRepository _repository = SupplierRepository();

  SupplierCubit() : super(SupplierInitial());

  void loadSuppliers() {
    emit(SupplierLoading());
    try {
      final suppliers = _repository.getAllSuppliers();
      emit(SupplierLoaded(suppliers));
    } catch (e) {
      emit(SupplierError(e.toString()));
    }
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _repository.saveSupplier(supplier);
    loadSuppliers();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _repository.saveSupplier(supplier);
    loadSuppliers();
  }

  Future<void> deleteSupplier(String id) async {
    await _repository.deleteSupplier(id);
    loadSuppliers();
  }
}
