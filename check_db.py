import sqlite3
import json
conn = sqlite3.connect(r'C:\Users\Admin\Desktop\Nayli Big Catalog\products.db')
c = conn.cursor()
c.execute("SELECT name FROM sqlite_master WHERE type='table';")
print('Tables:', c.fetchall())

try:
    c.execute("SELECT COUNT(*) FROM products WHERE barcode != ''")
    print('Products with barcodes in DB:', c.fetchone()[0])
except Exception as e:
    print(e)
    
# Let's also check json
with open(r'C:\Users\Admin\Desktop\Nayli Big Catalog\products.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
    if isinstance(data, list):
        bc = [item for item in data if item.get('barcode')]
        print('Products with barcodes in JSON:', len(bc))
