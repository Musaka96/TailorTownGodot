"""Tripo heads (a shaved base head + a grid of hair+skull heads) -> Rig_Medium head parts.

Run headless:

    blender.exe --background --factory-startup --python tools/blender/tripo_heads.py -- \
        [--src IMPORT/CHARREWORK/heads.blend] [--target assets/characters/CHARTGEN2.glb] \
        [--rig assets/characters/CHARTGEN1.glb] [--out-dir assets/characters/parts] \
        [--report-dir IMPORT/CHARREWORK/report/heads] [--no-sheet]

What the file holds (see docs/HEAD_POOL_HANDOFF.md): every mesh object is split into
loose shells, and the shells sort themselves:
  * a SKULL is a closed shell of a few hundred faces or more (it may carry its ears and
    a neck stub);
  * a HAIR is a large open shell, paired with the skull whose cell it sits in;
  * the rest are small pieces (ears) that belong to the skull whose box holds them;
  * the BALD base is the skull no hair sits on.
The hair heads are named by their place in the grid: head_tl, head_tr, head_bl, head_br
for a 2 x 2 grid, head_r<row>c<col> otherwise.

Every head is fitted to the rig by its skull: the neck stub is found (the lowest slice of
the skull before it widens) and left out of the measure; the skull above it is scaled to
the height of the target's (the Tripo gentleman's `head` in CHARTGEN2.glb) and centred on
it. The hair takes its own skull's transform. Full mesh, no decimation.

Exports, all bound 100% to bone `head` of Rig_Medium (the rig renames it head_2 at load
and CharacterRig._rebind_skin maps it):
  <out-dir>/tripo_head_<cell>_m.glb   `head` = that head's own skull (+ ears), `Hair`
  <out-dir>/tripo_bald_<cell>_m.glb   `head` = the bald skull + ears, `Hair` = that hair
      moved onto the bald skull (its own skull mapped onto the bald one by height and
      centre), with every hair vertex that ends up inside the skull lifted LIFT outside.
Plus a skull-shape table (how far each hair head's skull is from the bald one once both
are normalised) and a fit sheet in --report-dir.
"""

import argparse
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tripo_character as tc  # noqa: E402  (rig import, glb checks, parenting)

ROOT = Path(__file__).resolve().parents[2]
LIFT = 0.004  # rig metres a lifted hair vertex sits outside the skull
SKULL_MIN_FACES = 300
HAIR_MIN_FACES = 800
NECK_WIDEN = 1.6  # the neck stub ends where the skull gets this much wider than the stub
TILE = 700

_LOG = []


def log(text=""):
    print(text)
    _LOG.append(text)


def _arguments(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(prog="tripo_heads.py")
    p.add_argument("--src", default="IMPORT/CHARREWORK/heads.blend")
    p.add_argument("--target", default="assets/characters/CHARTGEN2.glb")
    p.add_argument("--rig", default="assets/characters/CHARTGEN1.glb")
    p.add_argument("--out-dir", default="assets/characters/parts")
    p.add_argument("--report-dir", default="IMPORT/CHARREWORK/report/heads")
    p.add_argument("--no-sheet", action="store_true")
    ns = p.parse_args(args)
    for key in ("src", "target", "rig", "out_dir", "report_dir"):
        path = Path(getattr(ns, key))
        setattr(ns, key, path if path.is_absolute() else (ROOT / path).resolve())
    return ns


# ---------------------------------------------------------------------------------------
# meshes as plain arrays: (verts: [Vector], faces: [tuple]) in world space


def _arrays(objs):
    verts, faces = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        faces += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
    return verts, faces


def _moved(mesh, m):
    return [m @ v for v in mesh[0]], mesh[1]


def _join(*meshes):
    verts, faces = [], []
    for vs, fs in meshes:
        base = len(verts)
        verts += list(vs)
        faces += [tuple(base + i for i in f) for f in fs]
    return verts, faces


def _bounds(verts):
    lo = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    hi = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    return lo, hi


def _neck_cut(verts):
    """Height where the neck stub ends: slices of 1% of the height from the bottom up, the
    first whose width passes NECK_WIDEN x the stub's. No stub: the bottom."""
    lo, hi = _bounds(verts)
    h = hi.z - lo.z
    step = 0.01 * h

    def width(z0, z1):
        xs = [v.x for v in verts if z0 <= v.z < z1]
        return (max(xs) - min(xs)) if len(xs) > 2 else 0.0

    stub = width(lo.z, lo.z + 3 * step)
    if stub <= 0.0:
        return lo.z
    z = lo.z
    while z < lo.z + 0.5 * h:
        if width(z, z + step) > NECK_WIDEN * stub:
            return z
        z += step
    return lo.z


def _skull_frame(verts):
    """(height, centre) of a skull above its neck cut."""
    cut = _neck_cut(verts)
    above = [v for v in verts if v.z >= cut]
    lo, hi = _bounds(above)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (cut + hi.z) / 2))
    return hi.z - cut, centre, cut


def _fit(src_verts, dst_height, dst_centre):
    h, c, cut = _skull_frame(src_verts)
    s = dst_height / h
    return Matrix.Translation(dst_centre) @ Matrix.Diagonal((s, s, s, 1.0)) @ Matrix.Translation(-c), s


# ---------------------------------------------------------------------------------------
# step 1: read the file into skulls, hairs, ears


def _load(ns):
    bpy.ops.wm.open_mainfile(filepath=str(ns.src))
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for o in meshes:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_select = False
        if o.data.users > 1:
            o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    for o in meshes:
        tc._select_only([o])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
    shells = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        open_edges = sum(1 for e in bm.edges if e.is_boundary)
        bm.free()
        verts = [v.co.copy() for v in o.data.vertices]
        lo, hi = _bounds(verts)
        shells.append({"obj": o, "faces": len(o.data.polygons), "open": open_edges,
                       "lo": lo, "hi": hi, "c": (lo + hi) / 2})
    return shells


def _sort(shells):
    skulls = [s for s in shells if s["open"] == 0 and s["faces"] >= SKULL_MIN_FACES]
    hairs = [s for s in shells if s["open"] > 0 and s["faces"] >= HAIR_MIN_FACES]
    small = [s for s in shells if s not in skulls and s not in hairs]
    for s in skulls:
        s["ears"], s["hair"] = [], None
    for h in hairs:
        best = min(skulls, key=lambda k: (Vector((k["c"].x, k["c"].z)) - Vector((h["c"].x, h["c"].z))).length)
        if best["hair"] is not None:
            log("  WARNING: two hairs over one skull; keeping the larger")
            if best["hair"]["faces"] >= h["faces"]:
                continue
        best["hair"] = h
    for e in small:
        for k in skulls:
            pad = 0.25 * (k["hi"] - k["lo"])
            if all(k["lo"][i] - pad[i] <= e["c"][i] <= k["hi"][i] + pad[i] for i in range(3)):
                k["ears"].append(e)
                break
        else:
            log("  small shell of %d faces at %s belongs to no skull: dropped" % (e["faces"], tuple(round(x, 3) for x in e["c"])))
    bald = [k for k in skulls if k["hair"] is None]
    grid = [k for k in skulls if k["hair"] is not None]
    if len(bald) != 1:
        raise SystemExit("expected exactly one skull with no hair (the bald base), found %d" % len(bald))
    # rows by height (top first), columns by x
    grid.sort(key=lambda k: -k["c"].z)
    rows = []
    for k in grid:
        if rows and abs(rows[-1][0]["c"].z - k["c"].z) < 0.5 * (k["hi"].z - k["lo"].z):
            rows[-1].append(k)
        else:
            rows.append([k])
    for r, row in enumerate(rows):
        row.sort(key=lambda k: k["c"].x)
        for c, k in enumerate(row):
            if len(rows) == 2 and len(row) == 2:
                k["name"] = ("t" if r == 0 else "b") + ("l" if c == 0 else "r")
            else:
                k["name"] = "r%dc%d" % (r + 1, c + 1)
    grid = [k for row in rows for k in row]
    log("  shells: %d skulls, %d hairs, %d small pieces" % (len(skulls), len(hairs), len(small)))
    for k in [bald[0]] + grid:
        log("    %-8s skull %4d faces (x %.2f..%.2f, z %.2f..%.2f), %d ear piece(s)%s" % (
            k.get("name", "bald"), k["faces"], k["lo"].x, k["hi"].x, k["lo"].z, k["hi"].z,
            len(k["ears"]), (", hair %d faces (%d open edges)" % (k["hair"]["faces"], k["hair"]["open"]))
            if k["hair"] else ""))
    return bald[0], grid


# ---------------------------------------------------------------------------------------
# step 2: fit, move hairs onto the bald skull, lift


def _target(ns):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ns.target))
    new = set(bpy.data.objects) - before
    head = next(o for o in new if o.type == "MESH" and o.name.split(".")[0] == "head")
    verts, _ = _arrays([head])
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    h, c, cut = _skull_frame(verts)
    log("  target: %s `head`, skull %.3f m tall above the neck cut at %.3f, centre (%.3f, %.3f, %.3f)"
        % (ns.target.name, h, cut, c.x, c.y, c.z))
    return h, c


def _lift(hair, skull):
    """Push every hair vertex inside the closed skull (behind the nearest surface point's
    normal) to LIFT outside it. Returns (moved hair, inside before, inside after)."""
    tree = BVHTree.FromPolygons(skull[0], skull[1])

    def inside(v):
        loc, n, _, _ = tree.find_nearest(v)
        return loc is not None and (v - loc).dot(n) < 0.0, loc, n

    verts = list(hair[0])
    before = 0
    for i, v in enumerate(verts):
        ins, loc, n = inside(v)
        if ins:
            before += 1
            verts[i] = loc + n * LIFT
    after = sum(1 for v in verts if inside(v)[0])
    return (verts, hair[1]), before, after


def _distances(a, b_tree):
    ds = []
    for v in a:
        loc, _, _, d = b_tree.find_nearest(v)
        if loc is not None:
            ds.append(d)
    return max(ds), sum(ds) / len(ds)


def _ear_tips(verts, cut):
    """The outermost vertex on each side, between the neck cut and the skull top."""
    above = [v for v in verts if v.z > cut]
    return max(above, key=lambda v: v.x), min(above, key=lambda v: v.x)


def build(ns):
    log("tripo_heads: %s" % ns.src)
    shells = _load(ns)
    bald, grid = _sort(shells)
    th, tcen = _target(ns)

    def skull_mesh(k):
        return _arrays([k["obj"]] + [e["obj"] for e in k["ears"]])

    bald_skull_only = _arrays([bald["obj"]])
    bald_full = skull_mesh(bald)
    fb, sb = _fit(bald_full[0], th, tcen)
    bald_rig = _moved(bald_full, fb)
    bald_skull_rig = _moved(bald_skull_only, fb)
    bh, bcen, bcut = _skull_frame(bald_full[0])
    log("\n== fit to the target (uniform scale by skull height, centred on the target skull)")
    log("  %-8s %8s %9s   %s" % ("head", "skull h", "scale", "offset (after scaling)"))
    log("  %-8s %8.3f %9.4f   %s" % ("bald", bh, sb, tuple(round(x, 3) for x in fb.to_translation())))
    heads = {"bald": {"head": bald_rig}}
    shape = []
    bald_tree = BVHTree.FromPolygons(bald_rig[0], bald_rig[1])
    b_tips = _ear_tips(bald_rig[0], _skull_frame(bald_rig[0])[2])
    for k in grid:
        name = k["name"]
        skull = skull_mesh(k)
        hair = _arrays([k["hair"]["obj"]])
        f, s = _fit(skull[0], th, tcen)
        h, c, cut = _skull_frame(skull[0])
        log("  %-8s %8.3f %9.4f   %s" % (name, h, s, tuple(round(x, 3) for x in f.to_translation())))
        own = {"head": _moved(skull, f), "Hair": _moved(hair, f)}
        # this skull mapped onto the bald one (height + centre), then the bald one's fit
        m, s2 = _fit(skull[0], bh, bcen)
        onto = fb @ m
        moved_hair = _moved(hair, onto)
        lifted, before, after = _lift(moved_hair, bald_skull_rig)
        swapped = {"head": bald_rig, "Hair": lifted, "_before": moved_hair,
                   "_inside": before, "_after": after}
        grid_on_bald = _moved(skull, onto)
        cut_on_bald = _skull_frame(grid_on_bald[0])[2]
        above = [v for v in grid_on_bald[0] if v.z > cut_on_bald]
        dmax, dmean = _distances(above, bald_tree)
        gtree = BVHTree.FromPolygons(grid_on_bald[0], grid_on_bald[1])
        bmax, bmean = _distances([v for v in bald_rig[0] if v.z > cut_on_bald], gtree)
        tips = _ear_tips(grid_on_bald[0], cut_on_bald)
        shape.append((name, dmax, dmean, bmax, bmean, tips, len(hair[0]), before, after))
        heads["head_" + name] = own
        heads["bald_" + name] = swapped
    log("\n== skull shape: each hair head's skull normalised onto the bald skull (rig metres)")
    log("  %-8s %22s %22s   %s" % ("head", "its skull -> bald", "bald -> its skull",
                                    "ear tips +x / -x (x, y, z)"))
    log("  %-8s %22s %22s   %s / %s" % ("bald", "", "", _pt(b_tips[0]), _pt(b_tips[1])))
    for name, dmax, dmean, bmax, bmean, tips, _, _, _ in shape:
        log("  %-8s  max %5.1f mean %4.1f mm  max %5.1f mean %4.1f mm   %s / %s" % (
            name, dmax * 1000, dmean * 1000, bmax * 1000, bmean * 1000, _pt(tips[0]), _pt(tips[1])))
    log("\n== hair moved onto the bald skull: vertices inside the skull, lifted %.0f mm out" % (LIFT * 1000))
    for name, _, _, _, _, _, nverts, before, after in shape:
        log("  %-8s %5d hair verts, %4d inside before (%.1f%%), %d after" % (
            name, nverts, before, 100.0 * before / nverts, after))
    return heads


def _pt(v):
    return "(%+.3f, %+.3f, %.3f)" % (v.x, v.y, v.z)


# ---------------------------------------------------------------------------------------
# step 3: export


def _export(ns, name, parts):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ns.rig))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    colours = {"head": (0.93, 0.76, 0.62), "Hair": (0.30, 0.19, 0.11)}
    for role in ("head", "Hair"):
        verts, faces = parts[role]
        me = bpy.data.meshes.new(role)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.validate()
        ob = bpy.data.objects.new(role, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        tc._select_only([ob])
        me.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        mat = bpy.data.materials.new("skin" if role == "head" else "hair")
        mat.diffuse_color = colours[role] + (1.0,)
        me.materials.append(mat)
        for bone in arm.data.bones:
            ob.vertex_groups.new(name=bone.name)
        ob.vertex_groups["head"].add(range(len(me.vertices)), 1.0, "REPLACE")
        tc._parent_to(ob, arm)
    path = ns.out_dir / ("tripo_%s_m.glb" % name)
    tc._select_only([])
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=False, export_yup=True,
        export_apply=False, export_skins=True, export_animations=False,
        export_materials="EXPORT", export_cameras=False, export_lights=False)
    g = tc._glb_json(path)
    nodes = g["nodes"]
    roots = [nodes[r].get("name") for r in g["scenes"][0]["nodes"]]
    joints = [nodes[j].get("name") for j in g["skins"][0]["joints"]] if g.get("skins") else []
    meshes = sorted(n.get("name") for n in nodes if "mesh" in n)
    skinned = all("skin" in n for n in nodes if "mesh" in n)
    tris = {n.get("name"): sum(g["accessors"][p["indices"]]["count"] // 3
                               for p in g["meshes"][n["mesh"]]["primitives"])
            for n in nodes if "mesh" in n}
    ok = roots == ["Rig_Medium"] and len(joints) == 22 and meshes == ["Hair", "head"] and skinned
    log("  %s %-26s head %5d tris, Hair %5d tris, %d KB" % (
        "ok  " if ok else "FAIL", path.name, tris.get("head", 0), tris.get("Hair", 0),
        path.stat().st_size // 1024))
    return ok


# ---------------------------------------------------------------------------------------
# step 4: fit sheet


def _sheet(ns, heads):
    import numpy as np

    out = ns.report_dir
    tiles_dir = out / "tiles"
    tiles_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    names = sorted(k[5:] for k in heads if k.startswith("head_"))
    for name in names:
        own, swap = heads["head_" + name], heads["bald_" + name]
        for view, yaw in (("front", 30.0), ("back", 200.0)):
            row = []
            for col, parts in enumerate((
                    [("skin", own["head"], None), ("hair", own["Hair"], None)],
                    [("skin", swap["head"], None), ("hair", swap["_before"], swap["head"])],
                    [("skin", swap["head"], None), ("hair", swap["Hair"], None)])):
                path = tiles_dir / ("%s_%s_%d.png" % (name, view, col))
                _render_tile(parts, yaw, path)
                row.append(str(path))
            rows.append(row)
    imgs = [[_load_png(p) for p in row] for row in rows]
    h, w = imgs[0][0].shape[:2]
    sheet = np.ones((h * len(imgs), w * 3, 4), dtype=np.float32)
    for r, row in enumerate(imgs):
        for c, im in enumerate(row):
            sheet[(len(imgs) - 1 - r) * h:(len(imgs) - r) * h, c * w:(c + 1) * w] = im
    img = bpy.data.images.new("fit_sheet", w * 3, h * len(imgs), alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = str(out / "fit_sheet.png")
    img.file_format = "PNG"
    img.save()
    log("\n  fit sheet: %s (rows: %s, each front 3/4 then back; columns: as delivered |"
        " on the bald skull, hair inside it red | after the lift)" % (
            out / "fit_sheet.png", ", ".join(names)))


def _load_png(path):
    import numpy as np

    im = bpy.data.images.load(path)
    px = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
    bpy.data.images.remove(im)
    return px


def _render_tile(parts, yaw, path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_object_outline = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = TILE
    scene.render.resolution_y = TILE
    world = bpy.data.worlds.new("w")
    world.color = (0.85, 0.87, 0.9)
    scene.world = world
    pts = []
    for kind, mesh, skull in parts:
        verts, faces = mesh
        me = bpy.data.meshes.new(kind)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        ob = bpy.data.objects.new(kind, me)
        scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        col = me.color_attributes.new("c", "FLOAT_COLOR", "POINT")
        base = (0.93, 0.76, 0.62) if kind == "skin" else (0.36, 0.22, 0.12)
        red = set()
        if skull is not None:
            tree = BVHTree.FromPolygons(skull[0], skull[1])
            for i, v in enumerate(verts):
                loc, n, _, _ = tree.find_nearest(v)
                if loc is not None and (v - loc).dot(n) < 0.0:
                    red.add(i)
        for i, d in enumerate(col.data):
            c = (1.0, 0.05, 0.05) if i in red else base
            d.color = (c[0], c[1], c[2], 1.0)
        me.color_attributes.active_color = col
        pts += list(verts)
    lo, hi = _bounds(pts)
    centre = (lo + hi) / 2
    size = max(hi - lo)
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = size * 1.15
    cam = bpy.data.objects.new("cam", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    r = math.radians(yaw)
    cam.location = centre + Vector((math.sin(r), -math.cos(r), 0.25)) * size * 3
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main(argv):
    ns = _arguments(argv)
    ns.out_dir.mkdir(parents=True, exist_ok=True)
    ns.report_dir.mkdir(parents=True, exist_ok=True)
    heads = build(ns)
    log("\n== export -> %s" % ns.out_dir)
    ok = True
    for name, parts in sorted(heads.items()):
        if name == "bald":
            continue
        ok = _export(ns, name, parts) and ok
    if not ns.no_sheet:
        _sheet(ns, heads)
    (ns.report_dir / "summary.txt").write_text("\n".join(_LOG) + "\n", encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
