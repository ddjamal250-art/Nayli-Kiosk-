import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/product/presentation/pages/stock_in_page.dart';
import '../../features/product/presentation/pages/master_catalog_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/activation_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/billing/presentation/pages/daily_report_page.dart';
import '../../features/billing/presentation/pages/expenses_page.dart';
import '../../features/billing/presentation/pages/devis_page.dart';
import '../../features/billing/presentation/pages/cashier_shifts_page.dart';
import '../../features/product/presentation/pages/supplier_invoices_page.dart';
import '../../features/product/presentation/pages/new_supplier_invoice_page.dart';
import '../../features/customer/presentation/pages/customers_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../core/utils/license_service.dart';
import '../../core/data/hive_database.dart';

import '../../features/product/presentation/pages/shelf_labels_page.dart';
import '../../features/product/presentation/pages/inventory_audit_page.dart';
import '../../features/product/presentation/pages/losses_page.dart';
import '../../features/settings/presentation/pages/receipt_customizer_page.dart';

import '../../features/billing/presentation/pages/desktop_pos_page.dart';
import '../../features/documents/presentation/pages/documents_hub_page.dart';
import '../../features/backup/presentation/pages/backup_page.dart';
import '../../features/shifts/presentation/pages/shifts_page.dart';
import '../../features/shifts/presentation/pages/staff_management_page.dart';
import '../../features/settings/presentation/pages/lan_sync_settings_page.dart';
import '../../features/billing/presentation/pages/kiosk_price_checker_page.dart';
import '../../features/settings/presentation/pages/kiosk_settings_page.dart';
import '../../features/settings/presentation/pages/advanced_pos_settings_page.dart';
import '../../features/product/presentation/pages/expiry_monitor_page.dart';
import '../../features/product/presentation/pages/shopping_list_page.dart';
import '../../features/documents/presentation/widgets/receipt_ocr_scanner_dialog.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isActivated = LicenseService.isActivated();
    final isGoingToActivation = state.matchedLocation == '/activation';
    final isGoingToScanner = state.matchedLocation == '/scanner';
    final isKioskRoute = state.matchedLocation == '/kiosk' || state.matchedLocation == '/kiosk-settings';
    
    // Check if device is configured as a dedicated Customer Price-Checker Kiosk terminal
    final isKioskDevice = HiveDatabase.settingsBox.get('device_role', defaultValue: 'cashier') == 'customer_kiosk';

    // Dedicated Kiosk terminals are free and unlimited; boot straight into /kiosk
    if (isKioskDevice) {
      if (!isKioskRoute && !isGoingToActivation) {
        return '/kiosk';
      }
      return null;
    }

    // Direct access to /kiosk is always permitted without consuming cashier quota
    if (isKioskRoute) {
      return null;
    }

    if (!isActivated && !isGoingToActivation && !isGoingToScanner) {
      return '/activation';
    }
    if (isActivated && isGoingToActivation) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/activation',
      builder: (context, state) => const ActivationPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) {
        // Desktop platforms (Windows, Linux, macOS) use the wide desktop POS interface
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          return const DesktopPosPage();
        }
        // Mobile platforms (Android, iOS) use the native mobile touch & camera interface
        return const HomePage();
      },
      routes: [
        GoRoute(
          path: 'desktop-pos',
          builder: (context, state) => const DesktopPosPage(),
        ),
        GoRoute(
          path: 'classic-mobile-pos',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        GoRoute(
          path: 'receipt-designer',
          builder: (context, state) => const ReceiptCustomizerPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/master-catalog',
      builder: (context, state) => const MasterCatalogPage(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const DailyReportPage(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpensesPage(),
    ),
    GoRoute(
      path: '/devis',
      builder: (context, state) => const DevisPage(),
    ),
    GoRoute(
      path: '/documents',
      builder: (context, state) => const DocumentsHubPage(),
    ),
    GoRoute(
      path: '/stock-in',
      builder: (context, state) => StockInPage(
        initialReceiptResult: state.extra is ParsedReceiptResult ? state.extra as ParsedReceiptResult : null,
      ),
    ),
    GoRoute(
      path: '/backups',
      builder: (context, state) => const BackupPage(),
    ),
    GoRoute(
      path: '/shifts',
      builder: (context, state) => const ShiftsPage(),
    ),
    GoRoute(
      path: '/staff-management',
      builder: (context, state) => const StaffManagementPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'stock-in',
          builder: (context, state) => StockInPage(
            initialReceiptResult: state.extra is ParsedReceiptResult ? state.extra as ParsedReceiptResult : null,
          ),
        ),
        GoRoute(
          path: 'supplier-invoices',
          builder: (context, state) => const SupplierInvoicesPage(),
        ),
        GoRoute(
          path: 'supplier-invoice/new',
          builder: (context, state) => const NewSupplierInvoicePage(),
        ),
        GoRoute(
          path: 'catalog',
          builder: (context, state) => const MasterCatalogPage(),
        ),
        GoRoute(
          path: 'shelf-labels',
          builder: (context, state) => const ShelfLabelsPage(),
        ),
        GoRoute(
          path: 'inventory-audit',
          builder: (context, state) => const InventoryAuditPage(),
        ),
        GoRoute(
          path: 'losses',
          builder: (context, state) => const LossesPage(),
        ),
        GoRoute(
          path: 'shopping-list',
          builder: (context, state) => const ShoppingListPage(),
        ),
        GoRoute(
          path: 'expiry-monitor',
          builder: (context, state) => const ExpiryMonitorPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
    GoRoute(
      path: '/lan-sync',
      builder: (context, state) => const LanSyncSettingsPage(),
    ),
    GoRoute(
      path: '/kiosk',
      builder: (context, state) => const KioskPriceCheckerPage(),
    ),
    GoRoute(
      path: '/kiosk-settings',
      builder: (context, state) => const KioskSettingsPage(),
    ),
    GoRoute(
      path: '/advanced-pos-settings',
      builder: (context, state) => const AdvancedPosSettingsPage(),
    ),
  ],
);

