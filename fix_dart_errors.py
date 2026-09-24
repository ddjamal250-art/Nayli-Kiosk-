import os
import re

# 1. Fix hive_database.dart
hive_path = r'd:\repos\Nayli Market -custom-\lib\core\data\hive_database.dart'
with open(hive_path, 'rb') as f:
    hive_bytes = f.read()

# Try to remove null bytes and fix the utf-16 string
hive_text = hive_bytes.decode('utf-8', errors='ignore')
hive_text = hive_text.replace('i\x00m\x00p\x00o\x00r\x00t\x00 \x00\'\x00.\x00.\x00/\x00.\x00.\x00/\x00f\x00e\x00a\x00t\x00u\x00r\x00e\x00s\x00/\x00p\x00r\x00o\x00d\x00u\x00c\x00t\x00/\x00d\x00a\x00t\x00a\x00/\x00m\x00o\x00d\x00e\x00l\x00s\x00/\x00p\x00r\x00o\x00d\x00u\x00c\x00t\x00_\x00u\x00n\x00i\x00t\x00_\x00m\x00o\x00d\x00e\x00l\x00.\x00d\x00a\x00t\x00a\x00\'\x00;\x00', '')
hive_text = hive_text.replace('\x00', '') # Remove all null bytes just in case
# Actually the better way is to regex out anything after the last `}`
last_brace = hive_text.rfind('}')
if last_brace != -1:
    hive_text = hive_text[:last_brace+1] + '\n'

with open(hive_path, 'w', encoding='utf-8') as f:
    f.write(hive_text)

# 2. Fix kiosk_tobacco_modal.dart
tobacco_path = r'd:\repos\Nayli Market -custom-\lib\features\billing\presentation\widgets\kiosk_tobacco_modal.dart'
with open(tobacco_path, 'r', encoding='utf-8') as f:
    tobacco_text = f.read()

tobacco_text = tobacco_text.replace('customPrice: _isWholesale ? _));', 'customPrice: _isWholesale ? p.wholesalePackPrice : null));')
with open(tobacco_path, 'w', encoding='utf-8') as f:
    f.write(tobacco_text)

# 3. Fix master_catalog_seed.dart
seed_path = r'd:\repos\Nayli Market -custom-\lib\core\data\master_catalog_seed.dart'
with open(seed_path, 'r', encoding='utf-8') as f:
    seed_text = f.read()

# master_catalog_seed.dart:1120:3: Expected to find ')'
# Let's see if there is an easy fix, or if I should just find the exact issue.
