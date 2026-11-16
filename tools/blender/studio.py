"""
Studio environment for Bridge Mad hero models.

Builds a deterministic product-shot scene in Blender 5.2 / EEVEE:
  * palette material (the same 256x256 atlas the game samples, Nearest filtering),
  * three-stop gradient world + seamless floor,
  * soft three-point light rig (warm key / cool fill / rim),
  * 65 mm 3/4 camera framed on the object bounds,
  * AgX grading, raytraced shadows and a subtle contact shadow.

Usable from the Blender MCP bridge (Window > MCP for Unity > Blender Bridge):

    import runpy; runpy.run_path(r"D:/DProjects/Bridge/tools/blender/studio.py")

and from a headless render pass (see render_previews.py):

    "D:/Programs/Blender/blender.exe" -b -P tools/blender/render_previews.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PNG = ROOT / "assets" / "textures" / "palette.png"

# Background gradient (linear-ish sRGB values, AgX will roll them off).
BG_TOP = (0.42, 0.51, 0.66)
BG_HORIZON = (0.30, 0.36, 0.47)
BG_BOTTOM = (0.13, 0.16, 0.21)

FLOOR_COL = (0.34, 0.37, 0.42)
FLOOR_ROUGH = 0.72

STUDIO = "STUDIO"
MODELS = "MODELS"
SOURCES = "SOURCES"

MATERIAL = "palette_voxel"


# --------------------------------------------------------------------------- utilities
def srgb(r: float, g: float, b: float, a: float = 1.0):
    """sRGB -> linear, so hand-picked colors look like the hex values in palette.js."""

    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b), a)


def _try(obj, attr: str, value) -> None:
    try:
        setattr(obj, attr, value)
    except (AttributeError, TypeError, ValueError):
        pass


def collection(name: str):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def make_active(coll) -> None:
    for layer in bpy.context.view_layer.layer_collection.children:
        if layer.collection == coll:
            bpy.context.view_layer.active_layer_collection = layer
            return


def link(ob, coll) -> None:
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    coll.objects.link(ob)


# --------------------------------------------------------------------------- scene
def clear_scene() -> None:
    """Wipe the studio + model objects, keeping anything the artist parked in SOURCES."""
    keep = set()
    sources = bpy.data.collections.get(SOURCES)
    if sources is not None:
        keep = {ob.name for ob in sources.all_objects}

    for ob in list(bpy.data.objects):
        if ob.name in keep:
            continue
        bpy.data.objects.remove(ob, do_unlink=True)

    for block in (bpy.data.meshes, bpy.data.lights, bpy.data.cameras, bpy.data.curves):
        for item in list(block):
            if item.users == 0:
                block.remove(item)

    if sources is not None:
        sources.hide_render = True
        for layer in bpy.context.view_layer.layer_collection.children:
            if layer.collection == sources:
                layer.exclude = True


def palette_material():
    """Image-texture material sampling one texel per face, exactly like voxel.material."""
    mat = bpy.data.materials.get(MATERIAL)
    if mat is None:
        mat = bpy.data.materials.new(MATERIAL)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (620, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (300, 0)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.location = (-40, 0)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    coord.location = (-260, 0)

    img = bpy.data.images.get("palette.png")
    if img is None:
        img = bpy.data.images.load(str(PALETTE_PNG), check_existing=True)
    img.colorspace_settings.name = "sRGB"
    tex.image = img
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"

    nt.links.new(coord.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    _try(bsdf.inputs["Roughness"], "default_value", 0.58)
    _try(bsdf.inputs["Metallic"], "default_value", 0.0)
    for name, value in (("Specular IOR Level", 0.35), ("Coat Weight", 0.0)):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = value
    return mat


def setup_world() -> None:
    world = bpy.data.worlds.get("StudioWorld") or bpy.data.worlds.new("StudioWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputWorld")
    out.location = (700, 0)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.location = (480, 0)
    bg.inputs["Strength"].default_value = 1.0

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (200, 0)
    stops = ((0.0, BG_BOTTOM), (0.52, BG_HORIZON), (1.0, BG_TOP))
    elems = ramp.color_ramp.elements
    elems[0].position, elems[0].color = stops[0][0], srgb(*stops[0][1])
    elems[1].position, elems[1].color = stops[2][0], srgb(*stops[2][1])
    mid = elems.new(stops[1][0])
    mid.color = srgb(*stops[1][1])

    maprange = nt.nodes.new("ShaderNodeMapRange")
    maprange.location = (-40, 0)
    maprange.inputs["From Min"].default_value = -1.0
    maprange.inputs["From Max"].default_value = 1.0
    maprange.inputs["To Min"].default_value = 0.0
    maprange.inputs["To Max"].default_value = 1.0
    maprange.clamp = True

    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    sep.location = (-240, 0)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    coord.location = (-420, 0)

    nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], maprange.inputs["Value"])
    nt.links.new(maprange.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def setup_backdrop(coll) -> None:
    """Seamless cyclorama: floor that sweeps up into a back wall (no horizon line)."""
    profile = [(-18.0, 0.0), (2.0, 0.0)]
    radius = 6.0
    arc_steps = 10
    for i in range(1, arc_steps + 1):
        a = -math.pi / 2 + (math.pi / 2) * i / arc_steps
        profile.append((2.0 + math.cos(a) * radius, 6.0 + math.sin(a) * radius))
    profile.append((8.0, 16.0))

    verts, faces = [], []
    for x in (-24.0, 24.0):
        for (y, z) in profile:
            verts.append((x, y, z))
    n = len(profile)
    for i in range(n - 1):
        faces.append((i, i + 1, n + i + 1, n + i))

    mesh = bpy.data.meshes.get("StudioBackdrop") or bpy.data.meshes.new("StudioBackdrop")
    mesh.clear_geometry()
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.get("StudioBackdrop") or bpy.data.objects.new("StudioBackdrop", mesh)
    link(ob, coll)

    mat = bpy.data.materials.get("StudioBackdropMat")
    if mat is None:
        mat = bpy.data.materials.new("StudioBackdropMat")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = srgb(*FLOOR_COL)
        bsdf.inputs["Roughness"].default_value = FLOOR_ROUGH
        _try(bsdf.inputs["Specular IOR Level"], "default_value", 0.2)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


def _area_light(name: str, coll, loc, energy, size, color, size_y=None, shape="SQUARE"):
    data = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = tuple(color)[:3]
    data.shape = "RECTANGLE" if size_y else shape
    data.size = size
    if size_y:
        data.size_y = size_y
    _try(data, "use_shadow_jitter", True)
    ob = bpy.data.objects.get(name) or bpy.data.objects.new(name, data)
    link(ob, coll)
    ob.location = Vector(loc)
    return ob


def aim(ob, target: Vector) -> None:
    direction = target - ob.location
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_lights(coll, center: Vector, radius: float) -> list:
    """Softbox rig scaled to the subject, so small props and tall towers both read well."""
    s = max(radius, 1.0)
    spec = (
        # name,        direction offset,      power,        size,          color
        ("Key",  Vector((1.05, -1.45, 1.35)), 130.0 * s * s, 3.2 * s, srgb(1.00, 0.95, 0.87)),
        ("Fill", Vector((-1.75, -0.95, 0.55)), 45.0 * s * s, 4.6 * s, srgb(0.80, 0.88, 1.00)),
        ("Rim", Vector((-0.75, 1.55, 1.05)), 110.0 * s * s, 2.4 * s, srgb(0.82, 0.90, 1.00)),
        ("Top", Vector((0.0, 0.15, 2.4)), 60.0 * s * s, 4.0 * s, srgb(1.00, 0.99, 0.96)),
    )
    lights = []
    for name, offset, energy, size, color in spec:
        ob = _area_light(name, coll, center + offset * s, energy, size, color)
        aim(ob, center)
        ob.visible_camera = False
        lights.append(ob)
    return lights


def setup_camera(coll):
    data = bpy.data.cameras.get("StudioCam") or bpy.data.cameras.new("StudioCam")
    data.lens = 65.0
    data.sensor_width = 36.0
    data.clip_start = 0.05
    data.clip_end = 500.0
    data.dof.use_dof = True
    data.dof.aperture_fstop = 11.0
    ob = bpy.data.objects.get("StudioCam") or bpy.data.objects.new("StudioCam", data)
    link(ob, coll)
    bpy.context.scene.camera = ob
    return ob


def setup_render(size: int = 900, samples: int = 64) -> None:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.render.filter_size = 1.5

    ee = sc.eevee
    _try(ee, "taa_render_samples", samples)
    _try(ee, "use_raytracing", True)
    _try(ee, "use_shadows", True)
    _try(ee, "shadow_ray_count", 2)
    _try(ee, "shadow_step_count", 8)
    _try(ee, "use_fast_gi", True)
    _try(ee, "fast_gi_method", "GLOBAL_ILLUMINATION")
    _try(ee, "fast_gi_distance", 1.2)
    _try(ee.ray_tracing_options, "resolution_scale", "1")
    _try(ee.ray_tracing_options, "use_denoise", True)

    vs = sc.view_settings
    vs.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "AgX - Base Contrast", "None"):
        try:
            vs.look = look
            break
        except TypeError:
            continue
    vs.exposure = -0.15
    vs.gamma = 1.0


def set_viewport_rendered(camera) -> None:
    """Make the interactive viewport (and MCP screenshots) show the studio render."""
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type != "VIEW_3D":
                continue
            for space in area.spaces:
                if space.type != "VIEW_3D":
                    continue
                space.shading.type = "RENDERED"
                space.shading.use_scene_lights = True
                space.shading.use_scene_world = True
                space.overlay.show_floor = False
                space.overlay.show_axis_x = False
                space.overlay.show_axis_y = False
                space.overlay.show_extras = False
                space.overlay.show_relationship_lines = False
                space.region_3d.view_perspective = "CAMERA"
                if camera is not None:
                    space.camera = camera
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            area.tag_redraw()


def object_bounds(objs) -> tuple[Vector, float]:
    pts = []
    for ob in objs:
        if ob.type != "MESH" or not ob.data.vertices:
            continue
        for corner in ob.bound_box:
            pts.append(ob.matrix_world @ Vector(corner))
    if not pts:
        return Vector((0, 0, 0)), 1.0
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.35)
    return center, radius


def frame_camera(camera, center: Vector, radius: float, direction=(0.72, -1.0, 0.42), margin: float = 1.16) -> None:
    cam = camera.data
    fov = 2.0 * math.atan(cam.sensor_width * 0.5 / cam.lens)
    dist = radius / math.tan(fov * 0.5) * margin
    camera.location = center + Vector(direction).normalized() * dist
    aim(camera, center)
    cam.dof.focus_distance = dist


def build(size: int = 900, samples: int = 64, center: Vector | None = None, radius: float = 1.0):
    """(Re)build the studio around a subject. Returns the studio objects."""
    clear_scene()
    studio = collection(STUDIO)
    collection(MODELS)
    collection(SOURCES)

    setup_world()
    backdrop = setup_backdrop(studio)
    center = center or Vector((0, 0, 1.0))
    radius = radius or 1.0
    setup_lights(studio, center, radius)
    camera = setup_camera(studio)
    frame_camera(camera, center, radius)
    setup_render(size, samples)
    return {"camera": camera, "backdrop": backdrop, "collection": studio}


def render(path, size: int | None = None, samples: int | None = None) -> Path:
    sc = bpy.context.scene
    if size:
        sc.render.resolution_x = size
        sc.render.resolution_y = size
    if samples:
        _try(sc.eevee, "taa_render_samples", samples)
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    sc.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    return out


def import_model(glb) -> list:
    """Import a .glb and park it in the MODELS collection with the palette material."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    fresh = [ob for ob in bpy.data.objects if ob not in before]
    coll = collection(MODELS)
    mat = palette_material()
    for ob in fresh:
        link(ob, coll)
        if ob.type == "MESH":
            ob.data.materials.clear()
            ob.data.materials.append(mat)
            for poly in ob.data.polygons:
                poly.use_smooth = False
    return fresh


def showcase(glb, out_png, size: int = 900, samples: int = 48, direction=(0.72, -1.0, 0.42)):
    """Open a clean studio around one .glb and render it from `direction`.

    Models centred on the origin (portals, the chamber sign) are lifted so their lowest
    vertex rests on the backdrop instead of sinking through it.
    """
    probe = import_model(glb)
    center, radius = object_bounds(probe)
    build(size=size, samples=samples, center=center, radius=radius)
    objs = import_model(glb)
    lowest = min((ob.matrix_world @ Vector(c)).z for ob in objs for c in ob.bound_box)
    for ob in objs:
        ob.location.z -= lowest
        ob.location.z += 0.002
    bpy.context.view_layer.update()
    center, radius = object_bounds(objs)
    cam = bpy.data.objects["StudioCam"]
    frame_camera(cam, center, radius, direction=direction)
    return render(out_png, size, samples)


if __name__ == "__main__":
    build()
    print("[studio] ready: gradient world, softbox rig, 65 mm camera, palette material")
