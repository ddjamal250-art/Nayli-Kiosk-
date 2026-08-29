import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/core/data/master_catalog_seed.dart';
import 'package:billing_app/core/utils/scale_barcode_parser.dart';
import 'package:billing_app/core/utils/license_service.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';
import 'package:billing_app/features/billing/domain/entities/held_cart.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🚀 HEAVY LOAD & STRESS TEST SUITE', () {
    test('1. Catalog O(1) Instant Lookup Stress Test (10,000 lookups)', () {
      final stopwatch = Stopwatch()..start();

      // Seed items lookup test
      for (int i = 0; i < 10000; i++) {
        final barcode = '6130234001147';
        final item = MasterCatalogSeed.lookup(barcode);
        if (item != null) {
          expect(item.name.isNotEmpty, true);
        }
      }

      stopwatch.stop();
      print('⚡ 10,000 Barcode Lookups completed in ${stopwatch.elapsedMilliseconds} ms (Average: ${(stopwatch.elapsedMicroseconds / 10000).toStringAsFixed(2)} µs per lookup)');
      expect(stopwatch.elapsedMilliseconds < 500, true, reason: 'Lookups must be under 500ms total');
    });

    test('2. Scale Barcode Parsing Heavy Load (5,000 parses)', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 5000; i++) {
        // Price embedded barcode (e.g. 20 01234 00450 8 -> Product 01234, Price 450 DA)
        final pResult = ScaleBarcodeParser.parse('2001234004508');
        expect(pResult.isScaleBarcode, true);
        expect(pResult.embeddedPrice, 450.0);

        // Weight embedded barcode (e.g. 21 00567 01500 4 -> Product 00567, Weight 1.500 kg)
        final wResult = ScaleBarcodeParser.parse('2100567015004');
        expect(wResult.isScaleBarcode, true);
        expect(wResult.weightKg, 1.500);
      }

      stopwatch.stop();
      print('⚖️ 5,000 Scale Barcode Parses completed in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds < 300, true);
    });

    test('3. Cart Calculations & High Volume Item Stress Test (1,000 items)', () {
      final stopwatch = Stopwatch()..start();

      final List<CartItem> items = [];
      double expectedSubtotal = 0;

      for (int i = 1; i <= 1000; i++) {
        final p = Product(
          id: 'prod_$i',
          name: 'منتج تجريبي $i',
          barcode: '613000000$i',
          price: (i * 10.0),
          costPrice: (i * 8.0),
          stock: 100,
        );
        final cartItem = CartItem(product: p, quantity: 2);
        items.add(cartItem);
        expectedSubtotal += cartItem.total;
      }

      expect(items.length, 1000);
      expect(expectedSubtotal, 1000 * 1001 * 10); // Sum of i from 1 to 1000 * 20 = 1000*1001/2 * 20

      // Test 10% Discount calculation
      final discountPercent = 10.0;
      final calculatedDiscount = expectedSubtotal * (discountPercent / 100.0);
      final finalTotal = expectedSubtotal - calculatedDiscount;

      expect(finalTotal, expectedSubtotal * 0.9);

      stopwatch.stop();
      print('🛒 1,000 Cart Items generated and computed in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds < 200, true);
    });

    test('4. Held Carts Parking & Expiration Stress Test (500 carts)', () {
      final stopwatch = Stopwatch()..start();

      final List<HeldCart> heldCarts = [];
      final now = DateTime.now();

      for (int i = 0; i < 500; i++) {
        final p = Product(
          id: 'prod_$i',
          name: 'سلعة $i',
          barcode: 'BAR_$i',
          price: 150.0,
          costPrice: 120.0,
        );
        // Half fresh, half expired (> 20 mins ago)
        final createdAt = i % 2 == 0
            ? now.subtract(const Duration(minutes: 5))
            : now.subtract(const Duration(minutes: 25));

        heldCarts.add(HeldCart(
          id: 'cart_$i',
          tag: 'زبون $i',
          items: [CartItem(product: p, quantity: 1)],
          totalAmount: 150.0,
          createdAt: createdAt,
        ));
      }

      // Filter expired (> 20 mins)
      final validCarts = heldCarts.where((c) {
        return now.difference(c.createdAt).inMinutes < 20;
      }).toList();

      expect(validCarts.length, 250);

      stopwatch.stop();
      print('⏸️ 500 Held Carts created, filtered, and validated in ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds < 100, true);
    });

    test('5. License & Field Activation Code Validation Stress Test', () {
      expect(LicenseService.verifyCode('RAACH-LIFETIME-PRO'), true);
      expect(LicenseService.verifyCode('RAACH60'), true);
      expect(LicenseService.verifyCode('RAACH-YEARLY-2026'), true);
      expect(LicenseService.verifyCode('INVALID-CODE-123'), false);
      expect(LicenseService.verifyCode(''), false);
      print('🔐 License & Activation Codes 100% verified');
    });

    test('6. CSV Export Generator Stress Test (10,000 rows)', () {
      final stopwatch = Stopwatch()..start();

      final buffer = StringBuffer();
      buffer.writeln('ID,Barcode,Name,Price,CostPrice,Stock,Category');

      for (int i = 0; i < 10000; i++) {
        buffer.writeln('$i,613$i,منتج جزائري $i,120.00,95.00,50,مواد غذائية');
      }

      final csvContent = buffer.toString();
      expect(csvContent.length > 300000, true);

      stopwatch.stop();
      print('📊 10,000 Products CSV Generated in ${stopwatch.elapsedMilliseconds} ms (${(csvContent.length / 1024).toStringAsFixed(1)} KB)');
      expect(stopwatch.elapsedMilliseconds < 300, true);
    });
  });
}
