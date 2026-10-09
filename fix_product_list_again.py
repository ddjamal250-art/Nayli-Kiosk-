import re

with open('lib/features/product/presentation/pages/product_list_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

c = re.sub(r'final catDef = _categoryTabsDef\[idx\];\s*final isSelected = _selectedCategoryIndex == idx;\s*final langCode = Localizations\.localeOf\(context\)\.languageCode;\s*final label = catDef\[langCode\] \?\? catDef\[\'ar\'\] \?\? \'\';', 'final label = _categoryTabs[idx];\n                      final isSelected = _selectedCategoryIndex == idx;', c, flags=re.DOTALL)

with open('lib/features/product/presentation/pages/product_list_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('product_list_page.dart updated successfully')
