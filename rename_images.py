import os
import csv
import glob

base_dir = r'C:\Users\Admin\Desktop\Nayli Big Catalog'
csv_path = os.path.join(base_dir, 'products.csv')
img_dir = os.path.join(base_dir, 'images')

# Read CSV and map ID to Barcode
id_to_barcode = {}
with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
    reader = csv.DictReader(f)
    for row in reader:
        pid = row.get('id', '').strip()
        barcode = row.get('barcode', '').strip()
        if pid and barcode:
            id_to_barcode[pid] = barcode

renamed_count = 0
not_found_count = 0

# Get all images
for img_path in glob.glob(os.path.join(img_dir, '*.*')):
    filename = os.path.basename(img_path)
    name, ext = os.path.splitext(filename)
    
    # If the image is named as an ID
    if name in id_to_barcode:
        barcode = id_to_barcode[name]
        new_filename = f"{barcode}{ext}"
        new_path = os.path.join(img_dir, new_filename)
        
        if not os.path.exists(new_path):
            os.rename(img_path, new_path)
            renamed_count += 1
        else:
            # If the barcode image already exists, just remove the old id image to clean up, or ignore.
            pass

print(f'Renamed {renamed_count} images successfully!')
