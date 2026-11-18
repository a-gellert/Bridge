"""
Two Dots Style Mountain Panorama Generator.
Renders majestic, stylized Flat 2.0 mountains with authentic Two Dots geometry.
"""
import os
import math
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BG_DIR = os.path.join(ROOT, "assets", "images", "backgrounds")
os.makedirs(BG_DIR, exist_ok=True)
OUT_PATH = os.path.join(BG_DIR, "bg_parallax_2_mountains.png")
ART_PATH = r"C:\Users\User\.gemini\antigravity\brain\ea8270cc-eea1-4b31-8c57-bd757a1a1b92\twodots_mountains_preview.png"

# Two Dots authentic mountain palette
FAR_LT = (150, 175, 195, 255)       # Pastel lavender slate left
FAR_DK = (122, 146, 166, 255)       # Pastel lavender slate right (half-tone)
SNOW_LT = (255, 255, 255, 255)      # Crisp white snow
SNOW_DK = (235, 242, 248, 255)      # Subtle shaded snow

MID_LT = (90, 140, 146, 255)        # Muted Teal left
MID_DK = (70, 115, 122, 255)        # Muted Teal right

NEAR_LT = (56, 75, 92, 255)         # Near ridge left
NEAR_DK = (42, 58, 72, 255)         # Near ridge right
PINE_COL = (28, 38, 48, 255)        # Signature Two Dots deep slate pines

SS = 2
W_FINAL = 2048
H_FINAL = 1024
W = W_FINAL * SS
H = H_FINAL * SS

def u(val):
    return int(round(val * SS))

def render():
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    
    # Baseline for mountain bases: sits at y = 680 (out of 1024)
    base_y = u(720)
    
    # --------------------------------------------------------------------------
    # 1. FAR MOUNTAINS: Wide majestic peaks with clean geometric snow caps
    # --------------------------------------------------------------------------
    far_peaks = [
        # (cx, peak_h, width)
        (u(150), u(360), u(380)),
        (u(480), u(460), u(480)),
        (u(850), u(420), u(440)),
        (u(1220), u(480), u(500)),
        (u(1580), u(390), u(420)),
        (u(1920), u(450), u(460)),
    ]
    
    for cx, ph, pw in far_peaks:
        top_y = base_y - ph
        hw = pw // 2
        # Mountain body: left & right facets
        poly_l = [(cx - hw, base_y), (cx, top_y), (cx, base_y)]
        poly_r = [(cx, top_y), (cx + hw, base_y), (cx, base_y)]
        draw.polygon(poly_l, fill=FAR_LT)
        draw.polygon(poly_r, fill=FAR_DK)
        
        # Snow cap (top 32% of height)
        sh = int(ph * 0.32)
        sy = top_y + sh
        sw = int(hw * 0.32)
        
        # Geometric 3-point zigzag base for snow cap
        p_snow_l = [
            (cx, top_y),
            (cx - sw, sy),
            (cx - int(sw * 0.6), sy - u(12)),
            (cx - int(sw * 0.3), sy + u(6)),
            (cx, sy - u(4)),
            (cx, base_y)
        ]
        p_snow_r = [
            (cx, top_y),
            (cx, sy - u(4)),
            (cx + int(sw * 0.3), sy + u(6)),
            (cx + int(sw * 0.6), sy - u(10)),
            (cx + sw, sy),
            (cx, base_y)
        ]
        draw.polygon(p_snow_l[:5], fill=SNOW_LT)
        draw.polygon(p_snow_r[:5], fill=SNOW_DK)
        
    # --------------------------------------------------------------------------
    # 2. MID MOUNTAINS: Interlocking soft teal ridges
    # --------------------------------------------------------------------------
    mid_peaks = [
        (u(0), u(280), u(340)),
        (u(300), u(340), u(380)),
        (u(660), u(310), u(360)),
        (u(1020), u(360), u(400)),
        (u(1400), u(320), u(370)),
        (u(1760), u(350), u(390)),
        (u(2048), u(290), u(340)),
    ]
    
    for cx, ph, pw in mid_peaks:
        top_y = base_y - ph
        hw = pw // 2
        draw.polygon([(cx - hw, base_y), (cx, top_y), (cx, base_y)], fill=MID_LT)
        draw.polygon([(cx, top_y), (cx + hw, base_y), (cx, base_y)], fill=MID_DK)
        
        # Snow cap on tall mid peaks
        if ph >= u(330):
            sh = int(ph * 0.22)
            sy = top_y + sh
            sw = int(hw * 0.22)
            draw.polygon([(cx, top_y), (cx - sw, sy), (cx, sy - u(6))], fill=SNOW_LT)
            draw.polygon([(cx, top_y), (cx, sy - u(6)), (cx + sw, sy)], fill=SNOW_DK)

    # --------------------------------------------------------------------------
    # 3. NEAR FOOTHILLS RIDGE (Continuous organic rolling skyline)
    # --------------------------------------------------------------------------
    # Smooth crest curve across the canvas
    crest_pts = []
    num_pts = 64
    for i in range(num_pts + 1):
        x = int(W * i / num_pts)
        # Organic rolling hills
        h_offset = math.sin(i * 0.35) * u(50) + math.cos(i * 0.8) * u(30) + math.sin(i * 1.5) * u(15)
        y = base_y - u(140) + int(h_offset)
        crest_pts.append((x, y))
        
    # Polygon for near ridge down to bottom
    near_poly = [(0, H)] + crest_pts + [(W, H)]
    draw.polygon(near_poly, fill=NEAR_DK)
    
    # --------------------------------------------------------------------------
    # 4. SIGNATURE TWO DOTS PINE TREES (Screen 2 conifer silhouette forest)
    # --------------------------------------------------------------------------
    def draw_pine(px, py, tree_h):
        tw = int(tree_h * 0.44)
        # 3 stacked sharp chevron triangles
        tier_h = int(tree_h * 0.42)
        overlap = int(tier_h * 0.32)
        
        # Bottom tier
        y0 = py
        y1 = y0 - tier_h
        draw.polygon([(px - tw, y0), (px, y1), (px + tw, y0)], fill=PINE_COL)
        # Middle tier
        tw_m = int(tw * 0.78)
        y0_m = y1 + overlap
        y1_m = y0_m - tier_h
        draw.polygon([(px - tw_m, y0_m), (px, y1_m), (px + tw_m, y0_m)], fill=PINE_COL)
        # Top tier
        tw_t = int(tw * 0.55)
        y0_t = y1_m + overlap
        y1_t = y0_t - tier_h
        draw.polygon([(px - tw_t, y0_t), (px, y1_t), (px + tw_t, y0_t)], fill=PINE_COL)

    # Walk along the crest curve and plant trees
    tree_step = u(14)
    for x in range(u(15), W - u(15), tree_step):
        # Find y on the crest curve
        idx = int((x / W) * num_pts)
        idx = max(0, min(num_pts - 1, idx))
        x0, y0 = crest_pts[idx]
        x1, y1 = crest_pts[idx + 1]
        t = (x - x0) / max(1, (x1 - x0))
        cy = y0 + (y1 - y0) * t
        
        # Clumping rhythm
        wave = math.sin(x * 0.0025) * math.cos(x * 0.006)
        if wave > -0.35:
            th = u(24) + int(u(16) * abs(math.sin(x * 0.012)))
            draw_pine(x, int(cy) + u(4), th)

    # Resize with Lanczos anti-aliasing
    final = canvas.resize((W_FINAL, H_FINAL), Image.Resampling.LANCZOS)
    final.save(OUT_PATH)
    final.save(ART_PATH)
    print("Generated authentic Two Dots mountains:", OUT_PATH)

if __name__ == "__main__":
    render()
