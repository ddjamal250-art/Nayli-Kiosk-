import re

with open('lib/features/product/presentation/pages/shelf_labels_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Add import if missing
if "import '../../../../core/utils/category_taxonomy.dart';" not in c:
    c = c.replace("import '../../../../core/utils/app_constants.dart';", "import '../../../../core/utils/app_constants.dart';\nimport '../../../../core/utils/category_taxonomy.dart';")

# replace static const List<String> _categoryTabs with instance variable
old_tabs = r'  static const List<String> _categoryTabs = \[(.*?)\];'
c = re.sub(old_tabs, '  List<String> _categoryTabs = [];', c, flags=re.DOTALL)

# Insert initialization into initState
if 'void initState() {' in c:
    c = c.replace('void initState() {', 'void initState() {\n    _categoryTabs = [\'الكل\'] + CategoryTaxonomy.getVisibleHomeScreenCategories();')
else:
    print("Could not find initState in shelf_labels_page.dart")

with open('lib/features/product/presentation/pages/shelf_labels_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('shelf_labels_page.dart updated successfully')
