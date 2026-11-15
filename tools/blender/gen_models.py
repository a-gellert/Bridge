"""
Blender-authored decor and portal models for Bridge Mad.

Run:
    "D:/Programs/Blender/blender.exe" -b -P tools/blender/gen_models.py

The script builds low-poly, flat-shaded meshes with palette UVs (one texel per face)
and exports one self-contained .glb per model into assets/models/.

The game's Defold material supplies the palette texture. Materials are deliberately not
exported: Defold's model component overrides the material slot, exactly like the procedural
JS models.
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


def uv(name):
    if name not in PALETTE:
        raise KeyError("unknown palette color: " + name)
    return float(PALETTE[name]["uv"][0]), float(PALETTE[name]["uv"][1])


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.colors = []

    def poly(self, pts, color):
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append(tuple(range(base, base + len(pts))))
        self.colors.append(color)

    def tri(self, a, b, c, color):
        self.poly([a, b, c], color)

    def box(self, x0, y0, z0, x1, y1, z1, colors):
        c = colors if isinstance(colors, dict) else {"side": colors, "front": colors, "back": colors, "top": colors, "bottom": colors}
        side = c.get("side") or c.get("front") or c.get("top")
        front = c.get("front") or side
        back = c.get("back") or side
        top = c.get("top") or side
        bottom = c.get("bottom") or side
        v = [
            (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
            (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
        ]
        self.poly([v[0], v[1], v[5], v[4]], front)  # -Y (towards camera)
        self.poly([v[2], v[3], v[7], v[6]], back)   # +Y
        self.poly([v[1], v[2], v[6], v[5]], side)   # +X
        self.poly([v[3], v[0], v[4], v[7]], side)   # -X
        self.poly([v[4], v[5], v[6], v[7]], top)    # +Z
        self.poly([v[3], v[2], v[1], v[0]], bottom) # -Z
        return self

    def box_c(self, cx, cy, cz, sx, sy, sz, colors):
        return self.box(cx - sx / 2, cy - sy / 2, cz - sz / 2, cx + sx / 2, cy + sy / 2, cz + sz / 2, colors)

    def rot_box_y(self, cx, cy, cz, sx, sy, sz, angle, colors):
        """Box rotated around the Y axis (arch voussoirs live in the X-Z plane)."""
        ca, sa = math.cos(angle), math.sin(angle)
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        pts = []
        for lx, ly, lz in (
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
            (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz),
        ):
            pts.append((cx + lx * ca + lz * sa, cy + ly, cz - lx * sa + lz * ca))
        c = colors if isinstance(colors, dict) else {"side": colors, "front": colors, "back": colors, "top": colors, "bottom": colors}
        side = c.get("side")
        self.poly([pts[0], pts[1], pts[5], pts[4]], c.get("front") or side)
        self.poly([pts[2], pts[3], pts[7], pts[6]], c.get("back") or side)
        self.poly([pts[1], pts[2], pts[6], pts[5]], side)
        self.poly([pts[3], pts[0], pts[4], pts[7]], side)
        self.poly([pts[4], pts[5], pts[6], pts[7]], c.get("top") or side)
        self.poly([pts[3], pts[2], pts[1], pts[0]], c.get("bottom") or side)
        return self

    def prism_z(self, pts, z0, z1, colors):
        """Convex polygon in X-Y extruded along Z (sun discs, butterfly wings)."""
        c = colors if isinstance(colors, dict) else {"side": colors, "top": colors, "bottom": colors}
        n = len(pts)
        cx = sum(p[0] for p in pts) / n
        cy = sum(p[1] for p in pts) / n
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            self.poly([(cx, cy, z1), (b[0], b[1], z1), (a[0], a[1], z1)], c.get("top") or c.get("side"))
            self.poly([(cx, cy, z0), (a[0], a[1], z0), (b[0], b[1], z0)], c.get("bottom") or c.get("side"))
            self.poly([(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], c.get("side"))
        return self

    def frustum(self, cx, cy, z0, z1, r0, r1, seg, colors, angle0=0.0, cap0=True, cap1=True):
        c = colors if isinstance(colors, dict) else {"side": colors, "top": colors, "bottom": colors}
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

    def tube(self, p0, p1, r0, r1, seg, colors, cap0=True, cap1=True):
        """Cylinder/tapered trunk between two arbitrary points (branches, crystals)."""
        c = colors if isinstance(colors, dict) else {"side": colors, "top": colors, "bottom": colors}
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
        c = colors if isinstance(colors, dict) else {"side": colors, "top": colors, "bottom": colors}
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

    def arch_ring(self, rx0, rz0, rx1, rz1, y0, y1, segs, colors, start_angle=0.0, end_angle=math.pi * 2):
        """Continuous polygonal ring / arch in X-Z plane extruded along Y from y0 to y1."""
        c = colors if isinstance(colors, dict) else {"front": colors, "back": colors, "inner": colors, "outer": colors}
        front = c.get("front") or "cargo"
        back = c.get("back") or "cargo"
        inner = c.get("inner") or "cargo_dk"
        outer = c.get("outer") or "cargo"

        n = segs
        step = (end_angle - start_angle) / n
        is_closed = abs((end_angle - start_angle) - math.pi * 2) < 1e-4

        for i in range(n):
            if not is_closed and i == n:
                break
            a0 = start_angle + i * step
            a1 = start_angle + (i + 1) * step
            ca0, sa0 = math.cos(a0), math.sin(a0)
            ca1, sa1 = math.cos(a1), math.sin(a1)

            p_in0_f = (ca0 * rx0, y0, sa0 * rz0)
            p_in1_f = (ca1 * rx0, y0, sa1 * rz0)
            p_out0_f = (ca0 * rx1, y0, sa0 * rz1)
            p_out1_f = (ca1 * rx1, y0, sa1 * rz1)

            p_in0_b = (ca0 * rx0, y1, sa0 * rz0)
            p_in1_b = (ca1 * rx0, y1, sa1 * rz0)
            p_out0_b = (ca0 * rx1, y1, sa0 * rz1)
            p_out1_b = (ca1 * rx1, y1, sa1 * rz1)

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
    b = Builder()
    b.tube((0, 0, 0), (0.04, 0, 2.05), 0.2, 0.12, 6, {"side": "trunk", "top": "trunk_lt", "bottom": "trunk_dk"})
    b.tube((0.02, 0.02, 1.55), (0.62, 0.12, 2.25), 0.1, 0.055, 5, {"side": "trunk", "top": "trunk_lt"})
    b.tube((0.0, 0.0, 1.7), (-0.55, -0.12, 2.35), 0.1, 0.05, 5, {"side": "trunk_dk", "top": "trunk"})
    b.tube((0.02, 0.0, 1.85), (0.18, 0.32, 2.55), 0.08, 0.045, 5, {"side": "trunk", "top": "trunk_lt"})
    b.blob(0.0, 0.0, 2.62, 1.15, 0.95, 0.9, 7, 4, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"}, seed=11)
    b.blob(0.72, 0.18, 2.38, 0.68, 0.6, 0.62, 6, 4, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"}, seed=12)
    b.blob(-0.68, -0.16, 2.45, 0.72, 0.62, 0.66, 6, 4, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"}, seed=13)
    b.blob(0.12, -0.5, 2.18, 0.58, 0.5, 0.5, 6, 3, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"}, seed=14)
    for i, (x, y, z) in enumerate(((0.55, -0.72, 2.5), (-0.7, 0.45, 2.62), (0.15, 0.7, 2.85), (0.9, 0.0, 2.2))):
        b.blob(x, y, z, 0.17, 0.14, 0.14, 5, 3, {"side": "flower_r", "top": "flower_y", "bottom": "flower_r"}, seed=20 + i, jitter=0.2)
    return b


def pine_tall():
    b = Builder()
    b.tube((0, 0, 0), (0, 0, 4.7), 0.23, 0.1, 6, {"side": "trunk", "top": "trunk_lt", "bottom": "trunk_dk"})
    tiers = (
        (1.05, 1.65, 1.38, 0.84),
        (1.55, 2.2, 1.2, 0.72),
        (2.05, 2.75, 1.02, 0.6),
        (2.55, 3.25, 0.86, 0.5),
        (3.05, 3.7, 0.68, 0.38),
        (3.5, 4.08, 0.5, 0.24),
    )
    for i, (z0, z1, r0, r1) in enumerate(tiers):
        side = "pine" if i % 2 == 0 else "pine_dk"
        top = "pine_lt" if i % 2 == 0 else "pine"
        b.frustum(0, 0, z0, z1, r0, r1, 7, {"side": side, "top": top, "bottom": "pine_dk"}, angle0=0.18 * i)
        if i >= 2:
            b.frustum(0, 0, z1 - 0.08, z1, r1 + 0.02, r1 * 0.55, 7, {"side": "snow", "top": "snow", "bottom": "snow"}, angle0=0.18 * i, cap0=False)
    b.tube((0, 0, 4.25), (0, 0, 4.95), 0.16, 0.02, 6, {"side": "pine_lt", "top": "pine_lt", "bottom": "pine"})
    return b


def rock_arch():
    b = Builder()
    for sx in (-1, 1):
        x = sx * 2.15
        for i in range(4):
            z0 = i * 0.62
            off = 0.05 * math.sin(i * 2.1 + sx)
            b.box_c(x + off, 0, z0 + 0.31, 1.02 - i * 0.05, 1.25, 0.64,
                    {"side": "base", "front": "base_hi", "back": "base_dk", "top": "base_lo", "bottom": "base_dk"})
    seg = 7
    for i in range(seg):
        a0 = (i / seg) * math.pi
        a = a0 + (math.pi / seg) * 0.5
        cx = math.cos(a) * 2.18
        cz = 2.02 + math.sin(a) * 2.18
        b.rot_box_y(cx, 0, cz, 1.02, 1.15, 0.92, -a,
                    {"side": "base", "front": "base_hi", "back": "base_dk", "top": "base_hi", "bottom": "base_dk"})
    b.blob(0.1, 0.0, 4.32, 0.95, 0.9, 0.5, 6, 3, {"side": "base", "top": "base_hi", "bottom": "base_dk"}, seed=31)
    b.blob(-2.35, 0.35, 0.38, 1.0, 0.95, 0.55, 6, 3, {"side": "base_lo", "top": "base", "bottom": "base_dk"}, seed=32)
    b.blob(2.28, -0.32, 0.42, 1.1, 1.0, 0.6, 6, 3, {"side": "base", "top": "base_hi", "bottom": "base_dk"}, seed=33)
    for x, z in ((-2.2, 2.2), (2.1, 2.3), (-1.4, 4.1), (0.9, 4.45)):
        b.box_c(x, -0.55, z, 0.5, 0.1, 0.12, "leaf_dk")
    return b


def ruin_arch():
    b = Builder()
    for sx in (-1, 1):
        x = sx * 1.85
        for i in range(5):
            z0 = i * 0.56
            b.box_c(x, 0, z0 + 0.28, 0.78, 0.92, 0.58,
                    {"side": "base_lo", "front": "base_hi", "back": "base_dk", "top": "base", "bottom": "base_dk"})
        b.box_c(x, 0, 2.95, 1.04, 1.12, 0.24, {"side": "base", "front": "base_hi", "back": "base_dk", "top": "base_hi", "bottom": "base_dk"})
    seg = 5
    for i in range(seg):
        a = (i + 0.5) / seg * math.pi
        cx = math.cos(a) * 1.85
        cz = 3.12 + math.sin(a) * 1.85
        if i == seg - 1:
            continue
        b.rot_box_y(cx, 0, cz, 0.82, 0.9, 0.66, -a,
                    {"side": "base_lo", "front": "base_hi", "back": "base_dk", "top": "base", "bottom": "base_dk"})
    b.box_c(-1.85, -0.62, 1.0, 1.05, 0.65, 2.0, {"side": "base", "front": "base_hi", "back": "base_dk", "top": "base_hi", "bottom": "base_dk"})
    b.box_c(2.55, 0.4, 0.22, 1.0, 1.15, 0.42, {"side": "base_lo", "front": "base", "back": "base_dk", "top": "base_hi", "bottom": "base_dk"})
    b.box_c(2.95, -0.2, 0.55, 0.55, 0.6, 0.3, {"side": "base", "front": "base_hi", "back": "base_dk", "top": "base", "bottom": "base_dk"})
    for x, z, h in ((-1.9, 2.1, 1.2), (-1.7, 3.2, 0.7), (1.5, 3.2, 0.8), (0.3, 4.2, 0.5)):
        b.box_c(x, -0.55, z, 0.18, 0.08, h, "leaf_dk")
    return b


def crystal_cluster():
    b = Builder()
    b.blob(0, 0, 0.32, 1.15, 1.0, 0.42, 7, 3, {"side": "base_dk", "top": "base", "bottom": "base_dk"}, seed=41)
    crystals = (
        ((0.0, 0.0, 0.2), (0.0, 0.0, 2.55), 0.32, 0.12, "lab_light"),
        ((-0.52, 0.12, 0.2), (-0.78, 0.2, 1.75), 0.24, 0.08, "glass"),
        ((0.5, -0.14, 0.2), (0.78, -0.24, 1.55), 0.22, 0.07, "portal_b_lt"),
        ((0.18, 0.42, 0.2), (0.35, 0.65, 1.2), 0.18, 0.06, "glass_lt"),
        ((-0.22, -0.4, 0.2), (-0.4, -0.62, 1.05), 0.16, 0.05, "lab_panel"),
    )
    for i, (p0, p1, r0, r1, col) in enumerate(crystals):
        b.tube(p0, p1, r0, r1, 6, {"side": col, "top": "white", "bottom": col})
        ax = [p1[k] - p0[k] for k in range(3)]
        tip = (p1[0] + ax[0] * 0.25, p1[1] + ax[1] * 0.25, p1[2] + ax[2] * 0.25)
        b.tube(p1, tip, r1, 0.006, 6, {"side": col, "top": "white", "bottom": col})
    return b


def windmill_tower():
    b = Builder()
    b.frustum(0, 0, 0, 0.45, 1.25, 1.1, 4, {"side": "base", "top": "base_hi", "bottom": "base_dk"}, angle0=math.pi / 4)
    for i in range(4):
        z0 = 0.45 + i * 1.05
        z1 = z0 + 1.05
        r0 = (1.08 - i * 0.09) * 0.7071
        r1 = (1.08 - (i + 1) * 0.09) * 0.7071
        b.frustum(0, 0, z0, z1, r0, r1, 4,
                  {"side": "wood", "top": "wood_lt", "bottom": "wood_dk"}, angle0=math.pi / 4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_c(sx * 0.72, sy * 0.72, 2.4, 0.1, 0.1, 4.4, "wood_dk")
    b.frustum(0, 0, 4.55, 4.7, 1.15, 1.15, 4, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"}, angle0=math.pi / 4)
    b.frustum(0, 0, 4.7, 5.55, 1.0, 0.05, 4, {"side": "base_dk", "top": "base", "bottom": "base_dk"}, angle0=math.pi / 4)
    b.box_c(0, -0.86, 0.75, 0.46, 0.12, 1.0, "wood_dk")
    b.box_c(0, -0.9, 1.55, 0.32, 0.1, 0.42, "glass_lt")
    b.box_c(0, -0.78, 3.55, 0.3, 0.1, 0.4, "glass_lt")
    b.tube((0, -0.9, 4.15), (0, -1.3, 4.15), 0.2, 0.2, 8, {"side": "steel", "top": "steel_lt", "bottom": "steel_dk"})
    return b


def windmill_blades():
    b = Builder()
    b.tube((0, -0.08, 0), (0, 0.08, 0), 0.34, 0.34, 8, {"side": "wood_dk", "top": "wood", "bottom": "wood_dk"})
    for i in range(4):
        a = i * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        cx, cz = ca * 1.15, sa * 1.15
        b.rot_box_y(cx, 0, cz, 2.0, 0.14, 0.14, a, {"side": "wood", "front": "wood_lt", "back": "wood_dk", "top": "wood_lt", "bottom": "wood_dk"})
        for k in (0.75, 1.2, 1.65):
            x, z = ca * k, sa * k
            b.rot_box_y(x, 0, z, 0.1, 0.1, 0.85, a, {"side": "wood_dk", "front": "wood", "back": "wood_dk", "top": "wood", "bottom": "wood_dk"})
            b.rot_box_y(x + ca * 0.28, 0, z + sa * 0.28, 0.62, 0.06, 0.86, a, {"side": "base_hi", "front": "base_hi", "back": "base_lo", "top": "base_hi", "bottom": "base_lo"})
    return b


def bird():
    b = Builder()
    b.tube((-0.32, 0, 0), (0.28, 0, 0.03), 0.15, 0.1, 5, {"side": "base_lo", "top": "base_hi", "bottom": "base_dk"})
    b.tube((0.26, 0, 0.05), (0.46, 0, 0.12), 0.1, 0.04, 5, {"side": "flag_k", "top": "base_hi", "bottom": "flag_k"})
    b.tube((0.44, 0, 0.12), (0.6, 0, 0.1), 0.04, 0.005, 4, "boost")
    b.poly([(-0.35, 0, 0.02), (-0.72, 0, 0.18), (-0.72, 0, 0.02), (-0.35, 0, -0.04)], "base_dk")
    b.poly([(-0.35, 0.02, 0.02), (-0.72, 0.02, 0.18), (-0.72, 0.02, 0.02), (-0.35, 0.02, -0.04)], "base_dk")
    b.poly([(-0.1, 0, 0.04), (0.25, 0, 0.04), (0.25, 0, 0.62), (0.02, 0, 0.5)], "white")
    b.poly([(-0.1, 0.03, 0.04), (0.25, 0.03, 0.04), (0.25, 0.03, 0.62), (0.02, 0.03, 0.5)], "base_hi")
    b.poly([(0.25, 0, 0.62), (0.42, 0, 0.36), (0.25, 0, 0.04)], "base_lo")
    return b


def butterfly():
    b = Builder()
    b.tube((0, 0, -0.14), (0, 0, 0.18), 0.035, 0.025, 5, {"side": "flag_k", "top": "base_dk", "bottom": "flag_k"})
    for sx in (-1, 1):
        b.poly([(0, 0, 0.06), (sx * 0.38, 0, 0.3), (sx * 0.52, 0, 0.1), (sx * 0.22, 0, 0.0)], "flower_y" if sx > 0 else "flower_r")
        b.poly([(0, 0, 0.0), (sx * 0.4, 0, -0.02), (sx * 0.26, 0, -0.26), (sx * 0.05, 0, -0.16)], "flower_b")
        b.poly([(0.01, -0.01, 0.02), (sx * 0.3, -0.01, 0.22), (sx * 0.36, -0.01, 0.1), (sx * 0.14, -0.01, 0.0)], "white")
    return b


# --------------------------------------------------------------------------- NEW MODELS
def build_reference_portal(primary_col, light_col, dark_col, is_exit=False):
    """
    Wall-mounted sci-fi quantum portal matching Bridge Constructor Portal reference.
    Aperture faces the vehicle path (+X normal), mounted with mechanical hydraulic
    brackets and a flange against the wall (-X). The elliptical ring is tilted 22 deg
    towards the camera so the player sees the glowing aperture and swirling event horizon.
    """
    b = Builder()

    # 1. HEAVY WALL MOUNTING FLANGE (-X side, sits flush against wall blocks)
    b.box_c(-0.32, 0, 0, 0.14, 1.45, 2.45,
            {"side": "cargo_dk", "front": "cargo_dk", "back": "black", "top": "cargo_dk", "bottom": "cargo_dk"})
    for y in (-0.55, 0.55):
        for z in (-0.95, -0.45, 0.45, 0.95):
            b.box_c(-0.23, y, z, 0.05, 0.1, 0.1, "chrome_dk")
            b.box_c(-0.20, y, z, 0.02, 0.06, 0.06, "bolt_lt")

    # 2. MECHANICAL ARTICULATION ARMS & HYDRAULIC STRUTS
    for sgn_y in (-1, 1):
        for sgn_z in (-1, 1):
            y_mount = sgn_y * 0.52
            z_mount = sgn_z * 0.95
            p_wall = (-0.23, y_mount, z_mount)
            p_ring = (-0.02, sgn_y * 0.62, sgn_z * 1.15)
            b.tube(p_wall, p_ring, 0.06, 0.05, 6, "cargo")
            p_mid = ((-0.23 + p_ring[0]) * 0.5, (y_mount + p_ring[1]) * 0.5, (z_mount + p_ring[2]) * 0.5)
            b.tube(p_wall, p_mid, 0.075, 0.075, 6, "chrome_dk")
            b.box_c(-0.23, y_mount, z_mount, 0.12, 0.12, 0.12, "chrome_dk")

    # Power conduits from wall flange into emitter coils
    for sgn_y in (-1, 1):
        b.tube((-0.23, sgn_y * 0.35, -0.85), (0.0, sgn_y * 0.45, -1.05), 0.045, 0.04, 6, "cargo_dk")
        b.tube((-0.14, sgn_y * 0.38, -0.91), (-0.10, sgn_y * 0.40, -0.94), 0.055, 0.055, 6, light_col)

    # 3. ELLIPTICAL PORTAL EMITTER RING (X ~ 0)
    # Tilted towards camera (-Y in Blender = +Z in Defold) by 22 degrees
    tilt = math.radians(22)
    cos_t, sin_t = math.cos(tilt), math.sin(tilt)

    def transform(x_loc, y_loc, z_loc):
        x_rot = x_loc * cos_t - y_loc * sin_t
        y_rot = x_loc * sin_t + y_loc * cos_t
        return (x_rot, y_rot, z_loc)

    seg = 24
    for i in range(seg):
        a0 = i * (2 * math.pi / seg)
        a1 = (i + 1) * (2 * math.pi / seg)

        y_in0, z_in0 = math.cos(a0) * 0.72, math.sin(a0) * 1.15
        y_in1, z_in1 = math.cos(a1) * 0.72, math.sin(a1) * 1.15
        y_mid0, z_mid0 = math.cos(a0) * 0.88, math.sin(a0) * 1.35
        y_mid1, z_mid1 = math.cos(a1) * 0.88, math.sin(a1) * 1.35
        y_out0, z_out0 = math.cos(a0) * 1.05, math.sin(a0) * 1.55
        y_out1, z_out1 = math.cos(a1) * 1.05, math.sin(a1) * 1.55

        v_in0_b = transform(-0.08, y_in0, z_in0)
        v_in1_b = transform(-0.08, y_in1, z_in1)
        v_in0_f = transform(0.08, y_in0, z_in0)
        v_in1_f = transform(0.08, y_in1, z_in1)

        v_mid0_b = transform(-0.12, y_mid0, z_mid0)
        v_mid1_b = transform(-0.12, y_mid1, z_mid1)
        v_mid0_f = transform(0.12, y_mid0, z_mid0)
        v_mid1_f = transform(0.12, y_mid1, z_mid1)

        v_out0_b = transform(-0.08, y_out0, z_out0)
        v_out1_b = transform(-0.08, y_out1, z_out1)
        v_out0_f = transform(0.08, y_out0, z_out0)
        v_out1_f = transform(0.08, y_out1, z_out1)

        b.poly([v_in0_f, v_mid0_f, v_mid1_f, v_in1_f], light_col)
        b.poly([v_mid0_f, v_out0_f, v_out1_f, v_mid1_f], primary_col)
        b.poly([v_in0_b, v_in1_b, v_in1_f, v_in0_f], "white")
        b.poly([v_out0_f, v_out1_f, v_out1_b, v_out0_b], "cargo_dk")
        b.poly([v_in0_b, v_in1_b, v_out1_b, v_out0_b], dark_col)

    # 4. SWIRLING EVENT HORIZON VORTEX INTERIOR
    for i in range(seg):
        a0 = i * (2 * math.pi / seg)
        a1 = (i + 1) * (2 * math.pi / seg)
        y_in0, z_in0 = math.cos(a0) * 0.70, math.sin(a0) * 1.13
        y_in1, z_in1 = math.cos(a1) * 0.70, math.sin(a1) * 1.13
        y_c0, z_c0 = math.cos(a0) * 0.38, math.sin(a0) * 0.62
        y_c1, z_c1 = math.cos(a1) * 0.38, math.sin(a1) * 0.62

        p0_outer = transform(-0.04, y_in0, z_in0)
        p1_outer = transform(-0.04, y_in1, z_in1)
        p0_mid = transform(-0.08, y_c0, z_c0)
        p1_mid = transform(-0.08, y_c1, z_c1)
        p_center = transform(-0.12, 0, 0)

        vortex_col = light_col if (i % 2 == 0) else primary_col
        b.poly([p0_outer, p1_outer, p1_mid, p0_mid], vortex_col)
        inner_col = dark_col if (i % 2 == 0) else "black"
        b.tri(p_center, p0_mid, p1_mid, inner_col)

    # 5. EMITTER PROJECTION STUDS AROUND THE RIM
    for k in range(8):
        a = k * (2 * math.pi / 8) + (math.pi / 8)
        y_stud = math.cos(a) * 0.98
        z_stud = math.sin(a) * 1.48
        p_stud = transform(0.12, y_stud, z_stud)
        b.box_c(p_stud[0], p_stud[1], p_stud[2], 0.16, 0.14, 0.14, "chrome_dk")
        p_tip = transform(0.20, y_stud, z_stud)
        b.box_c(p_tip[0], p_tip[1], p_tip[2], 0.08, 0.08, 0.08, light_col)

    # 6. ENTRANCE vs EXIT DETAILS
    if not is_exit:
        p_crest = transform(0.16, 0, 1.62)
        b.box_c(p_crest[0], p_crest[1], p_crest[2], 0.14, 0.36, 0.18, "cargo_dk")
        p_crest_glow = transform(0.22, 0, 1.62)
        b.box_c(p_crest_glow[0], p_crest_glow[1], p_crest_glow[2], 0.04, 0.28, 0.10, "portal_b_lt")
    else:
        for sgn_z in (-1, 1):
            p_fin = transform(0.20, 0, sgn_z * 1.65)
            b.box_c(p_fin[0], p_fin[1], p_fin[2], 0.16, 0.42, 0.12,
                    {"front": "boost_arrow", "side": "portal_o", "back": "cargo_dk"})

    return b


def portal_blue():
    return build_reference_portal("portal_b", "portal_b_lt", "portal_b_dk", is_exit=False)


def portal_orange():
    return build_reference_portal("portal_o", "portal_o_lt", "portal_o_dk", is_exit=True)


def portal_orange():
    return build_reference_portal("portal_o", "portal_o_lt", "portal_o_dk", is_exit=True)


def chamber_sign():
    """Aperture Science style Test Chamber Signboard (number 27 + hazard glyphs)."""
    b = Builder()
    b.box_c(0, 0.05, 0, 2.3, 0.12, 4.3, "cargo_dk")
    b.box_c(0, -0.02, 0, 2.1, 0.06, 4.1, "white")
    b.box_c(0, -0.06, 1.75, 1.9, 0.04, 0.32, "cargo_dk")
    b.box_c(-0.75, -0.07, 1.75, 0.22, 0.04, 0.22, "portal_b_lt")

    # Chamber number "27" pixel glyphs
    b.box_c(-0.4, -0.06, 1.25, 0.55, 0.03, 0.12, "black")
    b.box_c(-0.16, -0.06, 1.02, 0.14, 0.03, 0.36, "black")
    b.box_c(-0.4, -0.06, 0.82, 0.55, 0.03, 0.12, "black")
    b.box_c(-0.62, -0.06, 0.62, 0.14, 0.03, 0.36, "black")
    b.box_c(-0.4, -0.06, 0.42, 0.55, 0.03, 0.12, "black")

    b.box_c(0.4, -0.06, 1.25, 0.55, 0.03, 0.12, "black")
    b.box_c(0.62, -0.06, 0.84, 0.14, 0.03, 0.84, "black")

    for k in range(9):
        b.box_c(-0.68 + k * 0.17, -0.06, 0.15, 0.11, 0.03, 0.07, "black" if k < 6 else "steel_lt")

    for row in range(2):
        for col in range(3):
            cx = -0.55 + col * 0.55
            cz = -0.42 - row * 0.58
            b.box_c(cx, -0.055, cz, 0.44, 0.02, 0.46, "asphalt_lt")
            b.box_c(cx, -0.06, cz, 0.46, 0.015, 0.48, "steel_dk")
            if row == 0 and col == 0:
                b.box_c(cx, -0.07, cz + 0.08, 0.08, 0.02, 0.08, "portal_b")
                b.box_c(cx, -0.07, cz - 0.06, 0.14, 0.02, 0.18, "portal_b")
            elif row == 0 and col == 1:
                b.box_c(cx - 0.08, -0.07, cz, 0.06, 0.02, 0.22, "portal_b")
                b.box_c(cx + 0.08, -0.07, cz, 0.06, 0.02, 0.22, "portal_o")
            elif row == 0 and col == 2:
                b.box_c(cx, -0.07, cz, 0.22, 0.02, 0.22, "hazard")
            else:
                b.box_c(cx, -0.07, cz, 0.30, 0.02, 0.16, "cargo_dk")
    return b


def lab_generator():
    """Quantum Core / Fusion Reactor landmark for Quantum Lab."""
    b = Builder()
    b.box_c(0, 0, 0.15, 2.2, 2.2, 0.3, {"top": "cargo_lt", "side": "cargo", "bottom": "black"})
    for i, a in enumerate([k * math.pi / 4 for k in range(8)]):
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        col = "lane" if i % 2 == 0 else "hazard"
        b.box_c(x, y, 0.32, 0.22, 0.22, 0.05, col)
    # Reactor core containment cylinder
    b.frustum(0, 0, 0.3, 2.4, 0.55, 0.55, 8, {"side": "lab_light", "top": "white", "bottom": "lab_dark"})
    b.frustum(0, 0, 0.4, 2.3, 0.32, 0.32, 8, {"side": "white", "top": "white", "bottom": "white"})
    # Magnetic containment rings
    for z in (0.85, 1.35, 1.85):
        b.frustum(0, 0, z - 0.08, z + 0.08, 0.74, 0.74, 8, {"side": "cargo_dk", "top": "chrome_dk", "bottom": "cargo_dk"})
        b.frustum(0, 0, z - 0.04, z + 0.04, 0.78, 0.78, 8, {"side": "portal_b_lt", "top": "portal_b_lt", "bottom": "portal_b_lt"})
    # Top capacitor cap
    b.box_c(0, 0, 2.55, 1.3, 1.3, 0.3, {"top": "chrome_dk", "side": "cargo_dk", "bottom": "cargo"})
    b.frustum(0, 0, 2.7, 3.05, 0.26, 0.08, 6, {"side": "lab_light", "top": "white", "bottom": "lab_light"})
    # Corner support struts
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_c(sx * 0.85, sy * 0.85, 1.4, 0.16, 0.16, 2.2, "cargo")
            b.box_c(sx * 0.85, sy * 0.85, 0.35, 0.24, 0.24, 0.15, "cargo_dk")
            b.box_c(sx * 0.85, sy * 0.85, 2.45, 0.24, 0.24, 0.15, "cargo_dk")
    return b


def lab_terminal():
    """Sci-Fi Mainframe Server Rack / Diagnostic Terminal."""
    b = Builder()
    b.box_c(0, 0, 0.95, 0.9, 0.65, 1.9, {"side": "cargo_dk", "front": "cargo_dk", "back": "cargo_dk", "top": "cargo_lt", "bottom": "black"})
    for z in (0.35, 0.75, 1.15, 1.55):
        b.box_c(0, -0.34, z, 0.76, 0.04, 0.32, "lab_panel")
        for x in (-0.25, -0.15, -0.05, 0.05, 0.15, 0.25):
            b.box_c(x, -0.37, z, 0.05, 0.02, 0.24, "cargo_dk")
        b.box_c(-0.32, -0.37, z + 0.08, 0.04, 0.02, 0.04, "flag_g")
        b.box_c(-0.32, -0.37, z, 0.04, 0.02, 0.04, "lane")
        b.box_c(-0.32, -0.37, z - 0.08, 0.04, 0.02, 0.04, "flower_r")
    # Angled diagnostic terminal display console
    b.box_c(0.55, -0.1, 0.85, 0.22, 0.42, 0.06, "cargo_dk")
    b.box_c(0.55, -0.15, 1.05, 0.06, 0.34, 0.32, "cargo_dk")
    b.box_c(0.52, -0.15, 1.05, 0.02, 0.30, 0.28, "portal_b_lt")
    # Data cables
    b.tube((-0.35, -0.35, 0.04), (-0.35, -0.65, 0.04), 0.04, 0.04, 5, "cargo_dk")
    b.tube((0.15, -0.35, 0.04), (0.45, -0.65, 0.04), 0.045, 0.045, 5, "cargo_dk")
    return b


def energy_pylon():
    """High-voltage Quantum Relay Pylon / Tesla Spire."""
    b = Builder()
    b.box_c(0, 0, 0.15, 1.1, 1.1, 0.3, {"top": "base_hi", "side": "base", "bottom": "base_dk"})
    b.frustum(0, 0, 0.3, 3.8, 0.45, 0.16, 4, {"side": "cargo_dk", "top": "chrome_dk", "bottom": "cargo_dk"}, angle0=math.pi / 4)
    for z in (1.8, 2.7, 3.4):
        span = 1.3 - (z - 1.8) * 0.25
        b.box_c(0, 0, z, span, 0.12, 0.10, "cargo_dk")
        for sx in (-1, 1):
            x = sx * (span * 0.5 - 0.06)
            for iz in (-0.08, 0.0, 0.08):
                b.box_c(x, 0, z + iz, 0.14, 0.14, 0.04, "lab_panel")
            b.box_c(x, 0, z + 0.14, 0.08, 0.08, 0.08, "lab_light")
    b.frustum(0, 0, 3.8, 4.15, 0.14, 0.04, 6, {"side": "chrome", "top": "white", "bottom": "chrome_dk"})
    b.frustum(0, 0, 4.15, 4.45, 0.24, 0.24, 6, {"side": "lab_light", "top": "white", "bottom": "portal_b_lt"})
    return b


def cactus_saguaro():
    """Desert Saguaro Cactus for Canyon levels."""
    b = Builder()
    b.frustum(0, 0, 0, 3.2, 0.24, 0.21, 7, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
    b.frustum(0, 0, 3.2, 3.45, 0.21, 0.08, 7, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"})
    b.tube((0, 0, 1.4), (-0.65, 0, 1.45), 0.16, 0.15, 6, "leaf_dk")
    b.tube((-0.65, 0, 1.45), (-0.65, 0, 2.65), 0.15, 0.14, 6, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
    b.frustum(-0.65, 0, 2.65, 2.85, 0.14, 0.05, 6, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"})
    b.tube((0, 0, 1.9), (0.72, 0, 1.95), 0.15, 0.14, 6, "leaf_dk")
    b.tube((0.72, 0, 1.95), (0.72, 0, 3.0), 0.14, 0.13, 6, {"side": "leaf_dk", "top": "leaf", "bottom": "leaf_dk"})
    b.frustum(0.72, 0, 3.0, 3.2, 0.13, 0.05, 6, {"side": "leaf", "top": "leaf_lt", "bottom": "leaf_dk"})
    b.box_c(-0.65, 0, 2.9, 0.12, 0.12, 0.10, "flower_r")
    b.box_c(0.72, 0, 3.25, 0.12, 0.12, 0.10, "flower_y")
    b.box_c(0, 0, 3.5, 0.14, 0.14, 0.10, "flower_r")
    return b


def lantern_post():
    """Alpine Trail Lantern Post for Valley & Mountain levels."""
    b = Builder()
    b.box_c(0, 0, 0.12, 0.36, 0.36, 0.24, {"top": "base_hi", "side": "base", "bottom": "base_dk"})
    b.box_c(0, 0, 1.32, 0.16, 0.16, 2.16, {"top": "wood_end", "side": "wood_dk", "bottom": "wood_dk"})
    b.box_c(0.20, 0, 2.32, 0.56, 0.12, 0.12, {"top": "wood_lt", "side": "wood", "bottom": "wood_dk"})
    b.tube((0.08, 0, 1.9), (0.35, 0, 2.25), 0.05, 0.05, 4, "wood_dk")
    b.box_c(0, 0, 2.45, 0.22, 0.22, 0.12, {"top": "wood_lt", "side": "wood", "bottom": "wood_dk"})
    b.tube((0.42, 0, 2.32), (0.42, 0, 2.05), 0.02, 0.02, 4, "black")
    b.frustum(0.42, 0, 1.95, 2.05, 0.22, 0.06, 4, {"side": "black", "top": "black", "bottom": "cargo_dk"}, angle0=math.pi / 4)
    b.box_c(0.42, 0, 1.80, 0.26, 0.26, 0.30, {"top": "black", "side": "lane", "bottom": "black"})
    b.box_c(0.42, 0, 1.80, 0.14, 0.14, 0.18, "light")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box_c(0.42 + sx * 0.13, sy * 0.13, 1.80, 0.03, 0.03, 0.30, "black")
    b.box_c(0.42, 0, 1.63, 0.28, 0.28, 0.04, "black")
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
