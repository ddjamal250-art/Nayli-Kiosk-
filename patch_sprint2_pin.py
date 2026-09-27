import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target_ui = '''                  // Submit Button
                  ElevatedButton.icon('''

new_ui = '''                  if (_unitMode != ArrivageUnitMode.coffeeMachine)
                    SwitchListTile(
                      title: const Text('????? ?????? ?? ???? ????? ???????', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('???? ??? ?????? ????? ?? ????? ?? ??????'),
                      value: _pinToQuickItems,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setState(() {
                          _pinToQuickItems = val;
                        });
                      },
                    ),
                  const SizedBox(height: 18),

                  // Submit Button
                  ElevatedButton.icon('''

content = content.replace(target_ui, new_ui)

target_save = '''    if ((isCoffee && _coffeeData.pinToQuickSale) && savedProductId.isNotEmpty) {
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
    }'''

new_save = '''    final shouldPin = (isCoffee && _coffeeData.pinToQuickSale) || (!isCoffee && _pinToQuickItems);
    if (shouldPin && savedProductId.isNotEmpty) {
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
        debugPrint('Error pinning quick item: ');
      }
    }'''

content = content.replace(target_save, new_save)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Pin toggle applied')
