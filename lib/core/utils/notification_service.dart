import 'package:flutter/foundation.dart';
import '../data/hive_database.dart';

class StoreAlert {
  final String id;
  final String title;
  final String message;
  final String type; // 'low_stock', 'expiry', 'debt_limit', 'supplier'
  final DateTime timestamp;
  final String? targetRoute;

  StoreAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.targetRoute,
  });
}

class NotificationService {
  static const String _notifEnabledKey = 'system_notifications_enabled';
  static const String _lowStockThresholdKey = 'low_stock_alert_threshold';

  static bool isNotificationsEnabled() {
    return HiveDatabase.settingsBox.get(_notifEnabledKey, defaultValue: true) as bool;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_notifEnabledKey, enabled);
  }

  static int getLowStockThreshold() {
    return HiveDatabase.settingsBox.get(_lowStockThresholdKey, defaultValue: 5) as int;
  }

  static Future<void> setLowStockThreshold(int threshold) async {
    await HiveDatabase.settingsBox.put(_lowStockThresholdKey, threshold);
  }

  /// Gather live store alerts from inventory, customers, and supplier invoices
  static List<StoreAlert> getLiveAlerts() {
    final List<StoreAlert> alerts = [];
    final threshold = getLowStockThreshold();

    // 1. Low stock & Out of stock products
    final pBox = HiveDatabase.productBox;
    int outOfStockCount = 0;
    int lowStockCount = 0;

    for (final p in pBox.values) {
      if (p.stock <= 0) {
        outOfStockCount++;
      } else if (p.stock <= threshold) {
        lowStockCount++;
      }
    }

    if (outOfStockCount > 0) {
      alerts.add(StoreAlert(
        id: 'out_of_stock_alert',
        title: '⚠️ منتجات نفد مخزونها بالكامل ($outOfStockCount منتج)',
        message: 'يوجد $outOfStockCount صنف في المحل رصيدها 0، يرجى استلام سلع جديدة لتفادي ضياع المبيعات.',
        type: 'low_stock',
        timestamp: DateTime.now(),
        targetRoute: '/products',
      ));
    }

    if (lowStockCount > 0) {
      alerts.add(StoreAlert(
        id: 'low_stock_alert',
        title: '📦 منتجات قاربت على النفاد ($lowStockCount منتج)',
        message: 'يوجد $lowStockCount صنف في المحل رصيدها أقل من أو يساوي $threshold قطع.',
        type: 'low_stock',
        timestamp: DateTime.now(),
        targetRoute: '/products',
      ));
    }

    // 2. Customers exceeding credit limits
    final cBox = HiveDatabase.customersBox;
    int debtLimitExceededCount = 0;
    for (final c in cBox.values) {
      if (c.maxDebtLimit > 0 && c.currentDebt >= c.maxDebtLimit) {
        debtLimitExceededCount++;
      }
    }

    if (debtLimitExceededCount > 0) {
      alerts.add(StoreAlert(
        id: 'debt_limit_alert',
        title: '👥 زبائن تجاوزوا سقف الدين المسموح ($debtLimitExceededCount زبون)',
        message: 'يوجد $debtLimitExceededCount زبون وصل رصيد ديونهم إلى الحد الأقصى المحدد في الدفتر.',
        type: 'debt_limit',
        timestamp: DateTime.now(),
        targetRoute: '/customers',
      ));
    }

    // 3. Supplier debts
    final sBox = HiveDatabase.supplierInvoicesBox;
    double totalSupplierDebt = 0;
    for (final inv in sBox.values) {
      final remaining = (inv['remainingAmount'] as num?)?.toDouble() ?? 0.0;
      totalSupplierDebt += remaining;
    }

    if (totalSupplierDebt > 0) {
      alerts.add(StoreAlert(
        id: 'supplier_debt_alert',
        title: '🚚 ديون مستحقة للموردين (${totalSupplierDebt.toStringAsFixed(0)} دج)',
        message: 'لديك فواتير موردين غير مسددة بالكامل في قسم فواتير الموردين.',
        type: 'supplier',
        timestamp: DateTime.now(),
        targetRoute: '/products/supplier-invoices',
      ));
    }

    return alerts;
  }
}
