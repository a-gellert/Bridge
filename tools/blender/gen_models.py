"""
Blender-authored decor and portal models for Bridge Mad.

Run:
    "D:/Programs/Blender/blender.exe" -b -P tools/blender/gen_models.py

The script builds low-poly, flat-shaded meshes with palette UVs (one texel per face)
and exports one self-contained .glb per model into assets/models/.

The game's Defold material supplies the palette texture. Materials are deliberately not
exported: Defold's model component overrides the material slot, exactly like the procedural
JS models.

Art direction: every hard-surface block is chamfered (the Drive Mad / Bridge Constructor
look) so edges catch a highlight texel, silhouettes get extra layers (strata, belts,
bolts, pipes) and organic shapes are built from several offset blobs instead of one.
"""

import bpy
import bmesh
import json
import math
import os
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "models"
PALETTE = json.loads((ROOT / "tools" / "gen" / "palette.json").read_text(encoding="utf-8"))

# Bevel faces take the lighter neighbour of the base color, so chamfers read as edge light.
LIGHTEN = {
    "white": "white",
    "base_hi": "white", "base": "base_hi", "base_lo": "base", "base_dk": "base_lo",
    "asphalt": "asphalt_lt", "asphalt_lt": "curb", "asphalt_dk": "asphalt",
    "lane": "lane_w", "lane_w": "white", "curb": "curb", "curb_red": "curb",
    "wood": "wood_lt", "wood_lt": "wood_end", "wood_dk": "wood", "wood_end": "wood_lt",
    "wood_grain": "wood",
    "steel": "steel_lt", "steel_dk": "steel", "steel_lt": "steel_edge", "steel_edge": "steel_lt",
    "steelroad": "steelroad_lt", "steelroad_lt": "lane", "steelroad_dk": "steelroad",
    "rope": "rope_lt", "rope_dk": "rope", "cable": "cable_lt", "cable_dk": "cable",
    "boost": "boost_lt", "boost_dk": "boost", "bounce": "bounce_lt", "bounce_dk": "bounce",
    "bolt": "bolt_lt", "bolt_dk": "bolt", "anchor": "anchor_lt", "anchor_dk": "anchor",
    "truck": "truck_lt", "truck_dk": "truck", "car": "car_lt", "car_dk": "car",
    "moto": "moto_lt", "moto_dk": "moto", "cargo": "cargo_lt", "cargo_lt": "base_lo", "cargo_dk": "cargo",
    "chrome": "white", "chrome_dk": "chrome", "black": "cargo_dk", "rubber": "black",
    "tire": "tire_lt", "rim": "chrome", "rim_dk": "rim",
    "portal_b": "portal_b_lt", "portal_b_lt": "white", "portal_b_dk": "portal_b",
    "portal_o": "portal_o_lt", "portal_o_lt": "white", "portal_o_dk": "portal_o",
    "trunk": "trunk_lt", "trunk_dk": "trunk", "trunk_lt": "wood_end",
    "leaf": "leaf_lt", "leaf_dk": "leaf", "leaf_lt": "leaf", "pine": "pine_lt", "pine_dk": "pine",
    "pine_lt": "leaf_lt",
    "flower_r": "white", "flower_y": "white", "flower_w": "white", "flower_b": "white",
    "stem": "leaf", "snow": "white", "cloud": "white", "cloud_sh": "cloud",
    "rock": "rock_lt", "rock_lt": "base", "rock_dk": "rock",
    "lab_panel": "lab_line", "lab_line": "lab_light", "lab_light": "white", "lab_dark": "lab_panel",
    "hazard": "lane", "light": "white", "glass": "glass_lt", "glass_dk": "glass", "glass_lt": "white",
    "flag_w": "white", "flag_k": "black", "flag_g": "lane", "pole": "chrome",
    "water": "water_lt", "water_dk": "water", "water_lt": "foam",
}


def lighten(color):
    seen = set()
    while color in LIGHTEN and color not in seen:
        seen.add(color)
        color = LIGHTEN[color]
    return color


def uv(name):
    if name not in PALETTE:
        raise KeyError("unknown palette color: " + name)
    return float(PALETTE[name]["uv"][0]), float(PALETTE[name]["uv"][1])


def jit(seed, amount):
    return (random.Random(seed).random() - 0.5) * 2.0 * amount


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.colors = []

    # -- helpers
    def _c(self, colors):
        if isinstance(colors, str):
            d = {k: colors for k in ("side", "front", "back", "top", "bottom")}
        else:
            d = dict(colors)
            base = d.get("side") or d.get("front") or d.get("top") or d.get("back") or d.get("bottom")
            for key in ("side", "front", "back", "top", "bottom"):
                d.setdefault(key, base)
        d.setdefault("bevel", lighten(d["side"]))
        return d

    def mesh(self, pts, faces, colors):
        base = len(self.verts)
        self.verts.extend(pts)
        for face, color in zip(faces, colors):
            self.faces.append(tuple(base + i for i in face))
            self.colors.append(color)
        return self

    # -- primitives
    def poly(self, pts, color):
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(base, base + len(pts))))
        self.colors.append(color)
        return self

    def tri(self, a, b, c, color):
        return self.poly([a, b, c], color)

    def box(self, x0, y0, z0, x1, y1, z1, colors):
        c = self._c(colors)
        v = [
            (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
            (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
        ]
        self.poly([v[0], v[1], v[5], v[4]], c["front"])   # -Y (towards camera)
        self.poly([v[2], v[3], v[7], v[6]], c["back"])    # +Y
        self.poly([v[1], v[2], v[6], v[5]], c["side"])    # +X
        self.poly([v[3], v[0], v[4], v[7]], c["side"])    # -X
        self.poly([v[4], v[5], v[6], v[7]], c["top"])     # +Z
        self.poly([v[3], v[2], v[1], v[0]], c["bottom"])  # -Z
        return self

    def chamfer_box(self, x0, y0, z0, x1, y1, z1, colors, bevel=0.045, rot_y=0.0):
        """Axis-aligned (optionally Y-rotated) block with 12 chamfered edges + 8 cut corners.

        26 flat faces keep the palette look while every edge picks up a highlight texel,
        which is what makes the Drive Mad voxel props read as solid objects.
        """
        c = self._c(colors)
        cx, cy, cz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
        hx, hy, hz = (x1 - x0) * 0.5, (y1 - y0) * 0.5, (z1 - z0) * 0.5
        b = min(bevel, hx * 0.45, hy * 0.45, hz * 0.45)
        if b <= 1e-5:
            ca, sa = (math.cos(rot_y), math.sin(rot_y)) if rot_y else (1.0, 0.0)
            pts = []
            for sz in (-1, 1):
                for sy in (-1, 1):
                    for sx in (-1, 1):
                        px, py, pz = sx * hx, sy * hy, sz * hz
                        if rot_y:
                            px, pz = px * ca + pz * sa, -px * sa + pz * ca
                        pts.append((cx + px, cy + py, cz + pz))
            # index order: (-x,-y,-z), (+x,-y,-z), (-x,+y,-z), (+x,+y,-z), then +z
            faces = [
                (0, 1, 3, 2), (4, 6, 7, 5),
                (0, 4, 5, 1), (2, 3, 7, 6),
                (0, 2, 6, 4), (1, 5, 7, 3),
            ]
            cols = [c["bottom"], c["top"], c["front"], c["back"], c["side"], c["side"]]
            return self.mesh(pts, faces, cols)

        ex, ey, ez = hx - b, hy - b, hz - b
        ca, sa = (math.cos(rot_y), math.sin(rot_y)) if rot_y else (1.0, 0.0)
        pts, index = [], {}

        def vkey(sx, sy, sz, kind):
            nonlocal pts
            key = (sx, sy, sz, kind)
            if key in index:
                return index[key]
            if kind == "x":
                p = (sx * hx, sy * ey, sz * ez)
            elif kind == "y":
                p = (sx * ex, sy * hy, sz * ez)
            else:
                p = (sx * ex, sy * ey, sz * hz)
            if rot_y:
                p = (p[0] * ca + p[2] * sa, p[1], -p[0] * sa + p[2] * ca)
            index[key] = len(pts)
            pts.append((cx + p[0], cy + p[1], cz + p[2]))
            return index[key]

        faces, cols = [], []
        for sx in (-1, 1):
            faces.append([vkey(sx, sy, sz, "x") for sy, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
            cols.append(c["side"])
        for sy in (-1, 1):
            faces.append([vkey(sx, sy, sz, "y") for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
            cols.append(c["back"] if sy > 0 else c["front"])
        for sz in (-1, 1):
            faces.append([vkey(sx, sy, sz, "z") for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
            cols.append(c["top"] if sz > 0 else c["bottom"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                faces.append([vkey(sx, sy, -1, "x"), vkey(sx, sy, 1, "x"),
                              vkey(sx, sy, 1, "y"), vkey(sx, sy, -1, "y")])
                cols.append(c["bevel"])
        for sy in (-1, 1):
            for sz in (-1, 1):
                faces.append([vkey(-1, sy, sz, "y"), vkey(1, sy, sz, "y"),
                              vkey(1, sy, sz, "z"), vkey(-1, sy, sz, "z")])
                cols.append(c["bevel"])
        for sx in (-1, 1):
            for sz in (-1, 1):
                faces.append([vkey(sx, -1, sz, "x"), vkey(sx, 1, sz, "x"),
                              vkey(sx, 1, sz, "z"), vkey(sx, -1, sz, "z")])
                cols.append(c["bevel"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    faces.append([vkey(sx, sy, sz, "x"), vkey(sx, sy, sz, "y"), vkey(sx, sy, sz, "z")])
                    cols.append(c["bevel"])
        return self.mesh(pts, faces, cols)

    def cbox_c(self, cx, cy, cz, sx, sy, sz, colors, bevel=0.045, rot_y=0.0):
        return self.chamfer_box(cx - sx / 2, cy - sy / 2, cz - sz / 2,
                                cx + sx / 2, cy + sy / 2, cz + sz / 2, colors, bevel, rot_y)

    def box_c(self, cx, cy, cz, sx, sy, sz, colors):
        return self.box(cx - sx / 2, cy - sy / 2, cz - sz / 2, cx + sx / 2, cy + sy / 2, cz + sz / 2, colors)

    def rot_box_y(self, cx, cy, cz, sx, sy, sz, angle, colors):
        """Box rotated around the Y axis (arch voussoirs live in the X-Z plane)."""
        return self.cbox_c(cx, cy, cz, sx, sy, sz, colors, bevel=0.0, rot_y=angle)

    def prism_z(self, pts, z0, z1, colors):
        """Convex polygon in X-Y extruded along Z (sun discs, butterfly wings)."""
        c = self._c(colors)
        n = len(pts)
        cx = sum(p[0] for p in pts) / n
        cy = sum(p[1] for p in pts) / n
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            self.poly([(cx, cy, z1), (b[0], b[1], z1), (a[0], a[1], z1)], c.get("top"))
            self.poly([(cx, cy, z0), (a[0], a[1], z0), (b[0], b[1], z0)], c.get("bottom"))
            self.poly([(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], c.get("side"))
        return self

    def frustum(self, cx, cy, z0, z1, r0, r1, seg, colors, angle0=0.0, cap0=True, cap1=True):
        c = self._c(colors)
        side = c.get("side") or c.get("top")
        top = c.get("top") or side
        bottom = c.get("bottom") or side
        ring0, ring1 = [], []
        for i in range(seg):
            a = angle0 + (i / seg) * math.pi * 2
            ring0.append((cx + math.cos(a) * r0, cy + math.sin(a) * r0, z0))
            ring1.append((cx + math.cos(a) * r1, cy + math.sin(a) * r1, z1))
        for i in range(seg):
            j = (i + 1) % seg
            self.poly([ring0[i], ring0[j], ring1[j], ring1[i]], side)
        if cap0:
            for i in range(seg):
                j = (i + 1) % seg
                self.tri((cx, cy, z0), ring0[j], ring0[i], bottom)
        if cap1:
            for i in range(seg):
                j = (i + 1) % seg
                self.tri((cx, cy, z1), ring1[i], ring1[j], top)
        return self

    def disc(self, cx, cy, z, r, seg, colors, angle0=0.0):
        c = self._c(colors)
        ring = [(cx + math.cos(angle0 + i / seg * math.pi * 2) * r,
                 cy + math.sin(angle0 + i / seg * math.pi * 2) * r, z) for i in range(seg)]
        for i in range(seg):
            j = (i + 1) % seg
            self.tri((cx, cy, z), ring[i], ring[j], c.get("top"))
        return self

    def tube(self, p0, p1, r0, r1, seg, colors, cap0=True, cap1=True):
        """Cylinder/tapered trunk between two arbitrary points (branches, crystals)."""
        c = self._c(colors)
        side = c.get("side") or c.get("top")
        top = c.get("top") or side
        bottom = c.get("bottom") or side
        ax = [p1[i] - p0[i] for i in range(3)]
        length = math.sqrt(sum(v * v for v in ax)) or 1.0
        ax = [v / length for v in ax]
        up = [0, 0, 1] if abs(ax[2]) < 0.9 else [0, 1, 0]
        u = [ax[1] * up[2] - ax[2] * up[1], ax[2] * up[0] - ax[0] * up[2], ax[0] * up[1] - ax[1] * up[0]]
        ul = math.sqrt(sum(v * v for v in u)) or 1.0
        u = [v / ul for v in u]
        v = [ax[1] * u[2] - ax[2] * u[1], ax[2] * u[0] - ax[0] * u[2], ax[0] * u[1] - ax[1] * u[0]]
        ring0, ring1 = [], []
        for i in range(seg):
            a = (i / seg) * math.pi * 2
            ox, oy = math.cos(a) * r0, math.sin(a) * r0
            ring0.append((p0[0] + u[0] * ox + v[0] * oy, p0[1] + u[1] * ox + v[1] * oy, p0[2] + u[2] * ox + v[2] * oy))
            ox, oy = math.cos(a) * r1, math.sin(a) * r1
            ring1.append((p1[0] + u[0] * ox + v[0] * oy, p1[1] + u[1] * ox + v[1] * oy, p1[2] + u[2] * ox + v[2] * oy))
        for i in range(seg):
            j = (i + 1) % seg
            self.poly([ring0[i], ring0[j], ring1[j], ring1[i]], side)
        if cap0:
            self.poly(list(reversed(ring0)), bottom)
        if cap1:
            self.poly(ring1, top)
        return self

    def blob(self, cx, cy, cz, rx, ry, rz, seg, rings, colors, seed=1, jitter=0.12):
        c = self._c(colors)
        rnd = random.Random(seed)
        rows = []
        for iy in range(1, rings):
            theta = math.pi * iy / rings
            sr = math.sin(theta)
            z = cz + math.cos(theta) * rz
            row = []
            for ix in range(seg):
                a = 2 * math.pi * ix / seg
                k = 1.0 + (rnd.random() - 0.5) * jitter
                row.append((cx + math.cos(a) * sr * rx * k, cy + math.sin(a) * sr * ry * k, z))
            rows.append(row)
        top = (cx, cy, cz + rz)
        bottom = (cx, cy, cz - rz)
        for ix in range(seg):
            j = (ix + 1) % seg
            self.tri(top, rows[0][j], rows[0][ix], c.get("top") or c.get("side"))
            self.tri(bottom, rows[-1][ix], rows[-1][j], c.get("bottom") or c.get("side"))
        for iy in range(len(rows) - 1):
            for ix in range(seg):
                j = (ix + 1) % seg
                nz = (rows[iy][ix][2] + rows[iy + 1][ix][2]) * 0.5 - cz
                col = c.get("top") if nz > rz * 0.18 else (c.get("bottom") if nz < -rz * 0.18 else c.get("side"))
                self.poly([rows[iy][ix], rows[iy][j], rows[iy + 1][j], rows[iy + 1][ix]], col)
        return self

    def ring(self, cx, cy, z0, z1, r_in, r_out, seg, colors):
        """Hollow drum (rings around reactor cores, mill platforms)."""
        c = self._c(colors)
        for i in range(seg):
            a0 = i / seg * math.pi * 2
            a1 = (i + 1) / seg * math.pi * 2
            ca0, sa0, ca1, sa1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
            self.poly([(cx + ca0 * r_in, cy + sa0 * r_in, z0), (cx + ca1 * r_in, cy + sa1 * r_in, z0),
                       (cx + ca1 * r_out, cy + sa1 * r_out, z0), (cx + ca0 * r_out, cy + sa0 * r_out, z0)],
                      c.get("bottom"))
            self.poly([(cx + ca0 * r_in, cy + sa0 * r_in, z1), (cx + ca0 * r_out, cy + sa0 * r_out, z1),
                       (cx + ca1 * r_out, cy + sa1 * r_out, z1), (cx + ca1 * r_in, cy + sa1 * r_in, z1)],
                      c.get("top"))
            self.poly([(cx + ca0 * r_in, cy + sa0 * r_in, z0), (cx + ca0 * r_in, cy + sa0 * r_in, z1),
                       (cx + ca1 * r_in, cy + sa1 * r_in, z1), (cx + ca1 * r_in, cy + sa1 * r_in, z0)],
                      c.get("inner") or c.get("side"))
            self.poly([(cx + ca0 * r_out, cy + sa0 * r_out, z0), (cx + ca1 * r_out, cy + sa1 * r_out, z0),
                       (cx + ca1 * r_out, cy + sa1 * r_out, z1), (cx + ca0 * r_out, cy + sa0 * r_out, z1)],
                      c.get("side"))
        return self

    def arch_ring(self, rx0, rz0, rx1, rz1, y0, y1, segs, colors, start_angle=0.0, end_angle=math.pi * 2, cx=0.0, cz=0.0):
        """Continuous polygonal ring / arch in X-Z plane extruded along Y."""
        c = self._c(colors)
        front = c.get("front")
        back = c.get("back")
        inner = c.get("inner") or c.get("side")
        outer = c.get("outer") or c.get("side")
        n = segs
        step = (end_angle - start_angle) / n
        for i in range(n):
            a0 = start_angle + i * step
            a1 = start_angle + (i + 1) * step
            ca0, sa0 = math.cos(a0), math.sin(a0)
            ca1, sa1 = math.cos(a1), math.sin(a1)
            p_in0_f = (cx + ca0 * rx0, y0, cz + sa0 * rz0)
            p_in1_f = (cx + ca1 * rx0, y0, cz + sa1 * rz0)
            p_out0_f = (cx + ca0 * rx1, y0, cz + sa0 * rz1)
            p_out1_f = (cx + ca1 * rx1, y0, cz + sa1 * rz1)
            p_in0_b = (cx + ca0 * rx0, y1, cz + sa0 * rz0)
            p_in1_b = (cx + ca1 * rx0, y1, cz + sa1 * rz0)
            p_out0_b = (cx + ca0 * rx1, y1, cz + sa0 * rz1)
            p_out1_b = (cx + ca1 * rx1, y1, cz + sa1 * rz1)
            self.poly([p_in0_f, p_out0_f, p_out1_f, p_in1_f], front)
            self.poly([p_in0_b, p_in1_b, p_out1_b, p_out0_b], back)
            self.poly([p_in0_f, p_in1_f, p_in1_b, p_in0_b], inner)
            self.poly([p_out0_f, p_out0_b, p_out1_b, p_out1_f], outer)
        return self


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def export(name, b):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(b.verts, [], b.faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly, color in zip(mesh.polygons, b.colors):
        poly.use_smooth = False
        u, v = uv(color)
        # Blender's UV origin is bottom-left; the glTF exporter flips V. Pre-flip here so the
        # exported TEXCOORD_0 matches the palette cell used by the JS models and Defold.
        for li in poly.loop_indices:
            uv_layer.data[li].uv = (u, 1.0 - v)

    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)

    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_yup=True,
        use_selection=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="NONE",
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    xs = [p[0] for p in b.verts]
    ys = [p[1] for p in b.verts]
    zs = [p[2] for p in b.verts]
    print(
        f"[blender] {name}: {len(b.verts)} verts, {len(b.faces)} faces, "
        f"bounds x[{min(xs):.2f},{max(xs):.2f}] y[{min(ys):.2f},{max(ys):.2f}] z[{min(zs):.2f},{max(zs):.2f}]"
    )


# --------------------------------------------------------------------------- models
def tree_blossom():
    """Blossom tree: flared root, two-branch trunk and a layered low-poly crown."""
    b = Builder()
    b.frustum(0, 0, 0.0, 0.34, 0.46, 0.3, 8, {"side": "trunk_dk", "top": "trunk", "bottom": "trunk_dk"})
    b.tube((0, 0, 0.25), (0.05, 0.02, 2.3), 0.29, 0.15, 8,
           {"side": "trunk", "top": "trunk_lt", "bottom": "trunk_dk"})

    branches = (
        ((0.03, 0.0, 1.55), (0.85, 0.26, 2.22), 0.13, 0.075, "trunk"),
        ((0.0, 0.0, 1.7), (-0.82, -0.16, 2.3), 0.13, 0.075, "trunk_dk"),
        ((0.0, 0.03, 1.92), (0.26, 0.72, 2.55), 0.11, 0.06, "trunk"),
        ((-0.02, 0.0, 2.0), (-0.3, -0.66, 2.5), 0.11, 0.06, "trunk"),
        ((0.04, 0.0, 2.1), (0.12, 0.2, 2.72), 0.1, 0.055, "trunk_lt"),
    )
    for p0, p1, r0, r1, col in branches:
        b.tube(p0, p1, r0, r1, 6, {"side": col, "top": "trunk_lt", "bottom": "trunk_dk"})

    crown = (
        (0.0, 0.0, 2.48, 0.8, 0.74, 0.62, "leaf", 8, 4),
        (-0.78, -0.14, 2.1, 0.52, 0.48, 0.42, "leaf_dk", 6, 3),
        (0.74, 0.18, 2.22, 0.5, 0.46, 0.4, "leaf", 6, 3),
        (0.16, -0.66, 2.0, 0.48, 0.44, 0.38, "leaf_dk", 6, 3),
        (-0.2, 0.64, 2.04, 0.46, 0.44, 0.38, "leaf", 6, 3),
        (0.08, 0.06, 2.9, 0.54, 0.5, 0.44, "leaf_lt", 7, 3),
        (-0.5, 0.44, 2.58, 0.3, 0.28, 0.24, "leaf", 5, 3),
        (0.52, -0.44, 2.54, 0.32, 0.3, 0.26, "leaf_lt", 5, 3),
    )
    for i, (x, y, z, rx, ry, rz, col, seg, rings) in enumerate(crown):
        b.blob(x, y, z, rx, ry, rz, seg, rings,
               {"side": col, "top": "leaf_lt", "bottom": "leaf_dk"}, seed=11 + i)

    blossoms = (
        (0.62, -0.5, 2.5, "flower_r"), (-0.66, 0.24, 2.5, "flower_w"),
        (0.28, 0.62, 2.62, "flower_y"), (-0.34, -0.6, 2.2, "flower_r"),
        (0.86, 0.1, 2.16, "flower_w"), (-0.8, -0.28, 2.02, "flower_y"),
        (0.06, -0.3, 2.98, "flower_w"), (0.4, 0.16, 3.1, "flower_r"),
        (-0.22, 0.06, 3.18, "flower_y"),
    )
    for i, (x, y, z, col) in enumerate(blossoms):
        b.blob(x * 1.08, y * 1.08, z + 0.02, 0.18, 0.17, 0.15, 5, 3,
               {"side": col, "top": "white", "bottom": col}, seed=40 + i, jitter=0.25)
    return b


def pine_tall():
    """Tall conifer: tapered trunk, six alternating tiers, snow on the crown."""
    b = Builder()
    b.frustum(0, 0, 0.0, 0.3, 0.34, 0.26, 8, {"side": "trunk_dk", "top": "trunk", "bottom": "trunk_dk"})
    b.tube((0, 0, 0.2), (0.02, 0.0, 4.55), 0.25, 0.1, 8,
           {"side": "trunk", "top": "trunk_lt", "bottom": "trunk_dk"})

    tiers = (
        (0.95, 1.7, 1.5, 0.92, 0.06),
        (1.58, 2.3, 1.32, 0.8, -0.05),
        (2.12, 2.82, 1.14, 0.68, 0.08),
        (2.6, 3.28, 0.96, 0.56, -0.07),
        (3.04, 3.7, 0.76, 0.44, 0.05),
        (3.42, 4.08, 0.56, 0.3, -0.04),
        (3.78, 4.34, 0.38, 0.12, 0.03),
    )
    for i, (z0, z1, r0, r1, lean) in enumerate(tiers):
        side = "pine" if i % 2 == 0 else "pine_dk"
        top = "pine_lt" if i % 2 == 0 else "pine"
        seg = 8
        # dark underside skirt makes the tiers read separately in game
        b.frustum(lean * 0.4, 0, z0, z0 + 0.16, r0 * 0.96, r0 * 0.8, seg,
                  {"side": "pine_dk", "top": "pine_dk", "bottom": "pine_dk"}, angle0=0.2 * i)
        b.frustum(lean, 0, z0 + 0.12, z1, r0, r1, seg,
                  {"side": side, "top": top, "bottom": "pine_dk"}, angle0=0.2 * i)
        if i >= 2:
            # snow blanket capping the tier tip
            b.frustum(lean, 0, z1 - 0.03, z1 + 0.14, r1 + 0.04, r1 * 0.32, seg,
                      {"side": "snow", "top": "snow", "bottom": "snow"}, angle0=0.2 * i, cap0=False)
    b.tube((0, 0, 4.24), (0, 0, 4.95), 0.14, 0.015, 7, {"side": "pine_lt", "top": "pine_lt", "bottom": "pine"})
    return b


def rock_arch():
    """Weathered stone arch: stacked strata legs, chamfered voussoirs, rubble base."""
    b = Builder()
    for sx in (-1, 1):
        x = sx * 2.15
        for i in range(5):
            z0 = i * 0.58
            w = 1.06 - i * 0.055
            d = 1.32 - i * 0.05
            off = jit(i * 7 + sx, 0.06) + 0.05 * math.sin(i * 2.1 + sx)
            b.cbox_c(x + off, jit(i + sx * 3, 0.04), z0 + 0.29, w, d, 0.6,
                     {"side": "base", "front": "base_hi", "back": "base_dk",
                      "top": "base_lo", "bottom": "base_dk"}, bevel=0.06)
            # thin strata seams
            b.cbox_c(x + off, 0, z0 + 0.53, w * 1.03, d * 1.01, 0.06,
                     {"side": "base_dk", "front": "base_lo", "back": "base_dk",
                      "top": "base_lo", "bottom": "base_dk"}, bevel=0.02)

    seg = 9
    for i in range(seg):
        a = (i + 0.5) / seg * math.pi
        cx = math.cos(a) * 2.18
        cz = 2.06 + math.sin(a) * 2.3
        b.cbox_c(cx, jit(i, 0.04), cz, 0.98, 1.2, 0.86, 
                 {"side": "base", "front": "base_hi", "back": "base_dk",
                  "top": "base_hi", "bottom": "base_dk"}, bevel=0.07, rot_y=-a)

    b.blob(0.12, 0.0, 4.42, 1.0, 0.95, 0.52, 7, 3,
           {"side": "base", "top": "base_hi", "bottom": "base_dk"}, seed=31)
    b.blob(-0.55, 0.3, 4.55, 0.55, 0.5, 0.34, 6, 3,
           {"side": "base_lo", "top": "base", "bottom": "base_dk"}, seed=34)
    b.blob(-2.4, 0.36, 0.4, 1.05, 0.95, 0.55, 7, 3,
           {"side": "base_lo", "top": "base", "bottom": "base_dk"}, seed=32)
    b.blob(2.3, -0.34, 0.44, 1.14, 1.0, 0.62, 7, 3,
           {"side": "base", "top": "base_hi", "bottom": "base_dk"}, seed=33)
    for i, (x, z, rx) in enumerate(((-1.5, 0.18, 0.42), (1.05, 0.2, 0.34), (2.0, 0.16, 0.3), (-0.6, 0.14, 0.26))):
        b.blob(x, 0.72, z, rx, rx * 0.8, rx * 0.5, 5, 3,
               {"side": "base_dk", "top": "base_lo", "bottom": "base_dk"}, seed=50 + i)
    for x, z in ((-2.2, 2.35), (2.15, 2.5), (-1.45, 4.2), (0.95, 4.55)):
        b.cbox_c(x, -0.6, z, 0.5, 0.1, 0.14, "leaf_dk", bevel=0.02)
        b.cbox_c(x + 0.16, -0.62, z + 0.16, 0.24, 0.08, 0.1, "leaf", bevel=0.015)
    return b


def ruin_arch():
    """Collapsed test-ruin: carved columns, broken keystone, fallen blocks, vines."""
    b = Builder()
    for sx in (-1, 1):
        x = sx * 1.85
        b.cbox_c(x, 0, 0.14, 1.02, 1.12, 0.28,
                 {"side": "base_lo", "front": "base", "back": "base_dk",
                  "top": "base_hi", "bottom": "base_dk"}, bevel=0.04)
        for i in range(5):
            z0 = 0.28 + i * 0.56
            b.cbox_c(x, 0, z0 + 0.27, 0.74, 0.88, 0.54,
                     {"side": "base_lo", "front": "base_hi", "back": "base_dk",
                      "top": "base", "bottom": "base_dk"}, bevel=0.05)
            # carved band on the outward face
            b.cbox_c(x, -0.46, z0 + 0.27, 0.42, 0.05, 0.12, "base", bevel=0.015)
        b.cbox_c(x, 0, 3.0, 1.0, 1.06, 0.2,
                 {"side": "base", "front": "base_hi", "back": "base_dk",
                  "top": "base_hi", "bottom": "base_dk"}, bevel=0.03)

    seg = 7
    for i in range(seg):
        if i == 3:
            continue  # keystone knocked out of the crown
        a0 = i / seg * math.pi
        a1 = (i + 1) / seg * math.pi
        front = "base_hi" if i % 2 == 0 else "base_lo"
        outer = "base" if i % 2 == 0 else "base_lo"
        b.arch_ring(1.6, 1.6, 2.42, 2.42, -0.43, 0.43, 1,
                    {"front": front, "back": "base_dk", "inner": "base_dk", "outer": outer},
                    start_angle=a0, end_angle=a1, cz=3.02)
    b.cbox_c(0.0, 0.16, 0.16, 0.62, 0.5, 0.3,
             {"side": "base_lo", "front": "base", "back": "base_dk",
              "top": "base_hi", "bottom": "base_dk"}, bevel=0.035, rot_y=0.6)

    b.cbox_c(-1.85, -0.62, 1.05, 1.0, 0.62, 2.0,
             {"side": "base", "front": "base_hi", "back": "base_dk",
              "top": "base_hi", "bottom": "base_dk"}, bevel=0.05)
    b.cbox_c(2.5, 0.42, 0.24, 0.96, 1.1, 0.44,
             {"side": "base_lo", "front": "base", "back": "base_dk",
              "top": "base_hi", "bottom": "base_dk"}, bevel=0.05, rot_y=0.22)
    b.cbox_c(2.92, -0.16, 0.6, 0.58, 0.64, 0.34,
             {"side": "base", "front": "base_hi", "back": "base_dk",
              "top": "base", "bottom": "base_dk"}, bevel=0.04, rot_y=-0.34)
    b.cbox_c(0.6, 0.5, 0.14, 0.7, 0.55, 0.28,
             {"side": "base_lo", "front": "base", "back": "base_dk",
              "top": "base_hi", "bottom": "base_dk"}, bevel=0.04, rot_y=0.5)

    for x, z, h in ((-1.9, 2.2, 1.25), (-1.7, 3.3, 0.75), (1.5, 3.25, 0.85), (0.35, 4.25, 0.5)):
        b.cbox_c(x, -0.47, z, 0.16, 0.09, h, "leaf_dk", bevel=0.015)
        b.cbox_c(x, -0.49, z - h * 0.3, 0.2, 0.07, 0.16, "leaf", bevel=0.01)
    b.cbox_c(1.15, -0.46, 3.55, 0.24, 0.1, 0.5, "leaf_dk", bevel=0.02)
    return b


def crystal_cluster():
    """Quantum-lab crystal bloom: rock bed plus seven faceted prisms with lit tips."""
    b = Builder()
    b.blob(0, 0, 0.26, 1.16, 1.02, 0.36, 8, 3,
           {"side": "base_dk", "top": "base", "bottom": "base_dk"}, seed=41)
    for i, (x, y, r) in enumerate(((-0.78, 0.34, 0.4), (0.82, -0.28, 0.36),
                                   (0.18, 0.74, 0.3), (-0.3, -0.7, 0.26))):
        b.blob(x, y, 0.24, r, r * 0.92, r * 0.66, 6, 3,
               {"side": "base", "top": "base_hi", "bottom": "base_dk"}, seed=60 + i)

    crystals = (
        ((0.0, 0.0, 0.18), (0.02, 0.0, 2.55), 0.33, 0.15, "lab_light", 0.0),
        ((-0.55, 0.16, 0.22), (-0.8, 0.24, 1.78), 0.25, 0.1, "glass", 0.18),
        ((0.52, -0.16, 0.22), (0.8, -0.26, 1.58), 0.23, 0.09, "portal_b_lt", 0.1),
        ((0.2, 0.46, 0.22), (0.38, 0.7, 1.26), 0.19, 0.07, "glass_lt", 0.22),
        ((-0.24, -0.44, 0.22), (-0.44, -0.66, 1.1), 0.17, 0.06, "lab_panel", 0.12),
        ((-0.86, -0.34, 0.2), (-1.08, -0.48, 0.9), 0.15, 0.05, "portal_b", 0.26),
        ((0.7, 0.4, 0.2), (0.9, 0.54, 1.0), 0.16, 0.05, "glass_dk", 0.2),
    )
    for i, (p0, p1, r0, r1, col, tilt) in enumerate(crystals):
        ax = [p1[k] - p0[k] for k in range(3)]
        length = math.sqrt(sum(v * v for v in ax)) or 1.0
        ax = [v / length for v in ax]
        shaft = (p1[0] - ax[0] * 0.2, p1[1] - ax[1] * 0.2, p1[2] - ax[2] * 0.2)
        b.tube(p0, shaft, r0, r1, 6, {"side": col, "top": lighten(col), "bottom": col})
        tip = (p1[0] + ax[0] * 0.16, p1[1] + ax[1] * 0.16, p1[2] + ax[2] * 0.16)
        tip_col = "white" if i == 0 else col
        b.tube(shaft, tip, r1, 0.004, 6, {"side": tip_col, "top": lighten(col), "bottom": col})
    return b


def windmill_tower():
    """Alpine mill: chamfered tapered tower, belts, balcony, shingled roof, hub."""
    b = Builder()
    b.cbox_c(0, 0, 0.16, 2.5, 2.5, 0.32,
             {"side": "base", "top": "base_hi", "bottom": "base_dk"}, bevel=0.05)
    b.cbox_c(0, 0, 0.36, 2.2, 2.2, 0.12, {"side": "base_lo", "top": "base", "bottom": "base_dk"}, bevel=0.03)

    layers = 5
    for i in range(layers):
        z0 = 0.42 + i * 1.0
        z1 = z0 + 1.0
        side = 2.0 - i * 0.16
        b.cbox_c(0, 0, (z0 + z1) * 0.5, side, side, 0.98,
                 {"side": "wood", "front": "wood_lt", "back": "wood_dk",
                  "top": "wood_lt", "bottom": "wood_dk"}, bevel=0.05)
        # horizontal belt between storeys
        b.cbox_c(0, 0, z1 - 0.06, side + 0.1, side + 0.1, 0.12,
                 {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for i in range(layers):
                z0 = 0.42 + i * 1.0
                side = 2.0 - i * 0.16
                b.cbox_c(sx * (side * 0.5 - 0.05), sy * (side * 0.5 - 0.05), z0 + 0.5,
                         0.14, 0.14, 0.96, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.02)

    # top storey, eave platform, roof and hub
    b.cbox_c(0, 0, 5.46, 2.0, 2.0, 0.14, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.025)
    b.frustum(0, 0, 5.5, 6.62, 1.3, 0.05, 4,
              {"side": "base_dk", "top": "base", "bottom": "base_dk"}, angle0=math.pi / 4)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        b.tube((math.cos(a) * 1.24, math.sin(a) * 1.24, 5.56),
               (math.cos(a) * 0.08, math.sin(a) * 0.08, 6.56), 0.05, 0.03, 4,
               {"side": "base_lo", "top": "base_hi", "bottom": "base_dk"})
    b.cbox_c(0, 0, 6.66, 0.16, 0.16, 0.18, "chrome_dk", bevel=0.02)

    # front balcony walkway
    b.cbox_c(0, -1.0, 3.28, 1.5, 0.52, 0.1, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.02)
    b.cbox_c(0, -1.24, 3.86, 1.5, 0.07, 0.07, "wood", bevel=0.012)
    for sx in (-1, 1):
        b.cbox_c(sx * 0.68, -1.24, 3.58, 0.07, 0.07, 0.56, "wood_dk", bevel=0.012)
        b.cbox_c(sx * 0.34, -1.24, 3.58, 0.05, 0.05, 0.5, "wood_dk", bevel=0.01)
    b.cbox_c(0, -1.24, 3.34, 1.5, 0.06, 0.06, "wood_dk", bevel=0.01)

    # door, window, hatch
    b.cbox_c(0, -1.0, 0.95, 0.62, 0.14, 1.62, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.02)
    b.cbox_c(0, -1.03, 0.98, 0.48, 0.12, 1.44, {"side": "wood", "top": "wood_lt", "bottom": "wood_dk"}, bevel=0.015)
    b.cbox_c(0, -1.06, 0.9, 0.1, 0.06, 0.1, "chrome", bevel=0.01)
    b.cbox_c(0, -0.92, 2.55, 0.42, 0.1, 0.48, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.012)
    b.cbox_c(0, -0.95, 2.55, 0.3, 0.06, 0.36, "glass_lt", bevel=0.01)
    b.cbox_c(0.0, 0.92, 4.35, 0.34, 0.1, 0.42, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, bevel=0.012)
    b.cbox_c(0.0, 0.95, 4.35, 0.24, 0.06, 0.32, "glass_lt", bevel=0.01)

    # blade hub
    b.tube((0, -0.92, 4.72), (0, -1.42, 4.72), 0.24, 0.2, 8,
           {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"})
    b.tube((0, -1.42, 4.72), (0, -1.52, 4.72), 0.13, 0.11, 8,
           {"side": "chrome_dk", "top": "chrome", "bottom": "chrome_dk"})
    return b


def windmill_blades():
    """Four lattice sails with canvas panels; origin is the hub."""
    b = Builder()
    b.tube((0, -0.16, 0), (0, 0.16, 0), 0.36, 0.36, 8,
           {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"})
    b.tube((0, 0.16, 0), (0, 0.3, 0), 0.2, 0.15, 8,
           {"side": "chrome_dk", "top": "chrome", "bottom": "chrome_dk"})
    for i in range(4):
        a = i * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        b.rot_box_y(ca * 1.05, 0, sa * 1.05, 2.05, 0.12, 0.12, a,
                    {"side": "wood", "front": "wood_lt", "back": "wood_dk",
                     "top": "wood_lt", "bottom": "wood_dk"})
        b.rot_box_y(ca * 2.12, 0, sa * 2.12, 0.22, 0.16, 0.16, a,
                    {"side": "wood_dk", "front": "wood", "back": "wood_dk",
                     "top": "wood", "bottom": "wood_dk"})
        for k in (0.55, 0.85, 1.15, 1.45, 1.75):
            b.rot_box_y(ca * k, 0, sa * k, 0.09, 0.09, 0.94, a,
                        {"side": "wood_dk", "front": "wood", "back": "wood_dk",
                         "top": "wood", "bottom": "wood_dk"})
        for k in (0.7, 1.0, 1.3, 1.6):
            b.rot_box_y(ca * k, 0, sa * k, 0.23, 0.05, 0.74, a,
                        {"side": "base_hi", "front": "white", "back": "base_lo",
                         "top": "base_hi", "bottom": "base_lo"})
        b.rot_box_y(ca * 0.36, 0, sa * 0.36, 0.16, 0.14, 0.14, a, "chrome_dk")
    return b


def bird():
    """Distant bird: faceted body, swept plate wings, forked tail."""
    b = Builder()
    b.tube((-0.3, 0, 0.02), (0.26, 0, 0.04), 0.13, 0.09, 6,
           {"side": "base_lo", "top": "base_hi", "bottom": "base_dk"})
    b.tube((0.24, 0, 0.05), (0.4, 0, 0.1), 0.09, 0.05, 6,
           {"side": "flag_k", "top": "base_hi", "bottom": "flag_k"})
    b.tube((0.39, 0, 0.1), (0.55, 0, 0.08), 0.04, 0.004, 4, "boost")
    for sy in (-1, 1):
        # forked tail plate
        b.prism_z([(-0.28, sy * 0.04), (-0.58, sy * 0.16), (-0.58, sy * 0.06), (-0.28, sy * 0.0)],
                  0.0, 0.03, {"side": "base_dk", "top": "base", "bottom": "base_dk"})
        # swept wing plate (convex quad so the fan cap stays clean)
        b.prism_z([(0.12, sy * 0.05), (-0.16, sy * 0.05), (-0.28, sy * 0.5), (0.0, sy * 0.5)],
                  0.0, 0.045, {"side": "white", "top": "white", "bottom": "base_lo"})
    return b


def butterfly():
    """Ambient butterfly: segmented body, four wings, antennae."""
    b = Builder()
    b.tube((0, 0, -0.18), (0, 0, 0.1), 0.05, 0.03, 5,
           {"side": "flag_k", "top": "base_dk", "bottom": "flag_k"})
    b.blob(0, 0, 0.02, 0.06, 0.06, 0.12, 5, 3,
           {"side": "flag_k", "top": "cargo_dk", "bottom": "flag_k"}, seed=71, jitter=0.05)
    for sx in (-1, 1):
        b.poly([(0, 0, 0.08), (sx * 0.4, 0, 0.34), (sx * 0.56, 0, 0.12), (sx * 0.24, 0, 0.0)],
               "flower_y" if sx > 0 else "flower_r")
        b.poly([(0, 0, 0.0), (sx * 0.42, 0, -0.02), (sx * 0.28, 0, -0.3), (sx * 0.06, 0, -0.18)],
               "flower_b")
        b.poly([(0.01, -0.012, 0.02), (sx * 0.32, -0.012, 0.24), (sx * 0.4, -0.012, 0.1),
                (sx * 0.16, -0.012, 0.0)], "white")
        b.poly([(0.01, 0.012, 0.02), (sx * 0.32, 0.012, 0.24), (sx * 0.4, 0.012, 0.1),
                (sx * 0.16, 0.012, 0.0)], "flower_y")
        b.tube((0.02 * sx, 0, 0.12), (sx * 0.12, 0, 0.34), 0.012, 0.006, 4, "flag_k")

    return b


# --------------------------------------------------------------------------- portals
def build_reference_portal(primary_col, light_col, dark_col, is_exit=False):
    """
    Wall-mounted sci-fi quantum portal matching Bridge Constructor Portal reference.
    Aperture faces +X, mounted with mechanical hydraulic brackets and a flange against
    the wall (-X). The elliptical ring is tilted 22 deg towards the camera so the player
    sees the glowing aperture and the swirling event horizon.
    """
    b = Builder()

    # 1. HEAVY WALL MOUNTING FLANGE (-X side, sits flush against wall blocks)
    b.cbox_c(-0.34, 0, 0, 0.16, 1.5, 2.5,
             {"side": "cargo_dk", "front": "cargo", "back": "cargo_dk", "top": "cargo", "bottom": "cargo_dk"},
             bevel=0.035)
    for y in (-0.58, 0.58):
        for z in (-0.98, -0.46, 0.46, 0.98):
            b.cbox_c(-0.24, y, z, 0.08, 0.12, 0.12, "chrome_dk", bevel=0.015)
            b.cbox_c(-0.2, y, z, 0.03, 0.07, 0.07, "bolt_lt", bevel=0.008)

    # 2. MECHANICAL ARTICULATION ARMS & HYDRAULIC STRUTS
    for sgn_y in (-1, 1):
        for sgn_z in (-1, 1):
            y_mount = sgn_y * 0.55
            z_mount = sgn_z * 0.98
            p_wall = (-0.24, y_mount, z_mount)
            p_ring = (-0.02, sgn_y * 0.64, sgn_z * 1.18)
            b.tube(p_wall, p_ring, 0.065, 0.055, 6, "cargo")
            p_mid = ((-0.24 + p_ring[0]) * 0.5, (y_mount + p_ring[1]) * 0.5, (z_mount + p_ring[2]) * 0.5)
            b.tube(p_wall, p_mid, 0.082, 0.082, 6, "chrome_dk")
            b.tube(p_mid, p_ring, 0.05, 0.05, 6, "chrome")
            b.cbox_c(-0.24, y_mount, z_mount, 0.14, 0.14, 0.14, "chrome_dk", bevel=0.02)

    # Power conduits from the flange into the emitter coils
    for sgn_y in (-1, 1):
        b.tube((-0.24, sgn_y * 0.36, -0.9), (0.0, sgn_y * 0.47, -1.1), 0.05, 0.045, 6, "cargo_dk")
        b.tube((-0.15, sgn_y * 0.39, -0.96), (-0.1, sgn_y * 0.41, -0.99), 0.06, 0.06, 6, light_col)

    # 3. ELLIPTICAL PORTAL EMITTER RING (X ~ 0)
    tilt = math.radians(22)
    cos_t, sin_t = math.cos(tilt), math.sin(tilt)

    def transform(x_loc, y_loc, z_loc):
        return (x_loc * cos_t - y_loc * sin_t, x_loc * sin_t + y_loc * cos_t, z_loc)

    seg = 28
    for i in range(seg):
        a0 = i * (2 * math.pi / seg)
        a1 = (i + 1) * (2 * math.pi / seg)

        y_in0, z_in0 = math.cos(a0) * 0.72, math.sin(a0) * 1.15
        y_in1, z_in1 = math.cos(a1) * 0.72, math.sin(a1) * 1.15
        y_mid0, z_mid0 = math.cos(a0) * 0.9, math.sin(a0) * 1.38
        y_mid1, z_mid1 = math.cos(a1) * 0.9, math.sin(a1) * 1.38
        y_out0, z_out0 = math.cos(a0) * 1.06, math.sin(a0) * 1.56
        y_out1, z_out1 = math.cos(a1) * 1.06, math.sin(a1) * 1.56

        v_in0_b = transform(-0.09, y_in0, z_in0)
        v_in1_b = transform(-0.09, y_in1, z_in1)
        v_in0_f = transform(0.09, y_in0, z_in0)
        v_in1_f = transform(0.09, y_in1, z_in1)

        v_mid0_b = transform(-0.13, y_mid0, z_mid0)
        v_mid1_b = transform(-0.13, y_mid1, z_mid1)
        v_mid0_f = transform(0.13, y_mid0, z_mid0)
        v_mid1_f = transform(0.13, y_mid1, z_mid1)

        v_out0_b = transform(-0.09, y_out0, z_out0)
        v_out1_b = transform(-0.09, y_out1, z_out1)
        v_out0_f = transform(0.09, y_out0, z_out0)
        v_out1_f = transform(0.09, y_out1, z_out1)

        b.poly([v_in0_f, v_mid0_f, v_mid1_f, v_in1_f], light_col)
        b.poly([v_mid0_f, v_out0_f, v_out1_f, v_mid1_f], primary_col)
        b.poly([v_in0_b, v_in1_b, v_in1_f, v_in0_f], "white")
        b.poly([v_out0_f, v_out1_f, v_out1_b, v_out0_b], "cargo_dk")
        b.poly([v_in0_b, v_in1_b, v_out1_b, v_out0_b], dark_col)

    # 4. SWIRLING EVENT HORIZON VORTEX INTERIOR
    for i in range(seg):
        a0 = i * (2 * math.pi / seg)
        a1 = (i + 1) * (2 * math.pi / seg)
        y_in0, z_in0 = math.cos(a0) * 0.7, math.sin(a0) * 1.13
        y_in1, z_in1 = math.cos(a1) * 0.7, math.sin(a1) * 1.13
        y_c0, z_c0 = math.cos(a0) * 0.38, math.sin(a0) * 0.62
        y_c1, z_c1 = math.cos(a1) * 0.38, math.sin(a1) * 0.62

        p0_outer = transform(-0.05, y_in0, z_in0)
        p1_outer = transform(-0.05, y_in1, z_in1)
        p0_mid = transform(-0.1, y_c0, z_c0)
        p1_mid = transform(-0.1, y_c1, z_c1)
        p_center = transform(-0.15, 0, 0)

        vortex_col = light_col if (i % 2 == 0) else primary_col
        b.poly([p0_outer, p1_outer, p1_mid, p0_mid], vortex_col)
        inner_col = dark_col if (i % 2 == 0) else "black"
        b.tri(p_center, p0_mid, p1_mid, inner_col)

    # 5. EMITTER PROJECTION STUDS AROUND THE RIM
    for k in range(10):
        a = k * (2 * math.pi / 10) + (math.pi / 10)
        y_stud = math.cos(a) * 0.99
        z_stud = math.sin(a) * 1.49
        p_stud = transform(0.13, y_stud, z_stud)
        b.cbox_c(p_stud[0], p_stud[1], p_stud[2], 0.18, 0.16, 0.16, "chrome_dk", bevel=0.025)
        p_tip = transform(0.22, y_stud, z_stud)
        b.cbox_c(p_tip[0], p_tip[1], p_tip[2], 0.09, 0.09, 0.09, light_col, bevel=0.015)

    # 6. ENTRANCE vs EXIT DETAILS
    if not is_exit:
        p_crest = transform(0.17, 0, 1.64)
        b.cbox_c(p_crest[0], p_crest[1], p_crest[2], 0.16, 0.4, 0.2, "cargo_dk", bevel=0.025)
        p_crest_glow = transform(0.24, 0, 1.64)
        b.cbox_c(p_crest_glow[0], p_crest_glow[1], p_crest_glow[2], 0.05, 0.3, 0.11, "portal_b_lt", bevel=0.012)
        for sgn in (-1, 1):
            p_fin = transform(0.06, sgn * 1.02, 0)
            b.cbox_c(p_fin[0], p_fin[1], p_fin[2], 0.2, 0.06, 0.5, "cargo_dk", bevel=0.02)
    else:
        for sgn_z in (-1, 1):
            p_fin = transform(0.21, 0, sgn_z * 1.66)
            b.cbox_c(p_fin[0], p_fin[1], p_fin[2], 0.18, 0.44, 0.14,
                     {"front": "boost_arrow", "side": "portal_o", "back": "cargo_dk"}, bevel=0.02)
    return b


def portal_blue():
    return build_reference_portal("portal_b", "portal_b_lt", "portal_b_dk", is_exit=False)


def portal_orange():
    return build_reference_portal("portal_o", "portal_o_lt", "portal_o_dk", is_exit=True)


def chamber_sign():
    """Aperture-style test chamber signboard (number 27 + hazard glyphs)."""
    b = Builder()
    b.cbox_c(0, 0.05, 0, 2.34, 0.14, 4.34, "cargo_dk", bevel=0.04)
    b.cbox_c(0, -0.02, 0, 2.12, 0.07, 4.12, "white", bevel=0.03)
    b.cbox_c(0, -0.06, 1.78, 1.92, 0.05, 0.3, "cargo_dk", bevel=0.02)
    b.cbox_c(-0.78, -0.08, 1.78, 0.2, 0.04, 0.2, "portal_b_lt", bevel=0.012)

    # "27" pixel glyphs
    for x, z, sx, sz in ((-0.4, 1.28, 0.56, 0.11), (-0.17, 1.04, 0.13, 0.37),
                         (-0.4, 0.86, 0.56, 0.11), (-0.63, 0.66, 0.13, 0.37),
                         (-0.4, 0.46, 0.56, 0.11)):
        b.cbox_c(x, -0.065, z, sx, 0.04, sz, "black", bevel=0.008)
    b.cbox_c(0.4, -0.065, 1.28, 0.56, 0.04, 0.11, "black", bevel=0.008)
    b.cbox_c(0.63, -0.065, 0.86, 0.13, 0.04, 0.84, "black", bevel=0.008)

    for k in range(9):
        b.cbox_c(-0.68 + k * 0.17, -0.065, 0.15, 0.11, 0.04, 0.07,
                 "black" if k < 6 else "steel_lt", bevel=0.006)

    for row in range(2):
        for col in range(3):
            cx = -0.55 + col * 0.55
            cz = -0.42 - row * 0.6
            b.cbox_c(cx, -0.065, cz, 0.44, 0.03, 0.46, "asphalt_lt", bevel=0.01)
            b.cbox_c(cx, -0.062, cz, 0.47, 0.02, 0.49, "steel_dk", bevel=0.008)
            if row == 0 and col == 0:
                b.cbox_c(cx, -0.075, cz + 0.08, 0.08, 0.02, 0.08, "portal_b", bevel=0.005)
                b.cbox_c(cx, -0.075, cz - 0.06, 0.14, 0.02, 0.18, "portal_b", bevel=0.005)
            elif row == 0 and col == 1:
                b.cbox_c(cx - 0.08, -0.075, cz, 0.06, 0.02, 0.22, "portal_b", bevel=0.005)
                b.cbox_c(cx + 0.08, -0.075, cz, 0.06, 0.02, 0.22, "portal_o", bevel=0.005)
            elif row == 0 and col == 2:
                b.cbox_c(cx, -0.075, cz, 0.22, 0.02, 0.22, "hazard", bevel=0.005)
            else:
                b.cbox_c(cx, -0.075, cz, 0.3, 0.02, 0.16, "cargo_dk", bevel=0.005)
    for cx in (-0.95, 0.95):
        for cz in (-1.85, 1.85):
            b.cbox_c(cx, -0.07, cz, 0.06, 0.03, 0.06, "chrome_dk", bevel=0.006)
    return b


def lab_generator():
    """Quantum core / fusion reactor landmark for the lab chapters."""
    b = Builder()
    b.cbox_c(0, 0, 0.16, 2.3, 2.3, 0.32, {"top": "cargo_lt", "side": "cargo", "bottom": "black"}, bevel=0.05)
    b.cbox_c(0, 0, 0.35, 2.0, 2.0, 0.08, {"top": "cargo_dk", "side": "cargo_dk", "bottom": "cargo"}, bevel=0.02)
    for i, a in enumerate([k * math.pi / 4 for k in range(8)]):
        x, y = math.cos(a) * 0.98, math.sin(a) * 0.98
        col = "lane" if i % 2 == 0 else "hazard"
        b.cbox_c(x, y, 0.33, 0.24, 0.24, 0.06, col, bevel=0.012)

    # reactor containment column
    b.frustum(0, 0, 0.34, 2.45, 0.6, 0.6, 8, {"side": "lab_light", "top": "white", "bottom": "lab_dark"})
    b.frustum(0, 0, 0.42, 2.38, 0.36, 0.36, 8, {"side": "white", "top": "white", "bottom": "white"})
    for z in (0.86, 1.34, 1.82):
        b.ring(0, 0, z - 0.1, z + 0.1, 0.58, 0.8, 8,
               {"side": "cargo_dk", "top": "chrome_dk", "bottom": "cargo_dk", "inner": "lab_dark"})
        b.ring(0, 0, z - 0.04, z + 0.04, 0.79, 0.84, 8,
               {"side": "portal_b_lt", "top": "portal_b_lt", "bottom": "portal_b_lt", "inner": "portal_b_lt"})

    # pipes from base into the lower ring
    for sx in (-1, 1):
        b.tube((sx * 0.62, 0.62, 0.4), (sx * 0.55, 0.48, 0.86), 0.07, 0.07, 6, "cargo_dk")

    # capacitor cap + emitter spike
    b.cbox_c(0, 0, 2.58, 1.34, 1.34, 0.26, {"top": "chrome_dk", "side": "cargo_dk", "bottom": "cargo"}, bevel=0.035)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cbox_c(sx * 0.52, sy * 0.52, 2.72, 0.22, 0.22, 0.06, "lab_panel", bevel=0.01)
    b.frustum(0, 0, 2.7, 3.12, 0.28, 0.07, 6, {"side": "lab_light", "top": "white", "bottom": "lab_light"})
    b.frustum(0, 0, 3.12, 3.28, 0.07, 0.02, 6, {"side": "white", "top": "white", "bottom": "white"})

    # corner pylons
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cbox_c(sx * 0.9, sy * 0.9, 1.45, 0.18, 0.18, 2.2, "cargo", bevel=0.02)
            b.cbox_c(sx * 0.9, sy * 0.9, 0.38, 0.28, 0.28, 0.16, "cargo_dk", bevel=0.02)
            b.cbox_c(sx * 0.9, sy * 0.9, 2.52, 0.28, 0.28, 0.16, "cargo_dk", bevel=0.02)
            b.cbox_c(sx * 0.9, sy * 0.9, 2.42, 0.1, 0.1, 0.1, "lab_light", bevel=0.01)
    return b


def lab_terminal():
    """Sci-fi mainframe rack with a diagnostic console and cable run."""
    b = Builder()
    b.cbox_c(0, 0, 0.97, 0.94, 0.68, 1.94, "cargo_dk", bevel=0.035)
    b.cbox_c(0, 0, 1.96, 1.0, 0.72, 0.08, {"top": "cargo_lt", "side": "cargo", "bottom": "cargo_dk"}, bevel=0.02)
    for z in (0.36, 0.77, 1.18, 1.59):
        b.cbox_c(0, -0.35, z, 0.8, 0.05, 0.33, "lab_panel", bevel=0.01)
        for x in (-0.26, -0.16, -0.06, 0.04, 0.14, 0.24):
            b.cbox_c(x, -0.38, z, 0.05, 0.02, 0.24, "cargo_dk", bevel=0.005)
        for k, col in enumerate(("flag_g", "lane", "flower_r")):
            b.cbox_c(-0.33, -0.38, z + 0.09 - k * 0.08, 0.045, 0.02, 0.045, col, bevel=0.004)
        b.cbox_c(0.3, -0.38, z, 0.1, 0.02, 0.1, "lab_light", bevel=0.006)
    # swing-arm diagnostic monitor facing the player (-Y)
    b.cbox_c(0.5, -0.18, 1.15, 0.16, 0.14, 0.14, "chrome_dk", bevel=0.02)
    b.cbox_c(0.6, -0.26, 1.15, 0.1, 0.3, 0.08, "cargo_dk", bevel=0.015)
    b.cbox_c(0.62, -0.3, 1.15, 0.06, 0.1, 0.1, "chrome_dk", bevel=0.012)
    b.cbox_c(0.62, -0.36, 1.15, 0.46, 0.06, 0.36,
             {"front": "portal_b_lt", "side": "cargo_dk", "back": "cargo_dk",
              "top": "cargo_lt", "bottom": "cargo_dk"}, bevel=0.014)
    b.cbox_c(0.62, -0.39, 1.15, 0.36, 0.02, 0.26, "lab_line", bevel=0.008)
    # feet + cables
    for sx in (-0.4, 0.4):
        for sy in (-0.32, 0.32):
            b.cbox_c(sx, sy, 0.04, 0.14, 0.14, 0.08, "chrome_dk", bevel=0.01)
    b.tube((-0.34, -0.34, 0.05), (-0.34, -0.56, 0.05), 0.032, 0.032, 5, "cargo_dk")
    b.tube((0.14, -0.34, 0.05), (0.34, -0.56, 0.05), 0.034, 0.034, 5, "cargo_dk")
    return b


def energy_pylon():
    """High-voltage quantum relay pylon with lit insulator stacks."""
    b = Builder()
    b.cbox_c(0, 0, 0.16, 1.16, 1.16, 0.32, {"top": "base_hi", "side": "base", "bottom": "base_dk"}, bevel=0.04)
    b.cbox_c(0, 0, 0.36, 0.9, 0.9, 0.1, {"top": "base_lo", "side": "base_lo", "bottom": "base_dk"}, bevel=0.02)
    b.frustum(0, 0, 0.4, 3.7, 0.46, 0.16, 4,
              {"side": "cargo_dk", "top": "chrome_dk", "bottom": "cargo_dk"}, angle0=math.pi / 4)
    for i in range(3):
        z = 1.5 + i * 0.8
        span = 1.4 - i * 0.24
        b.cbox_c(0, 0, z, span, 0.14, 0.1, "cargo_dk", bevel=0.015)
        b.cbox_c(0, 0, z + 0.16, span * 0.6, 0.08, 0.06, "chrome_dk", bevel=0.01)
        for sx in (-1, 1):
            x = sx * (span * 0.5 - 0.07)
            b.cbox_c(x, 0, z + 0.08, 0.16, 0.16, 0.05, "lab_panel", bevel=0.01)
            b.cbox_c(x, 0, z + 0.17, 0.1, 0.1, 0.1, "lab_light", bevel=0.012)
            b.cbox_c(x, 0, z - 0.06, 0.12, 0.12, 0.04, "steel_dk", bevel=0.008)
        # diagonal braces
        for sgn in (-1, 1):
            b.cbox_c(sgn * 0.34, 0, z - 0.42, 0.06, 0.06, 0.9, "cargo", bevel=0.01, rot_y=sgn * 0.38)
    b.frustum(0, 0, 3.68, 4.0, 0.16, 0.05, 6, {"side": "chrome", "top": "white", "bottom": "chrome_dk"})
    b.ring(0, 0, 3.94, 4.06, 0.16, 0.32, 6,
           {"side": "lab_light", "top": "white", "bottom": "portal_b_lt", "inner": "white"})
    b.blob(0, 0, 4.14, 0.14, 0.14, 0.14, 6, 3,
           {"side": "lab_light", "top": "white", "bottom": "portal_b_lt"}, seed=81, jitter=0.05)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        b.cbox_c(math.cos(a) * 0.22, math.sin(a) * 0.22, 4.14, 0.24, 0.06, 0.06, "chrome_dk", bevel=0.008)
    return b


def cactus_saguaro():
    """Desert saguaro: ribbed trunk, two elbowed arms, blossoms on top."""
    b = Builder()
    b.frustum(0, 0, 0.0, 0.24, 0.3, 0.26, 8, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
    b.frustum(0, 0, 0.18, 3.16, 0.26, 0.22, 8, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
    b.frustum(0, 0, 3.16, 3.42, 0.22, 0.08, 8, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"})
    for i in range(6):
        a = i * math.pi / 3
        b.cbox_c(math.cos(a) * 0.23, math.sin(a) * 0.23, 1.65, 0.06, 0.06, 2.9,
                 {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"}, bevel=0.012)

    arms = (
        (-1, 1.35, 0.66, 2.72),
        (1, 1.85, 0.74, 2.98),
    )
    for sx, z, reach, top in arms:
        b.tube((0, 0, z), (sx * reach, 0, z + 0.12), 0.17, 0.16, 7,
               {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
        b.tube((sx * reach, 0, z + 0.12), (sx * reach, 0, z + 0.3), 0.17, 0.16, 7,
               {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
        b.tube((sx * reach, 0, z + 0.3), (sx * reach, 0, top), 0.16, 0.14, 7,
               {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
        b.frustum(sx * reach, 0, top, top + 0.22, 0.14, 0.05, 7,
                  {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"})
        b.cbox_c(sx * reach, -0.14, top - 0.02, 0.11, 0.1, 0.1, "flower_r", bevel=0.01)

    b.cbox_c(0, -0.22, 3.28, 0.12, 0.1, 0.1, "flower_y", bevel=0.01)
    b.cbox_c(0.16, 0.1, 3.2, 0.1, 0.09, 0.09, "flower_w", bevel=0.008)
    b.cbox_c(-0.14, 0.14, 3.18, 0.1, 0.09, 0.09, "flower_r", bevel=0.008)
    return b


def lantern_post():
    """Alpine trail lantern: stone footing, wooden post, iron bracket, glowing cage."""
    b = Builder()
    b.cbox_c(0, 0, 0.1, 0.5, 0.5, 0.2, {"top": "base_hi", "side": "base", "bottom": "base_dk"}, bevel=0.03)
    b.cbox_c(0, 0, 0.22, 0.34, 0.34, 0.1, {"top": "base_lo", "side": "base", "bottom": "base_dk"}, bevel=0.02)
    b.cbox_c(0, 0, 0.32, 0.2, 0.2, 0.16, {"top": "wood_end", "side": "wood_dk", "bottom": "wood_dk"}, bevel=0.02)
    b.frustum(0, 0, 0.34, 2.32, 0.13, 0.1, 8,
              {"side": "wood_dk", "top": "wood_end", "bottom": "wood_dk"})
    for z in (0.7, 1.5):
        b.cbox_c(0, 0, z, 0.4, 0.4, 0.08, {"top": "wood", "side": "wood_dk", "bottom": "wood_dk"}, bevel=0.02)
    b.cbox_c(0.24, 0, 2.3, 0.62, 0.14, 0.14, {"top": "wood_lt", "side": "wood", "bottom": "wood_dk"}, bevel=0.02)
    b.tube((0.1, 0, 1.95), (0.4, 0, 2.24), 0.05, 0.05, 4, "wood_dk")
    b.cbox_c(0, 0, 2.42, 0.26, 0.26, 0.14, {"top": "wood_lt", "side": "wood", "bottom": "wood_dk"}, bevel=0.02)
    b.tube((0.5, 0, 2.3), (0.5, 0, 2.2), 0.025, 0.025, 4, "black")

    # lantern: black frame, four glass panes, glowing core
    b.frustum(0.5, 0, 2.02, 2.2, 0.26, 0.03, 4,
              {"side": "black", "top": "cargo_dk", "bottom": "black"}, angle0=math.pi / 4)
    b.cbox_c(0.5, 0, 2.0, 0.34, 0.34, 0.05, "black", bevel=0.012)
    b.cbox_c(0.5, 0, 1.8, 0.26, 0.26, 0.3, "light", bevel=0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cbox_c(0.5 + sx * 0.135, sy * 0.135, 1.8, 0.04, 0.04, 0.34, "black", bevel=0.006)
    for sx, sy, ax in ((0, -1, "x"), (0, 1, "x"), (-1, 0, "y"), (1, 0, "y")):
        if ax == "x":
            b.cbox_c(0.5, sy * 0.13, 1.8, 0.22, 0.02, 0.28, "light", bevel=0.004)
        else:
            b.cbox_c(0.5 + sx * 0.13, 0, 1.8, 0.02, 0.22, 0.28, "light", bevel=0.004)
    b.cbox_c(0.5, 0, 1.62, 0.36, 0.36, 0.06, {"top": "black", "side": "black", "bottom": "cargo_dk"}, bevel=0.012)
    return b


MODELS = {
    "tree_blossom": tree_blossom,
    "pine_tall": pine_tall,
    "rock_arch": rock_arch,
    "ruin_arch": ruin_arch,
    "crystal_cluster": crystal_cluster,
    "windmill": windmill_tower,
    "windmill_blades": windmill_blades,
    "bird": bird,
    "butterfly": butterfly,
    "portal_blue": portal_blue,
    "portal_orange": portal_orange,
    "lab_generator": lab_generator,
    "lab_terminal": lab_terminal,
    "energy_pylon": energy_pylon,
    "chamber_sign": chamber_sign,
    "cactus_saguaro": cactus_saguaro,
    "lantern_post": lantern_post,
}


def main():
    for name, fn in MODELS.items():
        clear()
        export(name, fn())
    print("[blender] done:", ", ".join(MODELS.keys()))


if __name__ == "__main__":
    main()
