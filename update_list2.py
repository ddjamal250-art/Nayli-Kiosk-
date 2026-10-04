import re

file_path = 'lib/features/product/presentation/pages/product_list_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'bulk_price_update_page.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'bulk_price_update_page.dart';")

# Add the icon button next to export
icon_btn = '''
                  IconButton(
                    icon: Icon(Icons.price_change_outlined, color: AppTheme.primaryColor),
                    tooltip: '????? ????? ?????',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkPriceUpdatePage()));
                    },
                  ),'''

if 'price_change_outlined' not in content:
    content = content.replace("icon: Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),", icon_btn.strip() + "\n                  IconButton(\n                    icon: Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated product_list_page.dart')
