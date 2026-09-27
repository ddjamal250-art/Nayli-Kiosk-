import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                  TextField(
                    controller: _supplierNameController,
                    decoration: const InputDecoration(
                      labelText: '??? ?????? (???????)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),'''

new_target = '''                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final productBloc = context.read<ProductBloc>();
                      final products = productBloc.state.products;
                      final Set<String> suppliers = {};
                      for (var p in products) {
                        for (var b in p.stockBatches) {
                          if (b.supplierName != null && b.supplierName!.isNotEmpty) {
                            suppliers.add(b.supplierName!);
                          }
                        }
                      }
                      return suppliers.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      _supplierNameController.text = selection;
                      // Auto-fill phone if possible
                      final productBloc = context.read<ProductBloc>();
                      for (var p in productBloc.state.products) {
                        for (var b in p.stockBatches) {
                          if (b.supplierName == selection && b.supplierPhone != null && b.supplierPhone!.isNotEmpty) {
                            _supplierPhoneController.text = b.supplierPhone!;
                            return;
                          }
                        }
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      // Sync controller
                      controller.addListener(() {
                        if (_supplierNameController.text != controller.text) {
                          _supplierNameController.text = controller.text;
                        }
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '??? ?????? (???????)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),'''

if target in content:
    content = content.replace(target, new_target)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Autocomplete applied')
else:
    print('Target not found')
