"""
Process UI icons from generated Nano Banana sheets into Defold assets/images/ui/*.png
Uses PIL and numpy for smart background removal, trimming, centering, and sizing.
"""
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UI_DIR = os.path.join(ROOT, "assets", "images", "ui")

def remove_background(img_rgb, bg_color=None, threshold=28, softness=18):
    """
    Remove dark/solid background using Euclidean color distance with smooth alpha falloff.
    """
    arr = np.array(img_rgb).astype(np.float32)
    h, w, _ = arr.shape
    
    if bg_color is None:
        # Sample corners
        corners = np.array([arr[0, 0], arr[0, -1], arr[-1, 0], arr[-1, -1]])
        bg_color = np.median(corners, axis=0)
    
    # Distance from background color
    diff = arr - bg_color
    dist = np.sqrt(np.sum(diff * diff, axis=2))
    
    # Alpha mask: 0 when dist <= threshold, 1 when dist >= threshold + softness
    alpha = np.clip((dist - threshold) / max(softness, 1.0), 0.0, 1.0) * 255.0
    alpha = alpha.astype(np.uint8)
    
    rgba = np.dstack([arr.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")

def find_sub_regions(img_rgba, cols, rows, pad_ratio=0.06):
    """
    Divide image into regular grid cells and auto-trim transparent margins for each cell.
    """
    w, h = img_rgba.size
    cw = w / cols
    ch = h / rows
    
    cells = []
    for r in range(rows):
        for c in range(cols):
            x0 = int(c * cw + cw * pad_ratio)
            x1 = int((c + 1) * cw - cw * pad_ratio)
            y0 = int(r * ch + ch * pad_ratio)
            y1 = int((r + 1) * ch - ch * pad_ratio)
            
            sub = img_rgba.crop((x0, y0, x1, y1))
            
            # Trim transparent pixels within cell
            bbox = sub.getbbox()
            if bbox:
                sub = sub.crop(bbox)
            cells.append(sub)
    return cells

def fit_into(img, target_w, target_h, pad=4):
    """
    Scale aspect-correctly to fit inside target_w x target_h with padding, centered.
    """
    max_w = target_w - pad * 2
    max_h = target_h - pad * 2
    
    sw, sh = img.size
    scale = min(max_w / sw, max_h / sh)
    nw = max(1, int(sw * scale))
    nh = max(1, int(sh * scale))
    
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    
    canvas = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    px = (target_w - nw) // 2
    py = (target_h - nh) // 2
    canvas.paste(resized, (px, py), resized)
    return canvas

def process_sheet(sheet_path, names, cols, rows, target_w=96, target_h=96, pad=6):
    print(f"Processing sheet: {sheet_path}")
    raw = Image.open(sheet_path).convert("RGB")
    rgba = remove_background(raw)
    cells = find_sub_regions(rgba, cols, rows)
    
    for i, name in enumerate(names):
        if i >= len(cells):
            break
        cell = cells[i]
        out_img = fit_into(cell, target_w, target_h, pad=pad)
        out_path = os.path.join(UI_DIR, f"{name}.png")
        out_img.save(out_path)
        print(f"  -> Saved {name}.png ({target_w}x{target_h})")

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python process_ui_icons.py <sheet_path> <cols> <rows> <name1,name2,...> [target_w] [target_h] [pad]")
        sys.exit(1)
        
    sheet_p = sys.argv[1]
    cols = int(sys.argv[2])
    rows = int(sys.argv[3])
    names = sys.argv[4].split(",")
    tw = int(sys.argv[5]) if len(sys.argv) > 5 else 96
    th = int(sys.argv[6]) if len(sys.argv) > 6 else 96
    pad = int(sys.argv[7]) if len(sys.argv) > 7 else 6
    
    process_sheet(sheet_p, names, cols, rows, tw, th, pad)
