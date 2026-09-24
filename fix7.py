import re

BASE = r'd:\repos\Nayli Market -custom-'

def fix(path, old, new):
    full = BASE + '\\' + path
    with open(full, 'r', encoding='utf-8') as f:
        text = f.read()
    if old in text:
        text = text.replace(old, new)
        with open(full, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f'Fixed: {path.split(chr(92))[-1]} | {old[:60]}')
    else:
        print(f'NOT FOUND: {path.split(chr(92))[-1]} | {old[:60]}')

# 1. universal_unit_selector_dialog.dart - missing ProductUnit import
fix(
    r'lib\features\billing\presentation\widgets\universal_unit_selector_dialog.dart',
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\nimport '../../../../features/product/domain/entities/product_unit.dart';"
)

# 2. edit_product_page.dart - onSelected -> onPressed
fix(
    r'lib\features\product\presentation\pages\edit_product_page.dart',
    'TextButton(onSelected: () => Navigator.pop(ctx)',
    'TextButton(onPressed: () => Navigator.pop(ctx)'
)

# 3. stock_in_page.dart - cartonCostPrice not in Product constructor
fix(
    r'lib\features\product\presentation\pages\stock_in_page.dart',
    '        cartonCostPrice: cartonCostPrice,\n',
    ''
)

# 4. kiosk_price_checker_page.dart - packPrice/packMultiplier -> singlePrice/unitMultiplier
fix(
    r'lib\features\billing\presentation\pages\kiosk_price_checker_page.dart',
    'if (p.packPrice > 0 && p.packMultiplier > 1)',
    'if (p.singlePrice > 0 && p.unitMultiplier > 1)'
)

# 5. Fix validator type errors in add_product_page.dart and edit_product_page.dart
for path in [
    r'lib\features\product\presentation\pages\add_product_page.dart',
    r'lib\features\product\presentation\pages\edit_product_page.dart',
]:
    full = BASE + '\\' + path
    with open(full, 'r', encoding='utf-8') as f:
        text = f.read()
    # AppValidators.required when used without () returns a curried function - replace with inline
    new_text = re.sub(
        r'validator: AppValidators\.required(?!\()',
        "validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null",
        text
    )
    if new_text != text:
        with open(full, 'w', encoding='utf-8') as f:
            f.write(new_text)
        print(f'Fixed validator in {path}')
    else:
        print(f'No validator change in {path}')

print('Done!')
