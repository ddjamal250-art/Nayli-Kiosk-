import 'package:collection/collection.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

import '../../../../core/utils/barcode_normalizer.dart';

class ProductRepositoryImpl implements ProductRepository {
  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final box = HiveDatabase.productBox;
      final products = box.values.toList();
      return Right(products);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      final box = HiveDatabase.productBox;
      final products = box.values.toList();

      // بحث PLU: للميزان التجاري — الباركود يأتي بالشكل 'PLU_42'
      if (barcode.startsWith('PLU_')) {
        final pluSearch = barcode.substring(4).replaceFirst(RegExp(r'^0+'), '');
        if (pluSearch.isNotEmpty) {
          final pluMatch = products.firstWhereOrNull((p) {
            final plu = (p.pluCode ?? '').trim().replaceFirst(RegExp(r'^0+'), '');
            return plu.isNotEmpty && plu == pluSearch;
          });
          if (pluMatch != null) return Right(pluMatch.toEntity());
        }
        // لم يجد بـ PLU → لا تكمل بحثاً بالباركود المشوَّه
        return Left(CacheFailure('Product not found by PLU: $barcode'));
      }

      // بحث عادي بالباركود
      final matched = BarcodeNormalizer.findProduct(products, barcode);
      if (matched != null) {
        return Right(matched.toEntity());
      }
      return Left(CacheFailure('Product not found: $barcode'));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model); // Using ID as key
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      final box = HiveDatabase.productBox;
      await box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adjustStock(String id, int quantityDelta) async {
    try {
      final box = HiveDatabase.productBox;
      final existingModel = box.get(id);
      if (existingModel != null) {
        final updatedStock = existingModel.stock + quantityDelta;
        final updatedModel = ProductModel(
          id: existingModel.id,
          name: existingModel.name,
          barcode: existingModel.barcode,
          price: existingModel.price,
          stock: updatedStock,
        );
        await box.put(id, updatedModel);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
