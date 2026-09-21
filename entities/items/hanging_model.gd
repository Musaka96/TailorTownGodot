class_name HangingModel
extends RefCounted

## Garments as they hang on a clothing rack: a wooden hanger with a brass hook, and cloth
## cut to each garment's silhouette — a jacket with its sleeves, lapels and buttons, a
## shirt with its collar, trousers folded over the hanger's bar — in the order's own cloth
## (projected, so the weave and pattern sit true on any shape). Each outline is rounded
## off and puffed up like a little cushion: full in the middle, rolling to a soft edge,
## smooth-shaded. Simple and cute on purpose; everything is built in code.
##
## The origin is the hook: hung on a rack hook marker, the brass curl sits round a rail
## RAIL_ABOVE over it (ClothingRack's rail, RackSway's pivot). The rail runs through the
## garment front to back (local z), so on a rack they hang side-on, face to face. The
## hanger stays inside the cloth: its arms end within the shoulders, and its trouser bar
## is only there when trousers are, at their layer.
##   HangingModel.make({Enums.GarmentType.JACKET: material, ...})

const RAIL_ABOVE := 0.25
## Everything below the hanger's crown — the arms, the bar and the cloth — is drawn at this
## size, grown down from the crown so the crown and the brass curl stay on the rail. The
## outlines below are in the unscaled units.
const SIZE := 1.6
const TOP_Y := 0.155  # the hanger's crown, just above a neckline
const ARM_TIP := Vector2(0.12, 0.11)  # where each arm ends, inside the shoulder
const BAR_Y := 0.0  # the hanger's lower bar, which trousers fold over
const BAR_HALF := 0.1
const CLOTH_SCALE := 3.0  # fabric repeats per metre
## How the parts layer on one hanger, front to back (z, true size), when several share it.
const LAYER := {
	Enums.GarmentType.JACKET: 0.0,
	Enums.GarmentType.SHIRT: -0.04 * SIZE,
	Enums.GarmentType.PANTS: -0.08 * SIZE,
}
## The cushion: half-thickness in the middle, what's left at the rim, and how far in from
## the rim the roll reaches (m); SMOOTH passes of corner rounding on each outline.
const PUFF := {
	Enums.GarmentType.JACKET: 0.022,
	Enums.GarmentType.SHIRT: 0.017,
	Enums.GarmentType.PANTS: 0.018,
}
const RIM_SHARE := 0.25
const ROLL := 0.016
const SMOOTH := 2

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
const LAPEL_L := [Vector2(-0.045, 0.135), Vector2(-0.004, -0.09), Vector2(-0.07, 0.0)]
const COLLAR_L := [Vector2(-0.05, 0.148), Vector2(-0.004, 0.1), Vector2(-0.06, 0.065)]


## A hanger carrying `parts` (GarmentType -> MaterialType, or a plain Material). Several
## parts layer front to back; one alone hangs square on its hanger. `hanger` false leaves
## the hanger out (a GarmentSet draws its own).
static func make(parts: Dictionary, hanger := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Hanging"
	var layered := parts.size() > 1
	if hanger:
		var bar := NAN
		if parts.has(Enums.GarmentType.PANTS):
			bar = LAYER[Enums.GarmentType.PANTS] if layered else 0.0
		root.add_child(make_hanger(bar))
	for t: int in [Enums.GarmentType.PANTS, Enums.GarmentType.SHIRT, Enums.GarmentType.JACKET]:
		if parts.has(t):
			var g := garment(t, parts[t])
			g.position.z = LAYER[t] if layered else 0.0
			root.add_child(g)
	return root


## One garment's cloth (no hanger), at z = 0, at SIZE.
static func garment(garment_type: int, cloth: Variant) -> Node3D:
	var mat := _cloth(cloth)
	var puff: float = PUFF.get(garment_type, 0.018)
	var node := _grown()
	match garment_type:
		Enums.GarmentType.JACKET:
			node.add_child(_cushion(JACKET, puff, mat))
			for side: float in [-1.0, 1.0]:
				var lapel := _cushion(_mirror(LAPEL_L, side), 0.005, mat, 0.006)
				lapel.position.z = puff * 0.8
				node.add_child(lapel)
			for y: float in [-0.19, -0.28]:
				node.add_child(_ball(Vector3(0.022, y, puff + 0.002), 0.01, _flat(Style.WALNUT)))
		Enums.GarmentType.SHIRT:
			node.add_child(_cushion(SHIRT, puff, mat))
			for side: float in [-1.0, 1.0]:
				var collar := _cushion(_mirror(COLLAR_L, side), 0.005, mat, 0.006)
				collar.position.z = puff * 0.8
				node.add_child(collar)
			for y: float in [0.02, -0.1, -0.22, -0.34]:
				node.add_child(_ball(Vector3(0.0, y, puff + 0.001), 0.006, _flat(Style.CREAM)))
		_:
			node.add_child(_cushion(PANTS, puff, mat))
	return node


## The hanger: two sloping wooden arms that end inside the shoulders, a brass stem and a
## curl that sits round the rail. With `bar_z` (not NAN) it also has the lower bar that
## trousers fold over, at that layer, joined to the arms.
static func make_hanger(bar_z: float = NAN) -> Node3D:
	var wood := _flat(Style.BROWN)
	var brass := _flat(Style.BRASS, 0.5, 0.35)
	var h := Node3D.new()
	h.name = "Hanger"
	var body := _grown()  # the wooden part grows with the cloth; the brass stays at the rail
	h.add_child(body)
	bar_z /= SIZE
	var top := Vector3(0.0, TOP_Y, 0.0)
	for side: float in [-1.0, 1.0]:
		var tip := Vector3(ARM_TIP.x * side, ARM_TIP.y, 0.0)
		body.add_child(_rod(top, tip, 0.01, wood))
		# The side struts only when the bar shares the arms' plane (trousers alone): behind a
		# shirt they would cross it, and the bar sits hidden in the trousers' fold anyway.
		if not is_nan(bar_z) and is_zero_approx(bar_z):
			body.add_child(_rod(tip, Vector3(BAR_HALF * side, BAR_Y, bar_z), 0.006, wood))
	if not is_nan(bar_z):
		var a := Vector3(-BAR_HALF, BAR_Y, bar_z)
		body.add_child(_rod(a, Vector3(BAR_HALF, BAR_Y, bar_z), 0.006, wood))
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


## A node that draws its children at SIZE, grown down from the hanger's crown (which stays
## where it is, just under the hook).
static func _grown() -> Node3D:
	var node := Node3D.new()
	node.scale = Vector3.ONE * SIZE
	node.position.y = TOP_Y * (1.0 - SIZE)
	return node


## The outline, rounded off and puffed: the middle (the outline pulled in by `roll`) is
## `puff` thick either side, rolling down to a rim `puff * RIM_SHARE` thick at the edge.
## Shared vertices and generated normals make it read as soft cloth, not a cut board.
static func _cushion(outline: Array, puff: float, mat: Material, roll := ROLL) -> MeshInstance3D:
	var outer := _rounded(PackedVector2Array(outline))
	if _area(outer) < 0.0:
		outer.reverse()
	var inner := _inset(outer, roll)
	var tris := Geometry2D.triangulate_polygon(inner)
	if tris.is_empty():  # too slim to roll: a plain rounded slab
		inner = outer
		tris = Geometry2D.triangulate_polygon(outer)
	var rim := puff * RIM_SHARE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outer.size()
	for face: float in [1.0, -1.0]:
		var zc := puff * face
		var zr := rim * face
		for i in range(0, tris.size(), 3):
			_tri(
				st,
				_v(inner[tris[i]], zc),
				_v(inner[tris[i + 1]], zc),
				_v(inner[tris[i + 2]], zc),
				face
			)
		for i in n:
			var j := (i + 1) % n
			var o1 := _v(outer[i], zr)
			var o2 := _v(outer[j], zr)
			var i1 := _v(inner[i], zc)
			var i2 := _v(inner[j], zc)
			_quad(st, o1, o2, i2, i1, _out(outer[i], outer[j]), face)
	for i in n:
		var j := (i + 1) % n
		var out := _out(outer[i], outer[j])
		_quad(
			st,
			_v(outer[i], rim),
			_v(outer[j], rim),
			_v(outer[j], -rim),
			_v(outer[i], -rim),
			out,
			0.0
		)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


## The outward normal of edge a→b of a counter-clockwise outline.
static func _out(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(b.y - a.y, a.x - b.x).normalized()


## A quad a-b-c-d facing roughly `out` sideways and `face` towards ±z.
static func _quad(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector2, face: float
) -> void:
	var toward := Vector3(out.x, out.y, face).normalized()
	_tri_toward(st, a, b, c, toward)
	_tri_toward(st, a, c, d, toward)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, face: float) -> void:
	_tri_toward(st, a, b, c, Vector3(0.0, 0.0, face))


## Add a triangle whose front faces along `toward` (Godot's fronts are clockwise seen from
## outside). No normals are set: they're generated smooth once the mesh is indexed.
static func _tri_toward(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, toward: Vector3
) -> void:
	if (b - a).cross(c - a).dot(toward) > 0.0:
		var swap := b
		b = c
		c = swap
	for v: Vector3 in [a, b, c]:
		st.set_uv(Vector2(v.x, -v.y))
		st.add_vertex(v)


## Round every corner (Chaikin's corner cutting), SMOOTH times.
static func _rounded(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts
	for _pass in SMOOTH:
		var next := PackedVector2Array()
		for i in out.size():
			var a := out[i]
			var b := out[(i + 1) % out.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		out = next
	return out


## The outline pulled in by `d` along each corner's bisector (one point for each point, so
## the roll between the two can be stitched). Sharp inside corners are held back so the
## pulled-in outline never folds over itself.
static func _inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var prev := pts[(i - 1 + n) % n]
		var cur := pts[i]
		var next := pts[(i + 1) % n]
		var n1 := -_out(prev, cur)
		var n2 := -_out(cur, next)
		var bis := (n1 + n2).normalized()
		if bis == Vector2.ZERO:
			bis = n1
		var miter := d / maxf(bis.dot(n1), 0.5)
		out.append(cur + bis * miter)
	return out


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
		# Projected in the grown node's space: scale up so the weave keeps its real size.
		return ClothMaterial.build_triplanar(cloth, CLOTH_SCALE * SIZE, true)
	if cloth is Material:
		return cloth
	return _flat(Style.LINEN)


static func _flat(col: Color, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metal
	mat.roughness = rough
	return mat
