import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''      if (existing != null) {
        _isExistingInShop = true;
        _existingProductId = existing.id;
        _activeBarcode = existing.barcode;
        _priceController.text = existing.price.toStringAsFixed(2);
        _currentStock = existing.stock;
        _itemImageUrl = existing.imageUrl;
        _selectedCategory = existing.category.isNotEmpty ? existing.category : '???';
        _isCategoryUserSelected = true;
      } else {'''

new_target = '''      if (existing != null) {
        _isExistingInShop = true;
        _existingProductId = existing.id;
        _activeBarcode = existing.barcode;
        _priceController.text = existing.price.toStringAsFixed(2);
        _currentStock = existing.stock;
        _itemImageUrl = existing.imageUrl;
        _selectedCategory = existing.category.isNotEmpty ? existing.category : '???';
        _isCategoryUserSelected = true;
        
        if (existing.isWeighted || existing.name.contains('??') || existing.name.contains('?????') || existing.name.contains('????') || existing.name.contains('???') || existing.name.contains('????')) {
          _unitMode = ArrivageUnitMode.vracSacs;
        } else {
          final largeUnit = existing.units.where((u) => u.tier == UnitTier.large).firstOrNull;
          if (largeUnit != null) {
            _unitMode = ArrivageUnitMode.cartons;
            _cartonsPriceController.text = largeUnit.price.toStringAsFixed(2);
            _cartonCostController.text = largeUnit.cost.toStringAsFixed(2);
            
            final mediumUnit = existing.units.where((u) => u.tier == UnitTier.medium).firstOrNull;
            if (mediumUnit != null) {
              _hasMiddleTier = true;
              _packPriceController.text = mediumUnit.price.toStringAsFixed(2);
              _packCostController.text = mediumUnit.cost.toStringAsFixed(2);
              _packsPerCartonController.text = (largeUnit.multiplier / mediumUnit.multiplier).toInt().toString();
              _unitsPerPackController.text = mediumUnit.multiplier.toInt().toString();
            } else {
              _hasMiddleTier = false;
              _unitsPerCartonController.text = largeUnit.multiplier.toInt().toString();
            }
          }
        }
      } else {'''

content = content.replace(target, new_target)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Sprint 4 OCR unit detect applied')
