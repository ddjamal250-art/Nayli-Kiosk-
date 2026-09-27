import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = '''      _isExistingInShop = false;
      _existingProductId = null;
      _expiryDate = null;
      _itemImageUrl = null;
    });'''

new_target = '''      _isExistingInShop = false;
      _existingProductId = null;
      _expiryDate = null;
      _itemImageUrl = null;
      _pinToQuickItems = false;
      _hasMiddleTier = false;
    });'''

content = content.replace(target, new_target)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Reset vars added')
