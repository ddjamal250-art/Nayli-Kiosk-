import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/product_usecases.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/data/hive_database.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProductsUseCase getProductsUseCase;
  final AddProductUseCase addProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final AdjustStockUseCase adjustStockUseCase;

  StreamSubscription? _boxSubscription;
  Timer? _debounceTimer;

  ProductBloc({
    required this.getProductsUseCase,
    required this.addProductUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
    required this.adjustStockUseCase,
  }) : super(const ProductState()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
    on<AdjustProductStock>(_onAdjustProductStock);
    on<BatchDeductStock>(_onBatchDeductStock);

    _listenToProductBoxChanges();
  }

  void _listenToProductBoxChanges() {
    _boxSubscription?.cancel();
    try {
      if (Hive.isBoxOpen(HiveDatabase.productBoxName)) {
        _boxSubscription = HiveDatabase.productBox.watch().listen((_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 150), () {
            if (!isClosed) {
              add(const LoadProducts(silent: true));
            }
          });
        });
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _boxSubscription?.cancel();
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoadProducts(
      LoadProducts event, Emitter<ProductState> emit) async {
    if (!event.silent) {
      emit(state.copyWith(status: ProductStatus.loading));
    }
    final result = await getProductsUseCase(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (products) => emit(
          state.copyWith(status: ProductStatus.loaded, products: products)),
    );
  }

  Future<void> _onAddProduct(
      AddProduct event, Emitter<ProductState> emit) async {
    final updatedList = [event.product, ...state.products];
    emit(state.copyWith(status: ProductStatus.loading, products: updatedList));
    final result = await addProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            products: updatedList,
            message: null));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onUpdateProduct(
      UpdateProduct event, Emitter<ProductState> emit) async {
    final updatedList = state.products.map((p) => p.id == event.product.id ? event.product : p).toList();
    emit(state.copyWith(status: ProductStatus.loading, products: updatedList));
    final result = await updateProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            products: updatedList,
            message: null));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onDeleteProduct(
      DeleteProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await deleteProductUseCase(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: null));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onAdjustProductStock(
      AdjustProductStock event, Emitter<ProductState> emit) async {
    final result = await adjustStockUseCase(AdjustStockParams(
      productId: event.productId,
      quantityDelta: event.quantityDelta,
    ));
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Stock updated successfully'));
        add(LoadProducts());
      },
    );
  }

  Future<void> _onBatchDeductStock(
      BatchDeductStock event, Emitter<ProductState> emit) async {
    for (final item in event.items) {
      final id = item['id'] as String;
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      await adjustStockUseCase(AdjustStockParams(
        productId: id,
        quantityDelta: -qty,
      ));
    }
    add(LoadProducts());
  }
}
