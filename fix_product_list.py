import re

with open('lib/features/product/presentation/pages/product_list_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Add import if missing
if "import '../../../../core/utils/category_taxonomy.dart';" not in c:
    c = c.replace("import '../../domain/entities/product.dart';", "import '../../domain/entities/product.dart';\nimport '../../../../core/utils/category_taxonomy.dart';")

# We want to replace the hardcoded _categoryTabsDef and related functions
# Instead of a static list, we will initialize a dynamic list of strings.
# But wait! _productMatchesTab is huge.
# We will just rewrite the class properties down to _productMatchesAnyKnownCategory.

old_block_pattern = r'  static const List<Map<String, String>> _categoryTabsDef = \[.*?bool _productMatchesAnyKnownCategory\(Product p\) \{\n    for \(int i = 1; i < _categoryTabsDef.length - 1; i\+\+\) \{\n      if \(_productMatchesTab\(p, i\)\) return true;\n    \}\n    return false;\n  \}'

new_block = '''  List<String> _categoryTabs = [];
  
  @override
  void initState() {
    super.initState();
    _categoryTabs = ['الكل'] + CategoryTaxonomy.getVisibleHomeScreenCategories();
  }

  String get _selectedCategoryFilter =>
      _selectedCategoryIndex < _categoryTabs.length ? _categoryTabs[_selectedCategoryIndex] : 'الكل';

  bool _productMatchesTab(Product p, int tabIdx) {
    if (tabIdx == 0) return true;
    if (tabIdx >= _categoryTabs.length) return false;
    final catName = _categoryTabs[tabIdx];
    return p.category.trim() == catName.trim();
  }'''

c = re.sub(old_block_pattern, new_block, c, flags=re.DOTALL)

# We also need to fix where _categoryTabsDef is used.
# Let's replace _categoryTabsDef.length with _categoryTabs.length
c = c.replace('_categoryTabsDef.length', '_categoryTabs.length')

# And in the FilterChip loop:
# final catDef = _categoryTabsDef[idx];
# final langCode = Localizations.localeOf(context).languageCode;
# final label = catDef[langCode] ?? catDef['ar'] ?? '';
# change to just: final label = _categoryTabs[idx];

c = re.sub(r'final catDef = _categoryTabsDef\[idx\];\s*final langCode = Localizations\.localeOf\(context\)\.languageCode;\s*final label = catDef\[langCode\] \?\? catDef\[\'ar\'\] \?\? \'\';', 'final label = _categoryTabs[idx];', c, flags=re.DOTALL)

with open('lib/features/product/presentation/pages/product_list_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('product_list_page.dart updated successfully')
