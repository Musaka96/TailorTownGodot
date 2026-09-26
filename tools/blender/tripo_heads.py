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
for a 2 x 2 grid, head_r<row>c<col> otherwise. A file may hold several grids, one per mesh
object; they are ordered left to right and every grid after the first gets a set prefix
(g2_tl, g2_tr, ... for the second), so the first grid keeps its names.

A skull may carry a few open edges (SKULL_OPEN_MAX; Tripo seams), a hair has many more. A
cell with a hair but no skull of its own is a FUSED head (Tripo made skull and hair one
shell): the best-matching skull of the same grid is moved into that cell by the offset
between the neck stubs; when that skull lies on the fused shell (FUSED_MATCH of its
vertices within 2 x FUSED_TOL of the skull's height), the fused faces lying on it (every
corner within FUSED_SKIN_TOL, about 2 mm: flush hair such as a sideburn goes with the skin,
which the transplanted skull shows anyway) are its skin and the
rest are hair. The transplanted skull becomes the cell's skull (closed, with
its ears), the rest its hair. A fused cell whose skulls do not line up stops the run.

Every head is fitted to the rig by its skull: the neck stub is found (the lowest slice of
the skull before it widens) and left out of the measure; the skull above it is scaled to
the height of the target's (the Tripo gentleman's `head` in CHARTGEN2.glb) and centred on
it. The hair takes its own skull's transform. Full mesh, no decimation.

Exports, all bound 100% to bone `head` of Rig_Medium (the rig renames it head_2 at load
and CharacterRig._rebind_skin maps it):
  <out-dir>/tripo_head_<cell>_m.glb   `head` = that head's own skull (+ ears), `Hair`
  <out-dir>/tripo_bald_<cell>_m.glb   `head` = the bald skull + ears, `Hair` = that hair
      moved onto the bald skull (its own skull mapped onto the bald one by height and
      centre), with every hair vertex that ends up inside the skull, or outside it by less
      than LIFT, set LIFT outside, and the hair around each such vertex carried along
      (fading out over LIFT_SPREAD) so thin hair sheets keep their thickness.
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
LIFT_SPREAD = 0.015  # rig metres over which a lift carries the hair verts around it along
SKULL_MIN_FACES = 300
SKULL_OPEN_MAX = 10  # open edges a skull may have (Tripo seams); a hair has dozens or more
FUSED_TOL = 0.003  # of the skull height: the transplanted skull lies on the fused shell within 2x this
FUSED_SKIN_TOL = 0.006  # of the skull height: a fused face whose corners all lie this close is skin
FUSED_MATCH = 0.9  # share of the transplanted skull's vertices that must lie on the fused shell
FUSED_ISLAND = 20  # faces: smaller skin / hair islands in a fused shell take the other side
EYE_Z = 1.66  # rig metres: the height the face depth is measured at (the face profiles')
FACE_PAD = 0.025  # profile face_z = the face's front at EYE_Z + this
# The game's FaceUvBaker finds the face rect from the head's FRONT PLATE: vertices whose
# normal faces forward (>= 0.85) within 15% of the head's depth behind its front. With
# fewer than 30 it falls back to a loose rule that takes in the cheeks and draws the face
# far too big. A skull with fewer than FRONT_MIN_VERTS such vertices (counted unsplit here;
# Godot splits them at seams, so it counts at least as many) gets the faces around its front
# plate subdivided (flat cuts, the shape is kept) until it has them.
FRONT_NZ = 0.85
FRONT_DEPTH = 0.15
FRONT_MIN_VERTS = 30  # FaceUvBaker.MIN_FRONT
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
    p.add_argument("--export-cells", default="",
                   help="comma list of cell-name prefixes to export (e.g. g2_); all when empty")
    p.add_argument("--sheet-cells", default="",
                   help="comma list of cell-name prefixes for the fit sheet rows (e.g. g2_); all when empty")
    p.add_argument(
        "--neck-radius",
        type=float,
        default=0.0,
        help="the neck stub's radius after the fit (m); 0 = measured from the collars",
    )
    p.add_argument("--no-neck-fit", action="store_true", help="keep Tripo's neck stub as is")
    p.add_argument(
        "--collars",
        default="assets/characters/CHARTGEN2.glb,assets/characters/suit_doublebreasted.glb,"
        "assets/characters/street_overshirt.glb,assets/characters/street_overcoat.glb",
        help="outfit glbs whose collar openings the neck must sit inside",
    )
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
        o["tt_src"] = o.name  # separated shells keep it: which grid a shell came from
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
                       "lo": lo, "hi": hi, "c": (lo + hi) / 2, "src": o.get("tt_src", o.name)})
    return shells


def _sort(shells):
    skulls = [s for s in shells if s["open"] <= SKULL_OPEN_MAX and s["faces"] >= SKULL_MIN_FACES]
    hairs = [s for s in shells if s["open"] > SKULL_OPEN_MAX and s["faces"] >= HAIR_MIN_FACES]
    small = [s for s in shells if s not in skulls and s not in hairs]
    for s in skulls:
        s["ears"], s["hair"] = [], None
    for e in small:
        for k in skulls:
            pad = 0.25 * (k["hi"] - k["lo"])
            if all(k["lo"][i] - pad[i] <= e["c"][i] <= k["hi"][i] + pad[i] for i in range(3)):
                k["ears"].append(e)
                break
        else:
            log("  small shell of %d faces at %s belongs to no skull: dropped" % (e["faces"], tuple(round(x, 3) for x in e["c"])))
    fused = []
    for h in hairs:
        own = [k for k in skulls if k["src"] == h["src"]] or skulls
        best = min(own, key=lambda k: (Vector((k["c"].x, k["c"].z)) - Vector((h["c"].x, h["c"].z))).length)
        dx, dz = abs(best["c"].x - h["c"].x), abs(best["c"].z - h["c"].z)
        if dx > 0.5 * (best["hi"].x - best["lo"].x) or dz > 0.5 * (best["hi"].z - best["lo"].z):
            fused.append(h)  # no skull in this hair's cell
            continue
        if best["hair"] is not None:
            log("  WARNING: two hairs over one skull; keeping the larger")
            if best["hair"]["faces"] >= h["faces"]:
                continue
        best["hair"] = h
    bald = [k for k in skulls if k["hair"] is None]
    if len(bald) != 1:
        raise SystemExit("expected exactly one skull with no hair (the bald base), found %d" % len(bald))
    cells = [k for k in skulls if k["hair"] is not None] + [_unfuse(h, skulls) for h in fused]
    # one grid per source object, left to right; the first keeps plain names
    srcs = sorted({k["src"] for k in cells}, key=lambda src: min(k["lo"].x for k in cells if k["src"] == src))
    grid = []
    for g, src in enumerate(srcs):
        prefix = "" if g == 0 else "g%d_" % (g + 1)
        members = sorted((k for k in cells if k["src"] == src), key=lambda k: -k["c"].z)
        rows = []
        for k in members:  # rows by height (top first), columns by x
            if rows and abs(rows[-1][0]["c"].z - k["c"].z) < 0.5 * (k["hi"].z - k["lo"].z):
                rows[-1].append(k)
            else:
                rows.append([k])
        for r, row in enumerate(rows):
            row.sort(key=lambda k: k["c"].x)
            for c, k in enumerate(row):
                if len(rows) == 2 and len(row) == 2:
                    k["name"] = prefix + ("t" if r == 0 else "b") + ("l" if c == 0 else "r")
                else:
                    k["name"] = prefix + "r%dc%d" % (r + 1, c + 1)
        grid += [k for row in rows for k in row]
    log("  shells: %d skulls, %d hairs (%d fused with their skull), %d small pieces, %d grid(s)" % (
        len(skulls), len(hairs), len(fused), len(small), len(srcs)))
    for k in [bald[0]] + grid:
        if k.get("fused"):
            f = k["fused"]
            log("    %-8s FUSED shell %4d faces (%d open edges; x %.2f..%.2f, z %.2f..%.2f): skull from %s"
                " moved by %s, %d/%d of its verts on the shell -> skin %d faces, hair %d faces" % (
                    k["name"], f["faces"], f["open"], k["lo"].x, k["hi"].x, k["lo"].z, k["hi"].z,
                    f["donor"], tuple(round(x, 4) for x in f["offset"]), f["on"], f["verts"],
                    f["skin"], f["hair"]))
            continue
        log("    %-8s skull %4d faces (x %.2f..%.2f, z %.2f..%.2f), %d ear piece(s)%s" % (
            k.get("name", "bald"), k["faces"], k["lo"].x, k["hi"].x, k["lo"].z, k["hi"].z,
            len(k["ears"]), (", hair %d faces (%d open edges)" % (k["hair"]["faces"], k["hair"]["open"]))
            if k["hair"] else ""))
    return bald[0], grid


def _stub(verts):
    """The bottom of a neck stub: the centre of the lowest 1 cm band, at the lowest z."""
    lo = min(v.z for v in verts)
    band = [v for v in verts if v.z < lo + 0.01]
    c = sum(band, Vector()) / len(band)
    return Vector((c.x, c.y, lo))


def _unfuse(h, skulls):
    """A fused cell (skull and hair in one shell) -> a cell dict like a skull's, with the
    best sibling skull moved in (by the neck-stub offset) as its skull and the fused faces
    that do not lie on that skull as its hair."""
    fv, ff = _arrays([h["obj"]])
    ftree = BVHTree.FromPolygons(fv, ff)
    best = None
    for k in (k for k in skulls if k["src"] == h["src"]):
        sk = _arrays([k["obj"]] + [e["obj"] for e in k["ears"]])
        off = _stub(fv) - _stub(_arrays([k["obj"]])[0])
        tol = FUSED_TOL * _skull_frame(sk[0])[0]
        on = sum(1 for v in sk[0] if ftree.find_nearest(v + off)[3] <= 2.0 * tol)
        log("    fused %s: skull %s moved by %s, %d/%d verts within %.1f mm of the shell" % (
            h["obj"].name, k["obj"].name, tuple(round(x, 4) for x in off), on, len(sk[0]), 2000.0 * tol))
        if best is None or on / len(sk[0]) > best[0]:
            best = (on / len(sk[0]), k, sk, off, tol, on)
    if best is None or best[0] < FUSED_MATCH:
        raise SystemExit("fused shell %s: no skull of its grid lines up with it (best %.0f%% of verts;"
                         " needs a neck-stub + ears fit)" % (h["obj"].name, 100.0 * (best[0] if best else 0.0)))
    share, k, sk, off, tol, on = best
    moved = ([v + off for v in sk[0]], sk[1])
    tree = BVHTree.FromPolygons(moved[0], moved[1])
    skin_tol = FUSED_SKIN_TOL / FUSED_TOL * tol
    near = [tree.find_nearest(v)[3] <= skin_tol for v in fv]
    skin = [all(near[i] for i in f) for f in ff]
    skin = _settle_islands(ff, skin)
    hair = [f for f, is_skin in zip(ff, skin) if not is_skin]
    used = sorted({i for f in hair for i in f})
    remap = {o: n for n, o in enumerate(used)}
    hair_mesh = ([fv[i] for i in used], [tuple(remap[i] for i in f) for f in hair])
    skin_faces = [f for f, is_skin in zip(ff, skin) if is_skin]
    used_s = sorted({i for f in skin_faces for i in f})
    remap_s = {o: n for n, o in enumerate(used_s)}
    lo, hi = h["lo"], h["hi"]
    return {"obj": None, "arr": moved, "ears": [], "src": h["src"], "faces": h["faces"],
            "lo": lo, "hi": hi, "c": (lo + hi) / 2,
            "hair": {"obj": None, "arr": hair_mesh, "faces": len(hair), "open": h["open"]},
            "split": ([fv[i] for i in used_s], [tuple(remap_s[i] for i in f) for f in skin_faces]),
            "fused": {"faces": h["faces"], "open": h["open"], "donor": k["obj"].name, "offset": off,
                      "on": on, "verts": len(sk[0]), "skin": len(skin_faces), "hair": len(hair)}}


def _settle_islands(faces, skin):
    """Flip skin / hair islands (edge-connected faces of one kind) under FUSED_ISLAND faces."""
    by_edge = {}
    for i, f in enumerate(faces):
        for a, b in zip(f, f[1:] + f[:1]):
            by_edge.setdefault((min(a, b), max(a, b)), []).append(i)
    skin = list(skin)
    seen = set()
    for i in range(len(faces)):
        if i in seen:
            continue
        kind, stack, comp = skin[i], [i], []
        seen.add(i)
        while stack:
            j = stack.pop()
            comp.append(j)
            f = faces[j]
            for a, b in zip(f, f[1:] + f[:1]):
                for n in by_edge[(min(a, b), max(a, b))]:
                    if n not in seen and skin[n] == kind:
                        seen.add(n)
                        stack.append(n)
        if len(comp) < FUSED_ISLAND:
            for j in comp:
                skin[j] = not kind
    return skin


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
    before = near = 0
    for i, v in enumerate(verts):
        ins, loc, n = inside(v)
        if ins:
            before += 1
            verts[i] = loc + n * LIFT
        elif loc is not None and (v - loc).length < LIFT:
            # outside but closer than LIFT: a hair sheet lying flush on its own scalp would
            # otherwise come out half lifted, half not (jagged, z-fighting)
            near += 1
            verts[i] = loc + n * LIFT
    moved = {i: verts[i] - hair[0][i] for i in range(len(verts)) if verts[i] != hair[0][i]}
    spread = 0
    if LIFT_SPREAD > 0.0 and moved:
        # the verts around a lifted one go with it (fading out over LIFT_SPREAD), so a thin
        # hair sheet keeps its thickness: lifting only its inner layer would push that layer
        # through the outer one (dark, inside-out streaks)
        from mathutils.kdtree import KDTree

        kd = KDTree(len(moved))
        for n, i in enumerate(moved):
            kd.insert(hair[0][i], n)
        kd.balance()
        keys = list(moved)
        for i, v in enumerate(hair[0]):
            if i in moved:
                continue
            co, n, d = kd.find(v)
            if d < LIFT_SPREAD:
                t = 1.0 - d / LIFT_SPREAD
                verts[i] = v + moved[keys[n]] * (t * t * (3.0 - 2.0 * t))
                spread += 1
    # a long hair face over a curved patch of skull can still dip in between its lifted
    # corners: push such faces' corners out by how deep the face centre sits, a few passes
    dips = []
    for _ in range(4):
        hit = 0
        for f in hair[1]:
            c = sum((verts[i] for i in f), Vector()) / len(f)
            loc, n, _, _ = tree.find_nearest(c)
            if loc is None:
                continue
            depth = (loc - c).dot(n)  # > 0: inside
            if depth > -0.5 * LIFT:
                hit += 1
                for i in f:
                    verts[i] = verts[i] + n * (depth + LIFT)
        dips.append(hit)
        if hit == 0:
            break
    after = sum(1 for v in verts if inside(v)[0])
    _lift.near = near
    _lift.spread = spread
    _lift.dips = dips
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
        if k.get("arr") is not None:
            return k["arr"]
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
        hair = k["hair"]["arr"] if k["hair"].get("arr") is not None else _arrays([k["hair"]["obj"]])
        f, s = _fit(skull[0], th, tcen)
        h, c, cut = _skull_frame(skull[0])
        log("  %-8s %8.3f %9.4f   %s" % (name, h, s, tuple(round(x, 3) for x in f.to_translation())))
        own = {"head": _moved(skull, f), "Hair": _moved(hair, f)}
        # this skull mapped onto the bald one (height + centre), then the bald one's fit
        m, s2 = _fit(skull[0], bh, bcen)
        onto = fb @ m
        moved_hair = _moved(hair, onto)
        lifted, before, after = _lift(moved_hair, bald_skull_rig)
        near = (_lift.near, _lift.spread, _lift.dips)
        swapped = {"head": bald_rig, "Hair": lifted, "_before": moved_hair,
                   "_inside": before, "_after": after}
        grid_on_bald = _moved(skull, onto)
        cut_on_bald = _skull_frame(grid_on_bald[0])[2]
        above = [v for v in grid_on_bald[0] if v.z > cut_on_bald]
        dmax, dmean = _distances(above, bald_tree)
        gtree = BVHTree.FromPolygons(grid_on_bald[0], grid_on_bald[1])
        bmax, bmean = _distances([v for v in bald_rig[0] if v.z > cut_on_bald], gtree)
        tips = _ear_tips(grid_on_bald[0], cut_on_bald)
        shape.append((name, dmax, dmean, bmax, bmean, tips, len(hair[0]), before, after, near))
        heads["head_" + name] = own
        heads["bald_" + name] = swapped
        if k.get("split") is not None:
            own["_split"] = (_moved(k["split"], f), own["Hair"])
    log("\n== skull shape: each hair head's skull normalised onto the bald skull (rig metres)")
    log("  %-8s %22s %22s   %s" % ("head", "its skull -> bald", "bald -> its skull",
                                    "ear tips +x / -x (x, y, z)"))
    log("  %-8s %22s %22s   %s / %s" % ("bald", "", "", _pt(b_tips[0]), _pt(b_tips[1])))
    for name, dmax, dmean, bmax, bmean, tips, _, _, _, _ in shape:
        log("  %-8s  max %5.1f mean %4.1f mm  max %5.1f mean %4.1f mm   %s / %s" % (
            name, dmax * 1000, dmean * 1000, bmax * 1000, bmean * 1000, _pt(tips[0]), _pt(tips[1])))
    log("\n== hair moved onto the bald skull: vertices inside the skull, lifted %.0f mm out" % (LIFT * 1000))
    for name, _, _, _, _, _, nverts, before, after, near in shape:
        log("  %-8s %5d hair verts, %4d inside before (%.1f%%), %d after; %d just outside"
            " (under %.0f mm) also set to %.0f mm; %d around them carried along (%.0f mm falloff);"
            " faces dipping in, per pass: %s" % (
                name, nverts, before, 100.0 * before / nverts, after, near[0], LIFT * 1000, LIFT * 1000,
                near[1], LIFT_SPREAD * 1000, near[2]))
    return heads


def _front_plate(mesh):
    """(vertex indices of the front plate, face indices touching it) by FaceUvBaker's rule,
    in rig space (front is -y), with area-weighted smooth vertex normals."""
    verts, faces = mesh
    normals = [Vector() for _ in verts]
    for f in faces:
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        n = (b - a).cross(c - a)
        if len(f) == 4:
            n = n + (c - a).cross(verts[f[3]] - a)
        for i in f:
            normals[i] += n
    normals = [n.normalized() if n.length > 0.0 else n for n in normals]
    front = max(-v.y for v, n in zip(verts, normals) if -n.y >= FRONT_NZ)
    back = min(-v.y for v in verts)
    min_depth = front - FRONT_DEPTH * (front - back)
    plate = {i for i, (v, n) in enumerate(zip(verts, normals)) if -n.y >= FRONT_NZ and -v.y >= min_depth}
    touching = [k for k, f in enumerate(faces) if any(i in plate for i in f)]
    return plate, touching


def _dense_front(mesh, name):
    """Subdivide the faces around a thin front plate (see FRONT_MIN_VERTS), at most twice."""
    plate, touching = _front_plate(mesh)
    start = len(plate)
    passes = 0
    while len(plate) < FRONT_MIN_VERTS and passes < 2:
        verts, faces = mesh
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in verts]
        bm_faces = []
        for f in faces:
            try:
                bm_faces.append(bm.faces.new([vs[i] for i in f]))
            except ValueError:
                bm_faces.append(None)
        edges = {e for k in touching if bm_faces[k] is not None for e in bm_faces[k].edges}
        bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=1, use_grid_fill=True)
        bm.verts.index_update()
        mesh = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces])
        bm.free()
        plate, touching = _front_plate(mesh)
        passes += 1
    if passes:
        log("  %-12s front plate %d verts -> %d after %d cut(s), %d faces" % (
            name, start, len(plate), passes, len(mesh[1])))
    else:
        log("  %-12s front plate %d verts" % (name, start))
    return mesh


def _face_depth(verts, z=EYE_Z):
    """How far the face's front is ahead of the head bone (y = 0, front is -y) at height z,
    on the centre line; the band widens until it holds vertices."""
    for tol in (0.03, 0.05, 0.08, 0.12):
        band = [v for v in verts if abs(v.x) < 0.06 and abs(v.z - z) < tol and v.y < 0.0]
        if band:
            return -min(v.y for v in band)
    return -min(v.y for v in verts)


def _pt(v):
    return "(%+.3f, %+.3f, %.3f)" % (v.x, v.y, v.z)


# ---------------------------------------------------------------------------------------
# step 3: export


MATERIAL_OF = {"head": ("skin", (0.93, 0.76, 0.62)), "Hair": ("hair", (0.30, 0.19, 0.11)),
               "frames": ("frames", (0.12, 0.10, 0.09)), "lenses": ("lenses", (0.75, 0.85, 0.9))}


def _export(ns, name, parts):
    return _export_parts(ns, ns.out_dir / ("tripo_%s_m.glb" % name),
                         {k: v for k, v in parts.items() if k in ("head", "Hair")})


def _export_parts(ns, path, parts, colours=None):
    """Write `parts` (mesh name -> (verts, faces) in rig space) to a glb on Rig_Medium,
    every mesh bound 100% to bone `head`, then re-read it and check it. `colours` (mesh
    name -> one float per vertex) rides as vertex colour COLOR_0 (r = the value, g = b = 0,
    a = 1): tripo_glasses.py's temple marker."""
    colours = colours or {}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ns.rig))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for role, (verts, faces) in parts.items():
        me = bpy.data.meshes.new(role)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.validate()
        if role in colours:
            if len(me.vertices) != len(colours[role]):
                log("  WARNING: %s lost vertices in validate(); its colour is skipped" % role)
            else:
                attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
                attr.data.foreach_set("color", [c for t in colours[role] for c in (t, 0.0, 0.0, 1.0)])
                me.color_attributes.active_color = attr
                me.color_attributes.render_color_index = 0
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
        mat_name, colour = MATERIAL_OF.get(role, (role, (0.5, 0.5, 0.5)))
        mat = bpy.data.materials.new(mat_name)
        mat.diffuse_color = colour + (1.0,)
        me.materials.append(mat)
        for bone in arm.data.bones:
            ob.vertex_groups.new(name=bone.name)
        ob.vertex_groups["head"].add(range(len(me.vertices)), 1.0, "REPLACE")
        tc._parent_to(ob, arm)
    tc._select_only([])
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=False, export_yup=True,
        export_apply=False, export_skins=True, export_animations=False,
        export_materials="EXPORT", export_cameras=False, export_lights=False,
        export_vertex_color="ACTIVE" if colours else "MATERIAL")
    g = tc._glb_json(path)
    nodes = g["nodes"]
    roots = [nodes[r].get("name") for r in g["scenes"][0]["nodes"]]
    joints = [nodes[j].get("name") for j in g["skins"][0]["joints"]] if g.get("skins") else []
    meshes = sorted(n.get("name") for n in nodes if "mesh" in n)
    skinned = all("skin" in n for n in nodes if "mesh" in n)
    tris = {n.get("name"): sum(g["accessors"][p["indices"]]["count"] // 3
                               for p in g["meshes"][n["mesh"]]["primitives"])
            for n in nodes if "mesh" in n}
    ok = roots == ["Rig_Medium"] and len(joints) == 22 and meshes == sorted(parts) and skinned
    for n in nodes:  # every coloured mesh must carry COLOR_0 on each primitive
        if "mesh" in n and n.get("name") in colours:
            ok = ok and all("COLOR_0" in p["attributes"] for p in g["meshes"][n["mesh"]]["primitives"])
    log("  %s %-26s %s, %d KB" % (
        "ok  " if ok else "FAIL", path.name,
        ", ".join("%s %d tris" % (k, tris.get(k, 0)) for k in sorted(parts)),
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
    if ns.sheet_cells:
        keep = [x for x in ns.sheet_cells.split(",") if x]
        names = [n for n in names if any(n.startswith(x) for x in keep)]
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


def _split_sheet(ns, heads):
    """Fused cells: the shell's faces split into skin (skin colour) and hair, front 3/4 and
    back, beside the transplanted skull with that hair."""
    import numpy as np

    fused = sorted(k for k in heads if k.startswith("head_") and "_split" in heads[k])
    if not fused:
        return
    tiles_dir = ns.report_dir / "tiles"
    tiles_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for key in fused:
        skin, hair = heads[key]["_split"]
        row = []
        for col, (parts, yaw) in enumerate((
                ([("skin", skin, None), ("hair", hair, None)], 30.0),
                ([("skin", skin, None), ("hair", hair, None)], 200.0),
                ([("skin", skin, None)], 30.0),
                ([("skin", heads[key]["head"], None), ("hair", heads[key]["Hair"], None)], 30.0))):
            path = tiles_dir / ("%s_split_%d.png" % (key, col))
            _render_tile(parts, yaw, path)
            row.append(str(path))
        rows.append(row)
    imgs = [[_load_png(p) for p in row] for row in rows]
    h, w = imgs[0][0].shape[:2]
    sheet = np.ones((h * len(imgs), w * 4, 4), dtype=np.float32)
    for r, row in enumerate(imgs):
        for c, im in enumerate(row):
            sheet[(len(imgs) - 1 - r) * h:(len(imgs) - r) * h, c * w:(c + 1) * w] = im
    img = bpy.data.images.new("fused_split", w * 4, h * len(imgs), alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = str(ns.report_dir / "fused_split.png")
    img.file_format = "PNG"
    img.save()
    log("  fused split: %s (rows: %s; columns: the shell's skin faces (skin colour) + hair faces,"
        " front 3/4 | back | skin faces alone | the transplanted skull wearing that hair)" % (
            ns.report_dir / "fused_split.png", ", ".join(k[5:] for k in fused)))


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


NECK_MARGIN = 0.005  # metres between the fitted neck and the tightest collar


def _slice_radius(pts, z, half=0.01):
    """Half-width across (x) and half-depth (y) of a closed tube's slice at z."""
    band = [p for p in pts if abs(p.z - z) < half]
    if len(band) < 4:
        return None
    return ((max(p.x for p in band) - min(p.x for p in band)) / 2,
            (max(p.y for p in band) - min(p.y for p in band)) / 2,
            Vector(((max(p.x for p in band) + min(p.x for p in band)) / 2,
                    (max(p.y for p in band) + min(p.y for p in band)) / 2, z)))


def _neck_profile(verts):
    """(bottom, skull->stub height, [(z, rx, ry, centre)]) of a head's neck stub, in 1 cm
    slices from the bottom to the cut."""
    lo = min(v.z for v in verts)
    cut = _neck_cut(verts)
    rows = []
    z = lo + 0.01
    while z < cut:
        r = _slice_radius(verts, z)
        if r:
            rows.append((z,) + r)
        z += 0.01
    return lo, cut, rows


def _collar_opening(pts, top):
    """The collar's inner radius, per 1 cm slice from 1 to 5 cm below its top (the rolled
    edge itself is skipped): a circle fitted to the slice's cloth round the back and
    sides (the front is left out: a V or an open placket), then the distance from its
    centre that 10% of that cloth comes closer than (the inner wall, not the outer)."""
    rows = []
    for k in range(1, 6):
        z = top - k * 0.01
        band = [p for p in pts if abs(p.z - z) < 0.008 and abs(p.x) < 0.2]
        if len(band) < 8:
            continue
        cx = 0.0
        cy = sum(p.y for p in band) / len(band)
        ring = band
        for _ in range(3):
            ring = [p for p in band if p.y > cy - 0.3 * max(abs(q.y - cy) for q in band)
                    and math.hypot(p.x - cx, p.y - cy) < 0.2]
            if len(ring) < 6:
                break
            # Kasa circle fit: x^2 + y^2 + D x + E y + F = 0, least squares
            import numpy as np
            a = np.array([[p.x, p.y, 1.0] for p in ring])
            b = np.array([-(p.x * p.x + p.y * p.y) for p in ring])
            d, e, _ = np.linalg.lstsq(a, b, rcond=None)[0]
            cx, cy = -d / 2, -e / 2
        dists = sorted(math.hypot(p.x - cx, p.y - cy) for p in ring)
        if len(dists) >= 6:
            rows.append((z, dists[len(dists) // 10], dists[len(dists) // 2]))
    return rows


def _measure_collars(ns):
    """Every outfit's tightest collar opening; prints a table."""
    tight = None
    log("\n== collar openings the neck must sit inside (rig metres)")
    for path in [p.strip() for p in ns.collars.split(",") if p.strip()]:
        full = Path(path) if Path(path).is_absolute() else ROOT / path
        if not full.is_file():
            log("  %s: missing, skipped" % path)
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(full))
        meshes = {o.name.split(".")[0]: o for o in bpy.data.objects if o.type == "MESH"}
        for name in ("shirt", "jacket"):
            o = meshes.get(name)
            if o is None:
                continue
            pts = [o.matrix_world @ v.co for v in o.data.vertices]
            near = [p for p in pts if abs(p.x) < 0.15 and p.z > 1.0]
            if not near:
                continue
            top = max(p.z for p in near)
            rows = _collar_opening(pts, top)
            if not rows:
                continue
            least = sorted(r[1] for r in rows)[len(rows) // 2]
            log("  %-22s %-7s top %.3f | inner radius per cm down (10th pct / median): %s"
                " | opening %.3f" % (full.stem, name, top,
                                     "  ".join("%.3f/%.3f" % (r[1], r[2]) for r in rows), least))
            if tight is None or least < tight[0]:
                tight = (least, full.stem, name)
    return tight


def _fit_neck(mesh, target, name):
    """Thin a head's neck stub to `target` radius: each vertex moves towards the stub's
    axis, fully up to half the stub's height, then less and less up to no change at the
    jaw line (the cut), so the chin and jaw silhouette stay as they are; the length and
    everything above the cut are untouched."""
    verts, faces = mesh
    lo, cut, rows = _neck_profile(verts)
    lower = [r for r in rows if r[0] < lo + 0.6 * (cut - lo)]
    if not lower:
        return mesh, None
    rx = sorted(r[1] for r in lower)[len(lower) // 2]
    ry = sorted(r[2] for r in lower)[len(lower) // 2]
    axis = sum((r[3] for r in lower), Vector()) / len(lower)
    sx, sy = min(1.0, target / rx), min(1.0, target / ry)
    full_up_to = lo + 0.5 * (cut - lo)
    out = []
    for v in verts:
        if v.z >= cut:
            out.append(v)
            continue
        t = 1.0 if v.z <= full_up_to else 1.0 - (v.z - full_up_to) / (cut - full_up_to)
        t = t * t * (3.0 - 2.0 * t)
        kx = 1.0 + (sx - 1.0) * t
        ky = 1.0 + (sy - 1.0) * t
        out.append(Vector((axis.x + (v.x - axis.x) * kx, axis.y + (v.y - axis.y) * ky, v.z)))
    after = _neck_profile(out)[2]
    lower_after = [r for r in after if r[0] < lo + 0.6 * (cut - lo)]
    rx2 = sorted(r[1] for r in lower_after)[len(lower_after) // 2]
    ry2 = sorted(r[2] for r in lower_after)[len(lower_after) // 2]
    log("  %-8s stub %.3f..%.3f m | radius x/y %.3f/%.3f -> %.3f/%.3f (target %.3f)" % (
        name, lo, cut, rx, ry, rx2, ry2, target))
    return (out, faces), (rx, ry, rx2, ry2)


def main(argv):
    ns = _arguments(argv)
    ns.out_dir.mkdir(parents=True, exist_ok=True)
    ns.report_dir.mkdir(parents=True, exist_ok=True)
    tight = None if ns.no_neck_fit else _measure_collars(ns)
    base_neck = None
    if not ns.no_neck_fit:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(ns.target))
        head = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".")[0] == "head")
        hv = [head.matrix_world @ v.co for v in head.data.vertices]
        lo, cut, rows = _neck_profile(hv)
        lower = [r for r in rows if r[0] < lo + 0.6 * (cut - lo)]
        base_neck = sorted(r[1] for r in lower)[len(lower) // 2]
        log("  base head (%s): neck radius %.3f across, stub %.3f..%.3f" % (
            ns.target.stem, base_neck, lo, cut))
    heads = build(ns)
    log("\n== face front plate (FaceUvBaker needs %d vertices; fewer gets cut finer)" % FRONT_MIN_VERTS)
    done_front = {}
    for name, parts in sorted(heads.items()):
        key = id(parts["head"])
        if key not in done_front:
            done_front[key] = _dense_front(parts["head"], name)
        parts["head"] = done_front[key]
    if not ns.no_neck_fit:
        if ns.neck_radius > 0.0:
            target, why = ns.neck_radius, "--neck-radius"
        else:
            target = tight[0] - NECK_MARGIN if tight else base_neck
            why = "tightest collar (%s %s, %.3f) minus %.0f mm" % (
                tight[1], tight[2], tight[0], NECK_MARGIN * 1000) if tight else "base head"
            if base_neck is not None and base_neck < target:
                target, why = base_neck, "the base head's own neck (narrower than the collars allow)"
        log("\n== neck fit: target radius %.3f m (%s)" % (target, why))
        done = {}
        for name, parts in sorted(heads.items()):
            key = id(parts["head"])
            if key not in done:
                done[key] = _fit_neck(parts["head"], target, name)[0]
            parts["head"] = done[key]
    log("\n== face depth at eye height %.2f (front of the face on the centre line; profile"
        " face_z = depth + %.3f)" % (EYE_Z, FACE_PAD))
    for name, parts in sorted(heads.items()):
        if name == "bald" or name.startswith("bald_"):
            continue
        d = _face_depth(parts["head"][0])
        log("  %-12s depth %.3f -> face_z %.3f" % (name, d, d + FACE_PAD))
    d = _face_depth(heads["bald"]["head"][0])
    log("  %-12s depth %.3f -> face_z %.3f (every tripo_bald_* part)" % ("shaved", d, d + FACE_PAD))
    log("\n== export -> %s" % ns.out_dir)
    ok = True
    keep = [x for x in ns.export_cells.split(",") if x]
    for name, parts in sorted(heads.items()):
        if name == "bald":
            continue
        if keep and not any(name.split("_", 1)[1].startswith(x) for x in keep):
            continue
        ok = _export(ns, name, parts) and ok
    if not ns.no_sheet:
        _sheet(ns, heads)
        _split_sheet(ns, heads)
    (ns.report_dir / "summary.txt").write_text("\n".join(_LOG) + "\n", encoding="utf-8")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
