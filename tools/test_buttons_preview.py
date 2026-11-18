"""
Simulate and render Two Dots button styles with icons to verify contrast.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UI_DIR = os.path.join(ROOT, "assets", "images", "ui")
OUT_DIR = r"C:\Users\User\.gemini\antigravity\brain\ea8270cc-eea1-4b31-8c57-bd757a1a1b92"

SLATE_DK = (45, 55, 72, 255)
SLATE_LT = (113, 128, 150, 255)
MINT = (78, 186, 166, 255)
MINT_DK = (54, 155, 136, 255)
CORAL = (245, 114, 104, 255)
CORAL_DK = (218, 86, 76, 255)
PEACH = (249, 163, 107, 255)
MUSTARD = (246, 183, 60, 255)
MUSTARD_DK = (220, 154, 30, 255)
SKY = (99, 179, 237, 255)
WHITE = (255, 255, 255, 255)
LIP_GREY = (212, 218, 228, 255)
STROKE_GREY = (226, 232, 240, 255)

def draw_tactile_button(draw, x, y, w, h, fill=WHITE, lip=LIP_GREY, stroke=STROKE_GREY, r=16, lip_h=6):
    # Bottom lip / shadow
    draw.rounded_rectangle([x, y + lip_h, x + w, y + h], radius=r, fill=lip)
    # Face
    draw.rounded_rectangle([x, y, x + w, y + h - lip_h], radius=r, fill=fill, outline=stroke, width=2)

def draw_round_button(draw, cx, cy, size, fill=WHITE, stroke=STROKE_GREY, inner_well=True, well_ratio=0.74):
    r = size // 2
    # Base circle
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    # Outer ring
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=stroke, width=3)
    # Inner well if colored
    if inner_well and fill != WHITE:
        wr = int(r * well_ratio)
        draw.ellipse([cx - wr, cy - wr, cx + wr, cy + wr], fill=(255, 255, 255, 245), outline=(240, 244, 248, 255), width=2)

def render_preview():
    W = 1100
    H = 920
    canvas = Image.new("RGBA", (W, H), (238, 242, 246, 255)) # Soft background
    draw = ImageDraw.Draw(canvas)
    
    font_b = ImageFont.truetype("arialbd.ttf", 26)
    font_s = ImageFont.truetype("arial.ttf", 15)
    font_price = ImageFont.truetype("arialbd.ttf", 18)
    font_len = ImageFont.truetype("arial.ttf", 13)
    
    draw.text((50, 30), "TWO DOTS TACTILE BUTTONS — MAXIMUM ICON CONTRAST", fill=SLATE_DK, font=font_b)
    draw.text((50, 65), "Comparing new Light Tactile Pods & Booster Wells against the old Dark Slate buttons", fill=SLATE_LT, font=font_s)
    draw.line([(50, 95), (1050, 95)], fill=(210, 218, 226, 255), width=2)
    
    # -------------------------------------------------------------
    # ROW 1: Material buttons (Unselected & Selected)
    # -------------------------------------------------------------
    draw.text((50, 115), "1. MATERIAL BUTTONS (NEW LIGHT TACTILE CARDS VS OLD DARK SLATE)", fill=MINT, font=font_s)
    
    mats = [
        ("mat_road", "$30", "12m"),
        ("mat_steel_road", "$60", "10m"),
        ("mat_wood", "$15", "8m"),
        ("mat_steel", "$45", "10m"),
        ("mat_cable", "$25", "16m"),
        ("mat_boost", "$50", "8m"),
    ]
    
    # NEW STYLE: White tactile buttons
    draw.text((50, 140), "NEW Two Dots Light Cards (Crystal-clear icon visibility):", fill=SLATE_DK, font=font_s)
    bw, bh = 100, 115
    for i, (m_id, price, m_len) in enumerate(mats):
        bx = 50 + i * (bw + 20)
        by = 165
        is_sel = (i == 0) # Road is selected
        
        if is_sel:
            # Yellow Two Dots selection border
            draw.rounded_rectangle([bx - 4, by - 4, bx + bw + 4, by + bh + 4], radius=20, fill=MUSTARD)
            draw_tactile_button(draw, bx, by, bw, bh, fill=(255, 252, 240, 255), lip=MUSTARD_DK, stroke=MUSTARD, r=16)
        else:
            draw_tactile_button(draw, bx, by, bw, bh, fill=WHITE, lip=LIP_GREY, stroke=STROKE_GREY, r=16)
            
        # Icon
        ico_p = os.path.join(UI_DIR, f"{m_id}.png")
        if os.path.exists(ico_p):
            ico = Image.open(ico_p).convert("RGBA").resize((76, 50), Image.Resampling.LANCZOS)
            canvas.paste(ico, (bx + (bw - 76) // 2, by + 12), ico)
            
        # Price & Len
        draw.text((bx + bw // 2, by + 68), price, fill=SLATE_DK, font=font_price, anchor="mt")
        draw.text((bx + bw // 2, by + 88), m_len, fill=SLATE_LT, font=font_len, anchor="mt")
        
    # OLD STYLE comparison: Dark Slate buttons
    draw.text((790, 140), "OLD Dark Slate (Loss of contrast):", fill=SLATE_LT, font=font_s)
    old_mats = [("mat_road", "$30", "12m"), ("mat_steel", "$45", "10m")]
    for i, (m_id, price, m_len) in enumerate(old_mats):
        bx = 790 + i * (bw + 20)
        by = 165
        draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=16, fill=(61, 74, 92, 255))
        ico_p = os.path.join(UI_DIR, f"{m_id}.png")
        if os.path.exists(ico_p):
            ico = Image.open(ico_p).convert("RGBA").resize((76, 50), Image.Resampling.LANCZOS)
            canvas.paste(ico, (bx + (bw - 76) // 2, by + 12), ico)
        draw.text((bx + bw // 2, by + 68), price, fill=WHITE, font=font_price, anchor="mt")
        draw.text((bx + bw // 2, by + 88), m_len, fill=(160, 174, 192, 255), font=font_len, anchor="mt")

    # -------------------------------------------------------------
    # ROW 2: Tools & Actions (Eraser, Undo, Trash, Home, Wrench, Hint)
    # -------------------------------------------------------------
    y_r2 = 320
    draw.text((50, y_r2), "2. TOOLS & TOP BAR BUTTONS (LIGHT TACTILE PODS & WELLS)", fill=MINT, font=font_s)
    
    tools = [
        ("home", "Home", WHITE, False),
        ("undo", "Undo", WHITE, False),
        ("trash", "Clear", WHITE, False),
        ("eraser", "Eraser", WHITE, True), # Active eraser
        ("wrench", "Edit", PEACH, False),  # Colored button with inner well
        ("hint", "Hint", MUSTARD, False),  # Colored button with inner well
        ("fit", "Zoom", WHITE, False),     # Round button
    ]
    
    tx_start = 50
    for title, lbl, col, active in tools:
        if title == "fit":
            # Round button
            cx = tx_start + 40
            cy = y_r2 + 70
            draw_round_button(draw, cx, cy, 74, fill=WHITE, stroke=STROKE_GREY, inner_well=False)
            ico = Image.open(os.path.join(UI_DIR, "fit.png")).convert("RGBA").resize((42, 42), Image.Resampling.LANCZOS)
            canvas.paste(ico, (cx - 21, cy - 21), ico)
            draw.text((cx, cy + 46), lbl, fill=SLATE_DK, font=font_len, anchor="mt")
            tx_start += 110
            continue
            
        tbw, tbh = 88, 76
        bx = tx_start
        by = y_r2 + 32
        
        if active:
            # Active coral selection border for eraser
            draw.rounded_rectangle([bx - 3, by - 3, bx + tbw + 3, by + tbh + 3], radius=18, fill=CORAL)
            draw_tactile_button(draw, bx, by, tbw, tbh, fill=(255, 244, 242, 255), lip=CORAL_DK, stroke=CORAL, r=14)
        elif col == WHITE:
            draw_tactile_button(draw, bx, by, tbw, tbh, fill=WHITE, lip=LIP_GREY, stroke=STROKE_GREY, r=14)
        else:
            # Colored action button (e.g. Hint or Wrench)
            lip_c = MUSTARD_DK if col == MUSTARD else CORAL_DK
            draw_tactile_button(draw, bx, by, tbw, tbh, fill=col, lip=lip_c, stroke=col, r=14)
            # Inner white contrast well!
            draw.ellipse([bx + tbw // 2 - 24, by + 10, bx + tbw // 2 + 24, by + 58], fill=WHITE)
            
        ico_p = os.path.join(UI_DIR, f"{title}.png")
        if os.path.exists(ico_p):
            ico = Image.open(ico_p).convert("RGBA").resize((40, 40), Image.Resampling.LANCZOS)
            canvas.paste(ico, (bx + (tbw - 40) // 2, by + 14), ico)
            
        draw.text((bx + tbw // 2, by + 84), lbl, fill=SLATE_DK, font=font_len, anchor="mt")
        tx_start += tbw + 24

    # -------------------------------------------------------------
    # ROW 3: Vehicles & Pedals
    # -------------------------------------------------------------
    y_r3 = 490
    draw.text((50, y_r3), "3. VEHICLE BUTTONS & PEDALS (FLAT 2.0 LIGHT CARDS & BOOSTER STROKES)", fill=MINT, font=font_s)
    
    v_start = 50
    vehs = [("veh_car", "Car", True), ("veh_truck", "Truck", False), ("veh_moto", "Motorcycle", False)]
    for v_id, v_lbl, is_sel in vehs:
        vbw, vbh = 110, 84
        bx = v_start
        by = y_r3 + 32
        if is_sel:
            draw.rounded_rectangle([bx - 3, by - 3, bx + vbw + 3, by + vbh + 3], radius=18, fill=SKY)
            draw_tactile_button(draw, bx, by, vbw, vbh, fill=(240, 248, 255, 255), lip=(66, 153, 225, 255), stroke=SKY, r=14)
        else:
            draw_tactile_button(draw, bx, by, vbw, vbh, fill=WHITE, lip=LIP_GREY, stroke=STROKE_GREY, r=14)
            
        ico = Image.open(os.path.join(UI_DIR, f"{v_id}.png")).convert("RGBA").resize((56, 42), Image.Resampling.LANCZOS)
        canvas.paste(ico, (bx + (vbw - 56) // 2, by + 10), ico)
        draw.text((bx + vbw // 2, by + 58), v_lbl, fill=SLATE_DK, font=font_len, anchor="mt")
        v_start += vbw + 24
        
    # Pedals
    pedals_start = v_start + 60
    draw.text((pedals_start, y_r3 + 32), "Two Dots Style Pedals:", fill=SLATE_DK, font=font_s)
    
    # Gas pedal
    cx_gas = pedals_start + 50
    cy_gas = y_r3 + 90
    draw_round_button(draw, cx_gas, cy_gas, 84, fill=MINT, stroke=WHITE, inner_well=True)
    p_gas = Image.open(os.path.join(UI_DIR, "pedal_gas.png")).convert("RGBA").resize((40, 40), Image.Resampling.LANCZOS)
    canvas.paste(p_gas, (cx_gas - 20, cy_gas - 20), p_gas)
    draw.text((cx_gas, cy_gas + 50), "GAS", fill=SLATE_DK, font=font_len, anchor="mt")
    
    # Brake pedal
    cx_brk = cx_gas + 110
    cy_brk = cy_gas
    draw_round_button(draw, cx_brk, cy_brk, 84, fill=CORAL, stroke=WHITE, inner_well=True)
    p_brk = Image.open(os.path.join(UI_DIR, "pedal_brake.png")).convert("RGBA").resize((40, 40), Image.Resampling.LANCZOS)
    canvas.paste(p_brk, (cx_brk - 20, cy_brk - 20), p_brk)
    draw.text((cx_brk, cy_brk + 50), "BRAKE", fill=SLATE_DK, font=font_len, anchor="mt")

    # -------------------------------------------------------------
    # ROW 4: Primary Action Buttons (GO / PLAY / NEXT)
    # -------------------------------------------------------------
    y_r4 = 680
    draw.text((50, y_r4), "4. PRIMARY ACTION BUTTONS (VIBRANT TWO DOTS TACTILE PILLS)", fill=MINT, font=font_s)
    
    actions = [
        ("GO / ПУСК", MINT, MINT_DK, 180, 72),
        ("PLAY / ИГРАТЬ", MINT, MINT_DK, 220, 72),
        ("NEXT / ДАЛЕЕ", SKY, (66, 153, 225, 255), 180, 72),
        ("RETRY", CORAL, CORAL_DK, 160, 72),
    ]
    ax = 50
    for text, col, col_lip, pw, ph in actions:
        by = y_r4 + 32
        draw_tactile_button(draw, ax, by, pw, ph, fill=col, lip=col_lip, stroke=col, r=20, lip_h=8)
        draw.text((ax + pw // 2, by + 18), text, fill=WHITE, font=font_b, anchor="mt")
        ax += pw + 26
        
    out_path = os.path.join(OUT_DIR, "twodots_buttons_preview.png")
    canvas.save(out_path)
    print("Saved button preview to", out_path)

if __name__ == "__main__":
    render_preview()
