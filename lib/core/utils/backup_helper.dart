import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/product/presentation/bloc/product_bloc.dart';
import '../../features/customer/presentation/cubit/customer_cubit.dart';

class BackupHelper {
  /// Exports all Hive boxes into a single structured JSON string
  static String exportDatabaseToJson() {
    final Map<String, dynamic> fullBackup = {
      'backup_version': '1.1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'products': [],
      'invoices': [],
      'customers': [],
      'customer_debts': [],
      'quick_items': [],
      'settings': {},
    };

    // 1. Products
    final productBox = HiveDatabase.productBox;
    for (var key in productBox.keys) {
      final ProductModel? prod = productBox.get(key);
      if (prod != null) {
        fullBackup['products'].add(prod.toJson());
      }
    }

    // 2. Invoices
    final invoicesBox = HiveDatabase.invoicesBox;
    for (var key in invoicesBox.keys) {
      final val = invoicesBox.get(key);
      if (val is Map) {
        fullBackup['invoices'].add(Map<String, dynamic>.from(val));
      }
    }

    // 3. Customers
    final customersBox = HiveDatabase.customersBox;
    for (var key in customersBox.keys) {
      final val = customersBox.get(key);
      if (val is Map) {
        fullBackup['customers'].add(Map<String, dynamic>.from(val));
      }
    }

    // 4. Customer Debts
    final debtsBox = HiveDatabase.customerDebtsBox;
    for (var key in debtsBox.keys) {
      final val = debtsBox.get(key);
      if (val is Map) {
        fullBackup['customer_debts'].add(Map<String, dynamic>.from(val));
      }
    }

    // 5. Quick Items
    final quickBox = HiveDatabase.quickItemsBox;
    for (var key in quickBox.keys) {
      final val = quickBox.get(key);
      if (val is Map) {
        fullBackup['quick_items'].add(Map<String, dynamic>.from(val));
      }
    }

    // 6. Settings
    final settingsBox = HiveDatabase.settingsBox;
    for (var key in settingsBox.keys) {
      fullBackup['settings'][key.toString()] = settingsBox.get(key);
    }

    return const JsonEncoder.withIndent('  ').convert(fullBackup);
  }

  /// Restores database from a JSON backup string safely without data corruption
  static Future<bool> restoreDatabaseFromJson(BuildContext context, String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return false;

      final data = Map<String, dynamic>.from(decoded);

      // Restore Products
      if (data['products'] is List) {
        final productBox = HiveDatabase.productBox;
        for (var p in data['products']) {
          if (p is Map) {
            final model = ProductModel.fromJson(Map<String, dynamic>.from(p));
            await productBox.put(model.id, model);
          }
        }
      }

      // Restore Invoices
      if (data['invoices'] is List) {
        final invoicesBox = HiveDatabase.invoicesBox;
        for (var inv in data['invoices']) {
          if (inv is Map) {
            final map = Map<String, dynamic>.from(inv);
            final key = map['id'] ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
            await invoicesBox.put(key, map);
          }
        }
      }

      // Restore Customers
      if (data['customers'] is List) {
        final customersBox = HiveDatabase.customersBox;
        for (var c in data['customers']) {
          if (c is Map) {
            final map = Map<String, dynamic>.from(c);
            final id = map['id'] ?? 'cust_${DateTime.now().millisecondsSinceEpoch}';
            await customersBox.put(id, map);
          }
        }
      }

      // Restore Customer Debts
      if (data['customer_debts'] is List) {
        final debtsBox = HiveDatabase.customerDebtsBox;
        for (var d in data['customer_debts']) {
          if (d is Map) {
            final map = Map<String, dynamic>.from(d);
            final id = map['id'] ?? 'debt_${DateTime.now().millisecondsSinceEpoch}';
            await debtsBox.put(id, map);
          }
        }
      }

      // Restore Quick Items
      if (data['quick_items'] is List) {
        final quickBox = HiveDatabase.quickItemsBox;
        for (var q in data['quick_items']) {
          if (q is Map) {
            final map = Map<String, dynamic>.from(q);
            final id = map['id'] ?? 'q_${DateTime.now().millisecondsSinceEpoch}';
            await quickBox.put(id, map);
          }
        }
      }

      // Reload Blocs
      if (context.mounted) {
        context.read<ProductBloc>().add(LoadProducts());
        context.read<CustomerCubit>().loadCustomers();
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }
}