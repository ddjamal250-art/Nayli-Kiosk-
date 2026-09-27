import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add variables for Middle Tier and Quick Pin
target_vars = '''  final TextEditingController _cartonsPriceController = TextEditingController();'''
new_vars = target_vars + '''
  
  // --- Sprint 2 Variables ---
  bool _hasMiddleTier = false;
  final TextEditingController _packsPerCartonController = TextEditingController(text: '4');
  final TextEditingController _unitsPerPackController = TextEditingController(text: '6');
  final TextEditingController _packCostController = TextEditingController();
  final TextEditingController _packPriceController = TextEditingController();
  bool _pinToQuickItems = false;
'''

content = content.replace(target_vars, new_vars)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Variables added.')
