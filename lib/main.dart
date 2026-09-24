import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/single_instance_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/data/master_catalog_service.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_cubit.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/customer/presentation/cubit/customer_cubit.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'core/data/local_sync_server.dart';

import 'core/theme/theme_cubit.dart';
import 'core/theme/header_branding_cubit.dart';

class TouchAndMouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

void _log(String message) {
  try {
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isNotEmpty) {
      final file = File('$userProfile\\Documents\\nayli_kiosk_data\\startup_debug.log');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('[${DateTime.now().toIso8601String()}] $message\r\n', mode: FileMode.append);
    }
  } catch (_) {}
  debugPrint(message);
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _log('🚀 [STARTUP] WidgetsFlutterBinding initialized');

    FlutterError.onError = (FlutterErrorDetails details) {
      _log('❌ [FLUTTER_ERROR] ${details.exceptionAsString()}\n${details.stack}');
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      _log('⚠️ [ERROR_WIDGET] ${details.exceptionAsString()}');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('تنبيه أثناء تشغيل الواجهة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(details.exceptionAsString(), style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      );
    };

    // Window Manager & Single Instance Init (desktop only)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();
      _log('🖥️ [STARTUP] windowManager initialized');
      
      final isFirst = await SingleInstanceService.acquireSingleInstance();
      if (!isFirst) {
        _log('ℹ️ [STARTUP] Another instance is already active. Exiting.');
        exit(0);
      }

      await windowManager.setSize(const Size(1200, 720));
      await windowManager.setMinimumSize(const Size(800, 550));
      await windowManager.center();
      await windowManager.setTitle('Nayli Market POS');
      await windowManager.show();
      await windowManager.focus();
      _log('🖥️ [STARTUP] Window displayed and focused at 1200x720');
    }

    // إقلاع تسامحي لقواعد البيانات والسيرفر
    try {
      _log('📦 [STARTUP] Initializing HiveDatabase...');
      await HiveDatabase.initSafe();
      _log('📦 [STARTUP] HiveDatabase initialized successfully');
    } catch (e) {
      _log('❌ [STARTUP] Hive init failed: $e');
    }
    
    try {
      _log('💉 [STARTUP] Initializing Service Locator (DI)...');
      await di.init();
      _log('💉 [STARTUP] Service Locator (DI) initialized successfully');
    } catch (e) {
      _log('❌ [STARTUP] DI init failed: $e');
    }
    
    // 1. تشغيل التطبيق فوراً لظهور الواجهة للمستخدم
    _log('🎨 [STARTUP] Calling runApp(const MyApp())...');
    runApp(const MyApp());
    _log('🎨 [STARTUP] runApp executed');

    // 2. تحميل كتالوج الـ 60 ألف سلعة والسيرفر في الخلفية دون حجب الواجهة
    Future.microtask(() async {
      try {
        _log('📚 [STARTUP] Indexing Master Catalog in background...');
        await MasterCatalogService.instance.init();
        _log('📚 [STARTUP] Master Catalog indexed successfully');
      } catch (e) {
        _log('❌ [STARTUP] MasterCatalogService init error: $e');
      }
      try {
        _log('🌐 [STARTUP] Starting LocalSyncServer in background...');
        await LocalSyncServer.startServer();
        _log('🌐 [STARTUP] LocalSyncServer started successfully');
      } catch (e) {
        _log('❌ [STARTUP] Server init failed: $e');
      }
    });
  }, (error, stack) {
    _log('💥 [GLOBAL_ZONE_ERROR] $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LanguageCubit>(create: (context) => di.sl<LanguageCubit>()),
        BlocProvider<ThemeCubit>(create: (context) => di.sl<ThemeCubit>()),
        BlocProvider<HeaderBrandingCubit>(create: (context) => di.sl<HeaderBrandingCubit>()),
        BlocProvider<CustomerCubit>(create: (context) => di.sl<CustomerCubit>()..loadCustomers()),
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
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LanguageCubit, Locale>(
            builder: (context, locale) {
              return BlocBuilder<HeaderBrandingCubit, HeaderBrandingState>(
                builder: (context, branding) {
                  AppTheme.primaryColor = branding.headerColor;
                  return MaterialApp.router(
                    title: 'Nayli Kiosk',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.lightTheme,
                themeMode: ThemeMode.light,
                routerConfig: router,
                scrollBehavior: TouchAndMouseScrollBehavior(),
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
              );
            },
          );
        },
      ),
    );
  }
}

