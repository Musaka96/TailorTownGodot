"""Even out the texel density of a character's garment UVs, so woven cloth sits flat.

Run headless — nothing here needs the Blender GUI:

    blender.exe --background --factory-startup --python tools/blender/fix_garment_uvs.py
    blender.exe --background --factory-startup --python tools/blender/fix_garment_uvs.py \
        -- assets/characters/MY_SUIT.glb jacket shirt legs

With no arguments it does the shipped character. Pass a glb and the names of its cloth
meshes to run it over a NEW garment — which any new suit needs, because uv_scale is read
as tiles per METRE (see below), so a garment left on ordinary 0..1 UVs comes out showing
the fabric at the wrong size.

WHAT IT CHANGES, EXACTLY
------------------------
The UVs of the named meshes are rewritten. Everything else is preserved in meaning but
NOT byte for byte, because the whole file goes through Blender: positions and skin
weights come back within float32 rounding (~1e-7), normals within ~4e-4 (about a
fiftieth of a degree, from Blender renormalising them), and the exporter may re-split a
few vertices at the new UV seams — the jacket went 1993 -> 1996. Node names, bone names,
the skeleton and the mesh topology are checked against the file that went in, and the
asset is not replaced unless they all match and the stretch is under STRETCH_LIMIT.

The glb is in git, so `git checkout <the glb>` undoes a bad run.

MIND THE SOURCE .blend
----------------------
This edits the glb the game loads, not whatever it was exported from. For the shipped
character that means IMPORT/CHARTGEN1.blend still holds the OLD UVs, so re-exporting it
over the glb silently undoes this — re-run this script afterwards if you do.

WHAT WAS WRONG, AND WHY THIS DOESN'T RE-UNWRAP
----------------------------------------------
The jacket's texel density varied 4.2x across the mesh, which is what smeared a woven
pattern over it. But almost none of that was distortion INSIDE the UV islands: it was the
islands sitting at different scales from each other. The cause is the mesh, not the
layout — the shipped garments have their vertices split all over (the jacket carries 1993
for 1747 triangles, where a joined surface needs about 897), so the cloth arrives as
hundreds of disconnected scraps at hundreds of different sizes.

So all this does is weld a copy, which turns those scraps back into real islands, and
even their scales out. The original layout is otherwise left alone, because it was a
decent garment unwrap: continuous across each panel, and with the grain already running
the right way — a pinstripe down the body and down the sleeve.

Re-unwrapping was tried and is worse on every count, which is worth recording so it isn't
tried again:

  * `smart_project` gets the density flat (1.1x) but PACKS the islands, which puts
    neighbouring cloth at unrelated places in UV space. The pattern's phase then jumps at
    every island edge and the jacket reads as patchwork. Packing also rotates islands, so
    the grain ends up in a different direction on each one — pinstripes ran ACROSS the
    sleeves.
  * Draping the garment around the limb (a surface of revolution taken from the skeleton)
    gives perfect continuity and a perfect grain, but a jacket torso with lapels is
    nowhere near a cylinder: 5.2x.
  * Cutting tailoring seams and flattening conformally needs a good seam set; placed
    automatically from the drape it left the shirt with no seam at all, and a conformal
    unwrap of an uncut closed surface explodes (1109x).
  * `minimize_stretch` does nothing on the unwelded mesh (there is nothing connected to
    relax across) and wrecks the welded one (25x-85x).

The one thing left to fix properly is the shirt: its UVs are shattered into 55 pieces
that welding does not rejoin, so a patterned shirt still breaks up. It is nearly always
hidden under the jacket, and its density is fine, so it is left as it is.

UVs come out in METRES — one UV unit is one metre of cloth — so ClothMaterial's uv_scale
reads as "fabric tiles per metre". That also pins the jacket, shirt and trousers to one
texel density; they were at three different ones, so a shirt showed the same cloth about
three times coarser than the jacket it was cut from.

Verify with `godot --headless --path . --script res://tools/uv_report.gd`.
"""

import json
import math
import os
import struct
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GLB = ROOT / "assets" / "characters" / "CHARTGEN1.glb"
# The shipped character's meshes that get a tiling fabric (ClothMaterial) rather than a
# flat colour or the baked face texture — see entities/character/character_rig.gd.
DEFAULT_CLOTH_MESHES = ("jacket", "shirt", "legs")

# Coincident vertices closer than this are joined on the working copy. The meshes are
# modelled in metres, so this is a hundredth of a millimetre — it rejoins split vertices
# without merging anything that was genuinely apart.
WELD_DISTANCE = 1e-5
STRETCH_LIMIT = 1.6  # past this the weave visibly smears; the jacket started at 4.2


def main(argv) -> int:
    glb, cloth_meshes = _arguments(argv)
    stage = glb.with_suffix(".staged.glb")
    print("fix_garment_uvs: %s (%s)" % (glb, ", ".join(cloth_meshes)))
    if not glb.is_file():
        print("  ABORT: no such file")
        return 1

    # The contract is read off the file going IN, rather than hardcoded, so this works on
    # a new garment too and still proves the round trip changed nothing but the UVs.
    contract = _contract(glb)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))

    missing = [n for n in cloth_meshes if n not in bpy.data.objects]
    if missing:
        print("  ABORT: no mesh called %s in the glb" % ", ".join(missing))
        print("         it has: %s" % ", ".join(sorted(contract["meshes"])))
        return 1

    print("\n  before:")
    for name in cloth_meshes:
        _stats(bpy.data.objects[name], name)

    print("\n  evening out:")
    for name in cloth_meshes:
        if not _even_out(bpy.data.objects[name]):
            return 1

    print("\n  after:")
    worst = 1.0
    for name in cloth_meshes:
        worst = max(worst, _stats(bpy.data.objects[name], name))
    if worst > STRETCH_LIMIT:
        print("\n  ABORT: worst stretch %.2fx is over the %.1fx limit" % (worst, STRETCH_LIMIT))
        return 1

    _export(stage)
    if not _verify(stage, contract):
        print("\n  ABORT: export failed the contract check; %s left alone" % glb.name)
        stage.unlink(missing_ok=True)
        return 1
    os.replace(stage, glb)
    print("\nfix_garment_uvs: wrote %s (worst stretch %.2fx)" % (glb.name, worst))
    return 0


def _arguments(argv) -> tuple:
    """`-- <glb> [mesh ...]` after Blender's own arguments; defaults to the character."""
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    if not args:
        return DEFAULT_GLB, DEFAULT_CLOTH_MESHES
    glb = Path(args[0])
    if not glb.is_absolute():
        glb = (ROOT / glb).resolve()
    return glb, tuple(args[1:]) or DEFAULT_CLOTH_MESHES


def _even_out(obj) -> bool:
    """Put every UV island of one garment at the same texel density, in metres."""
    welded = _welded_copy(obj)
    try:
        before = _island_count(welded)
        _average_island_scale(welded)
        scale = _scale_to_metres(welded)
        if not _transfer_uvs(welded, obj):
            return False
    finally:
        bpy.data.objects.remove(welded, do_unlink=True)
    print(
        "    %-8s %d islands once welded (was %d unwelded) | UVs x%.3f -> metres"
        % (obj.name, before, _island_count(obj), scale)
    )
    return True


def _welded_copy(obj):
    """A welded duplicate to measure and rescale the islands on.

    Welding is the whole trick: until the split vertices are rejoined, the garment is
    hundreds of disconnected scraps, so there are no islands to compare scales between —
    which is why the density was all over the place. The UVs are copied back to the real
    mesh afterwards, leaving its topology, vertex count and split normals alone.
    """
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = obj.name + ".welded"
    bpy.context.scene.collection.objects.link(copy)
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=WELD_DISTANCE)
    bm.to_mesh(copy.data)
    bm.free()
    return copy


def _average_island_scale(obj) -> None:
    """Bring every island to a common texel density (Blender does the per-island maths;
    it leaves each island's shape and orientation alone, so the grain is untouched)."""
    bpy.context.view_layer.objects.active = obj
    for other in bpy.data.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale(scale_uv=True, shear=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _scale_to_metres(obj) -> float:
    """Scale the UVs so their area matches the surface area: one UV unit, one metre of
    cloth. That pins every garment to the same texel density, which is what stops a shirt
    showing the same fabric at a different size from the jacket it was cut from."""
    area_3d, area_uv = _areas(obj)
    if area_uv <= 0.0:
        return 1.0
    scale = math.sqrt(area_3d / area_uv)
    for element in obj.data.uv_layers.active.data:
        element.uv = element.uv * scale
    return scale


def _transfer_uvs(src, dst) -> bool:
    """Copy the UVs off the welded copy onto the real mesh.

    Faces are paired by centroid and their corners by position, because welding renumbers
    both but moves neither. Split vertices therefore all receive the UV of the single
    welded vertex they came from, so the result renders exactly like the welded mesh
    while the shipped topology stays as it was.
    """
    if len(src.data.polygons) != len(dst.data.polygons):
        print(
            "    ABORT: welding changed %s's face count (%d -> %d)"
            % (dst.name, len(dst.data.polygons), len(src.data.polygons))
        )
        return False
    src_uv = src.data.uv_layers.active.data
    dst_uv = dst.data.uv_layers.active.data
    by_centre = {_key(poly.center): poly for poly in src.data.polygons}
    for poly in dst.data.polygons:
        match = by_centre.get(_key(poly.center))
        if match is None:
            print("    ABORT: no welded face matches %s's at %s" % (dst.name, poly.center))
            return False
        corners = {
            _key(src.data.vertices[src.data.loops[loop].vertex_index].co): loop
            for loop in match.loop_indices
        }
        for loop in poly.loop_indices:
            co = dst.data.vertices[dst.data.loops[loop].vertex_index].co
            source = corners.get(_key(co))
            if source is None:
                print("    ABORT: no welded corner matches %s's at %s" % (dst.name, co))
                return False
            dst_uv[loop].uv = src_uv[source].uv
    return True


def _key(point) -> tuple:
    """A position rounded enough to match across a weld, fine enough not to collide."""
    return round(point.x, 4), round(point.y, 4), round(point.z, 4)


def _island_count(obj) -> int:
    """How many separate pieces the fabric runs across. Two faces count as joined when
    their UVs agree along the edge they share — that is where cloth is continuous."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.index_update()
    uv = bm.loops.layers.uv.active
    parent = {face.index: face.index for face in bm.faces}

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for edge in bm.edges:
        if len(edge.link_faces) != 2:
            continue
        left, right = edge.link_faces
        if _uv_continuous(edge, left, right, uv):
            parent[find(left.index)] = find(right.index)
    count = len({find(face.index) for face in bm.faces})
    bm.free()
    return count


def _uv_continuous(edge, left, right, uv) -> bool:
    for vert in edge.verts:
        a = next((loop[uv].uv for loop in left.loops if loop.vert is vert), None)
        b = next((loop[uv].uv for loop in right.loops if loop.vert is vert), None)
        if a is None or b is None or (a - b).length > 1e-6:
            return False
    return True


def _triangles(obj):
    """Each triangle as (world area, UV area), fanned from each face's first corner."""
    mesh = obj.data
    matrix = obj.matrix_world
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            i0, i1, i2 = loops[0], loops[k], loops[k + 1]
            p0 = matrix @ mesh.vertices[mesh.loops[i0].vertex_index].co
            p1 = matrix @ mesh.vertices[mesh.loops[i1].vertex_index].co
            p2 = matrix @ mesh.vertices[mesh.loops[i2].vertex_index].co
            e1 = uv[i1].uv - uv[i0].uv
            e2 = uv[i2].uv - uv[i0].uv
            yield (
                (p1 - p0).cross(p2 - p0).length * 0.5,
                abs(e1.x * e2.y - e1.y * e2.x) * 0.5,
            )


def _areas(obj) -> tuple:
    area_3d = 0.0
    area_uv = 0.0
    for a3, a2 in _triangles(obj):
        area_3d += a3
        area_uv += a2
    return area_3d, area_uv


def _stats(obj, label: str) -> float:
    """Print one mesh's texel density spread and return its stretch."""
    density = [math.sqrt(a2 / a3) for a3, a2 in _triangles(obj) if a3 > 1e-9 and a2 > 1e-12]
    if not density:
        print("    %-8s no usable triangles" % label)
        return 1.0
    density.sort()
    low = density[int(len(density) * 0.05)]
    high = density[int(len(density) * 0.95)]
    stretch = high / max(low, 1e-9)
    print(
        "    %-8s %4d tris | density %.2f..%.2f UV/m | stretch %.2fx %s"
        % (label, len(density), low, high, stretch, "" if stretch <= STRETCH_LIMIT else "SMEARS")
    )
    return stretch


def _export(stage: Path) -> None:
    """Write the staged glb. The importer parks its own helper objects in a
    `glTF_not_exported` collection, which the exporter skips on its own."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(stage),
        export_format="GLB",
        use_selection=False,
        export_yup=True,
        export_apply=False,  # never bake the armature modifier into the mesh
        export_skins=True,
        export_animations=False,  # the source glb carries none; animations live elsewhere
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )


def _contract(path: Path) -> dict:
    """The names and triangle counts the game relies on, read out of a glb."""
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20 : 20 + length])
    nodes = gltf.get("nodes", [])
    skins = gltf.get("skins", [])
    triangles = {}
    for node in nodes:
        if "mesh" not in node:
            continue
        total = 0
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            if "indices" in prim:
                total += gltf["accessors"][prim["indices"]]["count"] // 3
        triangles[node.get("name")] = total
    return {
        "meshes": sorted(triangles),
        "triangles": triangles,
        "roots": [nodes[r].get("name") for r in gltf["scenes"][0]["nodes"]],
        "bones": sorted(nodes[j].get("name") for j in skins[0]["joints"]) if skins else [],
    }


def _verify(path: Path, before: dict) -> bool:
    """Check the exported glb still carries everything the file going in did.

    Names because the game looks meshes and bones up by them; triangle counts because a
    changed one would mean geometry was altered, not just its UVs.
    """
    after = _contract(path)
    ok = True
    for what in ("meshes", "roots", "bones", "triangles"):
        if after[what] != before[what]:
            print("    %s changed!\n      was %s\n      now %s" % (what, before[what], after[what]))
            ok = False
    if ok:
        print(
            "    contract ok: %d mesh nodes, root %s, %d bones, %d triangles"
            % (
                len(after["meshes"]),
                after["roots"][0] if after["roots"] else "-",
                len(after["bones"]),
                sum(after["triangles"].values()),
            )
        )
    return ok


if __name__ == "__main__":
    sys.exit(main(sys.argv))
