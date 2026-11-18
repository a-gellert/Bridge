import os
import cv2
import numpy as np
from PIL import Image

artifact_dir = r"C:\Users\User\.gemini\antigravity\brain\cbb10e65-ef8c-424f-a923-ea4880335c5b"
target_dir = r"d:\DProjects\Bridge\assets\images\backgrounds"
os.makedirs(target_dir, exist_ok=True)

img1_path = os.path.join(artifact_dir, "bg_layer1_sky_1795013853287.jpg")
img2_path = os.path.join(artifact_dir, "bg_layer2_mountains_1795013882839.jpg")
img3_path = os.path.join(artifact_dir, "bg_layer3_hills_1795013910701.jpg")

# 1. Process Layer 1: Sky
im1 = Image.open(img1_path)
im1.save(os.path.join(target_dir, "bg_parallax_1_sky.png"))
im1.save(os.path.join(artifact_dir, "bg_parallax_1_sky.png"))
print("Saved Layer 1: Sky")

# Helper to isolate sky connected to top row
def extract_cutout(img_bgr, is_sky_mask):
    h, w = img_bgr.shape[:2]
    mask = is_sky_mask.astype(np.uint8)
    num_labels, labels = cv2.connectedComponents(mask)
    top_labels = list(set(labels[0, :]))
    sky_final = np.isin(labels, top_labels)
    
    alpha = np.where(sky_final, 0, 255).astype(np.uint8)
    
    # Fill any downward holes in alpha: for each column, ensure terrain doesn't have sky underneath
    for col in range(w):
        sky_pixels = np.where(alpha[:, col] == 0)[0]
        if len(sky_pixels) > 0:
            max_sky = np.max(sky_pixels)
            # if there are isolated zeros below max_sky, they are filled
            alpha[max_sky+1:, col] = 255
            
    # Soften 1px boundary slightly for clean alpha blending
    alpha_blurred = cv2.GaussianBlur(alpha, (3, 3), 0)
    # preserve solid interior
    alpha_final = np.where(alpha == 255, np.maximum(alpha_blurred, 240), alpha_blurred)
    
    bgra = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2BGRA)
    bgra[:, :, 3] = alpha_final
    return bgra

# 2. Process Layer 2: Mountains Cutout
img2_bgr = cv2.imread(img2_path)
hsv2 = cv2.cvtColor(img2_bgr, cv2.COLOR_BGR2HSV)
H2, S2, V2 = hsv2[:, :, 0], hsv2[:, :, 1], hsv2[:, :, 2]
# Sky in layer 2 is blue (80 <= H <= 115) and saturated (S >= 70) and bright (V >= 220)
is_sky2 = (H2 >= 80) & (H2 <= 115) & (S2 >= 70) & (V2 >= 220)
layer2_cutout = extract_cutout(img2_bgr, is_sky2)
cv2.imwrite(os.path.join(target_dir, "bg_parallax_2_mountains.png"), layer2_cutout)
cv2.imwrite(os.path.join(artifact_dir, "bg_parallax_2_mountains.png"), layer2_cutout)
print("Saved Layer 2 Cutout")

# 3. Process Layer 3: Hills & Trees Cutout
img3_bgr = cv2.imread(img3_path)
hsv3 = cv2.cvtColor(img3_bgr, cv2.COLOR_BGR2HSV)
H3, S3, V3 = hsv3[:, :, 0], hsv3[:, :, 1], hsv3[:, :, 2]
# Sky in layer 3 is blue (84 <= H <= 115) and bright (V >= 220) and S > 30
is_sky3 = (H3 >= 84) & (H3 <= 115) & (V3 >= 220) & (S3 > 30)
layer3_cutout = extract_cutout(img3_bgr, is_sky3)
cv2.imwrite(os.path.join(target_dir, "bg_parallax_3_hills.png"), layer3_cutout)
cv2.imwrite(os.path.join(artifact_dir, "bg_parallax_3_hills.png"), layer3_cutout)
print("Saved Layer 3 Cutout")

# 4. Composite Previews
h, w = img1_bgr = cv2.imread(img1_path).shape[:2]
im_sky = Image.open(os.path.join(target_dir, "bg_parallax_1_sky.png")).convert("RGBA")
im_mount = Image.open(os.path.join(target_dir, "bg_parallax_2_mountains.png")).convert("RGBA")
im_hills = Image.open(os.path.join(target_dir, "bg_parallax_3_hills.png")).convert("RGBA")

# Composite A: Standard composite
comp = Image.new("RGBA", (w, h))
comp.paste(im_sky, (0, 0))
comp.paste(im_mount, (0, 0), im_mount)
comp.paste(im_hills, (0, 0), im_hills)
comp.convert("RGB").save(os.path.join(target_dir, "bg_parallax_composite.png"))
comp.convert("RGB").save(os.path.join(artifact_dir, "bg_parallax_composite.png"))
print("Saved Composite")

# Composite B: Parallax shift demonstration (simulating camera pan)
def roll_image(img, shift_x):
    arr = np.array(img)
    rolled = np.roll(arr, shift_x, axis=1)
    return Image.fromarray(rolled)

shift_comp = Image.new("RGBA", (w, h))
shift_comp.paste(roll_image(im_sky, -40), (0, 0))
mount_shifted = roll_image(im_mount, -140)
shift_comp.paste(mount_shifted, (0, 0), mount_shifted)
hills_shifted = roll_image(im_hills, -280)
shift_comp.paste(hills_shifted, (0, 0), hills_shifted)

shift_comp.convert("RGB").save(os.path.join(target_dir, "bg_parallax_shifted_demo.png"))
shift_comp.convert("RGB").save(os.path.join(artifact_dir, "bg_parallax_shifted_demo.png"))
print("Saved Parallax Shifted Demo")
