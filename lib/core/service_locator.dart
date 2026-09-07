import 'package:get_it/get_it.dart';
import 'localization/language_cubit.dart';
import '../features/customer/data/repositories/customer_repository.dart';
import '../features/customer/presentation/cubit/customer_cubit.dart';
import '../features/product/data/repositories/product_repository_impl.dart';
import '../features/product/domain/repositories/product_repository.dart';
import '../features/product/domain/usecases/product_usecases.dart';
import '../features/product/presentation/bloc/product_bloc.dart';
import '../features/shop/data/repositories/shop_repository_impl.dart';
import '../features/shop/domain/repositories/shop_repository.dart';
import '../features/shop/domain/usecases/shop_usecases.dart';
import '../features/shop/presentation/bloc/shop_bloc.dart';
import '../features/settings/data/repositories/printer_repository_impl.dart';
import '../features/settings/domain/repositories/printer_repository.dart';
import '../features/settings/presentation/bloc/printer_bloc.dart';

import 'theme/theme_cubit.dart';
import 'theme/header_branding_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Localization & Theme Branding
  sl.registerLazySingleton<LanguageCubit>(() => LanguageCubit());
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
  sl.registerLazySingleton<HeaderBrandingCubit>(() => HeaderBrandingCubit());

  // Features - Product
  // Bloc
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
      adjustStockUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));
  sl.registerLazySingleton(() => AdjustStockUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );

  // Features - Shop
  // Use cases
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(),
  );

  // Features - Customer & Debts
  sl.registerLazySingleton<CustomerRepository>(() => CustomerRepository());
  sl.registerFactory(() => CustomerCubit(repository: sl()));

  // Features - Settings / Printer
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );
}
