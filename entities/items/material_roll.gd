class_name MaterialRoll
extends Node3D

## A physical bolt of cloth in the world. Carries a MaterialType (what it is) plus
## its own remaining length (how much is left). Can be picked up, carried, and
## stored on a shelf.
##
## The bolt is built in code (the cylinder in the .tscn is only the editor stand-in):
## cloth wound round a cardboard tube, as fat as the metres left on it, with the
## wound layers showing on its ends (materials/roll_end.gdshader). Cutting cloth off
## makes it thinner.

## Radius of the cardboard tube; an empty bolt shrinks to this.
const CORE_R := 0.035
## Cloth area per metre wound on: r = sqrt(CORE_R^2 + metres * WRAP_K). Chosen so a
## 20 m bolt keeps the old 0.13 m radius (5 m ~ 0.07, 40 m ~ 0.18).
const WRAP_K := (0.13 * 0.13 - CORE_R * CORE_R) / 20.0
const MIN_R := CORE_R + 0.01
const MAX_R := 0.20
## Bolt width (along the axis) and how far the tube stands proud of each end.
const WIDTH := 0.55
const CORE_PROUD := 0.015
const CORE_WALL := 0.004
const CORE_COLOR := Color(0.62, 0.48, 0.34)
## Radius the carry pose (CharacterRig.CARRY_POS) was tuned against: other girths are
## shifted along the hand's up so the bolt rests on the hands either way.
const CARRY_R := 0.13
## Weave density: the barrel's U runs one unit per circumference of a 0.13 m bolt and
## V half a unit along it (the old CylinderMesh layout), so a 20 m bolt looks as it
## did and a fatter one shows more repeats rather than a stretched weave.
const UV_REF_CIRC := TAU * 0.13
const UV_SCALE := 3.0
const SEGMENTS := 40
const END_SHADER := preload("res://materials/roll_end.gdshader")

## Built meshes by radius in whole millimetres (geometry only, so bolts share them).
static var _mesh_cache := {}
static var _core_mat: StandardMaterial3D

@export var material: MaterialType:
	set(value):
		material = value
		if is_node_ready():
			_apply_visual()
## Metres of cloth left on this bolt; -1 means "full" (resolved from material).
@export var remaining_length_m: float = -1.0:
	set(value):
		remaining_length_m = value
		if is_node_ready():
			_rebuild_mesh()

## The hold point we were seated on (see seat_in_hands); null when not carried.
var _seat: Node3D = null

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if remaining_length_m < 0.0 and material != null:
		remaining_length_m = material.roll_length_m
	set_process(false)
	_apply_visual()


func get_interaction_prompt(_actor) -> String:
	if material == null:
		return "Pick up roll"
	return "Pick up %s" % material.display_name


## Cut up to `length` metres off this bolt; returns how much was actually cut
## (capped at what's left). Never goes negative.
func cut(length: float) -> float:
	var amount := minf(maxf(length, 0.0), remaining_length_m)
	remaining_length_m -= amount
	return amount


func is_empty() -> bool:
	return remaining_length_m <= 0.05


## Outer radius of the bolt for the cloth left on it (metres, before any parent scale).
func radius() -> float:
	return radius_for(remaining_length_m if remaining_length_m >= 0.0 else _full_length())


## The radius a bolt with `metres` of cloth wound on has.
static func radius_for(metres: float) -> float:
	return clampf(sqrt(CORE_R * CORE_R + maxf(metres, 0.0) * WRAP_K), MIN_R, MAX_R)


func interact(actor) -> void:
	actor.carry.try_pick_up(self)


## Parent under a hold point / shelf slot and sit at its origin.
func attach_to(point: Node3D) -> void:
	_sit_at(point)
	set_pickable(false)


## Alias used by stations for readability.
func place_on(marker: Node3D) -> void:
	attach_to(marker)


## Called by CarrySlot once the bolt is on the hand: keeps it resting on the hands for
## its girth by lifting it along world up by (radius - CARRY_R), tracked every frame
## because the hand turns as the holding pose eases in.
func seat_in_hands() -> void:
	_seat = get_parent() as Node3D
	set_process(_seat != null)
	_update_seat()


func set_pickable(enabled: bool) -> void:
	if _interactable:
		_interactable.set_enabled(enabled)


func _process(_delta: float) -> void:
	_update_seat()


func _update_seat() -> void:
	if _seat == null or get_parent() != _seat:
		_seat = null
		set_process(false)
		return
	var up_local := (_seat.global_basis.inverse() * Vector3.UP).normalized()
	position = up_local * (radius() - CARRY_R)


func _sit_at(new_parent: Node3D) -> void:
	_seat = null
	set_process(false)
	reparent(new_parent)
	transform = Transform3D.IDENTITY


func _full_length() -> float:
	return material.roll_length_m if material != null else 20.0


func _apply_visual() -> void:
	if _mesh == null:
		return
	_rebuild_mesh()
	_mesh.material_override = null
	_mesh.set_surface_override_material(0, ClothMaterial.build(material, UV_SCALE))
	_mesh.set_surface_override_material(1, _end_material())
	_mesh.set_surface_override_material(2, _core_material())


## Swap in the mesh for the current girth (surface materials stay put) and resize the
## ends' ring gradient to match.
func _rebuild_mesh() -> void:
	if _mesh == null:
		return
	var r := radius()
	var key := roundi(r * 1000.0)
	if not _mesh_cache.has(key):
		_mesh_cache[key] = _build_mesh(key / 1000.0)
	if _mesh.mesh != _mesh_cache[key]:
		_mesh.mesh = _mesh_cache[key]
	var ends := _mesh.get_surface_override_material(1) as ShaderMaterial
	if ends != null:
		ends.set_shader_parameter("outer_r", key / 1000.0)


func _end_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = END_SHADER
	sm.set_shader_parameter("core_r", CORE_R)
	sm.set_shader_parameter("hole_r", CORE_R - CORE_WALL)
	sm.set_shader_parameter("outer_r", roundi(radius() * 1000.0) / 1000.0)
	if material != null:
		sm.set_shader_parameter("cloth_color", material.cloth_color)
		sm.set_shader_parameter("pattern_color", material.pattern_color)
		var patterned := ClothMaterial.pattern_tex_name(material.pattern) != "solid"
		sm.set_shader_parameter("pattern_mix", 0.5 if patterned else 0.0)
	return sm


static func _core_material() -> StandardMaterial3D:
	if _core_mat == null:
		_core_mat = StandardMaterial3D.new()
		_core_mat.vertex_color_use_as_albedo = true
		_core_mat.vertex_color_is_srgb = true
		_core_mat.roughness = 0.95
	return _core_mat


# --- Mesh ---------------------------------------------------------------------------
# Axis along local Y, centred (the Mesh node turns it to lie on its side), like the
# CylinderMesh it replaces. Three surfaces: 0 cloth barrel (no caps), 1 the two wound
# ends (full discs, UV = the disc plane in metres), 2 the cardboard tube (vertex colour).


static func _build_mesh(r: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_barrel(st, r)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_disc(st, r, WIDTH * 0.5, 1.0)
	_add_disc(st, r, -WIDTH * 0.5, -1.0)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_core(st)
	st.commit(mesh)
	return mesh


static func _ring_dir(i: int) -> Vector3:
	var a := TAU * float(i) / float(SEGMENTS)
	return Vector3(sin(a), 0.0, cos(a))


static func _add_barrel(st: SurfaceTool, r: float) -> void:
	var h := WIDTH * 0.5
	var u_span := TAU * r / UV_REF_CIRC
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		var u0 := float(i) / SEGMENTS * u_span
		var u1 := float(i + 1) / SEGMENTS * u_span
		var quad := [
			[d0 * r + Vector3.UP * h, d0, Vector2(u0, 0.0)],
			[d1 * r + Vector3.UP * h, d1, Vector2(u1, 0.0)],
			[d1 * r - Vector3.UP * h, d1, Vector2(u1, 0.5)],
			[d0 * r - Vector3.UP * h, d0, Vector2(u0, 0.5)],
		]
		_add_quad(st, quad, (d0 + d1).normalized())


static func _add_disc(st: SurfaceTool, r: float, y: float, side: float) -> void:
	var n := Vector3.UP * side
	var centre := [Vector3(0.0, y, 0.0), n, Vector2.ZERO]
	for i in SEGMENTS:
		var p0 := _ring_dir(i) * r + Vector3(0.0, y, 0.0)
		var p1 := _ring_dir(i + 1) * r + Vector3(0.0, y, 0.0)
		var a := [p0, n, Vector2(p0.x, p0.z)]
		var b := [p1, n, Vector2(p1.x, p1.z)]
		_add_tri(st, centre, a, b, n)


## The cardboard tube: outside wall, inside wall (dark, facing in) and a rim at each
## end, so from the end it reads as a ring round a hole.
static func _add_core(st: SurfaceTool) -> void:
	var h := WIDTH * 0.5 + CORE_PROUD
	var ro := CORE_R
	var ri := CORE_R - CORE_WALL
	var outer := CORE_COLOR
	var rim := CORE_COLOR.lightened(0.12)
	var inner := CORE_COLOR.darkened(0.6)
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		var mid := (d0 + d1).normalized()
		st.set_color(outer)
		_add_quad(
			st,
			[
				[d0 * ro + Vector3.UP * h, d0, Vector2.ZERO],
				[d1 * ro + Vector3.UP * h, d1, Vector2.ZERO],
				[d1 * ro - Vector3.UP * h, d1, Vector2.ZERO],
				[d0 * ro - Vector3.UP * h, d0, Vector2.ZERO],
			],
			mid,
		)
		st.set_color(inner)
		_add_quad(
			st,
			[
				[d0 * ri + Vector3.UP * h, -d0, Vector2.ZERO],
				[d1 * ri + Vector3.UP * h, -d1, Vector2.ZERO],
				[d1 * ri - Vector3.UP * h, -d1, Vector2.ZERO],
				[d0 * ri - Vector3.UP * h, -d0, Vector2.ZERO],
			],
			-mid,
		)
		st.set_color(rim)
		for side: float in [1.0, -1.0]:
			var n := Vector3.UP * side
			var y := Vector3.UP * h * side
			_add_quad(
				st,
				[
					[d0 * ri + y, n, Vector2.ZERO],
					[d1 * ri + y, n, Vector2.ZERO],
					[d1 * ro + y, n, Vector2.ZERO],
					[d0 * ro + y, n, Vector2.ZERO],
				],
				n,
			)


## Quad of four [position, normal, uv] corners in order round its edge.
static func _add_quad(st: SurfaceTool, c: Array, facing: Vector3) -> void:
	_add_tri(st, c[0], c[1], c[2], facing)
	_add_tri(st, c[0], c[2], c[3], facing)


## One triangle wound so its front faces `facing` (Godot's front faces are clockwise).
static func _add_tri(st: SurfaceTool, a: Array, b: Array, c: Array, facing: Vector3) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var order := [a, b, c]
	if (pb - pa).cross(pc - pa).dot(facing) > 0.0:
		order = [a, c, b]
	for v: Array in order:
		st.set_normal(v[1])
		st.set_uv(v[2])
		st.add_vertex(v[0])
