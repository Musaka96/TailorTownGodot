"""Render every mesh's skin weights, one image per bone, for checking a paint job by eye.

    blender.exe --background --factory-startup --python tools/blender/weight_renders.py -- \
        --glb assets/characters/CHARTGEN2.glb --out IMPORT/CHARREWORK/report/weights \
        [--meshes jacket,legs,...]

Rest pose, orthographic front and back, 1600 x 2000 px, each mesh on its own on white.
The colour is Blender's weight-paint ramp (0 blue, 0.25 cyan, 0.5 green, 0.75 yellow,
1 red; a vertex with no weight at all on the bone is a deep blue), baked per bone into a
colour attribute and rendered flat in the workbench, with a thin black wireframe laid
over it. Files: <out>/<mesh>__<bone>__<front|back>.png (spaces in names become _).
tools/weight_sheets.py then tiles them into one contact sheet per mesh.
"""

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
RAMP = ((0.0, (0.0, 0.0, 1.0)), (0.25, (0.0, 1.0, 1.0)), (0.5, (0.0, 1.0, 0.0)),
        (0.75, (1.0, 1.0, 0.0)), (1.0, (1.0, 0.0, 0.0)))
ZERO = (0.0, 0.0, 0.45)
WIDTH, HEIGHT = 1600, 2000


def ramp(w):
    if w <= 0.0:
        return ZERO
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if w <= b:
            t = (w - a) / (b - a)
            return tuple(ca[k] + (cb[k] - ca[k]) * t for k in range(3))
    return RAMP[-1][1]


def main(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--meshes", default="")
    ns = p.parse_args(args)
    glb = Path(ns.glb) if Path(ns.glb).is_absolute() else ROOT / ns.glb
    out = Path(ns.out) if Path(ns.out).is_absolute() else ROOT / ns.out
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    for a in (o for o in bpy.data.objects if o.type == "ARMATURE"):
        a.data.pose_position = "REST"
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.vertex_groups]
    if ns.meshes:
        wanted = [m.strip() for m in ns.meshes.split(",")]
        meshes = [o for o in meshes if o.name in wanted]
    scene = _scene()
    files = []
    for obj in meshes:
        files += _render_mesh(scene, obj, meshes, out)
    print("weight_renders: %d files in %s" % (len(files), out))
    for f in files:
        print("  " + f)
    return 0


def _scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_object_outline = False
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = WIDTH
    scene.render.resolution_y = HEIGHT
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("white")
    world.color = (1.0, 1.0, 1.0)
    scene.world = world
    cam_data = bpy.data.cameras.new("weights_cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("weights_cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene


def _render_mesh(scene, obj, meshes, out):
    """Every bone that carries weight on `obj`, front and back."""
    names = {g.index: g.name for g in obj.vertex_groups}
    per_bone = {}
    for v in obj.data.vertices:
        for g in v.groups:
            if g.weight > 0.001:
                per_bone.setdefault(names[g.group], {})[v.index] = g.weight
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o is not obj
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    size = max(hi.z - lo.z, (hi.x - lo.x) * HEIGHT / WIDTH) * 1.08
    wire = _wire_copy(obj, size)
    attr = obj.data.color_attributes.get("weights") or obj.data.color_attributes.new(
        "weights", "FLOAT_COLOR", "POINT")
    obj.data.color_attributes.active_color = attr
    files = []
    tag = obj.name.replace(" ", "_")
    centre = (lo + hi) * 0.5
    cam = scene.camera
    cam.data.ortho_scale = size
    for bone in sorted(per_bone):
        weights = per_bone[bone]
        for i in range(len(obj.data.vertices)):
            c = ramp(weights.get(i, 0.0))
            attr.data[i].color = (c[0], c[1], c[2], 1.0)
        obj.data.update()
        for view, sign in (("front", -1.0), ("back", 1.0)):
            cam.location = Vector((centre.x, centre.y + sign * 10.0, centre.z))
            cam.rotation_euler = (1.5707963, 0.0, 0.0 if sign < 0 else 3.14159265)
            path = out / ("%s__%s__%s.png" % (tag, bone, view))
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            files.append(str(path))
    bpy.data.objects.remove(wire, do_unlink=True)
    return files


def _wire_copy(obj, size):
    """A black wireframe of the mesh laid just over it."""
    mesh = obj.data.copy()
    wire = bpy.data.objects.new(obj.name + "_wire", mesh)
    bpy.context.scene.collection.objects.link(wire)
    wire.matrix_world = obj.matrix_world.copy()
    for m in list(wire.modifiers):
        wire.modifiers.remove(m)
    col = mesh.color_attributes.new("black", "FLOAT_COLOR", "POINT")
    for d in col.data:
        d.color = (0.0, 0.0, 0.0, 1.0)
    mesh.color_attributes.active_color = col
    mod = wire.modifiers.new("wire", "WIREFRAME")
    tris = sum(len(poly.vertices) - 2 for poly in mesh.polygons)
    # thinner on a dense mesh, or the wire hides the colours
    mod.thickness = size * 0.0009 * min(1.0, (3000.0 / max(tris, 1)) ** 0.5)
    mod.offset = 1.0
    mod.use_replace = True
    wire.hide_render = False
    return wire


if __name__ == "__main__":
    sys.exit(main(sys.argv))
