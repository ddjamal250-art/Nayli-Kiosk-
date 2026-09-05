import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/data/hive_database.dart';
import '../../core/utils/app_constants.dart';
import '../../features/billing/domain/entities/cart_item.dart';
import '../../features/shop/data/models/shop_model.dart';

class WhatsAppReceiptHelper {
  /// Attempts to launch WhatsApp native app directly (without passing through web browser)
  /// using the `whatsapp://send` URI scheme, falling back to `https://wa.me/` if not installed.
  static Future<bool> sendDirectWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = formatAlgerianPhone(phone);
    final encodedMsg = Uri.encodeComponent(message);

    // 1. First priority: native desktop / mobile app protocol (bypasses browser)
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched = await launchUrl(nativeUri, mode: LaunchMode.externalNonBrowserApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // 2. Fallback: web universal link (if native app protocol not recognized)
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return false;
  }
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
        if (shop.phoneNumber.isNotEmpty) shopPhone = shop.phoneNumber;
        if (shop.addressLine1.isNotEmpty) shopAddress = shop.addressLine1;
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
