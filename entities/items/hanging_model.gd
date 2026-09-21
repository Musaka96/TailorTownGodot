class_name HangingModel
extends RefCounted

## Garments as they hang on a clothing rack: a wooden hanger with a brass hook, and cloth
## cut to each garment's silhouette — a jacket with its sleeves, lapels and buttons, a
## shirt with its collar, trousers folded over the hanger's bar — built from flat outlines
## given a little depth, in the order's own cloth (projected, so the weave and pattern sit
## true on any shape). Simple and cute on purpose; everything is built in code.
##
## The origin is the hook: hung on a rack hook marker, the brass curl sits round a rail
## RAIL_ABOVE over it (ClothingRack's rail, RackSway's pivot). The rail runs through the
## garment front to back (local z), so on a rack they hang side-on, face to face.
##   HangingModel.make({Enums.GarmentType.JACKET: material, ...})

const RAIL_ABOVE := 0.25
const SHOULDER_Y := 0.13  # where the hanger's arms meet the garment
const BAR_Y := 0.0  # the hanger's lower bar, which trousers fold over
const CLOTH_SCALE := 3.0  # fabric repeats per metre
## How the parts layer on one hanger, front to back (z).
const LAYER := {
	Enums.GarmentType.JACKET: 0.0,
	Enums.GarmentType.SHIRT: -0.035,
	Enums.GarmentType.PANTS: -0.07,
}

## Outlines (x across, y up, metres; the hook is the origin).
const JACKET := [
	Vector2(-0.045, 0.14),
	Vector2(-0.16, 0.115),
	Vector2(-0.19, -0.3),
	Vector2(-0.13, -0.31),
	Vector2(-0.13, -0.02),
	Vector2(-0.145, -0.42),
	Vector2(0.145, -0.42),
	Vector2(0.13, -0.02),
	Vector2(0.13, -0.31),
	Vector2(0.19, -0.3),
	Vector2(0.16, 0.115),
	Vector2(0.045, 0.14),
	Vector2(0.0, -0.1),
]
const SHIRT := [
	Vector2(-0.05, 0.15),
	Vector2(-0.145, 0.12),
	Vector2(-0.175, -0.3),
	Vector2(-0.125, -0.305),
	Vector2(-0.12, -0.03),
	Vector2(-0.13, -0.4),
	Vector2(0.13, -0.4),
	Vector2(0.12, -0.03),
	Vector2(0.125, -0.305),
	Vector2(0.175, -0.3),
	Vector2(0.145, 0.12),
	Vector2(0.05, 0.15),
]
const PANTS := [
	Vector2(-0.14, 0.01),
	Vector2(0.14, 0.01),
	Vector2(0.13, -0.5),
	Vector2(0.025, -0.5),
	Vector2(0.0, -0.13),
	Vector2(-0.025, -0.5),
	Vector2(-0.13, -0.5),
]
const LAPEL_L := [Vector2(-0.045, 0.14), Vector2(0.0, -0.1), Vector2(-0.075, 0.0)]
const COLLAR_L := [Vector2(-0.05, 0.15), Vector2(0.0, 0.1), Vector2(-0.06, 0.06)]


## A hanger carrying `parts` (GarmentType -> MaterialType, or a plain Material), each at
## its layer. `hanger` false leaves the hanger out (a GarmentSet draws its own).
static func make(parts: Dictionary, hanger := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Hanging"
	if hanger:
		root.add_child(make_hanger())
	for t: int in [Enums.GarmentType.PANTS, Enums.GarmentType.SHIRT, Enums.GarmentType.JACKET]:
		if parts.has(t):
			var g := garment(t, parts[t])
			g.position.z = LAYER[t]
			root.add_child(g)
	return root


## One garment's cloth (no hanger), at z = 0.
static func garment(garment_type: int, cloth: Variant) -> Node3D:
	var mat := _cloth(cloth)
	var node := Node3D.new()
	match garment_type:
		Enums.GarmentType.JACKET:
			node.add_child(_slab(JACKET, 0.06, mat))
			for side: float in [-1.0, 1.0]:
				var lapel := _slab(_mirror(LAPEL_L, side), 0.012, mat)
				lapel.position.z = 0.034
				node.add_child(lapel)
			for y: float in [-0.19, -0.28]:
				node.add_child(_ball(Vector3(0.022, y, 0.033), 0.011, _flat(Style.WALNUT)))
		Enums.GarmentType.SHIRT:
			node.add_child(_slab(SHIRT, 0.05, mat))
			for side: float in [-1.0, 1.0]:
				var collar := _slab(_mirror(COLLAR_L, side), 0.012, mat)
				collar.position.z = 0.03
				node.add_child(collar)
			for y: float in [0.02, -0.1, -0.22, -0.34]:
				node.add_child(_ball(Vector3(0.0, y, 0.027), 0.007, _flat(Style.CREAM)))
		_:
			node.add_child(_slab(PANTS, 0.05, mat))
	return node


## The hanger: two sloping wooden arms, the lower bar trousers fold over, and a brass hook
## whose curl sits round the rail above.
static func make_hanger() -> Node3D:
	var wood := _flat(Style.BROWN)
	var brass := _flat(Style.BRASS, 0.5, 0.35)
	var h := Node3D.new()
	h.name = "Hanger"
	var top := Vector3(0.0, SHOULDER_Y + 0.02, 0.0)
	for side: float in [-1.0, 1.0]:
		var tip := Vector3(0.17 * side, SHOULDER_Y - 0.03, 0.0)
		h.add_child(_rod(top, tip, 0.012, wood))
		h.add_child(_rod(tip, Vector3(0.15 * side, BAR_Y, 0.0), 0.007, wood))
	h.add_child(_rod(Vector3(-0.15, BAR_Y, 0.0), Vector3(0.15, BAR_Y, 0.0), 0.006, wood))
	h.add_child(_rod(top, Vector3(0.0, RAIL_ABOVE - 0.03, 0.0), 0.005, brass))
	var curl := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.022
	ring.outer_radius = 0.03
	ring.rings = 12
	ring.ring_segments = 8
	curl.mesh = ring
	curl.material_override = brass
	curl.position = Vector3(0.0, RAIL_ABOVE, 0.0)
	curl.rotation.x = PI * 0.5  # the ring's axis along the rail, which runs through the front
	h.add_child(curl)
	return h


# --- Building blocks ---------------------------------------------------------


## A flat outline given `depth`, centred on z = 0: front, back and edge walls. Triangles
## are wound so their fronts face out, whatever way round the outline was drawn.
static func _slab(outline: Array, depth: float, mat: Material) -> MeshInstance3D:
	var pts := PackedVector2Array(outline)
	if _area(pts) < 0.0:
		pts.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var tris := Geometry2D.triangulate_polygon(pts)
	for i in range(0, tris.size(), 3):
		var a := pts[tris[i]]
		var b := pts[tris[i + 1]]
		var c := pts[tris[i + 2]]
		for z: float in [hz, -hz]:
			_tri(
				st,
				Vector3(a.x, a.y, z),
				Vector3(b.x, b.y, z),
				Vector3(c.x, c.y, z),
				Vector3(0, 0, signf(z))
			)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var out := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		var af := Vector3(a.x, a.y, hz)
		var bf := Vector3(b.x, b.y, hz)
		var ab := Vector3(a.x, a.y, -hz)
		var bb := Vector3(b.x, b.y, -hz)
		_tri(st, af, bf, bb, out)
		_tri(st, af, bb, ab, out)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


## Add a triangle facing along `normal` (Godot's fronts are clockwise seen from outside).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(v.x, -v.y))
		st.add_vertex(v)


static func _area(pts: PackedVector2Array) -> float:
	var sum := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func _mirror(outline: Array, side: float) -> Array:
	var out: Array = []
	for p: Vector2 in outline:
		out.append(Vector2(p.x * -side, p.y) if side > 0.0 else p)
	return out


## A round rod from `a` to `b`.
static func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var up := (b - a).normalized()
	var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(side).normalized()
	mi.transform = Transform3D(Basis(x, up, x.cross(up)), (a + b) * 0.5)
	return mi


static func _ball(at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	return mi


static func _cloth(cloth: Variant) -> Material:
	if cloth is MaterialType:
		return ClothMaterial.build_triplanar(cloth, CLOTH_SCALE, true)
	if cloth is Material:
		return cloth
	return _flat(Style.LINEN)


static func _flat(col: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metal
	mat.roughness = rough
	return mat
