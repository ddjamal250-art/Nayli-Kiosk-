import os
import csv
import glob

base_dir = r'C:\Users\Admin\Desktop\Nayli Big Catalog'
csv_path = os.path.join(base_dir, 'products.csv')
img_dir = os.path.join(base_dir, 'images')

id_to_barcode = {}
with open(csv_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
    reader = csv.DictReader(f)
    for row in reader:
        pid = row.get('id', '').strip()
        barcode = row.get('barcode', '').strip()
        if pid and barcode:
            id_to_barcode[pid] = barcode

renamed_count = 0

for img_path in glob.glob(os.path.join(img_dir, '*.*')):
    filename = os.path.basename(img_path)
    name, ext = os.path.splitext(filename)
    
    if name in id_to_barcode:
        barcode = id_to_barcode[name]
        new_filename = f"{barcode}{ext}"
        new_path = os.path.join(img_dir, new_filename)
        
        if img_path != new_path:
            if not os.path.exists(new_path):
                os.rename(img_path, new_path)
                renamed_count += 1
            else:
                try:
                    os.remove(img_path)
                except:
                    pass

print(f'Renamed {renamed_count} images successfully!')
