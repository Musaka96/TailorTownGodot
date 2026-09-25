"""Tripo glasses (a grid of bald heads wearing glasses) -> Rig_Medium glasses parts.

Run headless:

    blender.exe --background --factory-startup --python tools/blender/tripo_glasses.py -- \
        [--src IMPORT/CHARREWORK/glasses.blend] [--names round,square,wire,halfmoon] \
        [--bald assets/characters/parts/tripo_bald_tl_m.glb] \
        [--own assets/characters/parts/tripo_head_tl_m.glb] \
        [--out-dir assets/characters/parts] [--report-dir IMPORT/CHARREWORK/report/glasses]

The file holds one head per grid cell, each a closed skull with a pair of glasses on it.
Shells sort themselves: a SKULL is a closed shell taller than a third of its cell, the
rest are glasses pieces and belong to the skull whose cell holds them. Cells are named in
reading order (top-left, top-right, bottom-left, bottom-right) by --names.

Each cell's skull is fitted onto the shaved base skull exactly as tools/blender/
tripo_heads.py fits a hair head's skull onto it (uniform scale by the skull's height above
the neck, centred on it); the glasses take the same transform, so they land on the shaved
skull in rig space. The glasses are split into `frames` and `lenses` (flat front-facing
panes that fill the rims; a style without lens geometry gets no `lenses` mesh), bound
100% to bone `head` and exported as <out-dir>/glasses_<name>.glb, full mesh.

The game places them per head with a forward offset from the face profile; this prints
the shaved skull's face depth at the height the glasses sit, which the offset is
measured from. A fit sheet shows every style on the shaved skull and on --own.
"""

import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tripo_heads as th  # noqa: E402  (skull fit, export, render tiles)

ROOT = Path(__file__).resolve().parents[2]
SKULL_MIN_FACES = 500
LENS_FILL = 0.55  # a lens pane covers at least this much of its bounding box
LENS_MIN_WIDTH = 0.25  # of the whole glasses width: a pane spans most of one rim
TILE = 700


def log(text=""):
    th.log(text)


def _arguments(argv):
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser(prog="tripo_glasses.py")
    p.add_argument("--src", default="IMPORT/CHARREWORK/glasses.blend")
    p.add_argument("--names", default="round,square,wire,halfmoon")
    p.add_argument("--bald", default="assets/characters/parts/tripo_bald_tl_m.glb")
    p.add_argument("--own", default="assets/characters/parts/tripo_head_tl_m.glb")
    p.add_argument("--rig", default="assets/characters/CHARTGEN1.glb")
    p.add_argument("--out-dir", default="assets/characters/parts")
    p.add_argument("--report-dir", default="IMPORT/CHARREWORK/report/glasses")
    ns = p.parse_args(args)
    for key in ("src", "bald", "own", "rig", "out_dir", "report_dir"):
        path = Path(getattr(ns, key))
        setattr(ns, key, path if path.is_absolute() else (ROOT / path).resolve())
    return ns


def _glb_mesh(path, name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    o = next(x for x in bpy.data.objects if x.type == "MESH" and x.name.split(".")[0] == name)
    arm = next(x for x in bpy.data.objects if x.type == "ARMATURE")
    head = arm.matrix_world @ arm.data.bones["head"].head_local
    return th._arrays([o]), head


def _cells(ns):
    """Skulls and their glasses pieces, in reading order."""
    shells = th._load(argparse.Namespace(src=ns.src))
    height = max(s["hi"].z for s in shells) - min(s["lo"].z for s in shells)
    skulls = [s for s in shells if s["open"] == 0 and s["faces"] >= SKULL_MIN_FACES
              and s["hi"].z - s["lo"].z > height / 3.0]
    rest = [s for s in shells if s not in skulls]
    for k in skulls:
        k["glasses"] = []
    for g in rest:
        best = min(skulls, key=lambda k: (Vector((k["c"].x, k["c"].z)) - Vector((g["c"].x, g["c"].z))).length)
        best["glasses"].append(g)
    for k in skulls:  # stray bits (Tripo debris) poke out of the main glasses shell's box
        main = max(k["glasses"], key=lambda g: g["faces"])
        pad = (main["hi"] - main["lo"]) * 0.1
        keep = [g for g in k["glasses"] if g is main or all(
            main["lo"][i] - pad[i] <= g["lo"][i] and g["hi"][i] <= main["hi"][i] + pad[i] for i in range(3))]
        k["dropped"] = [g for g in k["glasses"] if g not in keep]
        k["glasses"] = keep
    skulls.sort(key=lambda k: (-round(k["c"].z / (height / 2)), k["c"].x))
    names = ns.names.split(",")
    log("  %d skulls, %d glasses pieces" % (len(skulls), len(rest)))
    for i, k in enumerate(skulls):
        k["name"] = names[i] if i < len(names) else "style%d" % (i + 1)
        log("    %-9s skull %4d faces (x %.2f..%.2f, z %.2f..%.2f) | glasses %s%s" % (
            k["name"], k["faces"], k["lo"].x, k["hi"].x, k["lo"].z, k["hi"].z,
            " + ".join("%d faces (%s)" % (g["faces"], "closed" if g["open"] == 0 else "%d open edges" % g["open"])
                       for g in k["glasses"]),
            "".join(" | dropped stray %d faces at z %.2f (outside the glasses)" % (g["faces"], g["c"].z)
                    for g in k["dropped"])))
    return skulls


def _split_lenses(mesh):
    """(frames, lenses or None): lenses are flat, front-facing (-y) regions (faces joined
    across edges bending under 12 deg) that fill most of their bounding box and are wide
    and tall enough to be a pane, not a rim's flat front ring or a bridge bar."""
    verts, faces = mesh
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bm.faces.index_update()
    bm.normal_update()
    span = max(v.x for v in verts) - min(v.x for v in verts)
    done, lens = set(), set()
    for f in bm.faces:
        if f in done or f.normal.y > -0.8:
            continue
        stack, region = [f], []
        done.add(f)
        while stack:
            g = stack.pop()
            region.append(g)
            for e in g.edges:
                if len(e.link_faces) != 2 or e.calc_face_angle(0.0) > math.radians(12):
                    continue
                for h in e.link_faces:
                    if h not in done and h.normal.y < -0.8:
                        done.add(h)
                        stack.append(h)
        cs = [v.co for g in region for v in g.verts]
        w = max(c.x for c in cs) - min(c.x for c in cs)
        hgt = max(c.z for c in cs) - min(c.z for c in cs)
        area = sum(g.calc_area() for g in region)
        fill = area / (w * max(hgt, 1e-6)) if w > 0 else 0.0
        pane = w > LENS_MIN_WIDTH * span and hgt > 0.3 * w and fill > LENS_FILL
        if pane:
            lens |= {g.index for g in region}
        if len(region) >= 10 or pane:
            log("      flat front region %4d faces, %.3f x %.3f m, fill %.2f -> %s" % (
                len(region), w, hgt, fill, "lens" if pane else "frame"))
    frame_faces = [f for i, f in enumerate(faces) if i not in lens]
    lens_faces = [f for i, f in enumerate(faces) if i in lens]
    bm.free()

    def compact(fs):
        used = sorted({i for f in fs for i in f})
        remap = {o: n for n, o in enumerate(used)}
        return [verts[i] for i in used], [tuple(remap[i] for i in f) for f in fs]

    return compact(frame_faces), (compact(lens_faces) if lens_faces else None)


def _face_depth(skull, head, z):
    """How far in front of the head bone the skull's face is at height z (the centre line)."""
    for tol in (0.03, 0.05, 0.08, 0.12):  # low-poly skulls: widen until the band holds verts
        band = [v for v in skull[0] if abs(v.x) < 0.06 and abs(v.z - z) < tol and v.y < head.y]
        if band:
            return head.y - min(v.y for v in band)
    return head.y - min(v.y for v in skull[0])


def main(argv):
    ns = _arguments(argv)
    ns.out_dir.mkdir(parents=True, exist_ok=True)
    ns.report_dir.mkdir(parents=True, exist_ok=True)
    log("tripo_glasses: %s" % ns.src)
    bald, head = _glb_mesh(ns.bald, "head")
    own, _ = _glb_mesh(ns.own, "head")
    bh, bcen, bcut = th._skull_frame(bald[0])
    log("  shaved skull (%s): %.3f m above the neck cut at %.3f, centre (%.3f, %.3f, %.3f);"
        " head bone at (%.3f, %.3f, %.3f)" % (ns.bald.stem, bh, bcut, bcen.x, bcen.y, bcen.z,
                                             head.x, head.y, head.z))
    skulls = _cells(ns)
    styles = {}
    log("\n== fit onto the shaved skull, positions (rig metres)")
    for k in skulls:
        skull = th._arrays([k["obj"]])
        glasses = th._arrays([g["obj"] for g in k["glasses"]])
        m, s = th._fit(skull[0], bh, bcen)
        placed = th._moved(glasses, m)
        frames, lenses = _split_lenses(placed)
        pts = placed[0]
        bridge = [v for v in pts if abs(v.x) < 0.02]
        bc = sum(bridge, Vector()) / len(bridge) if bridge else Vector()
        tips = [max((v for v in pts if v.x * side > 0), key=lambda v: v.y) for side in (1, -1)]
        eye_z = bc.z
        depth = _face_depth(bald, head, eye_z)
        own_depth = _face_depth(own, head, eye_z)
        front = head.y - min(v.y for v in pts)
        log("  %-9s scale %.3f | bridge (%+.3f, %+.3f, %.3f) | temple tips (%+.3f, %+.3f, %.3f) /"
            " (%+.3f, %+.3f, %.3f)" % (k["name"], s, bc.x, bc.y, bc.z, tips[0].x, tips[0].y,
                                        tips[0].z, tips[1].x, tips[1].y, tips[1].z))
        log("  %-9s sits at eye height %.3f: shaved face depth there %.3f, glasses front %.3f"
            " (%.3f proud) | on %s the face is %.3f deep (%+.3f)" % (
                "", eye_z, depth, front, front - depth, ns.own.stem, own_depth, own_depth - depth))
        log("  %-9s frames %d faces%s" % ("", len(frames[1]),
                                           (", lenses %d faces" % len(lenses[1])) if lenses else ", no lens geometry"))
        styles[k["name"]] = {"frames": frames, "lenses": lenses, "depth": depth,
                             "own_shift": own_depth - depth}
    log("\n== export -> %s" % ns.out_dir)
    ok = True
    for name, st in styles.items():
        parts = {"frames": st["frames"]}
        if st["lenses"]:
            parts["lenses"] = st["lenses"]
        ok = th._export_parts(ns, ns.out_dir / ("glasses_%s.glb" % name), parts) and ok
    _sheet(ns, styles, bald, own)
    (ns.report_dir / "summary.txt").write_text("\n".join(th._LOG) + "\n", encoding="utf-8")
    return 0 if ok else 1


def _sheet(ns, styles, bald, own):
    """Rows: one per style. Columns: shaved skull front 3/4 | side | --own front 3/4 | side
    (on --own the glasses are moved forward by the face-depth difference, as the game does)."""
    import numpy as np

    tiles = ns.report_dir / "tiles"
    tiles.mkdir(exist_ok=True)
    rows = []
    for name, st in styles.items():
        shift = Vector((0.0, -st["own_shift"], 0.0))
        moved = ([v + shift for v in st["frames"][0]], st["frames"][1])
        row = []
        for col, (skull, frames, yaw) in enumerate(((bald, st["frames"], 25.0), (bald, st["frames"], 90.0),
                                                    (own, moved, 25.0), (own, moved, 90.0))):
            path = tiles / ("%s_%d.png" % (name, col))
            _tile([("skin", skull), ("frames", frames)], yaw, path)
            row.append(str(path))
        rows.append(row)
    imgs = [[th._load_png(p) for p in row] for row in rows]
    h, w = imgs[0][0].shape[:2]
    sheet = np.ones((h * len(imgs), w * 4, 4), dtype=np.float32)
    for r, row in enumerate(imgs):
        for c, im in enumerate(row):
            sheet[(len(imgs) - 1 - r) * h:(len(imgs) - r) * h, c * w:(c + 1) * w] = im
    img = bpy.data.images.new("fit_sheet", w * 4, h * len(imgs), alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = str(ns.report_dir / "fit_sheet.png")
    img.file_format = "PNG"
    img.save()
    log("\n  fit sheet: %s (rows %s; columns: shaved skull 3/4, side | %s 3/4, side, glasses"
        " moved forward by the face-depth difference)" % (
            ns.report_dir / "fit_sheet.png", ", ".join(styles), ns.own.stem))


def _tile(parts, yaw, path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_object_outline = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = TILE
    scene.render.resolution_y = TILE
    world = bpy.data.worlds.new("w")
    world.color = (0.85, 0.87, 0.9)
    scene.world = world
    colours = {"skin": (0.93, 0.76, 0.62, 1.0), "frames": (0.85, 0.1, 0.1, 1.0)}
    pts = []
    for kind, (verts, faces) in parts:
        me = bpy.data.meshes.new(kind)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        ob = bpy.data.objects.new(kind, me)
        ob.color = colours[kind]
        scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        if kind == "frames":
            pts += list(verts)
    lo, hi = th._bounds(pts)
    centre = (lo + hi) / 2
    size = max(hi - lo) * 1.6
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = size
    cam = bpy.data.objects.new("cam", cd)
    scene.collection.objects.link(cam)
    scene.camera = cam
    r = math.radians(yaw)
    cam.location = centre + Vector((math.sin(r), -math.cos(r), 0.1)) * 5.0
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
