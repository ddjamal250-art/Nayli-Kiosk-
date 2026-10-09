import re

with open('lib/features/product/presentation/pages/product_list_page.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Remove the one we just added:
c = c.replace('''  @override
  void initState() {
    super.initState();
    _categoryTabs = ['الكل'] + CategoryTaxonomy.getVisibleHomeScreenCategories();
  }''', '')

# Insert the initialization into the existing initState:
c = c.replace('''  @override
  void initState() {
    super.initState();''', '''  @override
  void initState() {
    super.initState();
    _categoryTabs = ['الكل'] + CategoryTaxonomy.getVisibleHomeScreenCategories();''')

with open('lib/features/product/presentation/pages/product_list_page.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed duplicate initState')
