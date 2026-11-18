"""
Generate a showcase poster of all Two Dots GUI assets and icons.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UI_DIR = os.path.join(ROOT, "assets", "images", "ui")
OUT_DIR = r"C:\Users\User\.gemini\antigravity\brain\ea8270cc-eea1-4b31-8c57-bd757a1a1b92"

GROUPS = [
    ("REWARDS & META", ["coin", "star", "star_slot", "trophy", "garage", "lock"]),
    ("NAVIGATION", ["play", "stop", "retry", "next", "back", "home", "menu", "close"]),
    ("TOOLS & ACTIONS", ["wrench", "eraser", "trash", "undo", "fit", "hint"]),
    ("MATERIALS (96x64)", ["mat_road", "mat_steel_road", "mat_wood", "mat_steel", "mat_cable", "mat_rope", "mat_boost", "mat_bounce"]),
    ("VEHICLES & PEDALS", ["veh_moto", "veh_car", "veh_truck", "pedal_gas", "pedal_brake"]),
    ("SETTINGS & GESTURES", ["check", "video", "sound_on", "sound_off", "vibrate_on", "vibrate_off", "plus", "minus", "hand"]),
]

BG_COLOR = (244, 247, 246, 255)       # Soft Two Dots pastel background
CARD_BG = (255, 255, 255, 255)        # Clean white card
SLATE_DK = (45, 55, 72, 255)          # #2D3748
SLATE_LT = (113, 128, 150, 255)       # #718096
MINT = (78, 186, 166, 255)            # #4EBAA6
CORAL = (245, 114, 104, 255)          # #F57268
MUSTARD = (246, 183, 60, 255)         # #F6B73C

def make_showcase():
    W = 1200
    H = 1580
    canvas = Image.new("RGBA", (W, H), BG_COLOR)
    draw = ImageDraw.Draw(canvas)
    
    # Try loading a clean sans-serif font
    font_title = None
    font_group = None
    font_label = None
    for fn in ["arialbd.ttf", "segoeuib.ttf", "calibrib.ttf", "DejaVuSans-Bold.ttf"]:
        try:
            font_title = ImageFont.truetype(fn, 36)
            font_group = ImageFont.truetype(fn, 19)
            break
        except:
            pass
    for fn in ["arial.ttf", "segoeui.ttf", "calibri.ttf", "DejaVuSans.ttf"]:
        try:
            font_label = ImageFont.truetype(fn, 13)
            break
        except:
            pass
    if not font_title:
        font_title = font_group = font_label = ImageFont.load_default()
        
    # Top banner / header
    draw.text((60, 40), "TWO DOTS FLAT 2.0 GUI & ICON SET", fill=SLATE_DK, font=font_title)
    draw.text((60, 88), "Bridge Mad — 48 Lineless Vector Assets (42 Game Icons + 6 UI Primitives)", fill=SLATE_LT, font=font_group)
    
    # Decorative Two Dots palette dots
    palette_dots = [
        (78, 186, 166), (245, 114, 104), (249, 163, 107),
        (246, 183, 60), (99, 179, 237), (159, 122, 234)
    ]
    for idx, col in enumerate(palette_dots):
        draw.ellipse([980 + idx * 30, 48, 980 + idx * 30 + 18, 48 + 18], fill=(*col, 255))
        
    draw.line([(60, 126), (1140, 126)], fill=(225, 232, 237, 255), width=2)
    
    y_cursor = 145
    
    for group_name, icons in GROUPS:
        draw.text((60, y_cursor), group_name, fill=MINT, font=font_group)
        y_cursor += 30
        
        # Grid of icons - 9 columns so 9 items fit on one row!
        item_w = 104
        item_h = 118
        gap = 18
        
        for i, icon_name in enumerate(icons):
            col = i
            x = 60 + col * (item_w + gap)
            y = y_cursor
            
            # Card background
            draw.rounded_rectangle([x, y, x + item_w, y + item_h], radius=16, fill=CARD_BG, outline=(230, 236, 241, 255), width=2)
            
            # Load icon
            icon_path = os.path.join(UI_DIR, f"{icon_name}.png")
            if os.path.exists(icon_path):
                ico = Image.open(icon_path).convert("RGBA")
                max_box = 64
                ratio = min(max_box / ico.width, max_box / ico.height)
                nw, nh = int(ico.width * ratio), int(ico.height * ratio)
                ico_resized = ico.resize((nw, nh), Image.Resampling.LANCZOS)
                
                ox = x + (item_w - nw) // 2
                oy = y + 10 + (max_box - nh) // 2
                canvas.paste(ico_resized, (ox, oy), ico_resized)
            
            # Label
            draw.text((x + item_w // 2, y + 90), icon_name, fill=SLATE_DK, font=font_label, anchor="mt")
            
        y_cursor += item_h + 26

    # Bottom UI primitives preview row
    draw.text((60, y_cursor), "TACTILE UI PRIMITIVES & BUTTONS (FLAT 2.0)", fill=MINT, font=font_group)
    y_cursor += 32
    
    prims = [
        ("Tactile Btn", "btn.png", 150, 60),
        ("Panel 9-Slice", "panel.png", 150, 60),
        ("Circle Base", "circle.png", 64, 64),
        ("Ring Stroke", "ring.png", 64, 64),
        ("Glow Aura", "glow.png", 64, 64),
    ]
    px = 60
    for title, fname, pw, ph in prims:
        p_path = os.path.join(UI_DIR, fname)
        if os.path.exists(p_path):
            draw.text((px, y_cursor), title, fill=SLATE_LT, font=font_label)
            p_img = Image.open(p_path).convert("RGBA")
            p_scaled = p_img.resize((pw, ph), Image.Resampling.LANCZOS)
            
            # Draw card underneath in Slate dark
            card_h = 76
            draw.rounded_rectangle([px, y_cursor + 22, px + pw + 20, y_cursor + 22 + card_h], radius=14, fill=SLATE_DK)
            canvas.paste(p_scaled, (px + 10, y_cursor + 22 + (card_h - ph) // 2), p_scaled)
            px += pw + 42
            
    # Also show a composed Two Dots booster button sample!
    draw.text((px + 20, y_cursor), "Composed Booster", fill=SLATE_LT, font=font_label)
    # Circle + ring + icon
    booster_card = Image.new("RGBA", (140, 76), SLATE_DK)
    # Draw booster on top
    c_img = Image.open(os.path.join(UI_DIR, "circle.png")).convert("RGBA").resize((60, 60), Image.Resampling.LANCZOS)
    r_img = Image.open(os.path.join(UI_DIR, "ring.png")).convert("RGBA").resize((60, 60), Image.Resampling.LANCZOS)
    e_img = Image.open(os.path.join(UI_DIR, "eraser.png")).convert("RGBA").resize((38, 38), Image.Resampling.LANCZOS)
    
    # Tint circle to coral
    c_arr = list(c_img.getdata())
    c_tinted = Image.new("RGBA", (60, 60))
    c_tinted.putdata([(245, 114, 104, a[3]) for a in c_arr])
    
    draw_b = ImageDraw.Draw(canvas)
    draw_b.rounded_rectangle([px + 20, y_cursor + 22, px + 20 + 140, y_cursor + 22 + 76], radius=14, fill=SLATE_DK)
    
    bx = px + 20 + (140 - 60) // 2
    by = y_cursor + 22 + (76 - 60) // 2
    canvas.paste(c_tinted, (bx, by), c_tinted)
    canvas.paste(r_img, (bx, by), r_img)
    canvas.paste(e_img, (bx + (60 - 38) // 2, by + (60 - 38) // 2), e_img)
    
    out_path = os.path.join(OUT_DIR, "twodots_gui_showcase.png")
    canvas.save(out_path)
    print("Saved showcase to", out_path)

if __name__ == "__main__":
    make_showcase()
