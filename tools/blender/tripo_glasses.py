"""Tripo glasses (a grid of bald heads wearing glasses) -> Rig_Medium glasses parts.

Run headless:

    blender.exe --background --factory-startup --python tools/blender/tripo_glasses.py -- \
        [--src IMPORT/CHARREWORK/glasses.blend] [--names round,square,wire,halfmoon] \
        [--bald assets/characters/parts/tripo_bald_tl_m.glb] \
        [--own assets/characters/parts/tripo_head_tl_m.glb] \
        [--out-dir assets/characters/parts] [--report-dir IMPORT/CHARREWORK/report/glasses]
        [--front-scale W,H] [--style-scale name=W,H ...] [--clear-heads a.glb,b.glb] [--no-sheet]

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

Size variants: --front-scale W,H (and --style-scale name=W,H per style) scales the front
(rims + bridge, everything in front of the hinge plane) by W in x and H in z about the
bridge centre. Each temple is re-seated from the new hinge to its old tip, bent outward
where that straight run would cut into the shaved skull or any --clear-heads head (at the
forward offset the game gives each face), and its long edges are cut first so it can bend.
Variant sets go elsewhere with --out-dir (e.g. .dev/glasses_variants/v85) and --no-sheet;
tools/shot_glasses_variants.gd renders them on the cast in the engine.

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
TEMPLE_CLEAR = 0.006  # metres (rig): how far outside the skull a re-seated temple stays
TEMPLE_BINS = 32  # slices along a temple for its outward push
TEMPLE_EDGE = 0.02  # metres (rig): temple edges are cut down to this before they bend


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
    p.add_argument("--front-scale", default="0.75,0.70",
                   help="W,H: scale the front (rims + bridge) by W in x and H in z about the bridge")
    p.add_argument("--style-scale", action="append", default=[],
                   help="name=W,H: a per-style --front-scale (repeatable)")
    p.add_argument("--no-sheet", action="store_true", help="skip the Blender fit sheet")
    p.add_argument("--clear-heads", default=",".join(
        "assets/characters/parts/tripo_head_%s_m.glb" % c for c in ("tl", "tr", "bl", "br")),
        help="comma list of head glbs a re-seated temple must also clear (besides --bald), each"
             " at the forward offset the game gives its face")
    ns = p.parse_args(args)
    ns.scales = {}
    for item in ns.style_scale:
        name, wh = item.split("=")
        ns.scales[name.strip()] = tuple(float(x) for x in wh.split(","))
    ns.front_scale = tuple(float(x) for x in ns.front_scale.split(","))
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


def _hinge_y(pts):
    """The plane between the front and the temples: the rims' inner half (|x| under 0.6 of
    the half width, never a temple) ends at some depth; the hinge sits half that front's
    depth again behind it."""
    xmax = max(abs(v.x) for v in pts)
    ymin = min(v.y for v in pts)
    rim_back = max(v.y for v in pts if abs(v.x) < 0.6 * xmax)
    return rim_back + 0.5 * (rim_back - ymin)


def _box(pts):
    if not pts:
        return "-"
    xs = [v.x for v in pts]
    zs = [v.z for v in pts]
    return "%.3f x %.3f" % (max(xs) - min(xs), max(zs) - min(zs))


def _front_report(name, pts, hinge, old):
    """Log the front box (whole front) and one lens box (the +x rim) for pts; `old` is the
    same pair from before the scale, or None."""
    front = [v for v in pts if v.y < hinge]
    rim = [v for v in front if v.x > 0.0]
    new = (_box(front), _box(rim))
    if old is None:
        log("  %-9s front %s, lens box (one rim) %s | hinge plane y %.3f" % (name, new[0], new[1], hinge))
    else:
        log("  %-9s front %s -> %s, lens box (one rim) %s -> %s | hinge plane y %.3f" % (
            name, old[0], new[0], old[1], new[1], hinge))
    return new


def _cut_temples(mesh, hinge):
    """Tripo's temples are straight tubes with vertices only at their ends; before one can
    bend, its long edges (behind the hinge) are halved until none is over TEMPLE_EDGE."""
    verts, faces = mesh
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    for _ in range(8):
        long = [e for e in bm.edges if e.calc_length() > TEMPLE_EDGE
                and min(e.verts[0].co.y, e.verts[1].co.y) >= hinge]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    bm.verts.index_update()
    out = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces])
    bm.free()
    return out


def _scale_front(name, mesh, bc, w, h, heads):
    """Scale the front (every vertex in front of the hinge plane) by w in x and h in z about
    the bridge centre, depth kept. Each temple (the vertices behind the hinge on one side)
    is re-seated: its segment old hinge -> old tip is mapped onto new hinge -> the same
    tip, i.e. a vertex a fraction t of the way back moves by (1 - t) of the hinge's move.
    That is a shear along the temple, so its cross-section (thickness) is unchanged.
    The re-seated temples are then pushed out to clear every head in `heads`, a list of
    (label, mesh, offset): offset takes a glasses point into that head's frame (the game
    moves the glasses forward onto each face). Logs the boxes and how many temple vertices
    end up inside each head. Returns the mesh (the temples' long edges cut first, see
    _cut_temples)."""
    hinge = _hinge_y(mesh[0])
    n0 = len(mesh[1])
    mesh = _cut_temples(mesh, hinge)
    pts = mesh[0]
    log("  %-9s temples cut to %.2f m edges: %d -> %d faces" % (name, TEMPLE_EDGE, n0, len(mesh[1])))
    old = (_box([v for v in pts if v.y < hinge]), _box([v for v in pts if v.y < hinge and v.x > 0.0]))

    def front(v):
        return Vector((bc.x + w * (v.x - bc.x), v.y, bc.z + h * (v.z - bc.z)))

    out = [front(v) if v.y < hinge else v.copy() for v in pts]
    checks = [(_tree(m), off) for _, m, off in heads]
    for side in (1.0, -1.0):
        idx = [i for i, v in enumerate(pts) if v.y >= hinge and v.x * side > 0.0]
        if not idx:
            continue
        tip = max(pts[i].y for i in idx)
        near = [pts[i] for i in idx if pts[i].y < hinge + 0.1 * (tip - hinge)]
        if not near:
            near = [min((pts[i] for i in idx), key=lambda v: v.y)]
        c = sum(near, Vector()) / len(near)
        move = front(c) - c
        ts = {}
        for i in idx:
            t = min(max((pts[i].y - hinge) / max(tip - hinge, 1e-6), 0.0), 1.0)
            out[i] = pts[i] + move * (1.0 - t)
            ts[i] = t
        push = _push_out(checks, {i: out[i] for i in idx}, {i: pts[i] for i in idx}, ts, side)
        for i in idx:
            out[i] = out[i] + Vector((side * push(ts[i]), 0.0, 0.0))
        # whatever the hinge itself was pushed, the rim's outer end (endpiece) follows,
        # fading to nothing by 60% of the half width, so the temple stays joined to the front
        reach = max(abs(out[i].x) for i, v in enumerate(pts) if v.y < hinge and v.x * side > 0.0)
        for i, v in enumerate(pts):
            if v.y < hinge and v.x * side > 0.0:
                f = min(max((abs(out[i].x) - 0.6 * reach) / (0.4 * reach), 0.0), 1.0)
                out[i] = out[i] + Vector((side * push(0.0) * f, 0.0, 0.0))
        log("  %-9s %s temple: hinge (%+.3f, %.3f, %.3f) -> (%+.3f, %.3f, %.3f), tip y %.3f kept,"
            " pushed out up to %.3f to clear the heads (%.3f at the hinge)" % (
                name, "+x" if side > 0 else "-x", c.x, c.y, c.z, c.x + move.x, c.y, c.z + move.z, tip,
                max(push(j / float(TEMPLE_BINS)) for j in range(TEMPLE_BINS + 1)), push(0.0)))
    _front_report(name, out, hinge, old)
    for label, m, off in heads:
        before = _inside(m, [v + off for v in pts if v.y >= hinge])
        after = _inside(m, [out[i] + off for i, v in enumerate(pts) if v.y >= hinge])
        log("  %-9s temple verts inside %-16s %3d (deepest %.3f) as modelled, %3d (deepest %.3f)"
            " after" % (name, label + ":", before[0], before[1], after[0], after[1]))
    return out, mesh[1]


def _tree(mesh):
    from mathutils.bvhtree import BVHTree

    return BVHTree.FromPolygons([tuple(v) for v in mesh[0]], [tuple(f) for f in mesh[1]])


def _clear_of(tree, v):
    """True when v is outside the skull by at least TEMPLE_CLEAR."""
    hit = tree.find_nearest(v)
    if hit[0] is None:
        return True
    return (v - hit[0]).dot(hit[1]) > 0.0 and hit[3] >= TEMPLE_CLEAR


def _push_out(checks, verts, orig, ts, side):
    """A re-seated temple whose straight run now cuts into the skull (the front got narrower,
    the tips stayed) is bent outward: per slice along it (t, 0 at the hinge .. 1 at the tip)
    the x push that clears every vertex of that slice by TEMPLE_CLEAR, spread over the
    neighbouring slices so the bend stays smooth. Whole slices move, so the temple's
    thickness is kept. A vertex that already sat in the skull before (Tripo tucks the tips
    in behind the ears) only asks for what the re-seat added, so the tips stay put.
    Returns push(t)."""

    def clearance(v):
        dx = 0.0
        while dx < 0.2 and not all(_clear_of(tree, v + off + Vector((side * dx, 0.0, 0.0)))
                                   for tree, off in checks):
            dx += 0.002
        return dx

    need = [0.0] * (TEMPLE_BINS + 1)
    for i, v in verts.items():
        dx = clearance(v) - clearance(orig[i])
        b = int(round(ts[i] * TEMPLE_BINS))
        need[b] = max(need[b], dx)
    smooth = []
    for b in range(TEMPLE_BINS + 1):  # the tallest neighbour, eased by distance (5 slices)
        smooth.append(max(need[j] * (1.0 - abs(j - b) / 6.0)
                          for j in range(max(0, b - 5), min(TEMPLE_BINS, b + 5) + 1)))
    for _ in range(3):  # then soften the corners that leaves
        smooth = [(smooth[max(b - 1, 0)] + 2.0 * smooth[b] + smooth[min(b + 1, TEMPLE_BINS)]) / 4.0
                  for b in range(TEMPLE_BINS + 1)]

    def push(t):
        f = t * TEMPLE_BINS
        b = min(int(f), TEMPLE_BINS - 1)
        a = f - b
        return smooth[b] * (1.0 - a) + smooth[b + 1] * a

    return push


def _inside(mesh, pts):
    """(count, deepest) of pts inside the closed mesh (nearest-surface normal test)."""
    tree = _tree(mesh)
    n, deepest = 0, 0.0
    for v in pts:
        hit = tree.find_nearest(v)
        if hit[0] is not None and (v - hit[0]).dot(hit[1]) < 0.0:
            n += 1
            deepest = max(deepest, hit[3])
    return n, deepest


def main(argv):
    ns = _arguments(argv)
    ns.out_dir.mkdir(parents=True, exist_ok=True)
    ns.report_dir.mkdir(parents=True, exist_ok=True)
    log("tripo_glasses: %s" % ns.src)
    bald, head = _glb_mesh(ns.bald, "head")
    own, _ = _glb_mesh(ns.own, "head")
    extra = []
    for item in ns.clear_heads.split(","):
        if item.strip():
            path = Path(item.strip())
            path = path if path.is_absolute() else ROOT / path
            extra.append((path.stem, _glb_mesh(path, "head")[0]))
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
        pts = placed[0]
        bridge = [v for v in pts if abs(v.x) < 0.02]
        bc = sum(bridge, Vector()) / len(bridge) if bridge else Vector()
        w, h = ns.scales.get(k["name"], ns.front_scale)
        if (w, h) != (1.0, 1.0):
            heads = [(ns.bald.stem, bald, Vector())]
            for label, m in extra:  # the game moves the glasses forward by the face difference
                heads.append((label, m, Vector((0.0, -(_face_depth(m, head, bc.z) - _face_depth(bald, head, bc.z)), 0.0))))
            placed = _scale_front(k["name"], placed, bc, w, h, heads)
            pts = placed[0]
        else:
            _front_report(k["name"], pts, _hinge_y(pts), None)
        frames, lenses = _split_lenses(placed)
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
    if not ns.no_sheet:
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
