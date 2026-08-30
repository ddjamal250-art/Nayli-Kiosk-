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

import '../../features/product/presentation/pages/shelf_labels_page.dart';
import '../../features/product/presentation/pages/inventory_audit_page.dart';
import '../../features/product/presentation/pages/losses_page.dart';
import '../../features/settings/presentation/pages/receipt_customizer_page.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isActivated = LicenseService.isActivated();
    final isGoingToActivation = state.matchedLocation == '/activation';

    if (!isActivated && !isGoingToActivation) {
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
      builder: (context, state) => const HomePage(),
      routes: [
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
      path: '/shifts',
      builder: (context, state) => const CashierShiftsPage(),
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
          builder: (context, state) => const StockInPage(),
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
  ],
);

