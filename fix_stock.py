import re
with open('lib/features/product/presentation/pages/stock_in_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

n = '''              itemBuilder: (BuildContext context) {
                final List<PopupMenuEntry<String>> items = [];
                for (final cat in CategoryTaxonomy.getDropdownCategories()) {
                  final domain = CategoryTaxonomy.resolveDomain(cat);
                  items.add(
                    PopupMenuItem<String>(
                      value: cat,
                      child: Row(
                        children: [
                          Text(domain.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }
                return items;
              },'''
c = re.sub(r'              itemBuilder: \(BuildContext context\) \{.*?return items;\n              \},', n, c, flags=re.DOTALL)
with open('lib/features/product/presentation/pages/stock_in_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('stock_in_page.dart updated successfully')
