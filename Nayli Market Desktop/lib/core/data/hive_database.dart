import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String invoicesBoxName = 'invoices';
  static const String customersBoxName = 'customers';
  static const String customerDebtsBoxName = 'customer_debts';
  static const String quickItemsBoxName = 'quick_items';
  static const String supplierInvoicesBoxName = 'supplier_invoices';
  static const String expensesBoxName = 'expenses';
  static const String devisBoxName = 'devis_invoices';
  static const String shiftsBoxName = 'cashier_shifts';
  static const String lossesBoxName = 'product_losses';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(invoicesBoxName); // Box for storing sales transactions
    await Hive.openBox(customersBoxName); // Box for storing customers & debts
    await Hive.openBox(customerDebtsBoxName); // Box for debt payment logs
    await Hive.openBox(quickItemsBoxName); // Box for customizable quick items
    await Hive.openBox(supplierInvoicesBoxName); // Box for supplier purchases & invoices
    await Hive.openBox(expensesBoxName); // Box for store daily expenses
    await Hive.openBox(devisBoxName); // Box for proforma / devis quotations
    await Hive.openBox(shiftsBoxName); // Box for cashier shifts / fond de caisse
    await Hive.openBox(lossesBoxName); // Box for spoiled, expired & broken product losses
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get invoicesBox => Hive.box(invoicesBoxName);
  static Box get customersBox => Hive.box(customersBoxName);
  static Box get customerDebtsBox => Hive.box(customerDebtsBoxName);
  static Box get quickItemsBox => Hive.box(quickItemsBoxName);
  static Box get supplierInvoicesBox => Hive.box(supplierInvoicesBoxName);
  static Box get expensesBox => Hive.box(expensesBoxName);
  static Box get devisBox => Hive.box(devisBoxName);
  static Box get shiftsBox => Hive.box(shiftsBoxName);
  static Box get lossesBox => Hive.box(lossesBoxName);
}
