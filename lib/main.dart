import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_cubit.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LanguageCubit>(create: (context) => di.sl<LanguageCubit>()),
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
      ],
      child: BlocBuilder<LanguageCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: 'Billing App',
            theme: AppTheme.lightTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: const [
              Locale('ar'),
              Locale('fr'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
