import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/hive_database.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/customer/domain/entities/customer.dart';
import '../../features/customer/presentation/cubit/customer_cubit.dart';
import '../utils/app_constants.dart';

class ExcelExportHelper {
  /// Generate CSV string for Products Inventory (Excel UTF-8 compatible)
  static String exportProductsToCsv() {
    final box = HiveDatabase.productBox;
    final products = box.values.toList();

    final buffer = StringBuffer();
    // UTF-8 BOM for Excel Arabic character compatibility
    buffer.write('\uFEFF');
    buffer.writeln('الباركود,اسم المنتج,سعر الشراء (التكلفة دج),سعر البيع (دج),المخزون (الكمية),إجمالي قيمة السلعة (دج)');

    for (var p in products) {
      final barcode = '"${p.barcode.replaceAll('"', '""')}"';
      final name = '"${p.name.replaceAll('"', '""')}"';
      final cost = p.costPrice.toStringAsFixed(2);
      final price = p.price.toStringAsFixed(2);
      final stock = p.stock.toString();
      final totalValue = (p.price * p.stock).toStringAsFixed(2);

      buffer.writeln('$barcode,$name,$cost,$price,$stock,$totalValue');
    }

    return buffer.toString();
  }

  /// Generate CSV string for Customer Debts Ledger (Excel UTF-8 compatible)
  static String exportDebtsToCsv(List<Customer> customers) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln('اسم الزبون,رقم الهاتف,إجمالي الدين الحالي (دج),حالة الحساب');

    for (var c in customers) {
      final name = '"${c.name.replaceAll('"', '""')}"';
      final phone = '"${c.phoneNumber.replaceAll('"', '""')}"';
      final debt = c.currentDebt.toStringAsFixed(2);
      final status = c.currentDebt > 0 ? 'عليه دين' : 'خالص (0 دج)';

      buffer.writeln('$name,$phone,$debt,$status');
    }

    return buffer.toString();
  }
}