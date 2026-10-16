import 'package:flutter/foundation.dart';
import '../../../../core/data/hive_database.dart';
import '../domain/entities/customer.dart';

class LoyaltyService {
  static bool get isEnabled =>
      HiveDatabase.settingsBox.get('loyalty_enabled', defaultValue: true) as bool;

  static double get dinarPerPoint =>
      (HiveDatabase.settingsBox.get('loyalty_dinar_per_point', defaultValue: 100.0) as num).toDouble();

  static double get pointValueInDinar =>
      (HiveDatabase.settingsBox.get('loyalty_point_redemption_value', defaultValue: 1.0) as num).toDouble();

  /// احتساب النقاط المكتسبة من مبلغ المبيعات
  static double calculatePointsForAmount(double amount) {
    if (!isEnabled || dinarPerPoint <= 0 || amount <= 0) return 0.0;
    return (amount / dinarPerPoint).floorToDouble();
  }

  /// تسجيل وإضافة نقاط ولاء للزبون بعد إتمام البيع
  static Future<double> awardPointsForSale({
    required String customerId,
    required double totalAmount,
  }) async {
    if (!isEnabled || totalAmount <= 0) return 0.0;
    try {
      final box = HiveDatabase.customersBox;
      final data = box.get(customerId);
      if (data == null || data is! Map) return 0.0;

      final customer = Customer.fromMap(data);
      final earned = calculatePointsForAmount(totalAmount);
      if (earned <= 0) return 0.0;

      final updated = customer.copyWith(
        loyaltyPoints: customer.loyaltyPoints + earned,
        updatedAt: DateTime.now(),
      );

      await box.put(customerId, updated.toMap());
      debugPrint('Loyalty: Awarded $earned points to ${customer.name}. New total: ${updated.loyaltyPoints}');
      return earned;
    } catch (e) {
      debugPrint('Error awarding loyalty points: $e');
      return 0.0;
    }
  }

  /// استخدام/خصم نقاط الولاء وتحويلها إلى تخفيض نقدي
  static Future<bool> redeemPoints({
    required String customerId,
    required double pointsToRedeem,
  }) async {
    try {
      final box = HiveDatabase.customersBox;
      final data = box.get(customerId);
      if (data == null || data is! Map) return false;

      final customer = Customer.fromMap(data);
      if (customer.loyaltyPoints < pointsToRedeem) return false;

      final updated = customer.copyWith(
        loyaltyPoints: (customer.loyaltyPoints - pointsToRedeem).clamp(0.0, double.infinity),
        updatedAt: DateTime.now(),
      );

      await box.put(customerId, updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error redeeming points: $e');
      return false;
    }
  }

  /// إضافة رصيد متجر (Store Credit) للزبون
  static Future<void> addStoreCredit({
    required String customerId,
    required double creditAmount,
  }) async {
    try {
      final box = HiveDatabase.customersBox;
      final data = box.get(customerId);
      if (data == null || data is! Map) return;

      final customer = Customer.fromMap(data);
      final updated = customer.copyWith(
        storeCreditBalance: customer.storeCreditBalance + creditAmount,
        updatedAt: DateTime.now(),
      );

      await box.put(customerId, updated.toMap());
    } catch (e) {
      debugPrint('Error adding store credit: $e');
    }
  }
}
