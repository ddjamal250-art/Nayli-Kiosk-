import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update esolvedUnits block
old_block = '''    List<ProductUnit> resolvedUnits = [];
    if (_isExistingInShop && existingProduct != null && existingProduct.units.isNotEmpty) {
      final Map<UnitTier, ({double price, double cost})> newPrices = {};
      if (_unitMode == ArrivageUnitMode.cartons) {
        final cPrice = double.tryParse(_cartonsPriceController.text.trim()) ?? 0.0;
        final cCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
        newPrices[UnitTier.large] = (price: cPrice, cost: cCost);
        newPrices[UnitTier.small] = (price: effectivePrice, cost: effectiveCost);
      } else {
        newPrices[UnitTier.small] = (price: effectivePrice, cost: effectiveCost);
      }
      resolvedUnits = _mergeUnitsWithNewPrices(existingProduct.units, newPrices);
    } else {
      if (_unitMode == ArrivageUnitMode.cartons) {
        final perCarton = int.tryParse(_qtyController.text.trim()) ?? 1;
        final cPrice = double.tryParse(_cartonsPriceController.text.trim()) ?? 0.0;
        final cCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
        resolvedUnits = [
          ProductUnit(tier: UnitTier.large, name: '??????', multiplier: perCarton.toDouble(), price: cPrice, cost: cCost),
          ProductUnit(tier: UnitTier.small, name: '???', multiplier: 1.0, price: effectivePrice, cost: effectiveCost),
        ];
      } else if (_unitMode == ArrivageUnitMode.vracSacs) {'''

new_block = '''    List<ProductUnit> resolvedUnits = [];
    if (_isExistingInShop && existingProduct != null && existingProduct.units.isNotEmpty) {
      final Map<UnitTier, ({double price, double cost})> newPrices = {};
      if (_unitMode == ArrivageUnitMode.cartons) {
        final cPrice = double.tryParse(_cartonsPriceController.text.trim()) ?? 0.0;
        final cCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
        newPrices[UnitTier.large] = (price: cPrice, cost: cCost);
        
        if (_hasMiddleTier) {
          final pPrice = double.tryParse(_packPriceController.text.trim()) ?? 0.0;
          final pCost = double.tryParse(_packCostController.text.trim()) ?? 0.0;
          newPrices[UnitTier.medium] = (price: pPrice, cost: pCost);
        }
        newPrices[UnitTier.small] = (price: effectivePrice, cost: effectiveCost);
      } else {
        newPrices[UnitTier.small] = (price: effectivePrice, cost: effectiveCost);
      }
      resolvedUnits = _mergeUnitsWithNewPrices(existingProduct.units, newPrices);
    } else {
      if (_unitMode == ArrivageUnitMode.cartons) {
        final cPrice = double.tryParse(_cartonsPriceController.text.trim()) ?? 0.0;
        final cCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
        if (_hasMiddleTier) {
          final packs = int.tryParse(_packsPerCartonController.text.trim()) ?? 1;
          final unitsPerPack = int.tryParse(_unitsPerPackController.text.trim()) ?? 1;
          final pPrice = double.tryParse(_packPriceController.text.trim()) ?? 0.0;
          final pCost = double.tryParse(_packCostController.text.trim()) ?? 0.0;
          resolvedUnits = [
            ProductUnit(tier: UnitTier.large, name: '??????', multiplier: (packs * unitsPerPack).toDouble(), price: cPrice, cost: cCost),
            ProductUnit(tier: UnitTier.medium, name: '????', multiplier: unitsPerPack.toDouble(), price: pPrice, cost: pCost),
            ProductUnit(tier: UnitTier.small, name: '???', multiplier: 1.0, price: effectivePrice, cost: effectiveCost),
          ];
        } else {
          final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 1;
          resolvedUnits = [
            ProductUnit(tier: UnitTier.large, name: '??????', multiplier: perCarton.toDouble(), price: cPrice, cost: cCost),
            ProductUnit(tier: UnitTier.small, name: '???', multiplier: 1.0, price: effectivePrice, cost: effectiveCost),
          ];
        }
      } else if (_unitMode == ArrivageUnitMode.vracSacs) {'''

content = content.replace(old_block, new_block)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Phase 2 applied')
