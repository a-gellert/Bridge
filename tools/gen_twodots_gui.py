"""
Two Dots Style Complete GUI & Icon Generator for Bridge Mad.
Generates all 48 GUI textures (42 icons + 6 primitives) in the authentic Two Dots
flat 2.0 minimalist vector aesthetic (lineless vector art, pastel palette,
geometric shapes, two-tone split shading, tactile depth) using 4x supersampling.
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UI_DIR = os.path.join(ROOT, "assets", "images", "ui")

# Two Dots Palette
MINT         = (78, 186, 166, 255)       # #4EBAA6
MINT_DK      = (54, 155, 136, 255)
MINT_LT      = (125, 211, 196, 255)

CORAL        = (245, 114, 104, 255)      # #F57268
CORAL_DK     = (218, 86, 76, 255)
CORAL_LT     = (252, 160, 152, 255)

PEACH        = (249, 163, 107, 255)      # #F9A36B
PEACH_DK     = (226, 138, 80, 255)

MUSTARD      = (246, 183, 60, 255)       # #F6B73C
MUSTARD_DK   = (220, 154, 30, 255)
MUSTARD_LT   = (255, 210, 104, 255)

PURPLE       = (159, 122, 234, 255)      # #9F7AEA
PURPLE_DK    = (131, 92, 208, 255)

SKY          = (99, 179, 237, 255)       # #63B3ED
SKY_DK       = (66, 153, 225, 255)

SLATE        = (74, 85, 104, 255)        # #4A5568
SLATE_DK     = (45, 55, 72, 255)         # #2D3748
SLATE_LT     = (113, 128, 150, 255)      # #718096
SLATE_XLT    = (160, 174, 192, 255)      # #A0AEC0
SLATE_SLOT   = (110, 122, 142, 255)

WHITE        = (255, 255, 255, 255)
CREAM        = (248, 249, 250, 255)
TRANS        = (0, 0, 0, 0)

SS = 4  # 4x supersampling

def u(val):
    return int(round(val * SS))

def new_canvas(w=96, h=96):
    img = Image.new("RGBA", (w * SS, h * SS), TRANS)
    draw = ImageDraw.Draw(img)
    return img, draw, w * SS, h * SS

def save_icon(img, name, w=96, h=96):
    final = img.resize((w, h), Image.Resampling.LANCZOS)
    p = os.path.join(UI_DIR, f"{name}.png")
    final.save(p)
    return p

def draw_pill(draw, p1, p2, width, color):
    draw.line([p1, p2], fill=color, width=width)
    r = width / 2.0
    draw.ellipse([p1[0] - r, p1[1] - r, p1[0] + r, p1[1] + r], fill=color)
    draw.ellipse([p2[0] - r, p2[1] - r, p2[0] + r, p2[1] + r], fill=color)

def draw_split_circle(draw, cx, cy, r, col_l, col_r):
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=col_l)
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 270, 90, fill=col_r)

def apply_split_shading(img, split_x, col_target, col_shade):
    arr = np.array(img)
    W = arr.shape[1]
    # mask: where x >= split_x and color is col_target (within small tolerance)
    is_right = np.arange(W)[None, :] >= int(split_x)
    is_target = (
        (np.abs(arr[:, :, 0] - col_target[0]) < 10) &
        (np.abs(arr[:, :, 1] - col_target[1]) < 10) &
        (np.abs(arr[:, :, 2] - col_target[2]) < 10) &
        (arr[:, :, 3] > 20)
    )
    mask = is_right & is_target
    arr[mask, 0] = col_shade[0]
    arr[mask, 1] = col_shade[1]
    arr[mask, 2] = col_shade[2]
    return Image.fromarray(arr, "RGBA")

# ==============================================================================
# 1. PRIMITIVES
# ==============================================================================
def gen_white():
    im = Image.new("RGBA", (8, 8), WHITE)
    im.save(os.path.join(UI_DIR, "white.png"))

def gen_panel():
    img, draw, W, H = new_canvas(64, 64)
    r = u(18)
    draw.rounded_rectangle([0, 0, W - 1, H - 1], radius=r, fill=WHITE)
    save_icon(img, "panel", 64, 64)

def gen_btn():
    img, draw, W, H = new_canvas(64, 72)
    r = u(18)
    lip_h = u(8)
    lip_color = (210, 218, 228, 255)
    stroke_color = (226, 232, 240, 255)
    # Bottom tactile lip
    draw.rounded_rectangle([0, lip_h, W - 1, H - 1], radius=r, fill=lip_color)
    # Face with fine subtle perimeter stroke
    draw.rounded_rectangle([0, 0, W - 1, H - 1 - lip_h], radius=r, fill=WHITE, outline=stroke_color, width=u(1.0))
    save_icon(img, "btn", 64, 72)

def gen_circle():
    img, draw, W, H = new_canvas(128, 128)
    pad = u(2)
    stroke_color = (226, 232, 240, 255)
    draw.ellipse([pad, pad, W - 1 - pad, H - 1 - pad], fill=WHITE, outline=stroke_color, width=u(1.0))
    save_icon(img, "circle", 128, 128)

def gen_ring():
    img, draw, W, H = new_canvas(128, 128)
    pad = u(3)
    stroke = u(5)
    draw.ellipse([pad, pad, W - 1 - pad, H - 1 - pad], outline=WHITE, width=stroke)
    save_icon(img, "ring", 128, 128)

def gen_glow():
    img = Image.new("RGBA", (128, 128), TRANS)
    cx, cy = 64, 64
    for r in range(60, 2, -2):
        alpha = int(45 * (1.0 - (r / 60.0) ** 1.5))
        d = ImageDraw.Draw(img)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha))
    img.save(os.path.join(UI_DIR, "glow.png"))

# ==============================================================================
# 2. REWARDS & META
# ==============================================================================
def gen_star():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(2)
    r_out = u(36)
    r_in = u(18)
    stroke = u(8)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * (math.pi / 5)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    
    for i in range(10):
        draw.line([pts[i], pts[i+1]], fill=MUSTARD, width=stroke)
        draw.ellipse([pts[i][0]-stroke/2, pts[i][1]-stroke/2, pts[i][0]+stroke/2, pts[i][1]+stroke/2], fill=MUSTARD)
    draw.polygon(pts[:-1], fill=MUSTARD)
    
    img = apply_split_shading(img, cx, MUSTARD, MUSTARD_DK)
    save_icon(img, "star", 96, 96)

def gen_star_slot():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(2)
    r_out = u(36)
    r_in = u(18)
    stroke = u(5.5)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * (math.pi / 5)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append(pts[0])
    
    for i in range(10):
        draw.line([pts[i], pts[i+1]], fill=SLATE_SLOT, width=int(round(stroke)))
        draw.ellipse([pts[i][0]-stroke/2, pts[i][1]-stroke/2, pts[i][0]+stroke/2, pts[i][1]+stroke/2], fill=SLATE_SLOT)
    save_icon(img, "star_slot", 96, 96)

def gen_coin():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    r = u(38)
    draw_split_circle(draw, cx, cy, r, MUSTARD, MUSTARD_DK)
    
    r_in = u(30)
    draw.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], outline=MUSTARD_LT, width=u(3))
    
    # Minimalist Bridge icon in center
    col_bridge = SLATE_DK
    draw_pill(draw, (cx - u(14), cy + u(16)), (cx - u(14), cy - u(16)), u(4), col_bridge)
    draw_pill(draw, (cx + u(14), cy + u(16)), (cx + u(14), cy - u(16)), u(4), col_bridge)
    draw_pill(draw, (cx - u(24), cy + u(6)), (cx + u(24), cy + u(6)), u(4), col_bridge)
    cable_pts = [
        (cx - u(24), cy - u(8)),
        (cx - u(14), cy - u(16)),
        (cx, cy + u(2)),
        (cx + u(14), cy - u(16)),
        (cx + u(24), cy - u(8))
    ]
    draw.line(cable_pts, fill=col_bridge, width=u(3))
    save_icon(img, "coin", 96, 96)

def gen_trophy():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 - u(2)
    
    draw.arc([cx - u(36), cy - u(20), cx - u(12), cy + u(12)], 90, 270, fill=MUSTARD, width=u(6))
    draw.arc([cx + u(12), cy - u(20), cx + u(36), cy + u(12)], 270, 90, fill=MUSTARD_DK, width=u(6))
    
    cup_pts_l = [(cx, cy - u(26)), (cx - u(22), cy - u(26)), (cx - u(20), cy + u(6)), (cx - u(6), cy + u(18)), (cx, cy + u(18))]
    cup_pts_r = [(cx, cy - u(26)), (cx + u(22), cy - u(26)), (cx + u(20), cy + u(6)), (cx + u(6), cy + u(18)), (cx, cy + u(18))]
    draw.polygon(cup_pts_l, fill=MUSTARD)
    draw.polygon(cup_pts_r, fill=MUSTARD_DK)
    
    draw.ellipse([cx - u(24), cy - u(30), cx + u(24), cy - u(22)], fill=MUSTARD_LT)
    
    draw.rectangle([cx - u(5), cy + u(18), cx, cy + u(28)], fill=MUSTARD)
    draw.rectangle([cx, cy + u(18), cx + u(5), cy + u(28)], fill=MUSTARD_DK)
    draw.rounded_rectangle([cx - u(18), cy + u(28), cx, cy + u(36)], radius=u(4), fill=MUSTARD)
    draw.rounded_rectangle([cx, cy + u(28), cx + u(18), cy + u(36)], radius=u(4), fill=MUSTARD_DK)
    
    star_r = u(7)
    s_pts = []
    for i in range(10):
        a = -math.pi / 2 + i * (math.pi / 5)
        r = star_r if i % 2 == 0 else star_r * 0.45
        s_pts.append((cx + r * math.cos(a), cy - u(6) + r * math.sin(a)))
    draw.polygon(s_pts, fill=WHITE)
    save_icon(img, "trophy", 96, 96)

def gen_garage():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(2)
    
    roof_pts_l = [(cx, cy - u(34)), (cx - u(36), cy - u(10)), (cx, cy - u(10))]
    roof_pts_r = [(cx, cy - u(34)), (cx + u(36), cy - u(10)), (cx, cy - u(10))]
    draw.polygon(roof_pts_l, fill=SLATE_LT)
    draw.polygon(roof_pts_r, fill=SLATE)
    
    draw.rectangle([cx + u(16), cy - u(32), cx + u(24), cy - u(18)], fill=SLATE)
    
    draw.rectangle([cx - u(30), cy - u(10), cx, cy + u(30)], fill=MINT)
    draw.rectangle([cx, cy - u(10), cx + u(30), cy + u(30)], fill=MINT_DK)
    
    dw, dh = u(20), u(24)
    draw.rounded_rectangle([cx - dw, cy + u(6), cx + dw, cy + u(30)], radius=u(4), fill=SLATE_DK)
    for sy in range(int(cy + u(11)), int(cy + u(28)), int(u(4))):
        draw.line([(cx - dw + u(4), sy), (cx + dw - u(4), sy)], fill=SLATE_LT, width=u(2))
    
    draw.rounded_rectangle([cx - u(8), cy - u(4), cx + u(8), cy + u(2)], radius=u(2), fill=CREAM)
    save_icon(img, "garage", 96, 96)

def gen_lock():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(4)
    
    shackle_r = u(18)
    shackle_stroke = u(7)
    draw.arc([cx - shackle_r, cy - u(36), cx + shackle_r, cy], 180, 0, fill=SLATE_LT, width=shackle_stroke)
    draw.line([(cx - shackle_r, cy - u(18)), (cx - shackle_r, cy - u(8))], fill=SLATE_LT, width=shackle_stroke)
    draw.line([(cx + shackle_r, cy - u(18)), (cx + shackle_r, cy - u(8))], fill=SLATE_LT, width=shackle_stroke)
    
    bw, bh = u(26), u(22)
    r = u(8)
    draw.rounded_rectangle([cx - bw, cy - u(8), cx, cy + bh], radius=r, fill=CORAL)
    draw.rounded_rectangle([cx, cy - u(8), cx + bw, cy + bh], radius=r, fill=CORAL_DK)
    
    draw.ellipse([cx - u(5), cy, cx + u(5), cy + u(10)], fill=SLATE_DK)
    draw.polygon([(cx - u(3), cy + u(7)), (cx + u(3), cy + u(7)), (cx + u(5), cy + u(16)), (cx - u(5), cy + u(16))], fill=SLATE_DK)
    save_icon(img, "lock", 96, 96)

# ==============================================================================
# 3. NAVIGATION & INTERFACE BUTTONS
# ==============================================================================
def gen_play():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0 + u(3), H / 2.0
    r = u(26)
    p_top = (cx - r * 0.7, cy - r * 1.05)
    p_bot = (cx - r * 0.7, cy + r * 1.05)
    p_right = (cx + r * 1.15, cy)
    
    stroke = u(12)
    draw_pill(draw, p_top, p_right, stroke, MINT)
    draw_pill(draw, p_right, p_bot, stroke, MINT)
    draw_pill(draw, p_bot, p_top, stroke, MINT)
    draw.polygon([p_top, p_right, p_bot], fill=MINT)
    
    arr = np.array(img)
    mask = (arr[:, :, 3] > 0) & (np.arange(W)[None, :] >= int(cx))
    arr[mask, 0] = MINT_DK[0]
    arr[mask, 1] = MINT_DK[1]
    arr[mask, 2] = MINT_DK[2]
    img = Image.fromarray(arr, "RGBA")
    save_icon(img, "play", 96, 96)

def gen_stop():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    s = u(26)
    r = u(8)
    draw.rounded_rectangle([cx - s, cy - s, cx, cy + s], radius=r, fill=CORAL)
    draw.rounded_rectangle([cx, cy - s, cx + s, cy + s], radius=r, fill=CORAL_DK)
    save_icon(img, "stop", 96, 96)

def gen_retry():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    r = u(26)
    stroke = u(8)
    draw.arc([cx - r, cy - r, cx + r, cy + r], 45, 315, fill=MUSTARD, width=stroke)
    ax, ay = cx + r * math.cos(math.radians(45)), cy + r * math.sin(math.radians(45))
    ah = u(14)
    draw.polygon([(ax - u(4), ay - ah), (ax + ah, ay), (ax - u(4), ay + ah)], fill=MUSTARD_DK)
    save_icon(img, "retry", 96, 96)

def gen_next():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    ch_w = u(8)
    for dx in [-u(10), u(10)]:
        x = cx + dx
        draw_pill(draw, (x - u(10), cy - u(20)), (x + u(8), cy), ch_w, MINT)
        draw_pill(draw, (x + u(8), cy), (x - u(10), cy + u(20)), ch_w, MINT)
    save_icon(img, "next", 96, 96)

def gen_back():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0 + u(2), H / 2.0
    ch_w = u(8)
    draw_pill(draw, (cx + u(6), cy - u(20)), (cx - u(12), cy), ch_w, SKY)
    draw_pill(draw, (cx - u(12), cy), (cx + u(6), cy + u(20)), ch_w, SKY)
    draw_pill(draw, (cx - u(10), cy), (cx + u(20), cy), ch_w, SKY)
    save_icon(img, "back", 96, 96)

def gen_home():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(2)
    r_pts_l = [(cx, cy - u(32)), (cx - u(32), cy - u(8)), (cx, cy - u(8))]
    r_pts_r = [(cx, cy - u(32)), (cx + u(32), cy - u(8)), (cx, cy - u(8))]
    draw.polygon(r_pts_l, fill=CORAL)
    draw.polygon(r_pts_r, fill=CORAL_DK)
    draw.rectangle([cx - u(24), cy - u(8), cx, cy + u(28)], fill=CREAM)
    draw.rectangle([cx, cy - u(8), cx + u(24), cy + u(28)], fill=(235, 238, 242, 255))
    draw.rounded_rectangle([cx - u(8), cy + u(6), cx + u(8), cy + u(28)], radius=u(4), fill=SLATE_DK)
    save_icon(img, "home", 96, 96)

def gen_menu():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    bar_w = u(26)
    th = u(6)
    for dy in [-u(16), 0, u(16)]:
        draw_pill(draw, (cx - bar_w, cy + dy), (cx + bar_w, cy + dy), th, SLATE_LT)
    save_icon(img, "menu", 96, 96)

def gen_close():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    s = u(22)
    th = u(9)
    draw_pill(draw, (cx - s, cy - s), (cx + s, cy + s), th, CORAL)
    draw_pill(draw, (cx + s, cy - s), (cx - s, cy + s), th, CORAL)
    save_icon(img, "close", 96, 96)

# ==============================================================================
# 4. TOOLS & ACTIONS
# ==============================================================================
def gen_wrench():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    rad = math.radians(45)
    p_start = (cx - u(20), cy + u(20))
    p_end = (cx + u(10), cy - u(10))
    draw.line([p_start, p_end], fill=MUSTARD, width=u(14))
    cr = u(7)
    draw.ellipse([p_start[0]-cr, p_start[1]-cr, p_start[0]+cr, p_start[1]+cr], fill=MUSTARD)

    hx, hy = cx + u(16), cy - u(16)
    head_r = u(18)
    draw.ellipse([hx-head_r, hy-head_r, hx+head_r, hy+head_r], fill=SLATE_LT)

    jw, jh = u(8), u(24)
    jaw_poly = []
    for f_forward, f_lateral in [(0, -jw), (jh, -jw), (jh, jw), (0, jw)]:
        rx = hx + (f_forward * math.cos(rad) - f_lateral * math.sin(rad))
        ry = hy - (f_forward * math.sin(rad) + f_lateral * math.cos(rad))
        jaw_poly.append((rx, ry))

    jaw_img = Image.new("L", (W, H), 0)
    d_jaw = ImageDraw.Draw(jaw_img)
    d_jaw.polygon(jaw_poly, fill=255)

    hr = u(4)
    hole_img = Image.new("L", (W, H), 0)
    d_hole = ImageDraw.Draw(hole_img)
    d_hole.ellipse([p_start[0]-hr, p_start[1]-hr, p_start[0]+hr, p_start[1]+hr], fill=255)

    arr = np.array(img)
    arr[np.array(jaw_img) > 0] = [0, 0, 0, 0]
    arr[np.array(hole_img) > 0] = [0, 0, 0, 0]
    img = Image.fromarray(arr, "RGBA")
    save_icon(img, "wrench", 96, 96)

def gen_eraser():
    W, H = 96 * SS, 96 * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ew, eh = u(32), u(50)
    er_base = Image.new("RGBA", (ew, eh), (0, 0, 0, 0))
    d_e = ImageDraw.Draw(er_base)
    d_e.rounded_rectangle([0, 0, ew - 1, eh - 1], radius=u(6), fill=CORAL)
    d_e.rectangle([0, int(eh * 0.42), ew - 1, int(eh * 0.58)], fill=WHITE)
    d_e.rounded_rectangle([0, int(eh * 0.58), ew - 1, eh - 1], radius=u(6), fill=SKY)
    d_e.rounded_rectangle([0, 0, ew - 1, eh - 1], radius=u(6), outline=SLATE_LT, width=u(2))

    er_rot = er_base.rotate(25, expand=True, resample=Image.Resampling.BICUBIC)
    rw, rh = er_rot.size
    img.paste(er_rot, (int(W / 2.0 - rw / 2.0), int(H / 2.0 - rh / 2.0)), er_rot)
    save_icon(img, "eraser", 96, 96)

def gen_trash():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(2)
    draw_pill(draw, (cx - u(8), cy - u(26)), (cx + u(8), cy - u(26)), u(4), SLATE)
    draw_pill(draw, (cx - u(26), cy - u(18)), (cx + u(26), cy - u(18)), u(6), SLATE)
    body = [(cx - u(20), cy - u(14)), (cx + u(20), cy - u(14)), (cx + u(16), cy + u(26)), (cx - u(16), cy + u(26))]
    draw.polygon(body, fill=SLATE_LT)
    for fx in [-u(9), 0, u(9)]:
        draw_pill(draw, (cx + fx, cy - u(8)), (cx + fx * 0.8, cy + u(20)), u(3), SLATE)
    save_icon(img, "trash", 96, 96)

def gen_undo():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    r = u(24)
    stroke = u(8)
    draw.arc([cx - r, cy - r, cx + r, cy + r], 120, 360, fill=SKY, width=stroke)
    ax = cx + r * math.cos(math.radians(120))
    ay = cy + r * math.sin(math.radians(120))
    ah = u(14)
    draw.polygon([(ax - ah, ay - u(6)), (ax + u(4), ay - ah), (ax, ay + u(8))], fill=SKY_DK)
    save_icon(img, "undo", 96, 96)

def gen_fit():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    s = u(26)
    arm = u(14)
    th = u(6)
    draw_pill(draw, (cx - s, cy - s + arm), (cx - s, cy - s), th, SKY)
    draw_pill(draw, (cx - s, cy - s), (cx - s + arm, cy - s), th, SKY)
    draw_pill(draw, (cx + s - arm, cy - s), (cx + s, cy - s), th, SKY)
    draw_pill(draw, (cx + s, cy - s), (cx + s, cy - s + arm), th, SKY)
    draw_pill(draw, (cx - s, cy + s - arm), (cx - s, cy + s), th, SKY)
    draw_pill(draw, (cx - s, cy + s), (cx - s + arm, cy + s), th, SKY)
    draw_pill(draw, (cx + s - arm, cy + s), (cx + s, cy + s), th, SKY)
    draw_pill(draw, (cx + s, cy + s), (cx + s, cy + s - arm), th, SKY)
    save_icon(img, "fit", 96, 96)

def gen_hint():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 - u(4)
    r = u(22)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MUSTARD)
    draw.rectangle([cx - u(12), cy + u(10), cx + u(12), cy + u(24)], fill=MUSTARD)
    draw_pill(draw, (cx - u(10), cy + u(26)), (cx + u(10), cy + u(26)), u(4), SLATE_LT)
    draw_pill(draw, (cx - u(7), cy + u(32)), (cx + u(7), cy + u(32)), u(4), SLATE)
    draw.arc([cx - u(8), cy - u(8), cx + u(8), cy + u(8)], 0, 180, fill=WHITE, width=u(4))
    save_icon(img, "hint", 96, 96)

# ==============================================================================
# 5. MATERIALS (96x64)
# ==============================================================================
def gen_mat_road():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    w2, h2 = u(38), u(16)
    pts = [(cx - w2, cy), (cx, cy - h2), (cx + w2, cy), (cx, cy + h2)]
    bot = [(cx - w2, cy), (cx, cy + h2), (cx + w2, cy), (cx + w2, cy + u(8)), (cx, cy + h2 + u(8)), (cx - w2, cy + u(8))]
    draw.polygon(bot, fill=SLATE_DK)
    draw.polygon(pts, fill=SLATE)
    draw.line([(cx - w2, cy), (cx, cy - h2)], fill=SLATE_XLT, width=u(4))
    draw.line([(cx, cy + h2), (cx + w2, cy)], fill=SLATE_XLT, width=u(4))
    draw.line([(cx - u(12), cy + u(5)), (cx - u(4), cy + u(2))], fill=MUSTARD, width=u(3))
    draw.line([(cx + u(4), cy - u(2)), (cx + u(12), cy - u(5))], fill=MUSTARD, width=u(3))
    save_icon(img, "mat_road", 96, 64)

def gen_mat_steel_road():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    w2, h2 = u(38), u(16)
    pts = [(cx - w2, cy), (cx, cy - h2), (cx + w2, cy), (cx, cy + h2)]
    bot = [(cx - w2, cy), (cx, cy + h2), (cx + w2, cy), (cx + w2, cy + u(10)), (cx, cy + h2 + u(10)), (cx - w2, cy + u(10))]
    draw.polygon(bot, fill=SLATE_DK)
    draw.polygon(pts, fill=SLATE_LT)
    for i in range(-3, 4):
        dx = i * u(8)
        draw.line([(cx + dx - u(8), cy - h2 * 0.5), (cx + dx + u(8), cy + h2 * 0.5)], fill=SLATE, width=u(2))
    draw.line([(cx - w2, cy), (cx, cy - h2)], fill=SLATE, width=u(5))
    draw.line([(cx, cy + h2), (cx + w2, cy)], fill=SLATE, width=u(5))
    save_icon(img, "mat_steel_road", 96, 64)

def gen_mat_wood():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    p1 = (cx - u(36), cy + u(14))
    p2 = (cx + u(36), cy - u(14))
    draw_pill(draw, (p1[0], p1[1] + u(6)), (p2[0], p2[1] + u(6)), u(14), PEACH_DK)
    draw_pill(draw, p1, p2, u(14), PEACH)
    draw_pill(draw, (p1[0] + u(10), p1[1] - u(1)), (p2[0] - u(10), p2[1] - u(1)), u(3), PEACH_DK)
    draw.ellipse([p1[0] - u(7), p1[1] - u(7), p1[0] + u(7), p1[1] + u(7)], fill=SLATE)
    draw.ellipse([p2[0] - u(7), p2[1] - u(7), p2[0] + u(7), p2[1] + u(7)], fill=SLATE)
    save_icon(img, "mat_wood", 96, 64)

def gen_mat_steel():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    p1 = (cx - u(36), cy + u(14))
    p2 = (cx + u(36), cy - u(14))
    draw_pill(draw, (p1[0], p1[1] + u(4)), (p2[0], p2[1] + u(4)), u(16), SLATE)
    draw_pill(draw, p1, p2, u(16), SLATE_LT)
    draw_pill(draw, p1, p2, u(8), SLATE_DK)
    for k in [0.2, 0.4, 0.6, 0.8]:
        rx = p1[0] + (p2[0] - p1[0]) * k
        ry = p1[1] + (p2[1] - p1[1]) * k
        draw.ellipse([rx - u(2), ry - u(2), rx + u(2), ry + u(2)], fill=WHITE)
    save_icon(img, "mat_steel", 96, 64)

def gen_mat_cable():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    p1 = (cx - u(36), cy + u(16))
    p2 = (cx + u(36), cy - u(16))
    draw_pill(draw, p1, p2, u(8), SKY)
    for k in np.linspace(0.15, 0.85, 9):
        x = p1[0] + (p2[0] - p1[0]) * k
        y = p1[1] + (p2[1] - p1[1]) * k
        draw.line([(x - u(3), y - u(3)), (x + u(3), y + u(3))], fill=SKY_DK, width=u(2))
    draw.ellipse([p1[0] - u(5), p1[1] - u(5), p1[0] + u(5), p1[1] + u(5)], fill=SLATE_DK)
    draw.ellipse([p2[0] - u(5), p2[1] - u(5), p2[0] + u(5), p2[1] + u(5)], fill=SLATE_DK)
    save_icon(img, "mat_cable", 96, 64)

def gen_mat_rope():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    p1 = (cx - u(36), cy + u(16))
    p2 = (cx + u(36), cy - u(16))
    ROPE_COL = (226, 178, 122, 255)
    ROPE_DK  = (188, 138, 86, 255)
    draw_pill(draw, p1, p2, u(8), ROPE_COL)
    for k in np.linspace(0.12, 0.88, 10):
        x = p1[0] + (p2[0] - p1[0]) * k
        y = p1[1] + (p2[1] - p1[1]) * k
        draw.line([(x - u(2), y - u(4)), (x + u(2), y + u(4))], fill=ROPE_DK, width=u(3))
    save_icon(img, "mat_rope", 96, 64)

def gen_mat_boost():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    w2, h2 = u(38), u(16)
    pts = [(cx - w2, cy), (cx, cy - h2), (cx + w2, cy), (cx, cy + h2)]
    bot = [(cx - w2, cy), (cx, cy + h2), (cx + w2, cy), (cx + w2, cy + u(8)), (cx, cy + h2 + u(8)), (cx - w2, cy + u(8))]
    draw.polygon(bot, fill=SLATE_DK)
    draw.polygon(pts, fill=SLATE)
    for dx in [-u(10), u(8)]:
        draw.line([(cx + dx - u(8), cy + u(5)), (cx + dx + u(6), cy - u(2)), (cx + dx - u(8), cy - u(9))], fill=MINT_LT, width=u(4))
    save_icon(img, "mat_boost", 96, 64)

def gen_mat_bounce():
    img, draw, W, H = new_canvas(96, 64)
    cx, cy = W / 2.0, H / 2.0
    w2, h2 = u(36), u(10)
    draw.rounded_rectangle([cx - w2, cy - u(14), cx + w2, cy - u(4)], radius=u(5), fill=CORAL)
    draw.rounded_rectangle([cx - w2, cy - u(14), cx, cy - u(4)], radius=u(5), fill=CORAL_LT)
    for sx in [cx - u(18), cx + u(18)]:
        draw.arc([sx - u(8), cy - u(2), sx + u(8), cy + u(10)], 0, 360, fill=SLATE_LT, width=u(3))
        draw.arc([sx - u(8), cy + u(6), sx + u(8), cy + u(18)], 0, 360, fill=SLATE_LT, width=u(3))
    save_icon(img, "mat_bounce", 96, 64)

# ==============================================================================
# 6. VEHICLES & PEDALS (96x96)
# ==============================================================================
def gen_veh_moto():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(4)
    rw = u(15)
    w_left  = (cx - u(22), cy + u(12))
    w_right = (cx + u(22), cy + u(12))
    for wx, wy in [w_left, w_right]:
        draw.ellipse([wx - rw, wy - rw, wx + rw, wy + rw], fill=SLATE_DK)
        draw.ellipse([wx - rw * 0.5, wy - rw * 0.5, wx + rw * 0.5, wy + rw * 0.5], fill=WHITE)
        draw.ellipse([wx - u(3), wy - u(3), wx + u(3), wy + u(3)], fill=SLATE_DK)
    draw_pill(draw, w_left, (cx, cy - u(2)), u(5), MINT)
    draw_pill(draw, (cx, cy - u(2)), w_right, u(5), MINT)
    draw_pill(draw, (cx - u(6), cy - u(12)), (cx + u(8), cy - u(12)), u(6), MINT)
    draw_pill(draw, (cx - u(12), cy - u(14)), (cx - u(2), cy - u(14)), u(4), SLATE)
    draw_pill(draw, (cx + u(10), cy - u(14)), (cx + u(18), cy - u(20)), u(4), SLATE)
    save_icon(img, "veh_moto", 96, 96)

def gen_veh_car():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(4)
    rw = u(14)
    w_left  = (cx - u(20), cy + u(14))
    w_right = (cx + u(20), cy + u(14))
    draw.rounded_rectangle([cx - u(32), cy - u(4), cx + u(32), cy + u(14)], radius=u(6), fill=CORAL)
    cabin = [(cx - u(18), cy - u(4)), (cx - u(10), cy - u(18)), (cx + u(12), cy - u(18)), (cx + u(22), cy - u(4))]
    draw.polygon(cabin, fill=CORAL_DK)
    win = [(cx - u(14), cy - u(5)), (cx - u(8), cy - u(15)), (cx + u(9), cy - u(15)), (cx + u(16), cy - u(5))]
    draw.polygon(win, fill=SKY)
    for wx, wy in [w_left, w_right]:
        draw.ellipse([wx - rw, wy - rw, wx + rw, wy + rw], fill=SLATE_DK)
        draw.ellipse([wx - rw * 0.45, wy - rw * 0.45, wx + rw * 0.45, wy + rw * 0.45], fill=WHITE)
        draw.ellipse([wx - u(3), wy - u(3), wx + u(3), wy + u(3)], fill=SLATE_DK)
    save_icon(img, "veh_car", 96, 96)

def gen_veh_truck():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(4)
    rw = u(12)
    w1 = (cx - u(24), cy + u(16))
    w2 = (cx - u(4),  cy + u(16))
    w3 = (cx + u(22), cy + u(16))
    
    dumper = [(cx - u(34), cy - u(18)), (cx + u(2), cy - u(18)), (cx + u(2), cy + u(10)), (cx - u(30), cy + u(10))]
    draw.polygon(dumper, fill=SLATE_LT)
    
    draw.rounded_rectangle([cx + u(4), cy - u(14), cx + u(30), cy + u(12)], radius=u(4), fill=MUSTARD)
    draw.rounded_rectangle([cx + u(12), cy - u(10), cx + u(28), cy - u(2)], radius=u(2), fill=SKY)
    
    for wx, wy in [w1, w2, w3]:
        draw.ellipse([wx - rw, wy - rw, wx + rw, wy + rw], fill=SLATE_DK)
        draw.ellipse([wx - rw * 0.45, wy - rw * 0.45, wx + rw * 0.45, wy + rw * 0.45], fill=WHITE)
        draw.ellipse([wx - u(2.5), wy - u(2.5), wx + u(2.5), wy + u(2.5)], fill=SLATE_DK)
    save_icon(img, "veh_truck", 96, 96)

def gen_pedal_gas():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    draw.rounded_rectangle([cx - u(18), cy - u(28), cx + u(18), cy + u(28)], radius=u(8), fill=SLATE_DK)
    for dy in [-u(10), u(8)]:
        draw.line([(cx - u(10), cy + dy + u(6)), (cx, cy + dy - u(4)), (cx + u(10), cy + dy + u(6))], fill=MINT, width=u(4))
    save_icon(img, "pedal_gas", 96, 96)

def gen_pedal_brake():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    draw.rounded_rectangle([cx - u(26), cy - u(20), cx + u(26), cy + u(20)], radius=u(8), fill=SLATE_DK)
    for dy in [-u(6), u(10)]:
        draw.line([(cx - u(12), cy + dy - u(6)), (cx, cy + dy + u(4)), (cx + u(12), cy + dy - u(6))], fill=CORAL, width=u(4))
    save_icon(img, "pedal_brake", 96, 96)

# ==============================================================================
# 7. SETTINGS, GESTURES & SYSTEM (96x96)
# ==============================================================================
def gen_check():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0 - u(2), H / 2.0 + u(2)
    p1 = (cx - u(18), cy)
    p2 = (cx - u(4), cy + u(16))
    p3 = (cx + u(22), cy - u(18))
    draw_pill(draw, p1, p2, u(9), MINT)
    draw_pill(draw, p2, p3, u(9), MINT)
    save_icon(img, "check", 96, 96)

def gen_hand():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0 + u(4)
    # Pointing hand gesture (up-left index finger) in Two Dots Peach
    # Tap ripple at finger tip
    tip = (cx - u(10), cy - u(18))
    draw.arc([tip[0] - u(14), tip[1] - u(14), tip[0] + u(14), tip[1] + u(14)], 160, 340, fill=MINT, width=u(3))
    draw.ellipse([tip[0] - u(2), tip[1] - u(18) - u(2), tip[0] + u(2), tip[1] - u(18) + u(2)], fill=MINT)
    
    # Index finger
    draw_pill(draw, (cx + u(2), cy - u(2)), tip, u(11), PEACH)
    
    # Palm body
    draw.rounded_rectangle([cx - u(8), cy - u(4), cx + u(18), cy + u(18)], radius=u(8), fill=PEACH)
    
    # Thumb folded / resting
    draw_pill(draw, (cx - u(10), cy + u(6)), (cx - u(2), cy + u(2)), u(9), PEACH)
    
    # Folded fingers (middle, ring, pinky)
    draw_pill(draw, (cx + u(10), cy - u(2)), (cx + u(18), cy + u(4)), u(8), PEACH_DK)
    draw_pill(draw, (cx + u(10), cy + u(4)), (cx + u(18), cy + u(10)), u(8), PEACH_DK)
    draw_pill(draw, (cx + u(10), cy + u(10)), (cx + u(18), cy + u(16)), u(8), PEACH_DK)
    
    # Two-tone split shading on palm
    img = apply_split_shading(img, cx + u(6), PEACH, PEACH_DK)
    save_icon(img, "hand", 96, 96)

def gen_video():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    bw, bh = u(26), u(20)
    draw.rounded_rectangle([cx - bw, cy - bh, cx + bw, cy + bh], radius=u(6), fill=PURPLE)
    draw.rounded_rectangle([cx - bw, cy - bh, cx + bw, cy - bh + u(12)], radius=u(4), fill=PURPLE_DK)
    for sx in range(int(cx - bw + u(6)), int(cx + bw), int(u(12))):
        draw.line([(sx, cy - bh), (sx + u(6), cy - bh + u(12))], fill=WHITE, width=u(4))
    draw.polygon([(cx - u(6), cy - u(1) - u(8)), (cx + u(8), cy - u(1)), (cx - u(6), cy - u(1) + u(8))], fill=WHITE)
    save_icon(img, "video", 96, 96)

def gen_sound_on():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0 - u(4), H / 2.0
    speaker = [(cx - u(16), cy - u(8)), (cx - u(6), cy - u(8)), (cx + u(8), cy - u(20)), (cx + u(8), cy + u(20)), (cx - u(6), cy + u(8)), (cx - u(16), cy + u(8))]
    draw.polygon(speaker, fill=SLATE_LT)
    draw.arc([cx + u(4), cy - u(12), cx + u(20), cy + u(12)], -60, 60, fill=SKY, width=u(4))
    draw.arc([cx + u(8), cy - u(20), cx + u(30), cy + u(20)], -60, 60, fill=SKY, width=u(4))
    save_icon(img, "sound_on", 96, 96)

def gen_sound_off():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0 - u(4), H / 2.0
    speaker = [(cx - u(16), cy - u(8)), (cx - u(6), cy - u(8)), (cx + u(8), cy - u(20)), (cx + u(8), cy + u(20)), (cx - u(6), cy + u(8)), (cx - u(16), cy + u(8))]
    draw.polygon(speaker, fill=SLATE_LT)
    draw_pill(draw, (cx - u(14), cy - u(16)), (cx + u(26), cy + u(18)), u(5), CORAL)
    save_icon(img, "sound_off", 96, 96)

def gen_vibrate_on():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    draw.rounded_rectangle([cx - u(14), cy - u(24), cx + u(14), cy + u(24)], radius=u(5), fill=SLATE_LT)
    draw.rounded_rectangle([cx - u(10), cy - u(18), cx + u(10), cy + u(18)], radius=u(2), fill=WHITE)
    draw.arc([cx - u(32), cy - u(16), cx - u(18), cy + u(16)], 120, 240, fill=SKY, width=u(4))
    draw.arc([cx + u(18), cy - u(16), cx + u(32), cy + u(16)], -60, 60, fill=SKY, width=u(4))
    save_icon(img, "vibrate_on", 96, 96)

def gen_vibrate_off():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    draw.rounded_rectangle([cx - u(14), cy - u(24), cx + u(14), cy + u(24)], radius=u(5), fill=SLATE_LT)
    draw.rounded_rectangle([cx - u(10), cy - u(18), cx + u(10), cy + u(18)], radius=u(2), fill=WHITE)
    draw_pill(draw, (cx - u(24), cy - u(24)), (cx + u(24), cy + u(24)), u(5), CORAL)
    save_icon(img, "vibrate_off", 96, 96)

def gen_plus():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    s = u(22)
    th = u(9)
    draw_pill(draw, (cx - s, cy), (cx + s, cy), th, MINT)
    draw_pill(draw, (cx, cy - s), (cx, cy + s), th, MINT)
    save_icon(img, "plus", 96, 96)

def gen_minus():
    img, draw, W, H = new_canvas(96, 96)
    cx, cy = W / 2.0, H / 2.0
    s = u(22)
    th = u(9)
    draw_pill(draw, (cx - s, cy), (cx + s, cy), th, CORAL)
    save_icon(img, "minus", 96, 96)

def generate_all():
    print("Generating Two Dots Flat 2.0 GUI Textures...")
    gen_white()
    gen_panel()
    gen_btn()
    gen_circle()
    gen_ring()
    gen_glow()
    
    gen_star()
    gen_star_slot()
    gen_coin()
    gen_trophy()
    gen_garage()
    gen_lock()
    
    gen_play()
    gen_stop()
    gen_retry()
    gen_next()
    gen_back()
    gen_home()
    gen_menu()
    gen_close()
    
    gen_wrench()
    gen_eraser()
    gen_trash()
    gen_undo()
    gen_fit()
    gen_hint()
    
    gen_mat_road()
    gen_mat_steel_road()
    gen_mat_wood()
    gen_mat_steel()
    gen_mat_cable()
    gen_mat_rope()
    gen_mat_boost()
    gen_mat_bounce()
    
    gen_veh_moto()
    gen_veh_car()
    gen_veh_truck()
    gen_pedal_gas()
    gen_pedal_brake()
    
    gen_check()
    gen_hand()
    gen_video()
    gen_sound_on()
    gen_sound_off()
    gen_vibrate_on()
    gen_vibrate_off()
    gen_plus()
    gen_minus()
    
    print("All 48 Two Dots GUI textures generated successfully!")

if __name__ == "__main__":
    generate_all()
