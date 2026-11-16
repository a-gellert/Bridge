"""
Render hero-model previews with the Blender studio (see studio.py).

    "D:/Programs/Blender/blender.exe" -b -P tools/blender/render_previews.py -- --only tree_blossom,portal_blue
    "D:/Programs/Blender/blender.exe" -b -P tools/blender/render_previews.py -- --size 1200 --samples 96

Output: build/blender_previews/<model>.png. Each model gets its own 3/4 camera so the
silhouette that matters in game is the one facing the lens.
"""

import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDIO_PY = Path(__file__).with_name("studio.py")
OUT = ROOT / "build" / "blender_previews"
MODELS = ROOT / "assets" / "models"

# direction = camera offset from the subject center (Blender axes, -Y is the model front)
VIEWS = {
    "tree_blossom": (0.62, -1.0, 0.3),
    "pine_tall": (0.55, -1.0, 0.22),
    "rock_arch": (0.36, -1.0, 0.24),
    "ruin_arch": (0.36, -1.0, 0.26),
    "crystal_cluster": (0.7, -1.0, 0.45),
    "windmill": (0.78, -1.0, 0.3),
    "windmill_blades": (0.34, -1.0, 0.22),
    "bird": (0.22, -1.0, 0.45),
    "butterfly": (0.28, -1.0, 0.55),
    "portal_blue": (1.0, -0.72, 0.3),
    "portal_orange": (1.0, -0.72, 0.3),
    "lab_generator": (0.8, -1.0, 0.45),
    "lab_terminal": (0.85, -1.0, 0.3),
    "energy_pylon": (0.62, -1.0, 0.3),
    "chamber_sign": (0.22, -1.0, 0.14),
    "cactus_saguaro": (0.5, -1.0, 0.18),
    "lantern_post": (0.85, -1.0, 0.3),
}


def parse_args(argv):
    opts = {"only": None, "size": 900, "samples": 64}
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    it = iter(argv)
    for arg in it:
        if arg == "--only":
            opts["only"] = {n.strip() for n in next(it, "").split(",") if n.strip()}
        elif arg == "--size":
            opts["size"] = int(next(it))
        elif arg == "--samples":
            opts["samples"] = int(next(it))
    return opts


def main():
    opts = parse_args(sys.argv)
    studio = runpy.run_path(str(STUDIO_PY), run_name="studio")
    OUT.mkdir(parents=True, exist_ok=True)

    names = [n for n in VIEWS if opts["only"] is None or n in opts["only"]]
    for name in names:
        glb = MODELS / (name + ".glb")
        if not glb.exists():
            print(f"[preview] skip {name}: {glb} missing")
            continue
        png = OUT / (name + ".png")
        studio["showcase"](glb, png, size=opts["size"], samples=opts["samples"],
                           direction=VIEWS[name])
        print(f"[preview] {name} -> {png}")
    print(f"[preview] {len(names)} model(s) rendered")


if __name__ == "__main__":
    main()
