part of 'product_bloc.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object> get props => [];
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class AddProduct extends ProductEvent {
  final Product product;
  const AddProduct(this.product);
  @override
  List<Object> get props => [product];
}

class UpdateProduct extends ProductEvent {
  final Product product;
  const UpdateProduct(this.product);
  @override
  List<Object> get props => [product];
}

class DeleteProduct extends ProductEvent {
  final String id;
  const DeleteProduct(this.id);
  @override
  List<Object> get props => [id];
}

class AdjustProductStock extends ProductEvent {
  final String productId;
  final int quantityDelta;
  final double? newPrice;
  const AdjustProductStock({
    required this.productId,
    required this.quantityDelta,
    this.newPrice,
  });
  @override
  List<Object> get props => [productId, quantityDelta];
}

class BatchDeductStock extends ProductEvent {
  final List<Map<String, dynamic>> items; // [{'id': String, 'quantity': int}]
  const BatchDeductStock(this.items);
  @override
  List<Object> get props => [items];
}
