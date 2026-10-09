import re

with open('lib/features/billing/presentation/pages/desktop_pos_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Add import if missing
if "import '../../../../core/utils/category_taxonomy.dart';" not in c:
    c = c.replace("import '../../../../core/utils/app_constants.dart';", "import '../../../../core/utils/app_constants.dart';\nimport '../../../../core/utils/category_taxonomy.dart';")

# Replace _categoriesDef with dynamic _categoryTabs
old_def = r'  static const List<Map<String, String>> _categoriesDef = \[.*?\];'
c = re.sub(old_def, '  List<String> _categoryTabs = [];', c, flags=re.DOTALL)

# Insert initialization into initState
if 'void initState() {' in c:
    c = c.replace('void initState() {', 'void initState() {\n    _categoryTabs = [\'الكل\'] + CategoryTaxonomy.getVisibleHomeScreenCategories();')
else:
    print("Could not find initState in desktop_pos_page.dart")

# Replace loops over _categoriesDef
# itemCount: _categoriesDef.length
c = c.replace('_categoriesDef.length', '_categoryTabs.length')

# final catDef = _categoriesDef[index];
# final isSelected = _selectedCategoryIndex == index;
# final icon = catDef['icon']!;
# final title = catDef['ar']!; # or context.tr(catDef['tr']!)

c = re.sub(r'final catDef = _categoriesDef\[index\];.*?final title = [^\n]*;', '''final catName = _categoryTabs[index];
                          final isSelected = _selectedCategoryIndex == index;
                          final domain = CategoryTaxonomy.resolveDomain(catName);
                          final icon = index == 0 ? '🛒' : domain.icon;
                          final title = catName;''', c, flags=re.DOTALL)

# Also need to fix _productMatchesTab
# bool _productMatchesTab(Product p, int tabIdx) { ... }
# Let's replace the whole method body.
old_match = r'  bool _productMatchesTab\(Product p, int tabIdx\) \{.*?    return false;\n  \}'
new_match = '''  bool _productMatchesTab(Product p, int tabIdx) {
    if (tabIdx == 0) return true;
    if (tabIdx >= _categoryTabs.length) return false;
    return p.category.trim() == _categoryTabs[tabIdx].trim();
  }'''
c = re.sub(old_match, new_match, c, flags=re.DOTALL)

with open('lib/features/billing/presentation/pages/desktop_pos_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('desktop_pos_page.dart updated successfully')
