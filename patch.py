import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

start_idx = content.find('  void _saveStockIn() {')
end_idx = content.find('  Future<void> _pickReceiptDate()', start_idx)

new_func = '''  List<ProductUnit> _mergeUnitsWithNewPrices(List<ProductUnit> existingUnits, Map<UnitTier, ({double price, double cost})> newPrices) {
    return existingUnits.map((unit) {
      final update = newPrices[unit.tier];
      if (update == null) return unit;
      return unit.copyWith(price: update.price, cost: update.cost);
    }).toList();
  }

  void _saveStockIn() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? 0.0;
    
    final productBloc = context.read<ProductBloc>();
    final products = productBloc.state.products;
    final existingProduct = _existingProductId != null
        ? products.where((p) => p.id == _existingProductId).firstOrNull
        : null;

    final isScaleProduct = existingProduct?.units.any((u) => u.isWeighable) ?? false;
    final rawQtyDouble = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final double qty = isScaleProduct ? (rawQtyDouble * 1000) : rawQtyDouble;

    if (name.isEmpty) {
      SnackbarHelper.showWarning(context, '???? ????? ??? ??????');
      return;
    }
    if (_activeBarcode.isEmpty) {
      _generateGreyProductBarcode();
    }
    if (qty <= 0) {
      SnackbarHelper.showWarning(context, '???? ????? ???? ?????? ?????');
      return;
    }

    final isWeighted = _unitMode == ArrivageUnitMode.vracSacs;
    double effectiveQty = qty;
    double effectiveCost = costPrice;
    final isCoffee = _unitMode == ArrivageUnitMode.coffeeMachine;

    if (isCoffee) {
      final bags = int.tryParse(_sacCountController.text.trim()) ?? 1;
      effectiveQty = ((bags > 0 ? bags : 1) * _coffeeData.baseYieldCount).toDouble();
      effectiveCost = _coffeeData.totalCupCost;
      _selectedCategory = '?????? ???????';
    }

    if (_isExistingInShop && _currentStock > 0 && costPrice > 0 && !isCoffee) {
      final oldCost = (existingProduct != null && existingProduct.costPrice > 0)
          ? existingProduct.costPrice
          : costPrice;
      final totalValue = (_currentStock * oldCost) + (qty * costPrice);
      final totalStock = _currentStock + qty;
      effectiveCost = totalStock > 0 ? (totalValue / totalStock) : costPrice;
    }

    final effectivePrice = isCoffee ? _coffeeData.salePrice : price;
    final effectiveCategory = isCoffee
        ? '?????? ???????'
        : (_selectedCategory.trim().isNotEmpty
            ? _selectedCategory.trim()
            : (existingProduct?.category ?? '???'));

    List<ProductUnit> resolvedUnits = [];
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
                ProductUnit(
                    tier: UnitTier.large,
                    name: '??????',
                    multiplier: perCarton.toDouble(),
                    price: cPrice,
                    cost: cCost,
                ),
                ProductUnit(
                    tier: UnitTier.small,
                    name: '???',
                    multiplier: 1.0,
                    price: effectivePrice,
                    cost: effectiveCost,
                )
            ];
        } else if (_unitMode == ArrivageUnitMode.vracSacs) {
            resolvedUnits = [
                ProductUnit(
                    tier: UnitTier.small,
                    name: '??',
                    multiplier: 1.0,
                    price: effectivePrice,
                    cost: effectiveCost,
                    isWeighable: true,
                )
            ];
        } else if (_unitMode == ArrivageUnitMode.coffeeMachine) {
            resolvedUnits = [
                ProductUnit(
                    tier: UnitTier.small,
                    name: '???',
                    multiplier: 1.0,
                    price: effectivePrice,
                    cost: effectiveCost,
                )
            ];
        } else {
            resolvedUnits = [
                ProductUnit(
                    tier: UnitTier.small,
                    name: '???',
                    multiplier: 1.0,
                    price: effectivePrice,
                    cost: effectiveCost,
                )
            ];
        }
    }

    final supplierName = _supplierNameController.text.trim();
    final supplierPhone = _supplierPhoneController.text.trim();
    final newBatch = PurchaseBatch(
      costPrice: effectiveCost,
      remainingQuantity: effectiveQty,
      dateAdded: _receiptDate,
      supplierName: supplierName.isEmpty ? null : supplierName,
      supplierPhone: supplierPhone.isEmpty ? null : supplierPhone,
    );
    
    final existingBatches = existingProduct?.stockBatches ?? [];
    final updatedBatches = [...existingBatches, newBatch];
    final cappedBatches = updatedBatches.length > 50 
        ? updatedBatches.sublist(updatedBatches.length - 50) 
        : updatedBatches;

    String savedProductId = '';

    if (_isExistingInShop && _existingProductId != null) {
      savedProductId = _existingProductId!;
      final updatedProduct = (existingProduct ?? Product(
        id: _existingProductId!,
        name: name,
        barcode: _activeBarcode,
        price: effectivePrice,
      )).copyWith(
        name: name,
        barcode: _activeBarcode,
        category: effectiveCategory,
        price: effectivePrice,
        costPrice: effectiveCost,
        stock: _currentStock + effectiveQty,
        units: resolvedUnits,
        stockBatches: cappedBatches,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );
      productBloc.add(UpdateProduct(updatedProduct));
    } else {
      final newId = const Uuid().v4();
      savedProductId = newId;
      final newProduct = Product(
        id: newId,
        name: name,
        barcode: _activeBarcode,
        category: effectiveCategory,
        price: effectivePrice,
        costPrice: effectiveCost,
        stock: effectiveQty,
        units: resolvedUnits,
        stockBatches: cappedBatches,
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );
      productBloc.add(AddProduct(newProduct));
    }

    if ((isCoffee && _coffeeData.pinToQuickSale) && savedProductId.isNotEmpty) {
      try {
        final qBox = HiveDatabase.quickItemsBox;
        final qItem = QuickItemData(
          id: 'quick_' + savedProductId,
          name: name,
          price: effectivePrice,
          costPrice: effectiveCost,
          icon: isCoffee ? _coffeeData.quickIcon : '???',
          barcode: _activeBarcode,
          shortCode: isCoffee ? _coffeeData.quickShortCode : (name.length >= 2 ? name.substring(0, 2) : name),
          stock: effectiveQty,
          linkedProductId: savedProductId,
          orderIndex: qBox.length,
        );
        qBox.put(qItem.id, qItem.toMap());
      } catch (e) {
        debugPrint('Error pinning quick item: ' + str(e));
      }
    }

    setState(() {
      _sessionStockIns.insert(0, {
        'name': name,
        'barcode': _activeBarcode,
        'qty': effectiveQty,
        'unitMode': _unitMode.name,
        'price': effectivePrice,
        'costPrice': effectiveCost,
        'supplier': supplierName,
        'supplierPhone': supplierPhone,
        'receiptDate': _receiptDate,
        'expiryDate': _expiryDate,
        'condition': _itemCondition,
      });

      _coffeeData = ReadyCoffeeData();
      _sacCountController.text = '1';
      _activeBarcode = '';
      _lastScannedBarcode = null;
      _nameController.clear();
      _priceController.clear();
      _costPriceController.clear();
      _cartonCostController.clear();
      _sacCostController.clear();
      _pricePerKgController.clear();
      _costPerKgController.clear();
      _qtyController.text = '24';
      _isExistingInShop = false;
      _existingProductId = null;
      _expiryDate = null;
      _itemImageUrl = null;
    });

    SoundService.playSaveSuccess();

    if (_activeOcrIndex >= 0 && _activeOcrIndex < _pendingOcrItems.length) {
      _pendingOcrItems.removeAt(_activeOcrIndex);
      if (_pendingOcrItems.isNotEmpty) {
        final nextIdx = _activeOcrIndex < _pendingOcrItems.length ? _activeOcrIndex : 0;
        _selectPendingOcrItem(nextIdx);
        SnackbarHelper.showSuccess(context, '? ?? ??? ??????? ?????? ?????!');
        return;
      } else {
        _activeOcrIndex = -1;
        SnackbarHelper.showSuccess(context, '?? ?? ?????? ???? ??? ???????? ?????!');
        return;
      }
    }

    SnackbarHelper.showSuccess(context, '? ?? ????? ???????? ?????!');
  }

'''

content = content[:start_idx] + new_func + content[end_idx:]

ctrl_idx = content.find('  final TextEditingController _costPriceController = TextEditingController();')
if ctrl_idx != -1:
    insert_str = '  final TextEditingController _cartonsPriceController = TextEditingController();\n'
    content = content[:ctrl_idx] + insert_str + content[ctrl_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
