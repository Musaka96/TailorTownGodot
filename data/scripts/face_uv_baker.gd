class_name FaceUvBaker
extends RefCounted

## Bakes a "face UV" into a head mesh: UV2 = a planar projection of the head's flat front,
## found from the mesh itself, so skin_face.gdshader can draw the face in the head's own
## material. Vertices go into head-bone rest space (model forward is +Z); the ones facing
## the front (normal.z >= FRONT_NZ) give the FACE RECT, their x/y bounding box, and every
## vertex gets UV2 = ((x - cx) / w + 0.5, 0.5 - (y - cy) / h), so the rect is 0..1 with v
## down. Vertices facing away (normal.z < BACK_NZ) would project into the rect from behind:
## they are pushed BACK_PUSH face units out from the rect centre along their own direction,
## so no triangle between them and a side vertex can sweep back across the rect.
## Every vertex also carries its head-bone rest position in CUSTOM0 (xyz, w = 1), which
## skin_face.gdshader reads to cut the neck stub off below the worn top's collar (NeckCut).
## Results are cached per source mesh (heads are shared resources).

const FRONT_NZ := 0.85
const FRONT_NZ_LOOSE := 0.4
const MIN_FRONT := 30
## Front-plate depth, as a fraction of the head's whole depth behind its frontmost vertex.
const FRONT_DEPTH := 0.15
const BACK_NZ := 0.15
const BACK_PUSH := 8.0

static var _cache := {}
static var _outputs := {}  # instance id of a baked mesh -> its result


## {"mesh": ArrayMesh with UV2, "frame": FaceFrame}; {} when the mesh has no front.
## `head_rest_inv` takes the mesh's vertices into head-bone rest space.
static func bake(mesh: Mesh, head_rest_inv: Transform3D) -> Dictionary:
	if mesh == null:
		return {}
	if _outputs.has(mesh.get_instance_id()):
		return _outputs[mesh.get_instance_id()]  # already baked: re-baking is a no-op
	var key := _key(mesh, head_rest_inv)
	if _cache.has(key):
		return _cache[key]
	var nb := head_rest_inv.basis.inverse().transposed()
	var surfaces := []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		pos.resize(src_v.size())
		nrm.resize(src_v.size())
		for i in src_v.size():
			pos[i] = head_rest_inv * src_v[i]
			nrm[i] = (nb * src_n[i]).normalized() if i < src_n.size() else Vector3.BACK
		surfaces.append({"arrays": arrays, "pos": pos, "nrm": nrm})
	var rect := _front_rect(surfaces, FRONT_NZ)
	if rect.is_empty():
		rect = _front_rect(surfaces, FRONT_NZ_LOOSE)
	if rect.is_empty():
		return {}
	var frame := FaceFrame.new()
	frame.center = rect.center
	frame.size = rect.size
	frame.front_z = rect.front_z
	var out := ArrayMesh.new()
	for s in surfaces.size():
		_add_surface(out, mesh, s, surfaces[s], frame)
	print_verbose("FaceUvBaker: %s -> %s" % [mesh.resource_path, frame.describe()])
	var result := {"mesh": out, "frame": frame}
	_outputs[out.get_instance_id()] = result
	_cache[key] = result
	return result


## Bounding rect (x/y) of the front plate: vertices whose normal faces +Z at least
## `min_nz` and that lie within FRONT_DEPTH of the head's depth behind the frontmost of them
## (so the front of the neck or a stray inner vertex does not stretch the rect); {} if fewer
## than MIN_FRONT qualify.
static func _front_rect(surfaces: Array, min_nz: float) -> Dictionary:
	var front_z := -INF
	var back_z := INF
	for surf: Dictionary in surfaces:
		var pos: PackedVector3Array = surf.pos
		var nrm: PackedVector3Array = surf.nrm
		for i in pos.size():
			back_z = minf(back_z, pos[i].z)
			if nrm[i].z >= min_nz:
				front_z = maxf(front_z, pos[i].z)
	var min_z := front_z - FRONT_DEPTH * (front_z - back_z)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var n := 0
	for surf: Dictionary in surfaces:
		var pos: PackedVector3Array = surf.pos
		var nrm: PackedVector3Array = surf.nrm
		for i in pos.size():
			var p := pos[i]
			if nrm[i].z < min_nz or p.z < min_z:
				continue
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			n += 1
	if n < MIN_FRONT:
		return {}
	var size := (hi - lo).max(Vector2(1e-4, 1e-4))
	return {"center": (lo + hi) * 0.5, "size": size, "front_z": front_z}


static func _add_surface(
	out: ArrayMesh, mesh: Mesh, s: int, surf: Dictionary, frame: FaceFrame
) -> void:
	var arrays: Array = surf.arrays
	var pos: PackedVector3Array = surf.pos
	var nrm: PackedVector3Array = surf.nrm
	var uv2 := PackedVector2Array()
	uv2.resize(pos.size())
	var rest := PackedFloat32Array()
	rest.resize(pos.size() * 4)
	for i in pos.size():
		var p := pos[i]
		rest[i * 4] = p.x
		rest[i * 4 + 1] = p.y
		rest[i * 4 + 2] = p.z
		rest[i * 4 + 3] = 1.0
		var uv := Vector2(
			(p.x - frame.center.x) / frame.size.x + 0.5, 0.5 - (p.y - frame.center.y) / frame.size.y
		)
		if nrm[i].z < BACK_NZ:
			var d := uv - Vector2(0.5, 0.5)
			d = d.normalized() if d.length() > 1e-4 else Vector2.UP
			uv = Vector2(0.5, 0.5) + d * BACK_PUSH
		uv2[i] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = rest
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var fmt: int = mesh.surface_get_format(s)
	if fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var blends := []
	if mesh is ArrayMesh:
		var am := mesh as ArrayMesh
		if s == 0:
			for b in am.get_blend_shape_count():
				out.add_blend_shape(am.get_blend_shape_name(b))
			out.blend_shape_mode = am.blend_shape_mode
		blends = am.surface_get_blend_shape_arrays(s)
	var prim: Mesh.PrimitiveType = mesh.surface_get_primitive_type(s)
	out.add_surface_from_arrays(prim, arrays, blends, {}, flags)
	var idx := out.get_surface_count() - 1
	out.surface_set_material(idx, mesh.surface_get_material(s))
	if mesh is ArrayMesh:
		out.surface_set_name(idx, (mesh as ArrayMesh).surface_get_name(s))


static func _key(mesh: Mesh, xf: Transform3D) -> String:
	var id := mesh.resource_path if mesh.resource_path != "" else str(mesh.get_instance_id())
	return "%s|%s" % [id, xf]
