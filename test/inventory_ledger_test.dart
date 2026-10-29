import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/entities/product_unit.dart';
import 'package:billing_app/features/product/data/inventory_ledger.dart';

void main() {
  group('InventoryLedger.baseId Tests', () {
    test('strips unit suffixes correctly', () {
      expect(InventoryLedger.baseId('prod123_carton_456'), 'prod123');
      expect(InventoryLedger.baseId('prod123_pack_10'), 'prod123');
      expect(InventoryLedger.baseId('prod123_piece_1'), 'prod123');
      expect(InventoryLedger.baseId('prod123_meter_5'), 'prod123');
      expect(InventoryLedger.baseId('prod123_ml_50'), 'prod123');
      expect(InventoryLedger.baseId('prod123_unit_2'), 'prod123');
      expect(InventoryLedger.baseId('prod123_offer_1'), 'prod123');
    });

    test('strips scale_ prefix and timestamp correctly', () {
      expect(InventoryLedger.baseId('scale_prod123_1730000000000'), 'prod123');
      expect(InventoryLedger.baseId('scale_prod123'), 'prod123');
      expect(InventoryLedger.baseId('scale_custom_item_id_99999999'), 'custom_item_id');
    });

    test('leaves clean product ID intact', () {
      expect(InventoryLedger.baseId('prod123'), 'prod123');
      expect(InventoryLedger.baseId('my-guid-uuid-456'), 'my-guid-uuid-456');
    });
  });

  group('InventoryLedger FIFO & Stock Invariant Tests', () {
    final baseProduct = Product(
      id: 'p1',
      name: 'Test Milk',
      barcode: '1234567890123',
      price: 120.0,
      costPrice: 100.0,
      stock: 15.0,
      stockBatches: [
        PurchaseBatch(
          costPrice: 90.0,
          remainingQuantity: 5.0,
          dateAdded: DateTime(2026, 1, 1),
        ),
        PurchaseBatch(
          costPrice: 100.0,
          remainingQuantity: 10.0,
          dateAdded: DateTime(2026, 1, 2),
        ),
      ],
    );

    test('consume FIFO drains oldest batch first', () {
      final res = InventoryLedger.consume(baseProduct, 7.0);

      // Consumed 5 from batch 1 (@90) + 2 from batch 2 (@100) = 450 + 200 = 650
      expect(res.cogs, 650.0);
      expect(res.quantity, 7.0);
      expect(res.unitCost, 650.0 / 7.0);
      expect(res.product.stock, 8.0);

      // Remaining batches: only batch 2 with 8 remaining
      expect(res.product.stockBatches.length, 1);
      expect(res.product.stockBatches.first.remainingQuantity, 8.0);
      expect(res.product.stockBatches.first.costPrice, 100.0);

      // Invariant: stock == sum(batches)
      final sumBatches = res.product.stockBatches.fold<double>(0.0, (s, b) => s + b.remainingQuantity);
      expect(sumBatches, res.product.stock);
    });

    test('consume beyond stock drains all batches and costs excess at fallback', () {
      final res = InventoryLedger.consume(baseProduct, 20.0, allowNegative: true);

      // 5*90 + 10*100 = 1450 from batches.
      // 5 units excess @ fallback 100 = 500. Total COGS = 1950.
      expect(res.cogs, 1950.0);
      expect(res.product.stock, -5.0);

      // Reference batch with 0 remaining is kept for price reference
      expect(res.product.stockBatches.length, 1);
      expect(res.product.stockBatches.first.remainingQuantity, 0.0);
      expect(res.product.stockBatches.first.costPrice, 100.0);
    });

    test('restock adds to newest batch and maintains invariant', () {
      final res = InventoryLedger.restock(baseProduct, 5.0);

      expect(res.product.stock, 20.0);
      final sorted = List<PurchaseBatch>.from(res.product.stockBatches)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      expect(sorted.first.remainingQuantity, 15.0); // was 10, added 5

      final sumBatches = res.product.stockBatches.fold<double>(0.0, (s, b) => s + b.remainingQuantity);
      expect(sumBatches, res.product.stock);
    });

    test('reconcile reprices all batches and adjusts quantity', () {
      final reconciled = InventoryLedger.reconcile(baseProduct, newStock: 25.0, repriceTo: 105.0);

      expect(reconciled.stock, 25.0);
      expect(reconciled.costPrice, 105.0);
      for (final b in reconciled.stockBatches) {
        expect(b.costPrice, 105.0);
      }
      final sumBatches = reconciled.stockBatches.fold<double>(0.0, (s, b) => s + b.remainingQuantity);
      expect(sumBatches, 25.0);
    });

    test('sanitizeBatchUnitCost heals carton cost stored as piece cost', () {
      final productWithCarton = Product(
        id: 'p2',
        name: 'Juice',
        barcode: '2222',
        price: 150.0,
        costPrice: 100.0,
        units: const [
          ProductUnit(name: 'حبة', tier: UnitTier.small, multiplier: 1.0, price: 150.0, cost: 100.0),
          ProductUnit(name: 'كرتونة', tier: UnitTier.large, multiplier: 24.0, price: 3200.0, cost: 2400.0),
        ],
      );

      // 2400 is carton cost. Divided by 24 = 100.
      final healed = InventoryLedger.sanitizeBatchUnitCost(productWithCarton, 2400.0);
      expect(healed, 100.0);
    });
  });
}
