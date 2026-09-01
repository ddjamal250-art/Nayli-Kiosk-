import 'dart:math';
import '../data/hive_database.dart';

class BarcodeGeneratorHelper {
  /// Calculate EAN-13 Checksum digit (Modulo 10)
  static int calculateEan13Checksum(String first12Digits) {
    if (first12Digits.length != 12) return 0;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.tryParse(first12Digits[i]) ?? 0;
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int mod = sum % 10;
    return (mod == 0) ? 0 : 10 - mod;
  }

  /// Generate a unique in-store EAN-13 barcode starting with '200'
  static String generateUniqueInStoreEan13() {
    final box = HiveDatabase.productBox;
    final existingBarcodes = box.values.map((p) => p.barcode.trim()).toSet();

    for (int attempt = 0; attempt < 1000; attempt++) {
      // 200 prefix (Standard GS1 In-Store) + 9 random/sequential digits
      final timestampPart = DateTime.now().millisecondsSinceEpoch.toString();
      final suffix = timestampPart.length >= 9
          ? timestampPart.substring(timestampPart.length - 9)
          : timestampPart.padLeft(9, '0');
      
      final first12 = '200$suffix';
      final checksum = calculateEan13Checksum(first12);
      final ean13 = '$first12$checksum';

      if (!existingBarcodes.contains(ean13)) {
        return ean13;
      }
    }

    final fallback = '200${Random().nextInt(999999999).toString().padLeft(9, '0')}';
    return '$fallback${calculateEan13Checksum(fallback)}';
  }

  /// Generate next sequential short SKU number (e.g., '1', '2', '3'...) for fast numpad entry
  static String generateNextShortSku() {
    final box = HiveDatabase.quickItemsBox;
    final quickItems = box.values.toList();
    int maxSku = 0;
    for (var item in quickItems) {
      if (item is Map) {
        final code = item['shortCode']?.toString() ?? item['id']?.toString() ?? '';
        final parsed = int.tryParse(code);
        if (parsed != null && parsed > maxSku && parsed < 1000) {
          maxSku = parsed;
        }
      }
    }
    return (maxSku + 1).toString();
  }
}

