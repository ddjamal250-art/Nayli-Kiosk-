import os
import shutil
from PIL import Image, ImageDraw, ImageFont

def ensure_dirs():
    os.makedirs('windows/installer', exist_ok=True)
    os.makedirs('assets/images', exist_ok=True)
    os.makedirs('Nayli Market Desktop/windows/installer', exist_ok=True)
    os.makedirs('Nayli Market Desktop/assets/images', exist_ok=True)

def generate_wizard_small():
    """
    Generates wizard_small.bmp (110x110 px) for the upper right corner of Inno Setup pages.
    Background is white (#FFFFFF) to blend seamlessly with Inno Setup modern wizard header.
    """
    size = (110, 110)
    bg = Image.new('RGB', size, (255, 255, 255))
    
    logo = Image.open('assets/images/app_logo.png').convert('RGBA')
    # Fit logo within 90x90 with padding
    logo.thumbnail((92, 92), Image.Resampling.LANCZOS)
    
    pos_x = (size[0] - logo.width) // 2
    pos_y = (size[1] - logo.height) // 2
    
    bg.paste(logo, (pos_x, pos_y), logo)
    
    out_path = 'windows/installer/wizard_small.bmp'
    bg.save(out_path, format='BMP')
    print(f"Generated {out_path} ({size[0]}x{size[1]})")
    return out_path

def generate_wizard_large():
    """
    Generates wizard_large.bmp (328x628 px) for the left banner of Welcome and Finish pages.
    Background is a rich Navy Blue gradient (#06325C -> #021B33) with the official logo
    and refined brand text.
    """
    width, height = 328, 628
    img = Image.new('RGB', (width, height), (6, 50, 92))
    draw = ImageDraw.Draw(img)
    
    # Subtle vertical gradient from #06325C (top) to #021B33 (bottom)
    top_color = (6, 50, 92)
    bottom_color = (2, 27, 51)
    for y in range(height):
        ratio = y / float(height)
        r = int(top_color[0] * (1 - ratio) + bottom_color[0] * ratio)
        g = int(top_color[1] * (1 - ratio) + bottom_color[1] * ratio)
        b = int(top_color[2] * (1 - ratio) + bottom_color[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # Top and bottom decorative accent lines (Brand Orange #FF6E00)
    accent_orange = (255, 110, 0)
    draw.rectangle([0, 0, width, 5], fill=accent_orange)
    draw.rectangle([0, height - 6, width, height], fill=accent_orange)
    
    # Place white badge / circular card behind logo or clean transparent logo
    logo = Image.open('assets/images/app_logo.png').convert('RGBA')
    logo.thumbnail((180, 180), Image.Resampling.LANCZOS)
    
    logo_x = (width - logo.width) // 2
    logo_y = 130
    
    # Draw soft subtle rounded card background for logo to pop on dark gradient
    card_margin = 16
    card_box = [
        logo_x - card_margin,
        logo_y - card_margin,
        logo_x + logo.width + card_margin,
        logo_y + logo.height + card_margin
    ]
    draw.rounded_rectangle(card_box, radius=16, fill=(255, 255, 255))
    
    # Paste logo onto card
    img.paste(logo, (logo_x, logo_y), logo)
    
    # Subtitle texts
    try:
        font_large = ImageFont.truetype('assets/fonts/Tajawal-Bold.ttf', 24)
        font_small = ImageFont.truetype('assets/fonts/Tajawal-Regular.ttf', 15)
        font_en = ImageFont.truetype('assets/fonts/Tajawal-Bold.ttf', 16)
    except Exception:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()
        font_en = ImageFont.load_default()
    
    # Text 1: Nayli Kiosk POS
    text_en = "Nayli Kiosk POS"
    bbox_en = draw.textbbox((0, 0), text_en, font=font_large)
    tw_en = bbox_en[2] - bbox_en[0]
    draw.text(((width - tw_en) // 2, logo_y + logo.height + card_margin + 36), text_en, fill=(255, 255, 255), font=font_large)
    
    # Text 2: Brand Tagline
    tagline = "Desktop POS Engine"
    bbox_tag = draw.textbbox((0, 0), tagline, font=font_en)
    tw_tag = bbox_tag[2] - bbox_tag[0]
    draw.text(((width - tw_tag) // 2, logo_y + logo.height + card_margin + 74), tagline, fill=accent_orange, font=font_en)
    
    # Bottom version watermark
    bottom_ver = "v2.5 Official Release"
    bbox_v = draw.textbbox((0, 0), bottom_ver, font=font_small)
    tw_v = bbox_v[2] - bbox_v[0]
    draw.text(((width - tw_v) // 2, height - 38), bottom_ver, fill=(150, 180, 210), font=font_small)
    
    out_path = 'windows/installer/wizard_large.bmp'
    img.save(out_path, format='BMP')
    print(f"Generated {out_path} ({width}x{height})")
    return out_path

def generate_app_icon():
    """
    Generates multi-resolution .ico containing 16, 24, 32, 48, 64, 128, 256 px layers.
    """
    logo = Image.open('assets/images/app_logo.png').convert('RGBA')
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    
    out_ico1 = 'assets/images/app_icon.ico'
    out_ico2 = 'windows/runner/resources/app_icon.ico'
    
    logo.save(out_ico1, format='ICO', sizes=sizes)
    logo.save(out_ico2, format='ICO', sizes=sizes)
    print(f"Generated {out_ico1} and {out_ico2} with {len(sizes)} resolutions.")

def sync_to_desktop_subfolder():
    """
    Synchronizes generated assets to 'Nayli Market Desktop' subfolder.
    """
    files_to_sync = [
        ('assets/images/app_logo.svg', 'Nayli Market Desktop/assets/images/app_logo.svg'),
        ('assets/images/nayli_kiosk_logo_full.svg', 'Nayli Market Desktop/assets/images/nayli_kiosk_logo_full.svg'),
        ('assets/images/app_icon.ico', 'Nayli Market Desktop/assets/images/app_icon.ico'),
        ('windows/wizard_small.bmp', 'Nayli Market Desktop/windows/wizard_small.bmp'),
        ('windows/wizard_large.bmp', 'Nayli Market Desktop/windows/wizard_large.bmp'),
        ('windows/wizard_small.bmp', 'windows/installer/wizard_small.bmp'),
        ('windows/wizard_large.bmp', 'windows/installer/wizard_large.bmp'),
    ]
    for src, dst in files_to_sync:
        if os.path.exists(src):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            print(f"Synced {src} -> {dst}")

if __name__ == '__main__':
    print("Generating Nayli Kiosk Installer Assets...")
    ensure_dirs()
    generate_wizard_small()
    generate_wizard_large()
    generate_app_icon()
    sync_to_desktop_subfolder()
    print("All installer assets successfully generated and synchronized!")
