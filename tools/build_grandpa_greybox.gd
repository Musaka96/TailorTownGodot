extends SceneTree

## Builds the GREYBOX shell of grandpa's shop: floors, walls with collision, a fading
## cut-away (roof + the upper part of every left-right wall) and a boarded-up blocker across
## each doorway that a renovation will open later. Re-run after changing the room sizes:
##
##   godot --headless --path . --script res://tools/build_grandpa_greybox.gd
##
## The Blender-built shop replaces this scene once the layout has settled; until then this
## file is the single place the footprint lives. Coordinates are ShopRoom space (street at
## +Z, the game camera looks toward -Z). See docs/STORY_AND_RENOVATION.md §6.5.

const OUT := "res://scenes/world/grandpa/grandpa_shell_greybox.tscn"

# Footprint (metres). Front room 7 x 5.5, nook 3 x 5.5, workroom 7 x 5, cloth store 3 x 5,
# the neighbouring unit 5 x 10.5.
const X0 := -4.35  # west wall
const XM := 2.65  # front room | nook, workroom | cloth store
const X1 := 5.65  # east wall of grandpa's building (party wall to next door)
const X2 := 10.65  # east wall of the neighbouring unit
const ZB := -3.5  # back wall
const ZM := 1.5  # front rooms | back rooms
const ZF := 7.0  # street front
const T := 0.2  # wall thickness
const H := 2.8  # wall height
const LOW := 1.1  # what stays of a left-right wall when the cut-away fades

const DOOR_STREET := Vector2(-1.55, -0.15)  # x range of the street door
const DOOR_WORKROOM := Vector2(-0.75, 0.6)  # x range, in the ZM wall
const DOOR_NOOK := Vector2(3.3, 4.3)  # z range, in the XM wall
const DOOR_CLOTH := Vector2(-1.5, -0.3)  # z range, in the XM wall
const DOOR_NEXT := Vector2(3.5, 5.5)  # z range, in the X1 wall (knocked through later)

var _root: Node3D
var _body_meshes: Node3D
var _roof: Node3D
var _walls: StaticBody3D
var _blockers: Node3D
var _mats := {}


func _init() -> void:
	_root = Node3D.new()
	_root.name = "GrandpaShell"
	_body_meshes = _group("Body")
	_roof = _group("Roof")
	_blockers = _group("Blockers")
	_walls = StaticBody3D.new()
	_walls.name = "Walls"
	_add(_root, _walls)
	_floors()
	_shell()
	_dressing()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var packed := PackedScene.new()
	packed.pack(_root)
	var err := ResourceSaver.save(packed, OUT)
	print("greybox: ", OUT, " -> ", error_string(err))
	quit()


func _floors() -> void:
	_floor("Floor_front", X0, XM, ZM, ZF, "floor_open")
	_floor("Floor_nook", XM, X1, ZM, ZF, "floor_locked")
	_floor("Floor_workroom", X0, XM, ZB, ZM, "floor_locked")
	_floor("Floor_cloth", XM, X1, ZB, ZM, "floor_locked")
	_floor("Floor_nextdoor", X1, X2, ZB, ZF, "floor_other")
	_slab(
		"RoofSlab",
		_roof,
		Vector3((X0 + X2) / 2, H + 0.1, (ZB + ZF) / 2),
		Vector3(X2 - X0 + 0.4, 0.2, ZF - ZB + 0.4),
		"roof"
	)


func _shell() -> void:
	# The outer side walls lean away from the (perspective) camera and hide nothing; the
	# inner ones lean across the side rooms, so they are cut away like the left-right walls.
	_wall_z("West", X0, ZB, ZF, [], false)
	_wall_z("Mid", XM, ZB, ZF, [DOOR_CLOTH, DOOR_NOOK], true)
	_wall_z("Party", X1, ZB, ZF, [DOOR_NEXT], true)
	_wall_z("East", X2, ZB, ZF, [], false)
	# Left-right walls: low part stays, the rest fades with the roof. The back wall is
	# behind everything, so it may stay whole.
	_wall_x("Back", ZB, X0, X2, [], false)
	_wall_x("Divide", ZM, X0, X1, [DOOR_WORKROOM], true)
	_wall_x("Front", ZF, X0, X2, [DOOR_STREET], true)
	_blocker("workroom", Vector3(_mid(DOOR_WORKROOM), 0, ZM), Vector3(_len(DOOR_WORKROOM), H, T))
	_blocker("nook", Vector3(XM, 0, _mid(DOOR_NOOK)), Vector3(T, H, _len(DOOR_NOOK)))
	_blocker("cloth", Vector3(XM, 0, _mid(DOOR_CLOTH)), Vector3(T, H, _len(DOOR_CLOTH)))
	_blocker("nextdoor", Vector3(X1, 0, _mid(DOOR_NEXT)), Vector3(T, H, _len(DOOR_NEXT)))


## What a renovation clears or puts up, found by name by RenovationDirector:
##   Spots/<cleanup project>/Spot<i>  one mess pile per spot to clear by hand
##   Wip_<room>                       the builders' clutter while work is under way
##   Label_<room>                     the greybox "(locked)" floor label
func _dressing() -> void:
	var spots := {
		"front_sweep": [Vector3(-2.6, 0, 3.6), Vector3(0.3, 0, 3.9), Vector3(-0.2, 0, 6.3)],
		"workroom_clear":
		[
			Vector3(-2.8, 0, -1.4),
			Vector3(-0.6, 0, -2.4),
			Vector3(1.2, 0, -0.6),
			Vector3(-2.2, 0, 0.5),
		],
		"cloth_clear": [Vector3(4.0, 0, -2.4), Vector3(4.9, 0, -0.6), Vector3(3.8, 0, 0.6)],
		"nook_clear": [Vector3(4.0, 0, 2.5), Vector3(4.9, 0, 4.4), Vector3(3.9, 0, 6.0)],
		"next_clear":
		[
			Vector3(7.2, 0, -2.2),
			Vector3(9.4, 0, -0.4),
			Vector3(7.6, 0, 2.6),
			Vector3(9.2, 0, 5.6),
		],
	}
	var holder := _group("Spots")
	for project: String in spots:
		var group := Node3D.new()
		group.name = project
		_add(holder, group)
		var i := 0
		for at: Vector3 in spots[project]:
			var spot := Node3D.new()
			spot.name = "Spot%d" % i
			spot.position = at
			_add(group, spot)
			var s := 0.45 + 0.15 * float(i % 3)
			var low := project == "front_sweep"  # dust and leaves, not rubble
			var size := Vector3(s * 1.7, 0.08 if low else s * 0.65, s * 1.2)
			_slab("Pile", spot, Vector3(0, size.y / 2, 0), size, "dust" if low else "rubble")
			i += 1
	var rooms := {
		"workroom": Vector3(-0.8, 0, -1.0),
		"cloth": Vector3(4.15, 0, -1.0),
		"nook": Vector3(4.15, 0, 4.2),
		"nextdoor": Vector3(8.15, 0, 1.7),
	}
	for room: String in rooms:
		var wip := Node3D.new()
		wip.name = "Wip_" + room
		wip.position = rooms[room]
		_add(_root, wip)
		_slab("Trestle", wip, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.5), "boards")
		_slab("Tarp", wip, Vector3(0.9, 0.04, 0.9), Vector3(1.6, 0.06, 1.4), "tarp")
		_slab("Pots", wip, Vector3(-0.9, 0.18, 0.7), Vector3(0.5, 0.36, 0.5), "roof")
	_label("workroom", "Workroom\n(locked)", Vector3((X0 + XM) / 2, 0.06, (ZB + ZM) / 2))
	_label("cloth", "Cloth store\n(locked)", Vector3((XM + X1) / 2, 0.06, (ZB + ZM) / 2))
	_label("nook", "Nook\n(locked)", Vector3((XM + X1) / 2, 0.06, (ZM + ZF) / 2))
	_label("nextdoor", "Next door\n(not yours)", Vector3((X1 + X2) / 2, 0.06, (ZB + ZF) / 2))


# --- pieces ------------------------------------------------------------------


func _floor(nm: String, xa: float, xb: float, za: float, zb: float, mat: String) -> void:
	_slab(
		nm,
		_body_meshes,
		Vector3((xa + xb) / 2, -0.03, (za + zb) / 2),
		Vector3(xb - xa, 0.1, zb - za),
		mat
	)


## A wall along Z at x, split around `gaps` (z ranges), with collision. With `cut`, only
## the low part stays when the player is inside; the rest joins the fading roof group.
func _wall_z(nm: String, x: float, za: float, zb: float, gaps: Array, cut: bool) -> void:
	var i := 0
	for seg: Vector2 in _segments(za, zb, gaps):
		var length := seg.y - seg.x
		var cz := (seg.x + seg.y) / 2
		_collide("%s%d" % [nm, i], Vector3(x, H / 2, cz), Vector3(T, H, length))
		if cut:
			_slab(
				"%s%d" % [nm, i],
				_body_meshes,
				Vector3(x, LOW / 2, cz),
				Vector3(T, LOW, length),
				"wall"
			)
			_slab(
				"%sTop%d" % [nm, i],
				_roof,
				Vector3(x, (H + LOW) / 2, cz),
				Vector3(T, H - LOW, length),
				"wall"
			)
		else:
			_slab(
				"%s%d" % [nm, i], _body_meshes, Vector3(x, H / 2, cz), Vector3(T, H, length), "wall"
			)
		i += 1


## A wall along X at z, split around `gaps` (x ranges). With `cut`, only the low part
## stays when the player is inside; the rest joins the fading roof group.
func _wall_x(nm: String, z: float, xa: float, xb: float, gaps: Array, cut: bool) -> void:
	var i := 0
	for seg: Vector2 in _segments(xa, xb, gaps):
		var length := seg.y - seg.x
		var cx := (seg.x + seg.y) / 2
		_collide("%s%d" % [nm, i], Vector3(cx, H / 2, z), Vector3(length, H, T))
		if cut:
			_slab(
				"%s%d" % [nm, i],
				_body_meshes,
				Vector3(cx, LOW / 2, z),
				Vector3(length, LOW, T),
				"wall"
			)
			_slab(
				"%sTop%d" % [nm, i],
				_roof,
				Vector3(cx, (H + LOW) / 2, z),
				Vector3(length, H - LOW, T),
				"wall"
			)
		else:
			_slab(
				"%s%d" % [nm, i], _body_meshes, Vector3(cx, H / 2, z), Vector3(length, H, T), "wall"
			)
		i += 1
	if cut:
		for gap: Vector2 in gaps:  # a lintel over each doorway, fading with the rest
			_slab(
				"%sLintel%d" % [nm, i],
				_roof,
				Vector3(_mid(gap), (H + 2.1) / 2, z),
				Vector3(_len(gap), H - 2.1, T),
				"wall"
			)
			i += 1


## Boards across a doorway: its own body, so a renovation can simply free it.
func _blocker(id: String, foot: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Blocker_" + id
	_add(_blockers, body)
	body.position = foot + Vector3(0, LOW / 2, 0)
	var low := Vector3(size.x, LOW, size.z)
	var mesh := MeshInstance3D.new()
	mesh.name = "Boards"
	var box := BoxMesh.new()
	box.size = low + Vector3(0.06, 0, 0.06)
	box.material = _mat("boards")
	mesh.mesh = box
	_add(body, mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Col"
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, H, size.z)
	shape.shape = bs
	shape.position = Vector3(0, (H - LOW) / 2, 0)
	_add(body, shape)


func _segments(a: float, b: float, gaps: Array) -> Array:
	var out: Array = []
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var at := a
	for gap: Vector2 in cuts:
		if gap.x > at:
			out.append(Vector2(at, gap.x))
		at = gap.y
	if b > at:
		out.append(Vector2(at, b))
	return out


func _slab(nm: String, parent: Node, at: Vector3, size: Vector3, mat: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = nm
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(mat)
	mesh.mesh = box
	mesh.position = at
	_add(parent, mesh)


func _collide(nm: String, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Col_" + nm
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = at
	_add(_walls, shape)


func _label(room: String, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Label_" + room
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = Color(1, 1, 1, 0.75)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = at
	_add(_root, label)


func _mat(id: String) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var colors := {
		"wall": Color(0.80, 0.78, 0.74),
		"floor_open": Color(0.62, 0.50, 0.38),
		"floor_locked": Color(0.36, 0.35, 0.34),
		"floor_other": Color(0.27, 0.27, 0.29),
		"roof": Color(0.45, 0.33, 0.30),
		"boards": Color(0.47, 0.33, 0.20),
		"rubble": Color(0.50, 0.47, 0.44),
		"dust": Color(0.55, 0.50, 0.42),
		"tarp": Color(0.30, 0.42, 0.55),
	}
	var m := StandardMaterial3D.new()
	m.resource_name = "greybox_" + id
	m.albedo_color = colors[id]
	m.roughness = 0.95
	_mats[id] = m
	return m


func _group(nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	_add(_root, n)
	return n


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _root


func _mid(r: Vector2) -> float:
	return (r.x + r.y) / 2


func _len(r: Vector2) -> float:
	return r.y - r.x
