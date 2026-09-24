"""Turn a Tripo-generated character into a drop-in replacement for the live character glb.

Run headless, nothing here needs the Blender GUI:

    blender.exe --background --factory-startup --python tools/blender/tripo_character.py -- \
        [--src IMPORT/CHARREWORK/singlebreasted.blend] [--rig assets/characters/CHARTGEN1.glb] \
        [--out assets/characters/CHARTGEN2.glb] [--stop-after STEP] [--report]

INPUT
-----
A .blend holding the Tripo model: one mesh (or several), all-quad, already split by the
owner into loose shells (jacket, trousers, head, hair, hands, shoe pieces, buttons, ...)
with UV seams marked on the garments. Any transform (the FBX import leaves a 90 degree X
rotation) is applied first. If an object in the .blend is already NAMED after a role
(`jacket`, `Hair`, `legs`, ...), that name wins and the object is taken whole; everything
else is split into loose shells and classified by geometry (z band, x position, size,
mirror pairs, overlap), and the table of what went where is printed so it can be checked.

OUTPUT
------
A glb skinned to the same KayKit `Rig_Medium` skeleton as the rig glb (--rig), with these
mesh nodes, which entities/character/character_rig.gd looks up by name:

    head  Hair  jacket  shirt  legs  arms  shoes  tie  buttons  square

(`head` as a mesh name is also what makes Godot rename the head BONE to `head_2`, which
the face code relies on, so it must stay.) The two shoe meshes of the old rig
(`left leg` / `right leg`) are replaced by the single `shoes`.

STEPS (each one a function; `--stop-after STEP` ends there and saves the working .blend)
------------------------------------------------------------------------------------
  classify  load, apply transforms, split shells, classify into roles, join per role
  align     uniform scale to the rig's height, feet on the floor, centred, front = -Y;
            prints landmarks against the rig and flags anything more than 10% off
  uv        cloth meshes (jacket legs shirt tie): unwrap on the owner's seams, then per
            island turn the grain (UV +V) to run up along the bone and scale to METRES
            (1 UV unit = 1 m of cloth, what ClothMaterial's uv_scale expects); the rest
            get a plain smart projection
  decimate  poly budget per role (Un-Subdivide where the quad grid allows it, else
            collapse), AFTER the unwrap so the seams are cut at full resolution
  skin      weights transferred from the matching rig mesh, head and hair hard-bound to
            the head bone; normalised, limited to 4, smoothed on the garments
  export    glb with only the armature and the 10 meshes, then re-read and checked
  --report  workbench renders, a UV layout per cloth mesh and summary.txt in --report-dir

See tools/blender/fix_garment_uvs.py for why the garment UVs are in metres and for the
unwraps that were tried on CHARTGEN1 and rejected. The difference here is that the owner
marks real tailoring seams, so each island is one pattern piece (sleeve, front, back,
trouser leg) and the grain can be set per piece.
"""

import argparse
import heapq
import json
import math
import os
import struct
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
STEPS = ("classify", "align", "uv", "decimate", "skin", "export")
ROLES = ("head", "Hair", "jacket", "shirt", "legs", "arms", "shoes", "tie", "buttons", "square")
# Meshes that get a tiling fabric in the game, so they need metre UVs and a grain.
CLOTH_ROLES = ("jacket", "legs", "shirt", "tie")
GARMENT_ROLES = ("jacket", "legs", "shirt", "tie")  # weights smoothed on these
DEFAULT_BUDGET = {
    "head": 1800,
    "Hair": 1800,
    "jacket": 2300,
    "legs": 800,
    "shirt": 380,  # front + collar + the two cuffs
    "shoes": 800,
    "arms": 500,
    "tie": 160,
    "buttons": 80,
    "square": 60,
}
# Where each mesh's skin weights come from. They are a COPY of the owner's hand-cleaned
# CHARTGEN1 weights: each vertex takes the inverse-distance average of the k nearest
# vertices of the matching rig mesh ("src"). Nothing is clipped except left/right.
#   Where the owner's mesh has NO vertex within KNN_RADIUS (his jacket has none between
#       |x| 0.30 and 0.45: one long quad spans from the cap ring to the sleeve tube), the
#       weights are interpolated linearly between his nearest vertex on the inner and on
#       the outer side along the limb, which is what his long quad does under linear
#       blend skinning.
#   "regions": "sleeves"  labels pieces (UV islands) past --sleeve-x as SLEEVE pieces,
#       for the report and for "sleeve_src"; with --body-caps / --sleeve-caps the mesh is
#       split along the armhole and the opening capped (a doll shoulder / arm socket).
#   "regions": "legs"  the trouser legs are split at the rise so each keeps its own side.
#   "sleeve_src": rig meshes the sleeve pieces sample instead (shirt cuffs -> jacket).
#   "own": sample OUR finished mesh of that name (tie and buttons ride on the new jacket).
#   "top_body": vertices inside --sleeve-x that stand ABOVE the owner's garment in their
#       |x| column (our shoulder top is higher than his) sample only his body vertices
#       (arm weight under half), so the shoulder top rides with chest/spine like the
#       body just beneath it instead of turning with his sleeve cap.
#   "bind": hard-bind the whole mesh to one bone.
WEIGHT_RULES = {
    "jacket": {"src": ("jacket",), "regions": "sleeves", "cap": True, "top_body": True},
    "shirt": {"src": ("shirt",), "regions": "sleeves", "sleeve_src": ("jacket",)},
    "legs": {"src": ("legs",), "regions": "legs"},
    "arms": {"src": ("arms",)},
    "shoes": {"src": ("left leg", "right leg")},
    "tie": {"own": "jacket"},
    "buttons": {"own": "jacket"},
    "square": {"own": "jacket"},
    "head": {"bind": "head"},
    "Hair": {"bind": "head"},
}
ARM_BONES = (
    "upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
    "upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
)
# Jacket body vertices above the armpit and near the centre (the collar and lapels, and
# any piece whose centre sits there) carry no arm bone: in a walk the arms swing and an
# arm weight there drags the lapel towards the sleeve.
LAPEL_ZONE_Z = 1.02
LAPEL_ZONE_X = 0.17
KNN = 6  # source vertices averaged per vertex
KNN_RADIUS = 0.06  # metres; past it the single nearest source vertex is used
MIN_WEIGHT = 0.05  # weights below this are dropped before the limit of 4
CAP_INSET = 0.015  # metres the doll-shoulder cap sits inside the body, towards x = 0
HEM_BAND = 0.05  # metres of trouser hem that are 100% lowerleg, blended over as much again
HEAD_BONE = "head"
MATERIAL = {
    "head": "skin",
    "arms": "skin",
    "Hair": "hair",
    "jacket": "cloth",
    "legs": "cloth",
    "shirt": "cloth",
    "tie": "cloth",
    "square": "cloth",
    "shoes": "shoe",
    "buttons": "button",
}
REPORT_COLOUR = {
    "head": (0.93, 0.76, 0.62),
    "arms": (0.93, 0.76, 0.62),
    "Hair": (0.45, 0.27, 0.18),
    "jacket": (0.35, 0.45, 0.70),
    "legs": (0.40, 0.35, 0.60),
    "shirt": (0.92, 0.92, 0.88),
    "tie": (0.75, 0.25, 0.25),
    "square": (0.30, 0.75, 0.75),
    "shoes": (0.25, 0.22, 0.20),
    "buttons": (0.95, 0.80, 0.30),
}
RIG_PREFIX = "RIG_"
STRETCH_LIMIT = 1.6  # same limit as fix_garment_uvs: past this a weave visibly smears
LANDMARK_TOLERANCE = 0.10

# Classification thresholds, all in units of total model height (feet at 0, top at 1).
SHOE_TOP = 0.12  # shells entirely below this are shoe pieces
HAND_REACH = 0.9  # a shell reaching this fraction of the widest x is a hand
HEAD_REGION = 0.8  # big shells reaching above this are the head and the hair
HEAD_ATTACH = 0.1  # small shells this far above the neck, inside the head box: ears etc.
CENTRE_X = 0.02  # |x| below this counts as on the centre line
BUTTON_SIZE = 0.025
OVERLAP = 0.003

_LOG = []


def log(text="") -> None:
    print(text)
    _LOG.append(text)


# ---------------------------------------------------------------------------------------
# arguments


def _arguments(argv):
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    p = argparse.ArgumentParser(prog="tripo_character.py")
    p.add_argument("--src", default="IMPORT/CHARREWORK/singlebreasted.blend")
    p.add_argument("--rig", default="assets/characters/CHARTGEN1.glb")
    p.add_argument("--out", default="assets/characters/CHARTGEN2.glb")
    p.add_argument("--stop-after", choices=STEPS, default="export")
    p.add_argument("--report", action="store_true", help="render the result and its UVs")
    p.add_argument("--report-dir", default="IMPORT/CHARREWORK/report")
    p.add_argument("--height", type=float, default=0.0, help="target height; 0 = the rig's")
    p.add_argument(
        "--sleeve-x",
        type=float,
        default=0.25,
        help="islands whose centroid |x| (m, after scaling) is past this follow the arm bone",
    )
    p.add_argument("--budget", default="", help="role=tris,... overrides, e.g. Hair=2500")
    p.add_argument("--no-unsubdiv", action="store_true", help="always use collapse decimate")
    p.add_argument(
        "--auto-seams",
        action="store_true",
        help="FALLBACK for models without owner seams: add a trouser rise + inseams and a "
        "jacket centre-back seam by shortest path where none is marked",
    )
    p.add_argument(
        "--no-centre-cut",
        action="store_true",
        help="do not split wide garment pieces that still straddle x = 0 (fused fronts)",
    )
    p.add_argument(
        "--shoulder-seams",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="cut the jacket from each armhole top to the neckline when the owner marked no "
        "shoulder seam, so front and back are separate pieces with their own grain "
        "(default on; without it the stripes form a V over the back)",
    )
    p.add_argument(
        "--weight-smooth",
        type=int,
        default=0,
        help="smoothing passes on the garment weights (within each mesh's bone set)",
    )
    p.add_argument(
        "--cap-blend",
        type=float,
        default=0.0,
        help="metres of sleeve next to the armhole that blend from the body's weights to "
        "the arm (like the owner's sleeve caps, measured at ~0.07 m on CHARTGEN1); "
        "0 = sleeves follow the arm alone, which opens a hole over each shoulder when "
        "the arm drops because the Tripo cap is twice as tall",
    )
    p.add_argument(
        "--rigid-hem",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="make the bottom 5 cm of the trousers 100%% lowerleg (a rigid cuff), blended over"
        " the next 5 cm; the owner's hem carries ~15%% foot, which tilts the hem with the"
        " foot in a walk (default on)",
    )
    p.add_argument(
        "--body-caps",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="cap the jacket body's armholes with a fan set inside the body (a doll shoulder),"
        " so a dropped sleeve shows a closed shoulder (default on)",
    )
    p.add_argument(
        "--sleeve-caps",
        action="store_true",
        help="split the jacket at the armholes and cap the sleeves' tops (doll arm socket)",
    )
    p.add_argument(
        "--straight-hem",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="make the bottom 10 cm of each trouser leg a straight column (off: measured, the"
        " Tripo legs are already straight at rest)",
    )
    p.add_argument(
        "--decimate",
        action="store_true",
        help="reduce each mesh to its --budget (off: the full Tripo mesh is exported)",
    )
    p.add_argument(
        "--copy-weights",
        action="store_true",
        help="copy the owner's CHARTGEN1 weights by position instead of the rigid per-part"
        " assignment (the default)",
    )
    p.add_argument(
        "--stitch-armhole",
        type=float,
        default=0.04,
        help="stitch each sleeve to the body along the armhole: the ring takes the body's"
        " bones at its height, handing over to the arm across this many metres (0 = off)."
        " Default on: the owner chose it over an open sleeve top, sleeve caps and a"
        " top-only chest band, the only variant with no gap at 45 and 90 degrees",
    )
    p.add_argument(
        "--shoulder-band",
        type=float,
        default=0.0,
        help="the shoulder round of each sleeve stays on the chest: 100%% within this many"
        " metres of the sleeve's highest point and of the armhole, handing over to the arm"
        " across as much again (down and along the arm); 0 = off",
    )
    for joint, width in JOINT_BLENDS.items():
        p.add_argument(
            "--%s-blend" % joint,
            type=float,
            default=None,
            help="metres of hand-over at the %s (default %.2f)" % (joint, width),
        )
    p.add_argument(
        "--fold-seams",
        type=float,
        default=0.0,
        help="also cut the cloth along folds sharper than this many degrees (0 = off)",
    )
    p.add_argument("--flip-front", action="store_true", help="force a 180 degree turn")
    p.add_argument("--no-front-check", action="store_true", help="never turn the model")
    ns = p.parse_args(args)
    for key in ("src", "rig", "out", "report_dir"):
        path = Path(getattr(ns, key))
        setattr(ns, key, path if path.is_absolute() else (ROOT / path).resolve())
    ns.budgets = dict(DEFAULT_BUDGET)
    for item in filter(None, ns.budget.split(",")):
        k, v = item.split("=")
        ns.budgets[k.strip()] = int(v)
    return ns


# ---------------------------------------------------------------------------------------
# small helpers


def _select_only(objs, active=None) -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objs[0] if objs else None)


def _world_verts(obj):
    m = obj.matrix_world
    return [m @ v.co for v in obj.data.vertices]


def _bounds(points):
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


def _tris(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _role_objects():
    return {r: bpy.data.objects[r] for r in ROLES if r in bpy.data.objects}


def _rig_objects():
    return {
        o.name[len(RIG_PREFIX) :]: o
        for o in bpy.data.objects
        if o.type == "MESH" and o.name.startswith(RIG_PREFIX)
    }


def _armature():
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


def _bone_head(arm, name) -> Vector:
    return arm.matrix_world @ arm.data.bones[name].head_local


def _role_from_name(name):
    base = name.split(".")[0].strip().lower()
    for role in ROLES:
        if base == role.lower():
            return role
    aliases = {"trousers": "legs", "pants": "legs", "hands": "arms", "hair": "Hair"}
    return aliases.get(base)


# ---------------------------------------------------------------------------------------
# step 1: classify


def step_classify(ns) -> None:
    log("== classify: %s" % ns.src)
    bpy.ops.wm.open_mainfile(filepath=str(ns.src))
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    tripo = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in tripo:
        log("  source object %-40s rot=%s scale=%s" % (
            o.name, tuple(round(math.degrees(a), 1) for a in o.rotation_euler),
            tuple(round(s, 3) for s in o.scale)))
    # a file saved in Edit Mode keeps its mesh in the edit buffer: leave Edit Mode first,
    # or the next mode switch writes the stale buffer back over everything done below
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        log("  the file was saved in %s mode: back to Object mode" % bpy.context.object.mode)
        bpy.ops.object.mode_set(mode="OBJECT")
    # objects hidden in the file cannot be selected, so every operator would skip them
    # (a hidden head kept its FBX rotation and ended up at the feet): unhide everything,
    # and bake the transforms into the meshes directly rather than through the selection
    hidden = [o.name for o in tripo if o.hide_get() or o.hide_viewport or o.hide_select]
    for o in tripo:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_select = False
    if hidden:
        log("  %d object(s) were hidden in the file, unhidden: %s" % (len(hidden), ", ".join(hidden)))
    for o in tripo:
        if o.data.users > 1:
            o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)

    # nothing active or selected: the glTF importer builds its bone-shape icosphere into
    # the active object's mesh when there is one
    _select_only([])
    rig_objects = _import_rig(ns.rig)

    named = {}
    shells = []
    for o in tripo:
        role = _role_from_name(o.name)
        if role is not None:
            named.setdefault(role, []).append(o)
            log("  object %s is named after role %s: taken whole" % (o.name, role))
            continue
        _select_only([o])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in rig_objects:
            if not any(o in objs for objs in named.values()):
                shells.append(o)
    roles = _classify(shells, named)
    for role in ROLES:
        objs = roles.get(role, [])
        if not objs:
            log("  WARNING: nothing classified as %s" % role)
            continue
        _select_only(objs)
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = role
        obj.data.name = role
        with bpy.context.temp_override(object=obj, active_object=obj):
            if obj.data.has_custom_normals:
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if "legs" in bpy.data.objects and "shoes" in bpy.data.objects:
        _shoe_bits_off_trousers(bpy.data.objects["legs"], bpy.data.objects["shoes"])
    missing = [r for r in ROLES if r not in bpy.data.objects]
    if missing:
        log("  roles this model has no shell for (left out of the glb): %s" % ", ".join(missing))
    leftovers = [o for o in bpy.data.objects if o.type == "MESH"
                 and o.name not in ROLES and o not in rig_objects]
    for o in leftovers:
        bpy.data.objects.remove(o, do_unlink=True)


def _shoe_bits_off_trousers(legs, shoes) -> None:
    """Tripo sometimes fuses a bit of a shoe (a lace) into the trouser shell. A trouser
    leg never reaches lower than its mirror twin, so faces below the other leg's lowest
    point (less a small margin) are shoe, and move to the shoes mesh."""
    me = legs.data
    pts = [legs.matrix_world @ v.co for v in me.vertices]
    height = max(p.z for p in pts) - min(p.z for p in pts)
    lows = {}
    for p in pts:
        side = 1 if p.x > 0 else -1
        lows[side] = min(lows.get(side, 1e9), p.z)
    if len(lows) < 2:
        return
    bm = bmesh.new()
    bm.from_mesh(me)
    moved = []
    for f in bm.faces:
        c = legs.matrix_world @ f.calc_center_median()
        side = 1 if c.x > 0 else -1
        if c.z < lows[-side] - 0.002 * height:
            moved.append(f)
    if not moved:
        bm.free()
        return
    lo = min((legs.matrix_world @ f.calc_center_median()).z for f in moved)
    hi = max((legs.matrix_world @ f.calc_center_median()).z for f in moved)
    part = bmesh.new()
    vmap = {}
    for f in moved:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = part.verts.new(legs.matrix_world @ v.co)
            vs.append(vmap[v])
        part.faces.new(vs)
    bmesh.ops.delete(bm, geom=moved, context="FACES")
    bm.to_mesh(me)
    bm.free()
    bit = bpy.data.meshes.new("shoe_bit")
    part.to_mesh(bit)
    part.free()
    ob = bpy.data.objects.new("shoe_bit", bit)
    bpy.context.scene.collection.objects.link(ob)
    _select_only([shoes, ob], shoes)
    bpy.ops.object.join()
    for poly in shoes.data.polygons:
        poly.use_smooth = True
    log("  %d trouser faces below the other leg's hem (z %.3f..%.3f) are shoe: moved to shoes"
        % (len(moved), lo, hi))


def _import_rig(path) -> set:
    """Import the target rig next to the model; its meshes are renamed RIG_<name> (they are
    the weight sources and the landmark reference). Returns every object it brought in."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = set(bpy.data.objects) - before
    for o in added:
        if o.type == "MESH" and o.parent is not None and o.parent.type == "ARMATURE":
            o.name = RIG_PREFIX + o.name
            o.data.name = o.name
    arm = _armature()
    log("  rig %s: armature %s, %d bones, meshes %s" % (
        path.name, arm.name, len(arm.data.bones),
        ", ".join(sorted(n for n in _rig_objects()))))
    return added


def _shell_info(i, obj):
    me = obj.data
    pts = _world_verts(obj)
    lo, hi = _bounds(pts)
    bm = bmesh.new()
    bm.from_mesh(me)
    open_edges = sum(1 for e in bm.edges if e.is_boundary)
    seams = sum(1 for e in bm.edges if e.seam)
    bm.free()
    return {
        "i": i,
        "obj": obj,
        "nv": len(me.vertices),
        "nf": len(me.polygons),
        "open": open_edges,
        "seams": seams,
        "lo": lo,
        "hi": hi,
        "c": sum(pts, Vector()) / len(pts),
    }


def _classify(shells, named):
    """Sort loose shells into roles by geometry. Returns {role: [objects]}."""
    infos = [_shell_info(i, o) for i, o in enumerate(sorted(shells, key=lambda o: -len(o.data.vertices)))]
    if not infos:
        return {r: list(v) for r, v in named.items()}
    lo_all, hi_all = _bounds([s["lo"] for s in infos] + [s["hi"] for s in infos])
    height = hi_all.z - lo_all.z
    xc = (lo_all.x + hi_all.x) * 0.5
    yc = (lo_all.y + hi_all.y) * 0.5

    def n(v):  # normalised: feet at 0, top at 1, centred in x/y
        return Vector(((v.x - xc) / height, (v.y - yc) / height, (v.z - lo_all.z) / height))

    for s in infos:
        s["nlo"], s["nhi"], s["nc"] = n(s["lo"]), n(s["hi"]), n(s["c"])
        s["dims"] = s["nhi"] - s["nlo"]
        s["role"], s["why"] = None, ""
    maxabs = max(max(abs(s["nlo"].x), abs(s["nhi"].x)) for s in infos)
    for s in infos:
        s["pair"] = next(
            (t["i"] for t in infos if t is not s
             and abs(t["nc"].x + s["nc"].x) < 0.01 and abs(t["nc"].z - s["nc"].z) < 0.01
             and abs(t["nc"].y - s["nc"].y) < 0.02
             and 0.7 < t["nv"] / max(s["nv"], 1) < 1.43), None)

    def free():
        return [s for s in infos if s["role"] is None]

    def assign(s, role, why):
        s["role"], s["why"] = role, why

    max_nf = max(s["nf"] for s in infos)
    for s in free():
        if s["nhi"].z < SHOE_TOP:
            assign(s, "shoes", "below %.2f H" % SHOE_TOP)
        elif max(abs(s["nlo"].x), abs(s["nhi"].x)) >= HAND_REACH * maxabs:
            assign(s, "arms", "reaches the arm tips")
    big = [s for s in free() if s["nhi"].z > HEAD_REGION and s["nf"] >= 0.05 * max_nf]
    head = hair = None
    if "head" not in named and big:
        head = min(big, key=lambda s: s["nlo"].z)
        assign(head, "head", "big, top region, reaches lowest (neck)")
    if "Hair" not in named:
        rest = [s for s in big if s is not head]
        if rest:
            hair = max(rest, key=lambda s: s["nhi"].z)
            assign(hair, "Hair", "big, top region, highest top")
    boxes = [s for s in (head, hair) if s is not None]
    if boxes:
        blo, bhi = _bounds([s["nlo"] for s in boxes] + [s["nhi"] for s in boxes])
        neck = min(s["nlo"].z for s in boxes)
        for s in free():
            inside = all(blo[k] - 0.01 <= s["nc"][k] <= bhi[k] + 0.01 for k in range(3))
            if inside and s["nc"].z > neck + HEAD_ATTACH:
                assign(s, "head", "inside the head box (ear etc.)")

    width_all = 2.0 * maxabs
    wide = [s for s in free() if s["dims"].x > 0.4 * width_all]
    jacket = max(wide, key=lambda s: s["nf"]) if wide and "jacket" not in named else None
    if jacket is not None:
        assign(jacket, "jacket", "largest wide torso shell")
    hem = jacket["nlo"].z if jacket else 0.3
    top = jacket["nhi"].z if jacket else 0.6
    low = [s for s in free() if s["nc"].z < hem + 0.05 and s["dims"].z > 0.1]
    if low and "legs" not in named:
        assign(max(low, key=lambda s: s["nf"]), "legs", "largest shell below the jacket hem")
    sleeve_x = 0.5 * maxabs
    sleeve_end = max(abs(jacket["nlo"].x), abs(jacket["nhi"].x)) if jacket else maxabs
    for s in free():
        if abs(s["nc"].x) <= sleeve_x:
            continue
        reach = max(abs(s["nlo"].x), abs(s["nhi"].x))
        size = max(s["dims"].y, s["dims"].z)
        if size > 2.0 * BUTTON_SIZE and s["open"] > 0 and reach > sleeve_end:
            # a ring round the wrist that sits in the sleeve opening and pokes out past
            # the jacket's sleeve end: the shirt cuff, not part of the jacket
            assign(s, "shirt", "shirt cuff: %.3f wide ring, reaches %.3f past the sleeve end"
                   % (size, reach - sleeve_end))
        else:
            assign(s, "jacket", "sleeve zone (cuff button / trim)")
    # the tie first: a long narrow centred shell is the tie even when it reaches the
    # collar (a tie modelled with its knot in one piece does)
    for s in free():
        d = s["dims"]
        if abs(s["nc"].x) < CENTRE_X and d.z > 0.05 and d.z > 3.0 * max(d.x, 1e-6):
            assign(s, "tie", "centred, long and narrow (blade)")
    collar = [s for s in free() if abs(s["nc"].x) < CENTRE_X and s["nhi"].z > top - 0.05]
    if collar and "shirt" not in named:
        assign(max(collar, key=lambda s: s["nf"]), "shirt", "largest centred shell at the collar")
    # the rest of a shirt split into several pieces: anything lying inside the shirt's box
    # that is not touching the tie, or a centred piece over it that is wider than the tie
    shirt = next((s for s in infos if s["role"] == "shirt"), None)
    blades = [s for s in infos if s["role"] == "tie"]
    if shirt is not None:
        tie_w = max((t["dims"].x for t in blades), default=0.0)
        for s in free():
            inside = all(shirt["nlo"][k] - OVERLAP <= s["nlo"][k] and
                         s["nhi"][k] <= shirt["nhi"][k] + OVERLAP for k in range(3))
            on_tie = any(_overlap(s, t, OVERLAP) for t in blades)
            wide = (abs(s["nc"].x) < CENTRE_X and _overlap(s, shirt, OVERLAP)
                    and s["dims"].x > 1.3 * tie_w)
            if inside and not on_tie:
                assign(s, "shirt", "inside the shirt's box, clear of the tie")
            elif wide:
                assign(s, "shirt", "centred over the shirt, wider than the tie")
    grew = True
    while grew:
        grew = False
        ties = [s for s in infos if s["role"] == "tie"]
        for s in free():
            if abs(s["nc"].x) < CENTRE_X and any(_overlap(s, t, OVERLAP) for t in ties):
                assign(s, "tie", "centred, touches the tie (knot)")
                grew = True
    for s in free():
        d = s["dims"]
        size = max(d.x, d.z)
        aspect = size / max(min(d.x, d.z), 1e-6)
        if size < BUTTON_SIZE and aspect < 1.5 and s["nc"].y < 0.0:
            assign(s, "buttons", "small, round, on the front")
    chest = (hem + top) * 0.5
    pocket = [s for s in free() if s["pair"] is None and abs(s["nc"].x) > CENTRE_X
              and s["nc"].z > chest]
    if pocket:
        sq = min(pocket, key=lambda s: s["dims"].x)
        assign(sq, "square", "unpaired chest piece, the narrowest (the welt is wider)"
               if len(pocket) > 1 else "the only unpaired piece on the chest")
    for s in free():
        assign(s, "jacket", "torso default (flap / welt / trim)")

    log("  %d shells, height %.3f, widest |x| %.3f (normalised to H=1 below)" % (
        len(infos), height, maxabs))
    log("  %3s %6s %6s %5s %4s %-21s %-21s %-21s %-8s %s" % (
        "#", "verts", "faces", "open", "pair", "x", "y", "z", "role", "why"))
    for s in infos:
        lo, hi = s["nlo"], s["nhi"]
        log("  %3d %6d %6d %5d %4s [%6.3f,%6.3f]     [%6.3f,%6.3f]     [%6.3f,%6.3f]     %-8s %s" % (
            s["i"], s["nv"], s["nf"], s["open"], "-" if s["pair"] is None else s["pair"],
            lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, s["role"], s["why"]))
    out = {r: list(v) for r, v in named.items()}
    for s in infos:
        out.setdefault(s["role"], []).append(s["obj"])
    return out


def _overlap(a, b, margin) -> bool:
    return all(a["nlo"][k] - margin <= b["nhi"][k] and b["nlo"][k] - margin <= a["nhi"][k]
               for k in range(3))


# ---------------------------------------------------------------------------------------
# step 2: align


def step_align(ns) -> None:
    log("\n== align")
    objs = _role_objects()
    rig = _rig_objects()
    pts = [p for o in objs.values() for p in _world_verts(o)]
    lo, hi = _bounds(pts)
    target = ns.height
    if target <= 0.0:
        rpts = [p for o in rig.values() for p in _world_verts(o)]
        target = max(p.z for p in rpts) - min(p.z for p in rpts)
    scale = target / (hi.z - lo.z)
    turn = _front_turn(ns, objs, rig)
    torso = objs.get("jacket") or objs.get("legs")
    tlo, thi = _bounds(_world_verts(torso)) if torso else (lo, hi)
    centre = Vector(((lo.x + hi.x) * 0.5, (tlo.y + thi.y) * 0.5, lo.z))
    m = (
        Matrix.Rotation(math.pi if turn else 0.0, 4, "Z")
        @ Matrix.Diagonal((scale, scale, scale, 1.0))
        @ Matrix.Translation(-centre)
    )
    for o in objs.values():
        o.data.transform(m)
        o.matrix_world = Matrix.Identity(4)
        o.data.update()
    log("  height %.3f -> %.3f (x%.4f), centred on x %.4f / torso y %.4f, feet at z 0%s" % (
        hi.z - lo.z, target, scale, centre.x, centre.y, ", turned 180" if turn else ""))
    _landmarks(objs, rig)
    if "legs" in objs:
        if ns.straight_hem:
            _straight_hem(objs["legs"])
        else:
            _hem_table(objs["legs"], "(rest, --straight-hem off)")


HEM_BAND_M = 0.10  # the bottom of each trouser leg that --straight-hem makes a column
HEM_REF = (0.10, 0.14)  # the section above the hem it copies (metres over the hem)


def _hem_table(obj, title) -> None:
    """Per leg: centre and half-widths (x across, y front-back) of the trouser tube at the
    hem ring, +5 and +10 cm, and the hem height."""
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    log("  trouser hems %s:" % title)
    for side in (1.0, -1.0):
        leg = [p for p in pts if p.x * side > 0.0]
        bottom = min(p.z for p in leg)
        row = "    leg %s hem %.3f m |" % ("+x" if side > 0 else "-x", bottom)
        for name, lo, hi in (("ring", 0.0, 0.012), ("+5", 0.04, 0.06), ("+10", 0.09, 0.11),
                             ("+12", 0.10, 0.14)):
            band = [p for p in leg if bottom + lo <= p.z <= bottom + hi]
            if not band:
                row += " %s -" % name
                continue
            xs, ys = [p.x for p in band], [p.y for p in band]
            row += " %s x%.3f y%.3f c(%+.3f,%+.3f)" % (
                name, (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2,
                (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2)
        log(row)


def _straight_hem(obj) -> None:
    """Make the bottom HEM_BAND_M of each trouser leg a straight column: every 1 cm slice
    is re-centred and rescaled (x and front-back separately) onto the section HEM_REF
    above the hem, fully at the hem and blending out towards the top of the band. The
    Tripo legs bell out at the back towards the hem (8% deeper at the ring than 20 cm up);
    the reference draws straight columns ending on the shoes."""
    _hem_table(obj, "before --straight-hem")
    me = obj.data
    pts = [v.co.copy() for v in me.vertices]
    inward = 0
    moved = 0
    for side in (1.0, -1.0):
        idx = [i for i, p in enumerate(pts) if p.x * side > 0.0]
        bottom = min(pts[i].z for i in idx)
        ref = [pts[i] for i in idx if bottom + HEM_REF[0] <= pts[i].z <= bottom + HEM_REF[1]]
        if len(ref) < 4:
            log("    leg %+d: no section to copy, left as is" % side)
            continue
        rc = Vector(((max(p.x for p in ref) + min(p.x for p in ref)) / 2,
                     (max(p.y for p in ref) + min(p.y for p in ref)) / 2))
        rr = Vector(((max(p.x for p in ref) - min(p.x for p in ref)) / 2,
                     (max(p.y for p in ref) - min(p.y for p in ref)) / 2))
        slices = {}
        for i in idx:
            if pts[i].z < bottom + HEM_BAND_M:
                slices.setdefault(int((pts[i].z - bottom) / 0.01), []).append(i)
        for band, members in slices.items():
            sp = [pts[i] for i in members]
            if len(sp) < 3:
                continue
            c = Vector(((max(p.x for p in sp) + min(p.x for p in sp)) / 2,
                        (max(p.y for p in sp) + min(p.y for p in sp)) / 2))
            r = Vector(((max(p.x for p in sp) - min(p.x for p in sp)) / 2,
                        (max(p.y for p in sp) - min(p.y for p in sp)) / 2))
            for i in members:
                p = pts[i]
                t = 1.0 - min(max((p.z - bottom) / HEM_BAND_M, 0.0), 1.0)
                t = t * t * (3.0 - 2.0 * t)
                ox = (p.x - c.x) * (rr.x / max(r.x, 1e-6))
                oy = (p.y - c.y) * (rr.y / max(r.y, 1e-6))
                nx, ny = rc.x + ox, rc.y + oy
                if (Vector((p.x, p.y)) - c).length < 0.5 * min(r.x, r.y):
                    inward += 1  # a vertex well inside the tube: part of a turned-in loop
                me.vertices[i].co.x = p.x + (nx - p.x) * t
                me.vertices[i].co.y = p.y + (ny - p.y) * t
                moved += 1
    me.update()
    log("    --straight-hem: %d verts moved in the bottom %.2f m, %d inside the tube"
        " (turned-in loop)" % (moved, HEM_BAND_M, inward))
    _hem_table(obj, "after --straight-hem")


def _front_turn(ns, objs, rig) -> bool:
    if ns.flip_front:
        return True
    if ns.no_front_check:
        return False

    def front_sign(meshes):
        body = meshes.get("jacket") or meshes.get("legs")
        marks = [meshes[k] for k in ("buttons", "tie") if k in meshes]
        if body is None or not marks:
            return 0.0
        by = sum(p.y for p in _world_verts(body)) / len(body.data.vertices)
        pts = [p for o in marks for p in _world_verts(o)]
        return math.copysign(1.0, sum(p.y for p in pts) / len(pts) - by)

    ours, theirs = front_sign(objs), front_sign(rig)
    log("  front: model faces %s, rig faces %s" % (
        {1.0: "+Y", -1.0: "-Y", 0.0: "?"}[ours], {1.0: "+Y", -1.0: "-Y", 0.0: "?"}[theirs]))
    return ours != 0.0 and theirs != 0.0 and ours != theirs


def _measure(meshes, arm, seam_obj):
    def pts(*names):
        return [p for n in names if n in meshes for p in _world_verts(meshes[n])]

    out = {}
    allp = pts(*meshes.keys())
    out["total height"] = max(p.z for p in allp)
    arms = pts("arms")
    if arms:
        out["hand centre z (sleeve axis)"] = sum(p.z for p in arms) / len(arms)
        out["hand tip |x|"] = (max(p.x for p in arms) - min(p.x for p in arms)) * 0.5
    if seam_obj is not None:
        me = seam_obj.data
        axis = out.get("hand centre z (sleeve axis)", 0.0)
        xs = sorted({abs(me.vertices[v].co.x) for e in me.edges if e.use_seam
                     for v in e.vertices if me.vertices[v].co.z >= axis})
        if xs:
            out["armhole |x|"] = xs[len(xs) // 2]
    else:
        out["armhole |x|"] = abs(_bone_head(arm, "upperarm.l").x)
    for key, names, fn in (
        ("jacket hem z", ("jacket",), min),
        ("jacket width |x|", ("jacket",), None),
        ("trouser hem z", ("legs",), min),
        ("trouser top z", ("legs",), max),
        ("head bottom z", ("head",), min),
        ("head top z", ("head",), max),
        ("hair top z", ("Hair",), max),
        ("shoe top z", ("shoes", "left leg", "right leg"), max),
    ):
        p = pts(*names)
        if not p:
            continue
        if fn is None:
            out[key] = (max(q.x for q in p) - min(q.x for q in p)) * 0.5
        else:
            out[key] = fn(q.z for q in p)
    return out


def _landmarks(objs, rig) -> None:
    arm = _armature()
    ours = _measure(objs, arm, objs.get("jacket"))
    theirs = _measure(rig, arm, None)
    log("  arm bone height %.3f, upperarm |x| %.3f, hand bone |x| %.3f, hips %.3f, head bone %.3f"
        % (_bone_head(arm, "upperarm.l").z, abs(_bone_head(arm, "upperarm.l").x),
           abs(_bone_head(arm, "hand.l").x), _bone_head(arm, "hips").z,
           _bone_head(arm, "head").z))
    log("  %-28s %8s %8s %8s" % ("landmark", "model", "rig", "off"))
    for key, ref in theirs.items():
        if key not in ours:
            continue
        off = (ours[key] - ref) / ref if abs(ref) > 1e-6 else 0.0
        flag = "  <-- more than %d%% off" % (LANDMARK_TOLERANCE * 100) if abs(off) > LANDMARK_TOLERANCE else ""
        log("  %-28s %8.3f %8.3f %+7.1f%%%s" % (key, ours[key], ref, off * 100, flag))
    log("  (rig armhole = the upperarm bone; the model's = median |x| of seam verts above the"
        " sleeve axis)")


# ---------------------------------------------------------------------------------------
# step 4: uv (runs before the decimation)


def step_uv(ns) -> None:
    log("\n== uv")
    objs = _role_objects()
    arm = _armature()
    for role in CLOTH_ROLES:
        if role in objs:
            _unwrap_cloth(ns, objs[role], arm)
    for role, obj in objs.items():
        if role not in CLOTH_ROLES:
            _smart_project(obj)
    log("  smart-projected (0..1): %s" % ", ".join(r for r in objs if r not in CLOTH_ROLES))


def _fold_seams(bm, name, degrees) -> int:
    """Seams along folds sharper than `degrees`: a trouser leg closed at the bottom, a
    turned-up cuff, a lapel's roll edge. Flattening a tube together with the cap or the
    fold on its end smears the whole piece; cut there, each part flattens on its own."""
    limit = math.radians(degrees)
    n = 0
    for e in bm.edges:
        if e.seam or len(e.link_faces) != 2:
            continue
        if e.calc_face_angle(0.0) > limit:
            e.seam = True
            n += 1
    if n:
        log("    %-7s %d edges on folds sharper than %.0f deg marked as seams" % (name, n, degrees))
    return n


def _unwrap_cloth(ns, obj, arm) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    owner = sum(1 for e in bm.edges if e.seam)
    added = 0
    if ns.auto_seams:
        added += _auto_seams(bm, obj.name)
    if ns.shoulder_seams and obj.name == "jacket":
        added += _shoulder_seams(bm, obj.name)
    if ns.fold_seams > 0.0:
        added += _fold_seams(bm, obj.name, ns.fold_seams)
    added += _cut_to_disks(bm, obj.name, ns.sleeve_x, not ns.no_centre_cut)
    bm.to_mesh(obj.data)
    bm.free()
    log("  %-7s seams: %d marked by the owner, %d added by script" % (obj.name, owner, added))
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    _select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", fill_holes=True, correct_aspect=True, margin=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    _orient_islands(obj, arm, ns.sleeve_x)
    obj["stretch_full"] = _stretch(obj, "full res")


def _islands(bm):
    """Faces grouped into pieces of cloth: joined across every edge that is not a seam."""
    bm.faces.ensure_lookup_table()
    parent = list(range(len(bm.faces)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in bm.edges:
        if e.seam or len(e.link_faces) != 2:
            continue
        a, b = find(e.link_faces[0].index), find(e.link_faces[1].index)
        if a != b:
            parent[a] = b
    groups = {}
    for f in bm.faces:
        groups.setdefault(find(f.index), []).append(f)
    return list(groups.values())


def _cut_to_disks(bm, name, sleeve_x, centre_cut=True) -> int:
    """Make every piece flattenable, finishing cuts the seams leave open.

    Non-manifold edges (three faces, where Tripo fused two layers of cloth) become seams.
    Then each piece (faces joined across non-seam edges) is checked on a copy split along
    its seams: a piece with more than one boundary loop (a ring, a front fused at the
    button, a centre-back seam that stops at a hole above the vent) gets its loops joined
    by shortest paths, a closed piece gets a slit. A piece straddling the centre line is
    cut along it (x = 0); sleeve pieces are cut underneath; others at the back.
    Returns the number of seam edges added.
    """
    added = 0
    for e in bm.edges:
        if len(e.link_faces) > 2 and not e.seam:
            e.seam = True
            added += 1
    if added:
        log("    %-7s %d non-manifold edges marked as seams" % (name, added))
    work = bm.copy()
    orig = work.verts.layers.int.new("orig")
    for v, ov in zip(work.verts, bm.verts):
        v[orig] = ov.index
    bmesh.ops.split_edges(work, edges=[e for e in work.edges if e.seam])
    bm.verts.ensure_lookup_table()
    work.verts.ensure_lookup_table()
    for faces in _islands(work):
        fset = set(faces)
        verts = {v for f in faces for v in f.verts}
        edges = {e for f in faces for e in f.edges}
        loops = _boundary_loops([e for e in edges if e.is_boundary])
        chi = len(verts) - len(edges) + len(faces)
        if len(loops) == 1 and chi == 1:
            continue
        centre = sum((v.co for v in verts), Vector()) / len(verts)
        lo, hi = _bounds([v.co for v in verts])
        xpenalty = 0.0
        if lo.x < -0.02 and hi.x > 0.02 and abs(centre.x) < sleeve_x:
            prefer, xpenalty, where = Vector(), 60.0, "along the centre line"
        elif abs(centre.x) > sleeve_x:
            prefer, where = Vector((0, 0, -1)), "underneath"
        else:
            prefer, where = Vector((0, 1, 0)), "at the back"
        paths = []
        if not loops:
            a = min(verts, key=lambda v: v.co.z)
            b = max(verts, key=lambda v: v.co.z)
            paths.append(_dijkstra(fset, {a}, {b}, centre, prefer, xpenalty))
            what = "closed piece: slit %s" % where
        else:
            joined = set(loops[0])
            rest = [set(lp) for lp in loops[1:]]
            while rest:
                path = _dijkstra(fset, joined, set().union(*rest), centre, prefer, xpenalty)
                if not path:
                    break
                hit = next(lp for lp in rest if path[-1] in lp)
                rest.remove(hit)
                joined |= hit | set(path)
                paths.append(path)
            what = "%d boundary loops joined %s (%s edges)" % (
                len(loops), where, "+".join(str(len(p) - 1) for p in paths))
            if chi != 2 - len(loops):
                what += " - Euler %d does not match %d loops (a handle or a pinched vertex)" % (
                    chi, len(loops))
            if len(loops) == 1:
                what = "one boundary loop but Euler %d: a handle or a pinched vertex, left as is" % chi
        for path in paths:
            for a, b in zip(path, path[1:]):
                e = bm.edges.get((bm.verts[a[orig]], bm.verts[b[orig]]))
                if e is not None and not e.seam:
                    e.seam = True
                    added += 1
        log("    %-7s piece of %4d faces at (%+.2f, %+.2f, %.2f): %s" % (
            name, len(faces), centre.x, centre.y, centre.z, what))
    work.free()
    if centre_cut:
        added += _centre_cuts(bm, name, sleeve_x)
    return added


def _centre_cuts(bm, name, sleeve_x) -> int:
    """Split wide pieces that still straddle the centre line (x = 0) where a short bridge
    of cloth joins the two halves, e.g. jacket fronts fused at the button: cut the
    shortest path along x = 0 between two places where the piece's edge meets the centre
    line. Narrow pieces (a tie) are left whole. Repeats until nothing is left to cut."""
    added = 0
    for _ in range(6):
        work = bm.copy()
        orig = work.verts.layers.int.new("orig")
        for v, ov in zip(work.verts, bm.verts):
            v[orig] = ov.index
        bmesh.ops.split_edges(work, edges=[e for e in work.edges if e.seam])
        bm.verts.ensure_lookup_table()
        best = None
        for faces in _islands(work):
            verts = {v for f in faces for v in f.verts}
            lo, hi = _bounds([v.co for v in verts])
            centre = sum((v.co for v in verts), Vector()) / len(verts)
            if hi.x - lo.x < 0.15 or abs(centre.x) > sleeve_x:
                continue
            sides = [f.calc_center_median().x for f in faces]
            if min(sides) > -0.03 or max(sides) < 0.03:
                continue
            fset = set(faces)
            path = _centre_bridge(fset, verts, 0.3 * (hi.z - lo.z))
            if path and (best is None or len(path) < len(best[0])):
                best = (path, len(faces))
        if best is not None:
            path, size = best
            for a, b in zip(path, path[1:]):
                e = bm.edges.get((bm.verts[a[orig]], bm.verts[b[orig]]))
                if e is not None and not e.seam:
                    e.seam = True
                    added += 1
            mid = path[len(path) // 2].co
            log("    %-7s piece of %4d faces cut along the centre line at (%+.2f, %+.2f, %.2f),"
                " %d edges" % (name, size, mid.x, mid.y, mid.z, len(path) - 1))
        work.free()
        if best is None:
            break
    return added


def _centre_bridge(fset, verts, max_len):
    """Shortest interior path hugging x = 0 between two separate stretches of the piece's
    edge that lie on the centre line, or None."""
    near = {v for v in verts if v.is_boundary and abs(v.co.x) < 0.012}
    parent = {v: v for v in near}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for v in near:
        for e in v.link_edges:
            w = e.other_vert(v)
            if e.is_boundary and w in near:
                parent[find(v)] = find(w)
    clusters = {}
    for v in near:
        clusters.setdefault(find(v), set()).add(v)
    clusters = list(clusters.values())
    best = None
    for i, src in enumerate(clusters):
        others = set().union(*(c for j, c in enumerate(clusters) if j != i)) if len(clusters) > 1 else set()
        if not others:
            continue
        dist = {v: 0.0 for v in src}
        back = {}
        heap = [(0.0, id(v), v) for v in src]
        heapq.heapify(heap)
        done = set()
        while heap:
            d, _, v = heapq.heappop(heap)
            if v in done or d > max_len:
                continue
            done.add(v)
            if v in others:
                path = [v]
                while path[-1] in back:
                    path.append(back[path[-1]])
                if best is None or d < best[0]:
                    best = (d, path[::-1])
                break
            for e in v.link_edges:
                if e.is_boundary or not all(f in fset for f in e.link_faces):
                    continue
                w = e.other_vert(v)
                if abs(w.co.x) > 0.03:
                    continue
                nd = d + e.calc_length() * (1.0 + 40.0 * abs(w.co.x))
                if nd < dist.get(w, math.inf):
                    dist[w] = nd
                    back[w] = v
                    heapq.heappush(heap, (nd, id(w), w))
    return best[1] if best else None


def _boundary_loops(edges):
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in edges:
        for v in e.verts:
            parent.setdefault(v, v)
        a, b = find(e.verts[0]), find(e.verts[1])
        if a != b:
            parent[a] = b
    loops = {}
    for v in parent:
        loops.setdefault(find(v), []).append(v)
    return sorted(loops.values(), key=len, reverse=True)


def _dijkstra(fset, sources, targets, centre, prefer, xpenalty=0.0):
    """Shortest edge path (as a vertex list) from any source to any target, walking only
    edges of the given faces, cheaper on the `prefer` side of `centre`."""
    dist = {v: 0.0 for v in sources}
    back = {}
    heap = [(0.0, id(v), v) for v in sources]
    heapq.heapify(heap)
    done = set()
    while heap:
        d, _, v = heapq.heappop(heap)
        if v in done:
            continue
        done.add(v)
        if v in targets and v not in sources:
            path = [v]
            while path[-1] in back:
                path.append(back[path[-1]])
            return path[::-1]
        for e in v.link_edges:
            if not any(f in fset for f in e.link_faces):
                continue
            w = e.other_vert(v)
            mid = (v.co + w.co) * 0.5
            side = (mid - centre).normalized().dot(prefer)
            cost = e.calc_length() * (1.0 + 1.5 * (1.0 - side) + xpenalty * abs(mid.x))
            nd = d + cost
            if nd < dist.get(w, math.inf):
                dist[w] = nd
                back[w] = v
                heapq.heappush(heap, (nd, id(w), w))
    return []


def _auto_seams(bm, name) -> int:
    """Fallback for a model without owner seams: a trouser rise and inseams, a jacket
    centre back, each as a shortest path hugging the centre line."""
    bm.verts.ensure_lookup_table()
    faces = set(bm.faces)
    lo, hi = _bounds([v.co for v in bm.verts])
    eps = 0.02 * (hi.z - lo.z)
    centre_line = [v for v in bm.verts if abs(v.co.x) < eps]
    marked = []
    if name == "legs" and not any(e.seam for e in bm.edges):
        front = [v for v in centre_line if v.co.y < 0]
        back = [v for v in centre_line if v.co.y > 0]
        crotch = min(centre_line, key=lambda v: v.co.z)
        fw, bw = max(front, key=lambda v: v.co.z), max(back, key=lambda v: v.co.z)
        c = Vector((0, 0, crotch.co.z))
        marked += _dijkstra(faces, {fw}, {crotch}, c, Vector((0, 0, 0)), 50.0)
        marked += _dijkstra(faces, {crotch}, {bw}, c, Vector((0, 0, 0)), 50.0)
        hem = [v for v in bm.verts if v.is_boundary and v.co.z < lo.z + eps]
        for side in (-1, 1):
            leg = [v for v in hem if v.co.x * side > 0]
            if leg:
                inner = min(leg, key=lambda v: abs(v.co.x))
                marked += _dijkstra(faces, {crotch}, {inner}, c, Vector((0, 0, 0)))
    elif name == "jacket" and not any(e.seam and abs(e.verts[0].co.x) < eps and
                                      e.verts[0].co.y > 0 for e in bm.edges):
        back = [v for v in centre_line if v.co.y > 0]
        if back:
            nape = max(back, key=lambda v: v.co.z)
            hem = min(back, key=lambda v: v.co.z)
            marked += _dijkstra(faces, {nape}, {hem}, Vector(), Vector((0, 0, 0)), 50.0)
    n = 0
    for path in [marked]:
        for a, b in zip(path, path[1:]):
            e = bm.edges.get((a, b))
            if e is not None and not e.seam:
                e.seam = True
                n += 1
    if n:
        log("    %-7s auto seams: %d edges" % (name, n))
    return n


def _shoulder_seams(bm, name) -> int:
    """Cut each shoulder from the top of the armhole seam to the neckline, so the front
    and the back become separate pieces. Without it a piece that folds over the shoulder
    carries two grains (front up and back up are not parallel once flattened), and no
    single turn gets both right: the stripes lean into a V on the back."""
    bm.verts.ensure_lookup_table()
    seam_verts = {v for e in bm.edges if e.seam for v in e.verts}
    parent = {v: v for v in seam_verts}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in bm.edges:
        if e.seam:
            parent[find(e.verts[0])] = find(e.verts[1])
    added = 0
    for side in (-1.0, 1.0):
        mine = [v for v in seam_verts if v.co.x * side > 0.05]
        if not mine:
            continue
        top = max(mine, key=lambda v: v.co.z)
        chain = find(top)
        targets = {v for v in bm.verts
                   if (v.is_boundary or (v in seam_verts and find(v) != chain))
                   and abs(v.co.x) < abs(top.co.x) and v.co.z > top.co.z - 0.03}
        dist = {top: 0.0}
        back = {}
        heap = [(0.0, 0, top)]
        done = set()
        end = None
        while heap:
            d, _, v = heapq.heappop(heap)
            if v in done:
                continue
            done.add(v)
            if v in targets:
                end = v
                break
            for e in v.link_edges:
                w = e.other_vert(v)
                if e.seam or abs(w.co.x) > abs(top.co.x) + 0.01:
                    continue
                up = max(0.0, w.normal.z)
                nd = d + e.calc_length() * (1.0 + 4.0 * (1.0 - up))
                if nd < dist.get(w, math.inf):
                    dist[w] = nd
                    back[w] = v
                    heapq.heappush(heap, (nd, id(w), w))
        if end is None:
            log("    %-7s shoulder %s: no neckline found from (%+.2f, %+.2f, %.2f)" % (
                name, "+x" if side > 0 else "-x", top.co.x, top.co.y, top.co.z))
            continue
        path = [end]
        while path[-1] in back:
            path.append(back[path[-1]])
        n = 0
        for a, b in zip(path, path[1:]):
            e = bm.edges.get((a, b))
            if e is not None and not e.seam:
                e.seam = True
                n += 1
        added += n
        log("    %-7s shoulder %s: %d edges from (%+.2f, %+.2f, %.2f) to (%+.2f, %+.2f, %.2f)" % (
            name, "+x" if side > 0 else "-x", n, top.co.x, top.co.y, top.co.z,
            end.co.x, end.co.y, end.co.z))
    return added


def _orient_islands(obj, arm, sleeve_x, quiet=False) -> None:
    """Per piece: turn it so the grain (UV V) runs along its bone, then scale it to
    metres. Pieces past sleeve_x follow their arm (V up towards the shoulder), the rest the
    vertical (V up). The grain is a direction without a sign, so a piece that folds over
    the shoulder (front and back in one) is averaged on doubled angles, and then turned so
    most of its area has V pointing up. A mirrored piece is flipped back first. When the
    angle-based flattening leaves a piece badly stretched or with a wandering grain, a
    cylindrical projection around the piece's bone axis is tried and kept if it scores
    better. Finally the pieces are laid side by side (no rotation) so the layout reads;
    overlap would not matter to a tiling fabric either way."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv = bm.loops.layers.uv.active
    arms = {}
    for side in ("l", "r"):
        shoulder = _bone_head(arm, "upperarm." + side)
        hand = _bone_head(arm, "hand." + side)
        arms[math.copysign(1.0, shoulder.x)] = (shoulder - hand).normalized()
    rows = []
    for faces in _islands(bm):
        a3 = sum(f.calc_area() for f in faces)
        if a3 <= 1e-12:
            continue
        centre = sum((f.calc_center_median() * f.calc_area() for f in faces), Vector()) / a3
        if abs(centre.x) > sleeve_x:
            axis = arms[math.copysign(1.0, centre.x)]
            label = "arm %s" % ("+x" if centre.x > 0 else "-x")
        else:
            axis = Vector((0, 0, 1))
            label = "vertical"
        luvs = [l[uv] for f in faces for l in f.loops]
        before = [x.uv.copy() for x in luvs]
        mirrored = _flipped_share(faces, uv) > 0.5
        if mirrored:
            for x in luvs:
                x.uv = Vector((-x.uv.x, x.uv.y))
        turned = _align_grain(faces, uv, axis, a3)
        abf = _piece_quality(faces, uv, axis)
        method = "abf"
        if abf[0] > 2.0 or abf[1] > 25.0:
            keep = [x.uv.copy() for x in luvs]
            _cylinder(faces, uv, axis, centre, a3)
            cyl = _piece_quality(faces, uv, axis)
            # a degree of wandering grain costs about as much as 3% of density spread
            if cyl[0] * (1.0 + cyl[1] / 30.0) < abf[0] * (1.0 + abf[1] / 30.0):
                method = "cylinder (abf was %.2fx, %.0f deg)" % abf
                turned = 0.0
            else:
                method = "abf (cylinder scored %.2fx, %.0f deg)" % cyl
                for x, k in zip(luvs, keep):
                    x.uv = k
        stretch, spread = _piece_quality(faces, uv, axis)
        del before
        rows.append((faces, label, a3, centre, turned, stretch, spread, mirrored, method))
    _shelf_pack(rows, uv)
    bm.to_mesh(obj.data)
    bm.free()
    if quiet:
        return
    log("  %-7s %d islands after unwrap (pieces under 0.005 m2 not listed):" % (obj.name, len(rows)))
    small = 0
    for faces, label, a3, centre, angle, stretch, spread, mirrored, method in sorted(
            rows, key=lambda r: -r[2]):
        if a3 < 0.005:
            small += 1
            continue
        log("    %4d faces %6.3f m2 at (%+.2f, %+.2f, %.2f) grain %-8s turned %+7.1f deg |"
            " stretch %.2fx, grain off by %4.1f deg avg | %s%s" % (
                len(faces), a3, centre.x, centre.y, centre.z, label, angle, stretch, spread,
                method, ", was mirrored" if mirrored else ""))
    if small:
        log("    + %d small pieces (buttons, trims)" % small)


def _fan(face):
    loops = list(face.loops)
    for k in range(1, len(loops) - 1):
        yield loops[0], loops[k], loops[k + 1]


def _grads(faces, uv, axis):
    """Per triangle: (UV area, signed det, UV gradient of the height along `axis`)."""
    for f in faces:
        for t in _fan(f):
            (p0, u0), (p1, u1), (p2, u2) = [(l.vert.co, l[uv].uv) for l in t]
            d1, d2 = u1 - u0, u2 - u0
            det = d1.x * d2.y - d1.y * d2.x
            if abs(det) < 1e-14:
                continue
            f1, f2 = (p1 - p0).dot(axis), (p2 - p0).dot(axis)
            grad = Vector(((f1 * d2.y - f2 * d1.y) / det, (d1.x * f2 - d2.x * f1) / det))
            yield abs(det) * 0.5, det, grad, (p1 - p0).cross(p2 - p0).length * 0.5


def _flipped_share(faces, uv) -> float:
    total = flipped = 0.0
    for area, det, _, _ in _grads(faces, uv, Vector((0, 0, 1))):
        total += area
        if det < 0:
            flipped += area
    return flipped / total if total else 0.0


def _align_grain(faces, uv, axis, a3) -> float:
    """Rotate + scale one piece in place; returns the turn in degrees."""
    c2 = s2 = 0.0
    a2 = 0.0
    for area, _, g, _ in _grads(faces, uv, axis):
        n2 = g.length_squared
        if n2 < 1e-16:
            continue
        # doubled angle: a direction and its opposite vote the same way
        c2 += area * (g.x * g.x - g.y * g.y) / n2
        s2 += area * (2.0 * g.x * g.y) / n2
        a2 += area
    if a2 <= 0.0:
        return 0.0
    phi = 0.5 * math.atan2(s2, c2)
    angle = math.pi * 0.5 - phi
    luvs = [l[uv] for f in faces for l in f.loops]
    uc = sum((x.uv for x in luvs), Vector((0.0, 0.0))) / len(luvs)
    rot = Matrix.Rotation(angle, 2)
    for x in luvs:
        x.uv = rot @ (x.uv - uc)
    up = sum(g.y * area for area, _, g, _ in _grads(faces, uv, axis))
    if up < 0.0:  # most of the piece has "up the bone" pointing down V: turn it round
        for x in luvs:
            x.uv = -x.uv
        angle += math.pi
    _to_metres(faces, uv, a3)
    return (math.degrees(angle) + 180.0) % 360.0 - 180.0


def _to_metres(faces, uv, a3) -> None:
    a2 = sum(area for area, _, _, _ in _grads(faces, uv, Vector((0, 0, 1))))
    if a2 <= 0.0:
        return
    k = math.sqrt(a3 / a2)
    for f in faces:
        for l in f.loops:
            l[uv].uv = l[uv].uv * k


def _piece_quality(faces, uv, axis):
    """(texel-density spread 95th/5th percentile, area-weighted mean angle in degrees
    between the local grain and the V axis, ignoring its sign)."""
    density = []
    off = weight = 0.0
    for area, _, g, a3 in _grads(faces, uv, axis):
        if a3 > 1e-12:
            density.append(math.sqrt(area / a3))
        if g.length_squared < 1e-16:
            continue
        a = abs(math.degrees(math.atan2(g.x, g.y)))
        off += min(a, 180.0 - a) * area
        weight += area
    if not density:
        return 99.0, 90.0
    density.sort()
    stretch = density[int(len(density) * 0.95)] / max(density[int(len(density) * 0.05)], 1e-9)
    return stretch, (off / weight if weight else 90.0)


def _cylinder(faces, uv, axis, centre, a3) -> None:
    """Project one piece onto a cylinder around `axis` through its centre: U = arc length
    round the axis, V = height along it (so the grain is exact). The cut falls at the back
    for the vertical axis and underneath for an arm."""
    ref = Vector((0, -1, 0)) if abs(axis.z) > 0.7 else Vector((0, 0, 1))
    e1 = (ref - axis * ref.dot(axis)).normalized()
    e2 = axis.cross(e1)
    verts = {v for f in faces for v in f.verts}
    radius = sum(((v.co - centre) - axis * (v.co - centre).dot(axis)).length for v in verts)
    radius /= max(len(verts), 1)
    for f in faces:
        thetas = []
        for l in f.loops:
            d = l.vert.co - centre
            thetas.append(math.atan2(d.dot(e2), d.dot(e1)))
        if max(thetas) - min(thetas) > math.pi:
            thetas = [t + 2.0 * math.pi if t < 0.0 else t for t in thetas]
        for l, t in zip(f.loops, thetas):
            l[uv].uv = Vector((t * radius, (l.vert.co - centre).dot(axis)))
    if _flipped_share(faces, uv) > 0.5:
        for f in faces:
            for l in f.loops:
                l[uv].uv = Vector((-l[uv].uv.x, l[uv].uv.y))
    del a3


def _shelf_pack(rows, uv, margin=0.02) -> None:
    boxes = []
    for r in rows:
        luvs = [l[uv] for f in r[0] for l in f.loops]
        lo = Vector((min(x.uv.x for x in luvs), min(x.uv.y for x in luvs)))
        hi = Vector((max(x.uv.x for x in luvs), max(x.uv.y for x in luvs)))
        boxes.append((luvs, lo, hi))
    width = math.sqrt(sum((hi.x - lo.x) * (hi.y - lo.y) for _, lo, hi in boxes)) * 1.4
    x = y = row_h = 0.0
    for luvs, lo, hi in sorted(boxes, key=lambda b: -(b[2].y - b[1].y)):
        w, h = hi.x - lo.x, hi.y - lo.y
        if x > 0.0 and x + w > width:
            x, y, row_h = 0.0, y + row_h + margin, 0.0
        shift = Vector((x, y)) - lo
        for item in luvs:
            item.uv = item.uv + shift
        x += w + margin
        row_h = max(row_h, h)


def _smart_project(obj) -> None:
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    _select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def _triangles(obj):
    mesh = obj.data
    uvd = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            i0, i1, i2 = loops[0], loops[k], loops[k + 1]
            p0 = mesh.vertices[mesh.loops[i0].vertex_index].co
            p1 = mesh.vertices[mesh.loops[i1].vertex_index].co
            p2 = mesh.vertices[mesh.loops[i2].vertex_index].co
            e1 = uvd[i1].uv - uvd[i0].uv
            e2 = uvd[i2].uv - uvd[i0].uv
            yield (p1 - p0).cross(p2 - p0).length * 0.5, abs(e1.x * e2.y - e1.y * e2.x) * 0.5


def _stretch(obj, label) -> float:
    """Texel-density spread (95th / 5th percentile), measured like fix_garment_uvs."""
    density = [math.sqrt(a2 / a3) for a3, a2 in _triangles(obj) if a3 > 1e-9 and a2 > 1e-12]
    if not density:
        log("  %-7s %-9s no usable triangles" % (obj.name, label))
        return 99.0
    density.sort()
    low = density[int(len(density) * 0.05)]
    high = density[int(len(density) * 0.95)]
    mid = density[len(density) // 2]
    a3 = sum(t[0] for t in _triangles(obj))
    a2 = sum(t[1] for t in _triangles(obj))
    stretch = high / max(low, 1e-9)
    # the same spread weighted by surface area, so a hundred tiny cuff-button triangles
    # count for what they cover rather than for their number
    pairs = sorted((math.sqrt(t2 / t3), t3) for t3, t2 in _triangles(obj) if t3 > 1e-9 and t2 > 1e-12)
    total = sum(w for _, w in pairs)
    acc, lo_w, hi_w = 0.0, pairs[0][0], pairs[-1][0]
    for d, w in pairs:
        acc += w
        if acc <= 0.05 * total:
            lo_w = d
        if acc <= 0.95 * total:
            hi_w = d
    by_area = hi_w / max(lo_w, 1e-9)
    log("  %-7s %-9s %5d tris | density %.2f..%.2f (median %.2f) UV/m | UV/3D area %.3f |"
        " stretch %.2fx (by area %.2fx) %s" % (
            obj.name, label, len(density), low, high, mid, a2 / max(a3, 1e-9), stretch, by_area,
            "" if stretch <= STRETCH_LIMIT else "SMEARS"))
    return stretch


# ---------------------------------------------------------------------------------------
# step 3: decimate (runs after the unwrap)


def step_decimate(ns) -> None:
    log("\n== decimate")
    if not ns.decimate:
        log("  off (--decimate to reduce): the full mesh is exported")
        for role, obj in _role_objects().items():
            log("  %-7s %7d tris" % (role, _tris(obj)))
        return
    log("  %-7s %7s %7s %7s  %s" % ("mesh", "before", "target", "after", "method"))
    for role, obj in _role_objects().items():
        target = ns.budgets.get(role, 0)
        before = _tris(obj)
        method = "kept"
        if target and before > target * 1.15:
            method = _reduce(obj, target, not ns.no_unsubdiv)
        log("  %-7s %7d %7d %7d  %s" % (role, before, target, _tris(obj), method))
    arm = _armature()
    for role, obj in _role_objects().items():
        if role in CLOTH_ROLES:
            obj["stretch_low"] = _stretch(obj, "decimated")
            _reflatten(obj, arm, ns.sleeve_x)


def _reflatten(obj, arm, sleeve_x) -> None:
    """Collapse drags UVs along with the vertices it merges, which smears the corners of
    the pieces. So the decimated mesh is flattened again, cut along the SAME pieces
    (seams taken from the full-resolution UV islands), and kept if it measures better."""
    keep = [d.uv.copy() for d in obj.data.uv_layers.active.data]
    before = _quiet_stretch(obj)
    _select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
    bpy.ops.uv.unwrap(method="ANGLE_BASED", fill_holes=True, correct_aspect=True, margin=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    _orient_islands(obj, arm, sleeve_x, quiet=True)
    after = _quiet_stretch(obj)
    if after < before:
        _stretch(obj, "re-flat")
    else:
        for d, uv in zip(obj.data.uv_layers.active.data, keep):
            d.uv = uv
        log("  %-7s re-flattening measured %.2fx, kept the decimated UVs" % (obj.name, after))


def _reduce(obj, target, try_unsubdiv) -> str:
    steps = []
    tris = _tris(obj)
    quads = sum(1 for p in obj.data.polygons if len(p.vertices) == 4)
    iterations = 0
    while tris / 4 ** (iterations + 1) >= target * 0.7:
        iterations += 1
    if try_unsubdiv and iterations and quads <= 0.9 * len(obj.data.polygons):
        steps.append("no unsubdiv (%d%% quads)" % (100 * quads // max(len(obj.data.polygons), 1)))
    if try_unsubdiv and iterations and quads > 0.9 * len(obj.data.polygons):
        backup = obj.data.copy()
        stretch_before = _quiet_stretch(obj) if obj.data.uv_layers else 0.0
        _apply_decimate(obj, "UNSUBDIV", iterations=iterations)
        after = _tris(obj)
        expect = tris / 4 ** iterations
        stretch_after = _quiet_stretch(obj) if obj.data.uv_layers else 0.0
        ok = after <= expect * 1.6 and (not obj.data.uv_layers or
                                        stretch_after <= max(stretch_before * 1.25, 1.3))
        if ok:
            steps.append("unsubdiv x%d (%d)" % (iterations, after))
            bpy.data.meshes.remove(backup)
        else:
            steps.append("unsubdiv x%d rejected (%d tris, expected ~%d, stretch %.2f->%.2f)"
                         % (iterations, after, expect, stretch_before, stretch_after))
            old = obj.data
            obj.data = backup
            backup.name = old.name
            bpy.data.meshes.remove(old)
            obj.data.name = obj.name
    if _tris(obj) > target * 1.15:
        parts = _collapse_by_part(obj, target)
        steps.append("collapse" + (" over %d parts by area" % parts if parts > 1 else ""))
    return ", ".join(steps)


def _collapse_by_part(obj, target, floor=12) -> int:
    """Collapse each loose part to its share of the budget by surface area (at least
    `floor` triangles), so a cuff button does not keep as many triangles as a sleeve.
    Returns the number of parts."""
    _select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects]
    if obj not in parts:
        parts.append(obj)
    areas = {o: sum(p.area for p in o.data.polygons) for o in parts}
    total = sum(areas.values()) or 1.0
    floors = sum(min(floor, _tris(o)) for o in parts)
    spare = max(target - floors, 0)
    for o in parts:
        want = min(floor, _tris(o)) + spare * areas[o] / total
        if _tris(o) > want * 1.05:
            _apply_decimate(o, "COLLAPSE", ratio=max(want / _tris(o), 0.001))
    _select_only(parts, obj)
    if len(parts) > 1:
        bpy.ops.object.join()
    return len(parts)


def _apply_decimate(obj, mode, iterations=1, ratio=1.0) -> None:
    _select_only([obj])
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.decimate_type = mode
    if mode == "UNSUBDIV":
        mod.iterations = iterations
    else:
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _quiet_stretch(obj) -> float:
    density = [math.sqrt(a2 / a3) for a3, a2 in _triangles(obj) if a3 > 1e-9 and a2 > 1e-12]
    if not density:
        return 99.0
    density.sort()
    return density[int(len(density) * 0.95)] / max(density[int(len(density) * 0.05)], 1e-9)


# ---------------------------------------------------------------------------------------
# step 5: skin


JOINT_BLEND = 0.04  # metres over which the legs hand left to right across x = 0
# Per joint: metres over which it hands one bone to the next (centred on the joint). The
# knee is wider: in a deep walk bend a 4 cm hand-over folds the back of the knee inward.
JOINT_BLENDS = {"chest": 0.04, "elbow": 0.04, "hip": 0.04, "knee": 0.12}
# Each mesh's bones in the rigid assignment; anything else must be exactly zero.
RIGID_BONES = {
    "jacket": {"chest", "spine", "upperarm.l", "lowerarm.l", "upperarm.r", "lowerarm.r"},
    "tie": {"chest", "spine"},
    "buttons": {"chest", "spine"},
    "square": {"chest", "spine"},
    "shirt": {"chest", "lowerarm.l", "lowerarm.r"},
    "arms": {"lowerarm.l", "lowerarm.r"},
    "legs": {"hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"},
    "shoes": {"foot.l", "foot.r"},
    "head": {"head"},
    "Hair": {"head"},
}


def step_skin_rigid(ns) -> None:
    """The most basic skin: each part on its own bones by height or along the limb, with a
    JOINT_BLEND-wide linear hand-over at each joint and nothing else.
      jacket body pieces, tie, buttons, square: chest above the chest bone, spine below
      jacket sleeve pieces: upperarm to the elbow, lowerarm past it, own side only
      shirt: chest; its cuffs: lowerarm of their side
      arms (hands): hand; shoes: foot; head, Hair: head
      trousers: hips above the upperleg head, upperleg to the knee, lowerleg below
    Joint heights come from the armature's rest pose. Every bone outside a mesh's list is
    asserted to be zero."""
    log("\n== skin (rigid by part)")
    arm = _armature()
    arm.data.pose_position = "REST"
    bones = [b.name for b in arm.data.bones]

    def head(name):
        return arm.matrix_world @ arm.data.bones[name].head_local

    chest_z = head("chest").z
    elbow_x = abs(head("lowerarm.l").x)
    hip_z = head("upperleg.l").z
    knee_z = head("lowerleg.l").z
    blends = dict(JOINT_BLENDS)
    for name in blends:
        value = getattr(ns, name + "_blend", None)
        if value is not None:
            blends[name] = value
    log("  joints from the rig: chest %.3f m, elbow |x| %.3f, upperleg %.3f m, knee %.3f m;"
        " blends %s" % (chest_z, elbow_x, hip_z, knee_z, ", ".join(
            "%s %.0f cm" % (k, v * 100) for k, v in blends.items())))

    def hand_over(value, joint, below, above, kind):
        width = blends[kind]
        t = min(max((value - (joint - width / 2)) / width, 0.0), 1.0)
        if t <= 0.0:
            return {below: 1.0}
        if t >= 1.0:
            return {above: 1.0}
        return {below: 1.0 - t, above: t}

    def side(x):
        return ".l" if x * math.copysign(1.0, head("upperarm.l").x) > 0 else ".r"

    for role, obj in _role_objects().items():
        labels = ["all"] * len(obj.data.vertices)
        note = ""
        if role in ("jacket", "shirt", "legs"):
            mode = "legs" if role == "legs" else "sleeves"
            # the trousers stay one piece (their seams are UV seams only); the jacket is
            # split at the armholes so sleeves and body carry their own weights
            want = set()
            if role == "jacket":
                want = ({"body"} if ns.body_caps else set()) | (
                    {"sleeve"} if ns.sleeve_caps else set())
            labels, split, caps = _split_regions(obj, mode, ns.sleeve_x, want, role != "legs")
            note = " | split along %d seam edges (%s)%s" % (
                split, " / ".join(sorted(set(labels))),
                (", %d armhole caps (%s)" % (len(caps), " + ".join(sorted(want)))) if caps else "")
        obj.vertex_groups.clear()
        for name in bones:
            obj.vertex_groups.new(name=name)
        tops, inner = {}, {}
        for i, v in enumerate(obj.data.vertices):
            if labels[i].startswith("sleeve"):
                p = obj.matrix_world @ v.co
                tops[labels[i]] = max(tops.get(labels[i], -1e9), p.z)
                inner[labels[i]] = min(inner.get(labels[i], 1e9), abs(p.x))
        banded = 0
        ring_tree, ring_count, stitched = None, 0, 0
        if ns.stitch_armhole > 0.0 and role == "jacket":
            ring_tree, ring_count = _armhole_ring(obj, labels)
        for i, v in enumerate(obj.data.vertices):
            co = obj.matrix_world @ v.co
            lab = labels[i]
            # a labelled piece (sleeve, trouser leg) takes its piece's side, anything else
            # the side its vertex is on
            if lab[-2:] in ("+x", "-x"):
                sd = side(1.0 if lab.endswith("+x") else -1.0)
            else:
                sd = side(co.x)
            if role in ("jacket", "tie", "buttons", "square"):
                if lab.startswith("sleeve"):
                    w = hand_over(abs(co.x), elbow_x, "upperarm" + sd, "lowerarm" + sd, "elbow")
                    if ring_tree is not None:
                        # stitched to the body along the armhole: a ring vertex takes the
                        # body's bones at its height, handing over to the arm across
                        # --stitch-armhole of distance from the ring
                        _, _, d = ring_tree.find(co)
                        t = min(max(d / ns.stitch_armhole, 0.0), 1.0)
                        if t < 1.0:
                            body_w = hand_over(co.z, chest_z, "spine", "chest", "chest")
                            mixed = {k: x * t for k, x in w.items()}
                            for k, x in body_w.items():
                                mixed[k] = mixed.get(k, 0.0) + x * (1.0 - t)
                            w = {k: x for k, x in mixed.items() if x > 0.0}
                            stitched += 1
                    band = ns.shoulder_band
                    depth = tops.get(lab, co.z) - co.z
                    along = abs(co.x) - inner.get(lab, abs(co.x))
                    if band > 0.0 and depth < 2.0 * band and along < 2.0 * band:
                        # the shoulder round of the sleeve stays on the chest: the top
                        # `band` below the sleeve's highest point, within `band` of the
                        # armhole, fading to the arm over one more band down AND along
                        # the arm (measured from the top alone, the band would run the
                        # sleeve's whole upper edge out to the cuff)
                        keep = (1.0 - min(max((depth - band) / band, 0.0), 1.0)) * (
                            1.0 - min(max((along - band) / band, 0.0), 1.0))
                        if keep > 0.0:
                            mixed = {k: x * (1.0 - keep) for k, x in w.items()}
                            mixed["chest"] = mixed.get("chest", 0.0) + keep
                            w = {k: x for k, x in mixed.items() if x > 0.0}
                            banded += 1
                else:
                    w = hand_over(co.z, chest_z, "spine", "chest", "chest")
            elif role == "shirt":
                w = {"lowerarm" + sd: 1.0} if lab.startswith("sleeve") else {"chest": 1.0}
            elif role == "arms":
                # the ball rides the forearm with the cuff: on `hand` it pivots at the
                # wrist and the walk's wrist turn swings it off the sleeve end
                w = {"lowerarm" + side(co.x): 1.0}
            elif role == "shoes":
                w = {"foot" + side(co.x): 1.0}
            elif role == "legs":
                # one mesh, no split: each side's rule, blended across x = 0 over
                # JOINT_BLEND so the rise and inseams stay closed when the legs part
                def leg(sfx):
                    if co.z >= knee_z + blends["knee"] / 2:
                        return hand_over(co.z, hip_z, "upperleg" + sfx, "hips", "hip")
                    return hand_over(co.z, knee_z, "lowerleg" + sfx, "upperleg" + sfx, "knee")

                lx = co.x * math.copysign(1.0, head("upperarm.l").x)
                t = min(max((lx + JOINT_BLEND / 2) / JOINT_BLEND, 0.0), 1.0)
                w = {}
                for sfx, share in ((".l", t), (".r", 1.0 - t)):
                    if share > 0.0:
                        for k, x in leg(sfx).items():
                            w[k] = w.get(k, 0.0) + x * share
            else:
                w = {HEAD_BONE: 1.0}
            for name, value in w.items():
                obj.vertex_groups[name].add([i], value, "REPLACE")
        _parent_to(obj, arm)
        used = set()
        for v in obj.data.vertices:
            for g in v.groups:
                if g.weight > 0.0:
                    used.add(obj.vertex_groups[g.group].name)
        stray = used - RIGID_BONES[role]
        assert not stray, "%s carries weight on %s" % (role, sorted(stray))
        if ring_tree is not None:
            note += ", armhole ring %d sleeve verts, %d verts stitched within %.0f cm" % (
                ring_count, stitched, ns.stitch_armhole * 100)
        if banded:
            note += ", %d sleeve verts in the %.0f+%.0f cm shoulder band" % (
                banded, ns.shoulder_band * 100, ns.shoulder_band * 100)
        log("  %-7s %s%s" % (role, _bones_used(obj), note))
        log("  %-7s   allowed %s; every other bone is zero (checked)" % (
            "", ", ".join(sorted(RIGID_BONES[role]))))
    arm.data.pose_position = "POSE"


def _armhole_ring(obj, labels):
    """The sleeve side of the armhole split: sleeve vertices sitting exactly on a body
    vertex. Returns (a KD tree of their positions, how many)."""
    from mathutils.kdtree import KDTree

    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    body = [i for i, lab in enumerate(labels) if lab == "body"]
    btree = KDTree(len(body))
    for n, i in enumerate(body):
        btree.insert(pts[i], n)
    btree.balance()
    ring = [i for i, lab in enumerate(labels)
            if lab.startswith("sleeve") and btree.find(pts[i])[2] < 1e-5]
    tree = KDTree(max(len(ring), 1))
    for n, i in enumerate(ring):
        tree.insert(pts[i], n)
    tree.balance()
    return tree, len(ring)


def step_skin(ns) -> None:
    """Copy the owner's weights: k-nearest inverse-distance average of the matching
    CHARTGEN1 garment's vertices, left/right kept apart, weak weights dropped, limit 4."""
    log("\n== skin")
    arm = _armature()
    arm.data.pose_position = "REST"
    rig = _rig_objects()
    bones = [b.name for b in arm.data.bones]
    side_of = {b.name: math.copysign(1.0, (arm.matrix_world @ b.head_local).x)
               for b in arm.data.bones if b.name[-2:] in (".l", ".r")}
    log("  owner's weights (CHARTGEN1), share of the weight per bone in 5 cm bands"
        " (z = the game's y); bones under 2% not listed:")
    for name in ("jacket", "legs", "shirt", "arms", "left leg", "right leg"):
        if name in rig:
            pts, ws = _vertex_weights(rig[name])
            _print_bands("%s by height" % name, _bands(pts, ws, lambda p: p.z, 0.05))
    pts, ws = _vertex_weights(rig["jacket"])
    _print_bands("jacket by |x|", _bands(pts, ws, lambda p: abs(p.x), 0.05))
    armish = lambda w: sum(v for k, v in w.items() if k in ARM_BONES) >= 0.5
    samplers = {}
    labels_of = {}
    for role, obj in _role_objects().items():
        rule = WEIGHT_RULES[role]
        obj.vertex_groups.clear()
        for name in bones:
            obj.vertex_groups.new(name=name)
        if "bind" in rule:
            obj.vertex_groups[rule["bind"]].add(range(len(obj.data.vertices)), 1.0, "REPLACE")
            _parent_to(obj, arm)
            log("  %-7s hard bind to %s | %s" % (role, rule["bind"], _bones_used(obj)))
            continue
        vlabel = ["all"] * len(obj.data.vertices)
        caps = []
        note = ""
        if "regions" in rule:
            want = set()
            if rule.get("cap"):
                want = ({"body"} if ns.body_caps else set()) | (
                    {"sleeve"} if ns.sleeve_caps else set())
            split_it = rule["regions"] == "legs" or bool(want)
            vlabel, split, caps = _split_regions(obj, rule["regions"], ns.sleeve_x, want,
                                                 split_it)
            note = " | split along %d seam edges (%s)%s" % (
                split, " / ".join(sorted(set(vlabel))),
                (", %d armhole caps (%s)" % (len(caps), " + ".join(sorted(want))))
                if caps else "")
            obj.vertex_groups.clear()
            for name in bones:
                obj.vertex_groups.new(name=name)
        if "own" in rule:
            own = bpy.data.objects[rule["own"]]
            keep = [lab == "body" for lab in labels_of.get(rule["own"], [])] or None
            main = _Knn.from_objects([own], keep)
            body = sleeve = main
        else:
            body = _knn(samplers, [rig[n] for n in rule["src"]], "all", None)
            sleeve = body
            if "sleeve_src" in rule:
                sleeve = _knn(samplers, [rig[n] for n in rule["sleeve_src"]], "all", None)
        stats = {"side": 0, "far": 0}
        bridged = []
        weights = []
        top_src, column_top, topped = None, None, 0
        if rule.get("top_body"):
            srcs = [rig[n] for n in rule["src"]]
            top_src = _knn(samplers, srcs, "body", lambda w: not armish(w))
            column_top = _column_tops(srcs, 0.02)
        for i, v in enumerate(obj.data.vertices):
            co = obj.matrix_world @ v.co
            src = sleeve if vlabel[i].startswith("sleeve") else body
            if top_src is not None and abs(co.x) < ns.sleeve_x and co.z > column_top(abs(co.x)):
                weights.append(_clip(top_src.idw(co), None, side_of, co, arm, stats))
                topped += 1
                continue
            raw, far = src.sample(co)
            if raw is None:  # no owner vertex near: bridge his inner and outer ones
                raw, value, axis_name = src.bridge(co, ns.sleeve_x)
                bridged.append((axis_name, value))
            stats["far"] += far
            weights.append(_clip(raw, None, side_of, co, arm, stats))
        if ns.weight_smooth:
            weights = _smooth(obj, weights, 0.5, ns.weight_smooth)
        for centre, ring in caps:  # the cap's centre carries the ring round it
            avg = {}
            for j in ring:
                for k, w in weights[j].items():
                    avg[k] = avg.get(k, 0.0) + w / len(ring)
            weights[centre] = avg
        lapels = 0
        if role == "jacket":
            lapels = _clear_lapel_arms(obj, weights, rig["jacket"])
        trims = _stick_trims(obj, weights, vlabel)
        capped = 0
        if ns.cap_blend > 0.0 and rule.get("regions") == "sleeves" and role == "jacket":
            capped = _blend_caps(obj, weights, vlabel, ns.cap_blend)
        hem = _rigid_hem(obj, weights, "lowerleg", side_of) if (ns.rigid_hem and role == "legs") else 0
        weights = [_clip(w, None, side_of, obj.matrix_world @ v.co, arm, None)
                   for w, v in zip(weights, obj.data.vertices)]
        for i, w in enumerate(weights):
            for name, value in _top4(w).items():
                obj.vertex_groups[name].add([i], value, "REPLACE")
        _parent_to(obj, arm)
        labels_of[role] = vlabel
        extra = []
        if trims:
            extra.append("%d trim verts copy the cloth under them" % trims)
        if topped:
            extra.append("%d verts above his garment's top sampled his body verts only" % topped)
        if lapels:
            extra.append("%d collar/lapel verts had their arm weight cleared" % lapels)
        if capped:
            extra.append("%d sleeve-cap verts blended into the body" % capped)
        if hem:
            extra.append("%d hem verts rigid to lowerleg" % hem)
        log("  %-7s k=%d nearest of rig %s%s%s" % (
            role, KNN, " + ".join(rule.get("src", (rule.get("own", ""),))),
            (" (sleeve pieces: rig %s)" % "+".join(rule["sleeve_src"]))
            if "sleeve_src" in rule else " (by position only)", note))
        log("  %-7s %d verts took the other side's bones (dropped), %d had no source vertex"
            " within %.2f m%s" % ("", stats["side"], stats["far"], KNN_RADIUS,
                                  (", " + ", ".join(extra)) if extra else ""))
        for axis_name in sorted({a for a, _ in bridged}):
            vals = [v for a, v in bridged if a == axis_name]
            log("  %-7s   bridged %d verts along %s, from %.3f to %.3f (linear between the"
                " owner's nearest inner and outer vertex)" % ("", len(vals), axis_name,
                                                              min(vals), max(vals)))
        for label in sorted(set(vlabel)):
            idx = [i for i, lab in enumerate(vlabel) if lab == label]
            used = {}
            for i in idx:
                for name in _top4(weights[i]):
                    used[name] = used.get(name, 0) + 1
            log("  %-7s   %-9s %4d verts | %s" % (
                "", label, len(idx),
                ", ".join("%s %d" % (k, used[k]) for k in sorted(used, key=lambda k: -used[k]))))
        if role == "legs":
            ours = ([obj.matrix_world @ v.co for v in obj.data.vertices], weights)
            _print_bands("legs by height: owner | ours",
                         _bands(*_vertex_weights(rig["legs"]), lambda p: p.z, 0.05),
                         _bands(*ours, lambda p: p.z, 0.05))
        if role == "jacket":
            _twist_table(obj, weights, vlabel, rig["jacket"], armish)
            ours = ([obj.matrix_world @ v.co for v in obj.data.vertices], weights)
            _print_bands("jacket by |x|: owner | ours",
                         _bands(*_vertex_weights(rig["jacket"]), lambda p: abs(p.x), 0.05),
                         _bands(*ours, lambda p: abs(p.x), 0.05))
    arm.data.pose_position = "POSE"


def _blend_caps(obj, weights, labels, band) -> int:
    """Optional (--cap-blend): the sleeve's first `band` metres from the armhole blend
    from the body's own weights at the seam to the arm, the way the owner's sleeve caps
    mix upperarm with chest/spine. The seam row then stays on the body's armhole (no hole
    opens over the shoulder when the arm drops) and the body itself still carries no arm
    weight. A tall sleeve cap swinging on the arm alone leaves a gap there."""
    from mathutils.kdtree import KDTree

    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    body = [i for i, lab in enumerate(labels) if lab == "body"]
    tree = KDTree(len(body))
    for n, i in enumerate(body):
        tree.insert(pts[i], n)
    tree.balance()
    seam = []  # sleeve verts sitting on a body vert: the two sides of the armhole split
    for i, lab in enumerate(labels):
        if lab.startswith("sleeve"):
            _, n, d = tree.find(pts[i])
            if d < 1e-5:
                seam.append((i, body[n]))
    if not seam:
        return 0
    stree = KDTree(len(seam))
    for n, (i, _) in enumerate(seam):
        stree.insert(pts[i], n)
    stree.balance()
    count = 0
    for i, lab in enumerate(labels):
        if not lab.startswith("sleeve"):
            continue
        _, n, d = stree.find(pts[i])
        if d >= band:
            continue
        t = d / band
        t = t * t * (3.0 - 2.0 * t)
        base = weights[seam[n][1]]
        mixed = {k: w * t for k, w in weights[i].items()}
        for k, w in base.items():
            mixed[k] = mixed.get(k, 0.0) + w * (1.0 - t)
        weights[i] = mixed
        count += 1
    return count


def _split_regions(obj, mode, sleeve_x, cap, split_it=True):
    """Label every piece (UV island) of a garment and split the mesh along the seams
    between pieces of different labels, keeping the shading: the glb splits those
    vertices anyway (they are UV seams), so no geometry changes, but now each side of
    the seam can carry its own weights. With `cap`, each body armhole left open by the
    split is closed with a fan to its centre, set CAP_INSET inside the body, so a dropped
    sleeve uncovers a closed shoulder (a doll's) instead of a hole into the jacket.
    Returns (label per vertex, edges split, [(cap centre, ring verts)])."""
    me = obj.data
    stored = {}
    corner = me.corner_normals
    for poly in me.polygons:
        stored[poly.index] = [corner[li].vector.copy() for li in poly.loop_indices]
    first_new = len(me.polygons)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    face_label = {}
    for faces in _uv_islands(bm, uvl):
        area = sum(f.calc_area() for f in faces) or 1.0
        c = sum((f.calc_center_median() * f.calc_area() for f in faces), Vector()) / area
        tag = "+x" if c.x > 0 else "-x"
        if mode == "sleeves":
            label = ("sleeve " + tag) if abs(c.x) > sleeve_x else "body"
        else:
            label = "leg " + tag
        for f in faces:
            face_label[f.index] = label
    cut = [e for e in bm.edges if len({face_label[f.index] for f in e.link_faces}) > 1]
    cut_keys = {_key((e.verts[0].co + e.verts[1].co) * 0.5) for e in cut}
    if not split_it:
        cut = []
    bmesh.ops.split_edges(bm, edges=cut)
    caps = []
    if cap:
        caps = _cap_armholes(bm, uvl, face_label, cut_keys, cap)
    bm.verts.index_update()
    bm.faces.index_update()
    caps = [(c.index, [v.index for v in ring]) for c, ring in caps]
    bm.to_mesh(me)
    bm.free()
    normals = [None] * len(me.loops)
    for poly in me.polygons:
        for k, li in enumerate(poly.loop_indices):
            normals[li] = stored[poly.index][k] if poly.index < first_new else poly.normal.copy()
    me.normals_split_custom_set(normals)
    labels = ["body"] * len(me.vertices)
    for poly in me.polygons:
        for v in poly.vertices:
            labels[v] = face_label.get(poly.index, "body")
    return labels, len(cut), caps


def _cap_armholes(bm, uvl, face_label, cut_keys, which):
    """Fan-fill every closed loop of boundary edges the split left, on both sides: the
    body's armhole (a doll's shoulder, set inside the body) and the sleeve's top (a doll's
    arm socket, set inside the sleeve), so neither shows a hole into the garment when the
    arm drops and the two part."""
    edges = [e for e in bm.edges if e.is_boundary and e.link_faces
             and _key((e.verts[0].co + e.verts[1].co) * 0.5) in cut_keys]
    label_of = {e: face_label.get(e.link_faces[0].index, "body") for e in edges}
    loops = _boundary_loops(edges)
    out = []
    for verts in loops:
        vs = set(verts)
        label = next(label_of[e] for e in edges if e.verts[0] in vs)
        if label.split(" ")[0] not in which:
            continue
        ring_edges = [e for e in edges if e.verts[0] in vs]
        if any(sum(1 for e in ring_edges if v in e.verts) != 2 for v in verts):
            log("    open armhole loop of %d verts left uncapped" % len(verts))
            continue
        ordered = [verts[0]]
        prev = None
        for _ in range(len(verts)):
            here = ordered[-1]
            nxt = next(e.other_vert(here) for e in ring_edges
                       if here in e.verts and e.other_vert(here) is not prev)
            if nxt is ordered[0]:
                break
            prev = here
            ordered.append(nxt)
        c = sum((v.co for v in ordered), Vector()) / len(ordered)
        # the body's cap faces out (away from x = 0) and sits inside the body; the sleeve's
        # faces in (towards the body) and sits inside the sleeve
        outward = math.copysign(1.0, c.x) * (1.0 if label == "body" else -1.0)
        c = c + Vector((-outward * CAP_INSET, 0.0, 0.0))
        centre = bm.verts.new(c)
        for a, b in zip(ordered, ordered[1:] + ordered[:1]):
            f = bm.faces.new((a, b, centre))
            f.normal_update()
            if f.normal.x * outward < 0:
                f.normal_flip()
            f.smooth = False
            for loop in f.loops:
                loop[uvl].uv = Vector((loop.vert.co.y, loop.vert.co.z))
        bm.faces.index_update()
        for f in centre.link_faces:
            face_label[f.index] = label
        out.append((centre, ordered))
    return out


def _key(point) -> tuple:
    """A position rounded enough to match the two sides of a split edge."""
    return round(point.x, 5), round(point.y, 5), round(point.z, 5)


def _vertex_weights(obj):
    """(world positions, weight dicts by bone name) of a skinned mesh's vertices."""
    names = {g.index: g.name for g in obj.vertex_groups}
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    ws = [{names[g.group]: g.weight for g in v.groups if g.weight > 0.001}
          for v in obj.data.vertices]
    return pts, ws


def _bands(pts, ws, axis, width):
    """{band start: (vertex count, {bone: share of the weight})} along `axis`."""
    rows = {}
    for p, w in zip(pts, ws):
        b = math.floor(axis(p) / width + 1e-9) * width
        n, acc = rows.get(b, (0, {}))
        for k, x in w.items():
            acc[k] = acc.get(k, 0.0) + x
        rows[b] = (n + 1, acc)
    out = {}
    for b, (n, acc) in rows.items():
        total = sum(acc.values()) or 1.0
        out[round(b, 3)] = (n, {k: x / total for k, x in acc.items()})
    return out


def _fmt_share(share):
    return "  ".join("%s %d" % (k, round(v * 100)) for k, v in
                     sorted(share.items(), key=lambda kv: -kv[1]) if v >= 0.02)


def _print_bands(title, rows, other=None):
    log("    %s:" % title)
    keys = sorted(set(rows) | set(other or {}))
    for b in keys:
        n, share = rows.get(b, (0, {}))
        line = "      %.2f-%.2f %4d | %-44s" % (b, b + 0.05, n, _fmt_share(share))
        if other is not None:
            m, theirs = other.get(b, (0, {}))
            line += " || %4d | %s" % (m, _fmt_share(theirs))
        log(line.rstrip())


def _twist_table(obj, weights, labels, rig_jacket, armish):
    """Mean weight per bone at the shoulder, middle and cuff of each sleeve, owner's
    (his arm-weighted jacket verts on that side) against ours (the sleeve piece)."""
    rpts, rws = _vertex_weights(rig_jacket)
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    log("    sleeve bands along |x| (first 20% / middle 20% / last 20% of each sleeve):"
        " owner || ours")
    for tag, side in (("+x", 1.0), ("-x", -1.0)):
        mine = [(abs(p.x), w) for p, w, lab in zip(pts, weights, labels)
                if lab == "sleeve " + tag]
        theirs = [(abs(p.x), w) for p, w in zip(rpts, rws) if p.x * side > 0 and armish(w)]
        for name, lo, hi in (("shoulder", 0.0, 0.2), ("middle", 0.4, 0.6), ("cuff", 0.8, 1.0)):
            cells = []
            for rows in (theirs, mine):
                if not rows:
                    cells.append("-")
                    continue
                a = min(r[0] for r in rows)
                z = max(r[0] for r in rows)
                sel = [w for x, w in rows if a + lo * (z - a) <= x <= a + hi * (z - a)]
                acc = {}
                for w in sel:
                    for k, v in w.items():
                        acc[k] = acc.get(k, 0.0) + v / max(len(sel), 1)
                cells.append("%3d verts %s" % (len(sel), _fmt_share(acc)))
            log("      sleeve %s %-8s %-48s || %s" % (tag, name, cells[0], cells[1]))


class _Knn:
    """Inverse-distance average of the k nearest source vertices' weights."""

    def __init__(self, pts, ws):
        from mathutils.kdtree import KDTree

        self.pts, self.ws = pts, ws
        self.tree = KDTree(max(len(pts), 1))
        for i, p in enumerate(pts):
            self.tree.insert(p, i)
        self.tree.balance()

    @classmethod
    def from_objects(cls, objs, keep=None, keep_weights=None):
        pts, ws = [], []
        for o in objs:
            p, w = _vertex_weights(o)
            pts += p
            ws += w
        if keep is not None:
            pts = [p for p, k in zip(pts, keep) if k]
            ws = [w for w, k in zip(ws, keep) if k]
        if keep_weights is not None:
            sel = [i for i, w in enumerate(ws) if keep_weights(w)]
            pts, ws = [pts[i] for i in sel], [ws[i] for i in sel]
        return cls(pts, ws)

    def sample(self, co):
        """(weights, 1) from the k nearest within KNN_RADIUS, or (None, 1) when there is
        none: the caller then bridges the gap."""
        near = [(p, i, d) for p, i, d in self.tree.find_n(co, KNN) if d <= KNN_RADIUS]
        if not near:
            return None, 1
        far = 0
        out = {}
        total = 0.0
        for _, i, d in near:
            k = 1.0 / (d + 1e-3)
            total += k
            for name, w in self.ws[i].items():
                out[name] = out.get(name, 0.0) + w * k
        return {n: w / total for n, w in out.items()}, far


    def idw(self, co):
        """The k nearest at any distance, inverse-distance weighted."""
        out = {}
        total = 0.0
        for _, i, d in self.tree.find_n(co, KNN):
            k = 1.0 / (d + 1e-3)
            total += k
            for n, w in self.ws[i].items():
                out[n] = out.get(n, 0.0) + w * k
        return {n: w / total for n, w in out.items()}

    def bridge(self, co, sleeve_x):
        """Weights for a vertex in a band where the source has none: the nearest source
        vertex on the inner and on the outer side along the limb (|x| past `sleeve_x`,
        height elsewhere), interpolated linearly, as a long quad between them skins.
        Returns (weights, the vertex's position along the axis, the axis name)."""
        if abs(co.x) > sleeve_x:
            name = "|x|"

            def axis(p):
                return abs(p.x)

            same = (lambda p: p.x * co.x > 0)
        else:
            name = "height"

            def axis(p):
                return p.z

            same = (lambda p: True)
        here = axis(co)
        inner = outer = None
        for p, i, d in self.tree.find_n(co, 600):
            if not same(p):
                continue
            a = axis(p)
            if a <= here and (inner is None or d < inner[1]):
                inner = (i, d, a)
            if a > here and (outer is None or d < outer[1]):
                outer = (i, d, a)
        if inner is None or outer is None:
            # past the end of the owner's mesh (our shoulder top sits above his jacket):
            # nothing to bridge to, so the k nearest at any distance, inverse-distance
            # weighted -- a single nearest vertex would make patches between neighbours
            out = {}
            total = 0.0
            for _, i, d in self.tree.find_n(co, KNN):
                k = 1.0 / (d + 1e-3)
                total += k
                for n, w in self.ws[i].items():
                    out[n] = out.get(n, 0.0) + w * k
            return {n: w / total for n, w in out.items()}, here, name + " (past his edge)"
        t = (here - inner[2]) / max(outer[2] - inner[2], 1e-6)
        t = min(max(t, 0.0), 1.0)
        out = {}
        for k, w in self.ws[inner[0]].items():
            out[k] = out.get(k, 0.0) + w * (1.0 - t)
        for k, w in self.ws[outer[0]].items():
            out[k] = out.get(k, 0.0) + w * t
        return out, here, name


def _clear_lapel_arms(obj, weights, rig_jacket) -> int:
    """Clear the arm bones from the collar/lapel zone (and from any UV piece centred in
    it), renormalising onto what is left (chest/spine). Prints the zone's weights next to
    the owner's in the same zone."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uvl = bm.loops.layers.uv.active
    zone = set()
    for faces in _uv_islands(bm, uvl):
        area = sum(f.calc_area() for f in faces) or 1.0
        c = sum((f.calc_center_median() * f.calc_area() for f in faces), Vector()) / area
        if c.z > LAPEL_ZONE_Z and abs(c.x) < LAPEL_ZONE_X:
            zone |= {v.index for f in faces for v in f.verts}
    bm.free()
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if p.z > LAPEL_ZONE_Z and abs(p.x) < LAPEL_ZONE_X:
            zone.add(v.index)
    before = [weights[i] for i in zone]
    count = 0
    for i in zone:
        w = weights[i]
        if any(k in ARM_BONES and x > 0.001 for k, x in w.items()):
            count += 1
        kept = {k: x for k, x in w.items() if k not in ARM_BONES}
        total = sum(kept.values())
        weights[i] = {k: x / total for k, x in kept.items()} if total > 1e-6 else {"chest": 1.0}

    def share(ws):
        acc = {}
        for w in ws:
            for k, x in w.items():
                acc[k] = acc.get(k, 0.0) + x
        t = sum(acc.values()) or 1.0
        return _fmt_share({k: x / t for k, x in acc.items()})

    pts, rws = _vertex_weights(rig_jacket)
    owner = [w for p, w in zip(pts, rws) if p.z > LAPEL_ZONE_Z and abs(p.x) < LAPEL_ZONE_X]
    log("    collar/lapel zone (z > %.2f, |x| < %.2f, plus pieces centred in it): %d verts,"
        " %d had arm weight" % (LAPEL_ZONE_Z, LAPEL_ZONE_X, len(zone), count))
    log("      owner, same zone (%d verts): %s" % (len(owner), share(owner)))
    log("      ours before:                %s" % share(before))
    log("      ours after:                 %s" % share([weights[i] for i in zone]))
    return count


def _column_tops(objs, width):
    """A function |x| -> the highest point of the source meshes in that |x| column
    (`width` wide; an empty column takes the nearest filled one)."""
    tops = {}
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            b = int(abs(p.x) / width)
            tops[b] = max(tops.get(b, -1e9), p.z)
    keys = sorted(tops)

    def top(ax):
        b = int(ax / width)
        if b in tops:
            return tops[b]
        return tops[min(keys, key=lambda k: abs(k - b))]

    return top


def _knn(cache, objs, tag, keep_weights):
    key = (tuple(o.name for o in objs), tag)
    if key not in cache:
        cache[key] = _Knn.from_objects(objs, keep_weights=keep_weights)
    return cache[key]


def _clip(w, allowed, side_of, co, arm, stats):
    """Keep only allowed bones, and only bones of the vertex's own side (past 2 cm from
    the centre line); an emptied vertex takes the nearest allowed bone. Normalised."""
    out = {}
    cut_bone = cut_side = False
    total = sum(w.values()) or 1.0
    for name, value in w.items():
        if value / total < MIN_WEIGHT:
            continue
        if allowed is not None and name not in allowed:
            cut_bone = cut_bone or value > 0.01
            continue
        side = side_of.get(name)
        if side is not None and co.x * side < -0.02:
            cut_side = cut_side or value > 0.01
            continue
        out[name] = value
    if stats is not None:
        stats["bone"] = stats.get("bone", 0) + cut_bone
        stats["side"] = stats.get("side", 0) + cut_side
    if sum(out.values()) <= 1e-6:
        if stats is not None:
            stats["empty"] = stats.get("empty", 0) + 1
        out = {_nearest_bone(arm, co, allowed or set(side_of) | set(w), side_of): 1.0}
    total = sum(out.values())
    return {k: v / total for k, v in out.items()}


def _nearest_bone(arm, co, allowed, side_of):
    from mathutils.geometry import intersect_point_line

    best, best_d = None, math.inf
    for b in arm.data.bones:
        if b.name not in allowed:
            continue
        side = side_of.get(b.name)
        if side is not None and co.x * side < -0.02:
            continue
        a = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        p, f = intersect_point_line(co, a, t)
        p = a if f < 0 else (t if f > 1 else p)
        if (p - co).length < best_d:
            best, best_d = b.name, (p - co).length
    return best


def _stick_trims(obj, weights, labels) -> int:
    """Small loose parts (pocket flaps, welt, cuff buttons) take the weights of the
    nearest point on the garment's main surfaces, so they cannot drift off them in a pose.
    A part is trim when its area is under a tenth of the largest part's; everything else
    (both shoe uppers, not just the bigger one) is a surface a trim can stick to."""
    from mathutils.bvhtree import BVHTree
    from mathutils.interpolate import poly_3d_calc

    me = obj.data
    parent = list(range(len(me.vertices)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    area = {}
    for poly in me.polygons:
        r = find(poly.vertices[0])
        area[r] = area.get(r, 0.0) + poly.area
    if len(area) < 2:
        return 0
    main = max(area, key=area.get)
    trims = {r for r, a in area.items() if a < 0.1 * area[main]}
    if not trims:
        return 0
    me.calc_loop_triangles()
    points = [obj.matrix_world @ v.co for v in me.vertices]
    count = 0
    trees = {}
    for i in range(len(me.vertices)):
        if find(i) not in trims:
            continue
        # stick to the same region (a cuff button to its sleeve, a flap to the body)
        if labels[i] not in trees:
            tris = [tuple(t.vertices) for t in me.loop_triangles
                    if find(t.vertices[0]) not in trims and labels[t.vertices[0]] == labels[i]]
            trees[labels[i]] = (BVHTree.FromPolygons(points, tris), tris) if tris else None
        if trees[labels[i]] is None:
            continue
        tree, tris = trees[labels[i]]
        loc, _, index, _ = tree.find_nearest(points[i])
        tri = tris[index]
        bary = poly_3d_calc([points[j] for j in tri], loc)
        out = {}
        for j, b in zip(tri, bary):
            for name, w in weights[j].items():
                out[name] = out.get(name, 0.0) + w * b
        weights[i] = out
        count += 1
    return count


def _roughness(obj, weights) -> float:
    """Mean distance between a vertex's weights and its neighbours' average: weights that
    jump from vertex to vertex bend a low-poly sleeve into kinks once the arm moves."""
    ring = [[] for _ in obj.data.vertices]
    for e in obj.data.edges:
        a, b = e.vertices
        ring[a].append(b)
        ring[b].append(a)
    total = 0.0
    for i, own in enumerate(weights):
        if not ring[i]:
            continue
        avg = {}
        for j in ring[i]:
            for g, w in weights[j].items():
                avg[g] = avg.get(g, 0.0) + w / len(ring[i])
        total += sum(abs(own.get(g, 0.0) - avg.get(g, 0.0)) for g in set(own) | set(avg))
    return total / max(len(weights), 1)


def _top4(w):
    top = dict(sorted(w.items(), key=lambda kv: -kv[1])[:4])
    total = sum(top.values()) or 1.0
    return {k: v / total for k, v in top.items() if v / total > 0.001}


def _smooth(obj, weights, factor, repeat):
    """Relax each vertex's weights towards its neighbours' average. It only mixes bones
    already present, so it stays inside the allowed set."""
    me = obj.data
    ring = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        ring[a].append(b)
        ring[b].append(a)
    for _ in range(repeat):
        new = []
        for i, own in enumerate(weights):
            if not ring[i]:
                new.append(own)
                continue
            avg = {}
            for j in ring[i]:
                for g, w in weights[j].items():
                    avg[g] = avg.get(g, 0.0) + w / len(ring[i])
            keys = set(avg) | set(own)
            new.append({g: (1.0 - factor) * own.get(g, 0.0) + factor * avg.get(g, 0.0)
                        for g in keys})
        weights = new
    return weights


def _rigid_hem(obj, weights, bone, side_of) -> int:
    """The trouser hem follows only the shin: the bottom HEM_BAND is 100% lowerleg of its
    side, blended back to the transferred weights over the next HEM_BAND. The owner's hem
    carries ~15% foot, so in a walk it tilts and flares with the foot; a rigid cuff stays
    square to the shin."""
    zs = [(obj.matrix_world @ v.co).z for v in obj.data.vertices]
    bottom = min(zs)
    count = 0
    for i, v in enumerate(obj.data.vertices):
        z = zs[i]
        if z > bottom + 2.0 * HEM_BAND:
            continue
        x = (obj.matrix_world @ v.co).x
        name = next(n for n, sd in side_of.items() if n.startswith(bone) and sd * x > 0)
        t = min(max((z - bottom - HEM_BAND) / HEM_BAND, 0.0), 1.0)
        mixed = {k: w * t for k, w in weights[i].items()}
        mixed[name] = mixed.get(name, 0.0) + (1.0 - t)
        weights[i] = mixed
        count += 1 if t == 0.0 else 0
    return count


def _parent_to(obj, arm) -> None:
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.matrix_world = world
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def _bones_used(obj) -> str:
    counts = {}
    for v in obj.data.vertices:
        for g in v.groups:
            if g.weight > 0.01:
                name = obj.vertex_groups[g.group].name
                counts[name] = counts.get(name, 0) + 1
    unweighted = sum(1 for v in obj.data.vertices if not any(g.weight > 0.01 for g in v.groups))
    text = ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts, key=lambda k: -counts[k]))
    return text + (" | %d verts UNWEIGHTED" % unweighted if unweighted else "")


# ---------------------------------------------------------------------------------------
# step 6: export


def step_export(ns) -> bool:
    log("\n== export -> %s" % ns.out)
    arm = _armature()
    keep = set(_role_objects().values()) | {arm}
    for o in list(bpy.data.objects):
        if o in keep:
            continue
        if o.users_collection and any(c.name == "glTF_not_exported" for c in o.users_collection):
            continue
        bpy.data.objects.remove(o, do_unlink=True)
    for role, obj in _role_objects().items():
        name = MATERIAL[role]
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        colour = REPORT_COLOUR[role]
        mat.diffuse_color = (colour[0], colour[1], colour[2], 1.0)
        if mat.node_tree is None:
            mat.use_nodes = True
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":  # what the glTF exporter reads
                node.inputs["Base Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
                node.inputs["Roughness"].default_value = 1.0
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    stage = ns.out.with_suffix(".staged.glb")
    _select_only([])
    bpy.ops.export_scene.gltf(
        filepath=str(stage),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=False,  # never bake the armature modifier into the mesh
        export_skins=True,
        export_animations=False,  # animations live in the rig scene, not the model
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    ok = _verify(stage, ns.rig, [r for r in ROLES if r in _role_objects()])
    if not ok:
        log("  ABORT: export failed the check; %s left alone (staged file kept)" % ns.out.name)
        return False
    os.replace(stage, ns.out)
    log("  wrote %s (%d KB)" % (ns.out, ns.out.stat().st_size // 1024))
    return True


def _glb_json(path):
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20 : 20 + length])


def _verify(path, rig_path, roles) -> bool:
    ours, ref = _glb_json(path), _glb_json(rig_path)
    ok = True

    def check(cond, text):
        nonlocal ok
        log("  %s %s" % ("ok  " if cond else "FAIL", text))
        ok = ok and cond

    nodes = ours["nodes"]
    roots = [nodes[r].get("name") for r in ours["scenes"][0]["nodes"]]
    check(roots == ["Rig_Medium"], "scene root %s" % roots)
    joints = [nodes[j].get("name") for j in ours["skins"][0]["joints"]] if ours.get("skins") else []
    ref_joints = [ref["nodes"][j].get("name") for j in ref["skins"][0]["joints"]]
    check(sorted(joints) == sorted(ref_joints) and len(joints) == 22,
          "%d joints, same names as %s" % (len(joints), rig_path.name))
    meshes = {n.get("name"): n for n in nodes if "mesh" in n}
    check(sorted(meshes) == sorted(roles), "mesh nodes %s" % sorted(meshes))
    for name, n in sorted(meshes.items()):
        prims = ours["meshes"][n["mesh"]]["primitives"]
        tris = sum(ours["accessors"][p["indices"]]["count"] // 3 for p in prims if "indices" in p)
        attrs = set().union(*(p["attributes"].keys() for p in prims))
        skinned = "skin" in n and "JOINTS_0" in attrs and "WEIGHTS_0" in attrs
        check(skinned and "TEXCOORD_0" in attrs, "%-8s %5d tris, skinned, UVs" % (name, tris))
    check(not ours.get("animations"), "no animations")
    # and back through Blender's importer, as the game's importer would see it
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    check(len(arms) == 1 and arms[0].name == "Rig_Medium" and len(arms[0].data.bones) == 22,
          "re-import: armature %s" % [(a.name, len(a.data.bones)) for a in arms])
    for role in roles:
        o = bpy.data.objects.get(role)
        good = o is not None and any(m.type == "ARMATURE" for m in o.modifiers)
        check(good, "re-import: %s bound to the armature" % role)
    return ok


# ---------------------------------------------------------------------------------------
# step 7: report


def step_report(ns) -> None:
    out = ns.report_dir
    out.mkdir(parents=True, exist_ok=True)
    log("\n== report -> %s" % out)
    if ns.out.is_file() and ns.stop_after == "export":
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(ns.out))
    objs = _role_objects()
    stripes = _stripe_image()
    for role, obj in objs.items():
        mat = bpy.data.materials.new("report_" + role)
        c = REPORT_COLOUR[role]
        mat.diffuse_color = (c[0], c[1], c[2], 1.0)
        if role in CLOTH_ROLES:
            if mat.node_tree is None:
                mat.use_nodes = True
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = stripes
            tex.extension = "REPEAT"
            mat.node_tree.nodes.active = tex
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1100
    pts = [p for o in objs.values() for p in _world_verts(o)]
    lo, hi = _bounds(pts)
    centre = (lo + hi) * 0.5
    size = max(hi - lo)
    cam_data = bpy.data.cameras.new("report_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size * 1.1
    cam = bpy.data.objects.new("report_cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    images = []
    for name, yaw, frame in (
        ("front", 0, None), ("side", 90, None), ("back", 180, None), ("three_quarter", 35, None),
        ("sleeve_closeup", 20, (Vector((0.5, 0, 1.1)), 0.7)),
        ("trousers_closeup", 25, (Vector((0.0, 0, 0.45)), 0.9)),
    ):
        r = math.radians(yaw)
        view = Vector((math.sin(r), -math.cos(r), 0))
        target, scale = frame if frame else (centre, size * 1.1)
        cam_data.ortho_scale = scale
        cam.location = target + view * size * 3
        cam.rotation_euler = (math.radians(90), 0, r)
        scene.render.filepath = str(out / ("blender_%s.png" % name))
        bpy.ops.render.render(write_still=True)
        images.append(scene.render.filepath)
    images.append(_silhouette(scene, cam, cam_data, lo, hi, out / "blender_ortho_rest_front.png"))
    for role in CLOTH_ROLES:
        if role in objs:
            images.append(_uv_layout(objs[role], out / ("uv_%s.png" % role)))
    log("  images:")
    for path in images:
        log("    %s" % path)
    summary = out / "summary.txt"
    _LOG.append("")
    summary.write_text("\n".join(_LOG), encoding="utf-8")
    print("  summary: %s" % summary)


def _silhouette(scene, cam, cam_data, lo, hi, path) -> str:
    """Rest pose, orthographic front, flat colours on a transparent background: the
    image tools/char_ref_compare.py lays over the owner's reference sheet. The frame is
    1.05 x the model height tall and centred on it."""
    height = hi.z - lo.z
    scene.render.film_transparent = True
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1100
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = height * 1.05
    cam.location = Vector((0.0, -10.0, lo.z + height * 0.5))
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return str(path)


def _stripe_image():
    """A 1x1 UV tile (= 1 m of cloth) with 6 dark pinstripes along V and faint rules
    across it, so the grain and the metre scale read in a workbench render."""
    size = 240
    img = bpy.data.images.new("report_stripes", size, size)
    px = []
    for y in range(size):
        for x in range(size):
            v = 0.85
            if (x % 40) < 5:
                v = 0.1
            elif (y % 40) < 1:
                v = 0.6
            px += [v, v, v * 1.05 if v < 0.5 else v, 1.0]
    img.pixels.foreach_set(px)
    img.pack()
    return img


def _uv_layout(obj, path) -> str:
    """Draw a mesh's UV edges to a PNG (fitted to the layout, with a 1 m grid, and a red
    stroke up the grain of each island) without needing a GPU."""
    import numpy as np

    size = 1024
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[:, :, 3] = 1.0
    img[:, :, :3] = 0.08
    if obj.data.uv_layers.active is None:
        return "(no UVs yet on %s)" % obj.name
    uvd = obj.data.uv_layers.active.data
    uvs = [uvd[i].uv.copy() for i in range(len(uvd))]
    lo = Vector((min(u.x for u in uvs), min(u.y for u in uvs)))
    hi = Vector((max(u.x for u in uvs), max(u.y for u in uvs)))
    span = max(hi.x - lo.x, hi.y - lo.y, 1e-6) * 1.04

    def px(u):
        return ((u.x - lo.x) / span * (size - 1), (u.y - lo.y) / span * (size - 1))

    def line(a, b, colour):
        (x0, y0), (x1, y1) = px(a), px(b)
        n = int(max(abs(x1 - x0), abs(y1 - y0), 1)) + 1
        for k in range(n + 1):
            t = k / n
            x, y = int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)
            if 0 <= x < size and 0 <= y < size:
                img[y, x, :3] = np.maximum(img[y, x, :3], colour)

    m = math.floor(lo.x)
    while m <= hi.x:
        line(Vector((m, lo.y)), Vector((m, hi.y)), (0.25, 0.25, 0.3))
        m += 1.0
    m = math.floor(lo.y)
    while m <= hi.y:
        line(Vector((lo.x, m)), Vector((hi.x, m)), (0.25, 0.25, 0.3))
        m += 1.0
    for poly in obj.data.polygons:
        loops = list(poly.loop_indices)
        for a, b in zip(loops, loops[1:] + loops[:1]):
            line(uvs[a], uvs[b], (0.3, 0.85, 0.45))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uvl = bm.loops.layers.uv.active
    for faces in _uv_islands(bm, uvl):
        pts = [l[uvl].uv for f in faces for l in f.loops]
        c = sum(pts, Vector((0.0, 0.0))) / len(pts)
        h = (max(p.y for p in pts) - min(p.y for p in pts)) * 0.3
        line(c - Vector((0, h)), c + Vector((0, h)), (1.0, 0.25, 0.2))
        line(c + Vector((0, h)), c + Vector((-h * 0.2, h * 0.8)), (1.0, 0.25, 0.2))
        line(c + Vector((0, h)), c + Vector((h * 0.2, h * 0.8)), (1.0, 0.25, 0.2))
    bm.free()
    image = bpy.data.images.new("uv_" + obj.name, size, size)
    image.pixels.foreach_set(img.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return str(path)


def _uv_islands(bm, uvl):
    """Islands by UV continuity (the exported glb has no seam flags)."""
    bm.faces.ensure_lookup_table()
    parent = list(range(len(bm.faces)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f0, f1 = e.link_faces
        same = True
        for v in e.verts:
            a = next(l[uvl].uv for l in f0.loops if l.vert is v)
            b = next(l[uvl].uv for l in f1.loops if l.vert is v)
            if (a - b).length > 1e-5:
                same = False
        if same:
            ra, rb = find(f0.index), find(f1.index)
            if ra != rb:
                parent[ra] = rb
    groups = {}
    for f in bm.faces:
        groups.setdefault(find(f.index), []).append(f)
    return list(groups.values())


# ---------------------------------------------------------------------------------------


def main(argv) -> int:
    ns = _arguments(argv)
    log("tripo_character: %s -> %s (stop after %s)" % (ns.src.name, ns.out.name, ns.stop_after))
    runs = (
        ("classify", step_classify),
        ("align", step_align),
        ("uv", step_uv),
        ("decimate", step_decimate),
        ("skin", lambda ns: step_skin(ns) if ns.copy_weights else step_skin_rigid(ns)),
        ("export", step_export),
    )
    for name, fn in runs:
        result = fn(ns)
        if result is False:
            return 1
        if name == ns.stop_after:
            if name != "export":
                ns.report_dir.mkdir(parents=True, exist_ok=True)
                blend = ns.report_dir / ("stage_%s.blend" % name)
                bpy.ops.wm.save_as_mainfile(filepath=str(blend), copy=True)
                log("\nstopped after %s; working file saved to %s" % (name, blend))
            break
    if ns.report:
        step_report(ns)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
