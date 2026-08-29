import 'package:intl/intl.dart';
import '../../core/data/hive_database.dart';
import '../../core/utils/app_constants.dart';
import '../../features/billing/domain/entities/cart_item.dart';
import '../../features/shop/data/models/shop_model.dart';

class WhatsAppReceiptHelper {
  /// Generate a clean, beautifully formatted WhatsApp text receipt for sales & credit
  static String generateReceiptMessage({
    required List<CartItem> items,
    required double subTotal,
    required double discount,
    required double total,
    required String paymentMode, // 'cash', 'credit', 'acompte'
    required double paidAmount,
    required double remainingCredit,
    String? customerName,
    String? customerPhone,
    double? totalCustomerDebt,
    String? invoiceId,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(now);

    // Get Shop details
    String shopName = AppConstants.defaultShopName;
    String shopPhone = '';
    String shopAddress = '';

    final shopBox = HiveDatabase.shopBox;
    if (shopBox.isNotEmpty) {
      final ShopModel? shop = shopBox.getAt(0);
      if (shop != null) {
        if (shop.name.isNotEmpty) shopName = shop.name;
        if (shop.phone.isNotEmpty) shopPhone = shop.phone;
        if (shop.address.isNotEmpty) shopAddress = shop.address;
      }
    }

    buffer.writeln('🏪 *$shopName*');
    if (shopAddress.isNotEmpty) buffer.writeln('📍 $shopAddress');
    if (shopPhone.isNotEmpty) buffer.writeln('📞 $shopPhone');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🧾 *وصل مشتريات إلكتروني* ${invoiceId != null ? '#$invoiceId' : ''}');
    buffer.writeln('📅 التاريخ: $dateStr');
    if (customerName != null && customerName.isNotEmpty) {
      buffer.writeln('👤 الزبون: *$customerName*');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🛍️ *تفاصيل السلع:*');

    for (final item in items) {
      final itemTotal = item.product.price * item.quantity;
      buffer.writeln('• ${item.product.name} [${item.quantity} × ${item.product.price.toStringAsFixed(0)}] = ${itemTotal.toStringAsFixed(0)} ${AppConstants.currencySymbol}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (discount > 0) {
      buffer.writeln('🏷️ المجموع الأولي: ${subTotal.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
      buffer.writeln('🎁 تخفيض: -${discount.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
    }
    buffer.writeln('💵 *المجموع الصافي:* *${total.toStringAsFixed(2)} ${AppConstants.currencySymbol}*');

    if (paymentMode == 'credit') {
      buffer.writeln('⚠️ *طريقة الدفع:* كريدي مسجل (دين)');
      buffer.writeln('📝 المبلغ المقيد: ${total.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
    } else if (paymentMode == 'acompte') {
      buffer.writeln('💰 *المدفوع نقداً (تسبيق):* ${paidAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
      buffer.writeln('⚠️ *المتبقي في الكريدي:* ${remainingCredit.toStringAsFixed(2)} ${AppConstants.currencySymbol}');
    } else {
      buffer.writeln('✅ *طريقة الدفع:* نقداً (خالص)');
    }

    if (totalCustomerDebt != null && totalCustomerDebt > 0) {
      buffer.writeln('📊 *إجمالي رصيد ديونك المسجلة:* *${totalCustomerDebt.toStringAsFixed(2)} ${AppConstants.currencySymbol}*');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🙏 *شكراً لثقتكم وزيارتكم الكريمة!*');

    return buffer.toString();
  }

  /// Clean phone number to international Algerian format (+213)
  static String formatAlgerianPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '213${clean.substring(1)}';
    } else if (!clean.startsWith('213')) {
      clean = '213$clean';
    }
    return clean;
  }
}
