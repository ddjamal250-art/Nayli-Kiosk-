import re

file_path = 'lib/features/product/presentation/pages/edit_product_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add a helper function at the top level of the state class if not exists
helper_func = '''
  String _formatDouble(double val) {
    if (val == val.toInt()) return val.toInt().toString();
    return val.toString();
  }
'''

if '_formatDouble' not in content:
    content = content.replace('class _EditProductPageState extends State<EditProductPage> {', 'class _EditProductPageState extends State<EditProductPage> {\n' + helper_func)

# Replace toStringAsFixed(0) with the helper
content = re.sub(r'([a-zA-Z0-9_\.]+)\.toStringAsFixed\(0\)', r'_formatDouble(\1)', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated edit_product_page.dart')
