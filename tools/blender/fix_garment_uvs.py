"""Re-unwrap the character's cloth garments so a woven fabric sits on them properly.

Run headless — nothing here needs the Blender GUI:

    "E:/SteamLibrary/steamapps/common/Blender/blender.exe" --background \
        --factory-startup --python tools/blender/fix_garment_uvs.py

It imports assets/characters/CHARTGEN1.glb, replaces the UVs of the meshes that get a
tiling fabric, and writes the glb back. Nothing else is touched: the armature, the skin
weights, the other meshes and every node name are imported and exported as they came,
and the script refuses to overwrite the asset unless that contract still holds. The glb
is in git too, so `git checkout assets/characters/CHARTGEN1.glb` undoes a bad run.

Why not a neatly packed atlas: the garment shader repeats a fabric across the UVs (see
materials/cloth.gdshader), so islands overlapping each other costs nothing at all. What
a woven pattern needs instead is

  * uniform texel density — the old jacket varied 4.2x across the mesh, which is what
    smeared the houndstooth; the shirt's UVs were shattered into one island per
    triangle, so a fabric on it came out as confetti;
  * one consistent grain direction, so a pinstripe runs DOWN every panel instead of
    turning a corner wherever the unwrapper happened to rotate an island;
  * a shared physical scale, or the jacket and the trousers show the same cloth at
    different sizes (they did: the shirt's density was a third of the jacket's).

So the UVs come out in METRES — one UV unit is one metre of cloth — which makes
ClothMaterial's uv_scale read directly as "fabric tiles per metre".

Verify the result with `godot --headless --path . --script res://tools/uv_report.gd`.
"""

import json
import math
import os
import struct
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "assets" / "characters" / "CHARTGEN1.glb"
STAGE = GLB.with_suffix(".staged.glb")

# Meshes that get a tiling fabric (ClothMaterial) rather than a flat colour or the
# baked face texture — see entities/character/character_rig.gd.
REUNWRAP = ("jacket", "shirt")  # their unwraps are unusable; see the module docstring
KEEP_LAYOUT = ("legs",)  # already uniform, so it only needs the shared scale
CLOTH = REUNWRAP + KEEP_LAYOUT

# Everything the game looks up by name, and the rig the wardrobe parts are skinned to.
# The whole point of the round trip is that ONLY UVs change, so this is checked on the
# way in and again in the exported file.
EXPECTED_ROOT = "Rig_Medium"
EXPECTED_MESHES = (
    "arms",
    "buttons",
    "Hair",
    "head",
    "jacket",
    "left leg",
    "legs",
    "right leg",
    "shirt",
)
EXPECTED_BONES = (
    "neutral_bone",
    "root",
    "hips",
    "spine",
    "chest",
    "head",
    "upperarm.l",
    "lowerarm.l",
    "wrist.l",
    "hand.l",
    "upperarm.r",
    "lowerarm.r",
    "wrist.r",
    "hand.r",
    "upperleg.l",
    "lowerleg.l",
    "foot.l",
    "toes.l",
    "upperleg.r",
    "lowerleg.r",
    "foot.r",
    "toes.r",
)

# Seam angle for the unwrap. 66 deg splits a sleeve from a body and a lapel from a
# front without dicing the mesh into confetti.
SEAM_ANGLE = math.radians(66.0)
STRETCH_LIMIT = 1.5  # past this the weave visibly smears; the jacket was at 4.2


def main() -> int:
    print("fix_garment_uvs: %s" % GLB)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GLB))

    missing = [n for n in EXPECTED_MESHES if n not in bpy.data.objects]
    if missing:
        print("  ABORT: glb is missing %s" % ", ".join(missing))
        return 1

    print("\n  before:")
    for name in CLOTH:
        _stats(bpy.data.objects[name], name)

    for name in REUNWRAP:
        _unwrap(bpy.data.objects[name])
    for name in CLOTH:
        obj = bpy.data.objects[name]
        turned = _align_grain(obj)
        scale = _scale_to_metres(obj)
        print("  %-8s grain-aligned %d island(s), UVs x%.3f -> metres" % (name, turned, scale))

    print("\n  after:")
    worst = 1.0
    for name in CLOTH:
        worst = max(worst, _stats(bpy.data.objects[name], name))
    if worst > STRETCH_LIMIT:
        print("\n  ABORT: worst stretch %.2fx is over the %.1fx limit" % (worst, STRETCH_LIMIT))
        return 1

    _export()
    if not _verify(STAGE):
        print("\n  ABORT: exported glb failed the contract check; %s left in place" % GLB.name)
        return 1
    os.replace(STAGE, GLB)
    print("\nfix_garment_uvs: wrote %s (worst stretch %.2fx)" % (GLB.name, worst))
    return 0


def _unwrap(obj) -> None:
    """Project the mesh afresh: per-face-cluster planar projections, then one scale
    pass so every island ends up at the same texel density."""
    bpy.context.view_layer.objects.active = obj
    for other in bpy.data.objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(
        angle_limit=SEAM_ANGLE,
        island_margin=0.0,  # islands may overlap; the fabric repeats
        area_weight=0.0,
        correct_aspect=True,
        scale_to_bounds=False,  # we set the scale ourselves, in metres
    )
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale(scale_uv=True, shear=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _align_grain(obj) -> int:
    """Rotate each UV island so the garment's vertical axis runs down V.

    Cloth has a grain: stripes run down a jacket. An unwrapper rotates islands to pack
    them, which would send the grain off in a different direction on every panel.
    Rotating an island changes neither its density nor its distortion, so this is free.
    """
    up = (obj.matrix_world.inverted().to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.index_update()
    uv = bm.loops.layers.uv.active
    turned = 0
    for island in _islands(bm, uv):
        direction = Vector((0.0, 0.0))
        for face in island:
            local = _up_in_uv(face, uv, up)
            if local is not None:
                direction += local * face.calc_area()
        if direction.length < 1e-9:
            continue
        loops = [loop for face in island for loop in face.loops]
        centre = Vector((0.0, 0.0))
        for loop in loops:
            centre += loop[uv].uv
        centre /= len(loops)
        # Turn that direction to point along +V.
        angle = math.pi / 2.0 - math.atan2(direction.y, direction.x)
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        for loop in loops:
            d = loop[uv].uv - centre
            loop[uv].uv = centre + Vector(
                (d.x * cos_a - d.y * sin_a, d.x * sin_a + d.y * cos_a)
            )
        turned += 1
    bm.to_mesh(obj.data)
    bm.free()
    return turned


def _islands(bm, uv) -> list:
    """Faces grouped by UV connectivity: two faces join when their UVs agree along the
    edge they share, which is exactly where the fabric runs continuously."""
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

    groups: dict = {}
    for face in bm.faces:
        groups.setdefault(find(face.index), []).append(face)
    return list(groups.values())


def _uv_continuous(edge, left, right, uv) -> bool:
    for vert in edge.verts:
        a = next((loop[uv].uv for loop in left.loops if loop.vert is vert), None)
        b = next((loop[uv].uv for loop in right.loops if loop.vert is vert), None)
        if a is None or b is None or (a - b).length > 1e-6:
            return False
    return True


def _up_in_uv(face, uv, up: Vector):
    """The UV direction that `up` points along on this face.

    Writes `up` in the face's own edge basis, then applies those coefficients to the
    matching UV edges — i.e. pushes the 3D direction through the same linear map the
    unwrap used.
    """
    loops = face.loops[:3]
    p0, p1, p2 = (loop.vert.co for loop in loops)
    u0, u1, u2 = (loop[uv].uv for loop in loops)
    d1, d2 = p1 - p0, p2 - p0
    g11, g12, g22 = d1.dot(d1), d1.dot(d2), d2.dot(d2)
    det = g11 * g22 - g12 * g12
    if abs(det) < 1e-12:
        return None
    r1, r2 = d1.dot(up), d2.dot(up)
    a = (r1 * g22 - r2 * g12) / det
    b = (r2 * g11 - r1 * g12) / det
    out = (u1 - u0) * a + (u2 - u0) * b
    return out.normalized() if out.length > 1e-9 else None


def _scale_to_metres(obj) -> float:
    """Scale the UVs so one UV unit is one metre of cloth, and return the factor.

    Density is uniform by this point, so a single factor per mesh lands every garment
    at the same texel density — which is what makes a jacket and its trousers show the
    same fabric at the same size.
    """
    area_3d, area_uv = _areas(obj)
    if area_uv <= 0.0:
        return 1.0
    scale = math.sqrt(area_3d / area_uv)
    for layer in obj.data.uv_layers.active.data:
        layer.uv = layer.uv * scale
    return scale


def _areas(obj) -> tuple:
    """(world surface area in m2, UV area) over the whole mesh."""
    mesh = obj.data
    matrix = obj.matrix_world
    uv = mesh.uv_layers.active.data
    area_3d = 0.0
    area_uv = 0.0
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            i0, i1, i2 = loops[0], loops[k], loops[k + 1]
            p0 = matrix @ mesh.vertices[mesh.loops[i0].vertex_index].co
            p1 = matrix @ mesh.vertices[mesh.loops[i1].vertex_index].co
            p2 = matrix @ mesh.vertices[mesh.loops[i2].vertex_index].co
            area_3d += (p1 - p0).cross(p2 - p0).length * 0.5
            e1 = uv[i1].uv - uv[i0].uv
            e2 = uv[i2].uv - uv[i0].uv
            area_uv += abs(e1.x * e2.y - e1.y * e2.x) * 0.5
    return area_3d, area_uv


def _stats(obj, label: str) -> float:
    """Print one mesh's texel density spread and return its stretch."""
    mesh = obj.data
    matrix = obj.matrix_world
    uv = mesh.uv_layers.active.data
    density = []
    for poly in mesh.polygons:
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            i0, i1, i2 = loops[0], loops[k], loops[k + 1]
            p0 = matrix @ mesh.vertices[mesh.loops[i0].vertex_index].co
            p1 = matrix @ mesh.vertices[mesh.loops[i1].vertex_index].co
            p2 = matrix @ mesh.vertices[mesh.loops[i2].vertex_index].co
            area = (p1 - p0).cross(p2 - p0).length * 0.5
            e1 = uv[i1].uv - uv[i0].uv
            e2 = uv[i2].uv - uv[i0].uv
            flat = abs(e1.x * e2.y - e1.y * e2.x) * 0.5
            if area > 1e-9 and flat > 1e-12:
                density.append(math.sqrt(flat / area))
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


def _export() -> None:
    """Write the staged glb. The importer parks its own helper objects in a
    `glTF_not_exported` collection, which the exporter skips on its own."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(STAGE),
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


def _verify(path: Path) -> bool:
    """Read the exported glb back and check the names the game depends on survived."""
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20 : 20 + length])
    nodes = gltf.get("nodes", [])
    meshes = sorted(n.get("name") for n in nodes if "mesh" in n)
    roots = [nodes[r].get("name") for r in gltf["scenes"][0]["nodes"]]
    skins = gltf.get("skins", [])
    bones = [nodes[j].get("name") for j in skins[0]["joints"]] if skins else []

    ok = True
    for what, got, want in (
        ("mesh nodes", meshes, sorted(EXPECTED_MESHES)),
        ("scene roots", roots, [EXPECTED_ROOT]),
        ("skin bones", sorted(bones), sorted(EXPECTED_BONES)),
    ):
        if got != want:
            print("    %s changed!\n      got  %s\n      want %s" % (what, got, want))
            ok = False
    if ok:
        print(
            "    contract ok: %d mesh nodes, root %s, %d bones, %d nodes total"
            % (len(meshes), roots[0], len(bones), len(nodes))
        )
    return ok


if __name__ == "__main__":
    code = main()
    if STAGE.exists():
        STAGE.unlink()
    sys.exit(code)
