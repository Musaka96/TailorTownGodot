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
## false = the Blender-built shop (IMPORT/town_kit/build_v8_grandpa.py) is what the player sees:
## this shell then only carries what is tested and works - collision, the boards across the
## doorways, the mess to clear, the builders' clutter - with its own walls, roof and floor
## labels left out and its floors unseen (they still give the director the building's outline).
const SHOW_SHELL := false

# Footprint (metres), on the town kit's 2 m grid so the Blender-built shop can use the kit's
# wall pieces (docs 6.11): kit x + 0.65 = x here, 8.34 - kit y = z here. Front room 8 x 6,
# nook 4 x 6, workroom 8 x 4, cloth store 4 x 4, the neighbouring unit 6 x 10.
const X0 := -4.35  # west wall (kit x -5)
const XM := 3.65  # front room | nook, workroom | cloth store (kit x 3)
const X1 := 7.65  # east wall of grandpa's building, the party wall to next door (kit x 7)
const X2 := 13.65  # east wall of the neighbouring unit (kit x 13)
const ZB := -1.66  # back wall (kit y 10)
const ZM := 2.34  # front rooms | back rooms (kit y 6)
const ZF := 8.34  # street front (kit y 0): where Mr. Hemming's door stands in his shop
const T := 0.2  # wall thickness
const H := 3.0  # wall height (the kit's)
const LOW := 1.1  # what stays of a cut-away wall when the rest fades with the roof

# Doorways: a 1.4 m gap in the middle of a 2 m wall module.
const DOOR_STREET := Vector2(-0.05, 1.35)  # x range, kit module -1..1 (the town's path ends here)
const DOOR_WORKROOM := Vector2(-2.05, -0.65)  # x range, in the ZM wall
const DOOR_NOOK := Vector2(4.64, 6.04)  # z range, in the XM wall
const DOOR_CLOTH := Vector2(0.64, 2.04)  # z range, in the XM wall (workroom -> cloth store)
const DOOR_NEXT := Vector2(4.64, 6.04)  # z range, in the X1 wall; lines up with the nook door

var _root: Node3D
var _body_meshes: Node3D
var _roof: Node3D
var _walls: StaticBody3D
var _blockers: Node3D
var _mats := {}
var _chunks := 0  # so every chunk gets a name of its own


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
		"front_sweep": [Vector3(-2.2, 0, 4.2), Vector3(2.4, 0, 4.4), Vector3(-1.0, 0, 7.2)],
		"workroom_clear":
		[
			Vector3(-3.2, 0, 0.6),
			Vector3(-0.4, 0, -0.6),
			Vector3(1.8, 0, 0.9),
			Vector3(2.8, 0, -0.9),
		],
		"cloth_clear": [Vector3(5.0, 0, -0.6), Vector3(6.6, 0, 0.9), Vector3(4.6, 0, 1.2)],
		"nook_clear": [Vector3(5.0, 0, 3.6), Vector3(6.6, 0, 5.3), Vector3(5.2, 0, 7.2)],
		"next_clear":
		[
			Vector3(9.0, 0, -0.4),
			Vector3(12.2, 0, 1.2),
			Vector3(9.6, 0, 4.2),
			Vector3(12.0, 0, 6.6),
		],
		# Outside (IMPORT/town_kit/build_v8_town.py lays the lot): rubbish on the brick
		# forecourt, clear of the door's path, and weeds in the front of the side garden.
		"yard_rubbish": [Vector3(-2.9, 0, 9.45), Vector3(4.9, 0, 9.6), Vector3(6.9, 0, 9.3)],
		"yard_weeds":
		[
			Vector3(-8.3, 0, 8.4),
			Vector3(-5.6, 0, 8.3),
			Vector3(-7.8, 0, 6.9),
			Vector3(-5.9, 0, 6.5),
		],
	}
	var holder := _group("Spots")
	_boarded_windows(holder)
	_facade_weeds()
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
			var dice := RandomNumberGenerator.new()
			dice.seed = hash("%s/%d" % [project, i])  # the same heap every build
			if project == "front_sweep":
				_dust_heap(spot, dice)
			elif project == "yard_rubbish":
				_litter(spot, dice)
			elif project == "yard_weeds":
				for k in 3:
					var root := Vector3(dice.randf_range(-0.4, 0.4), 0, dice.randf_range(-0.35, 0.35))
					_weed_clump(spot, "Clump%d" % k, root, dice, 1.4)
			else:
				_rubble_heap(spot, dice)
			i += 1
	var rooms := {
		"workroom": Vector3(-0.4, 0, 0.6),
		"cloth": Vector3(5.65, 0, 0.2),
		"nook": Vector3(5.65, 0, 5.3),
		"nextdoor": Vector3(10.65, 0, 3.3),
	}
	for room: String in rooms:
		var wip := Node3D.new()
		wip.name = "Wip_" + room
		wip.position = rooms[room]
		_add(_root, wip)
		_builders_kit(wip)
	_label("workroom", "Workroom\n(locked)", Vector3((X0 + XM) / 2, 0.06, (ZB + ZM) / 2))
	_label("cloth", "Cloth store\n(locked)", Vector3((XM + X1) / 2, 0.06, (ZB + ZM) / 2))
	_label("nook", "Nook\n(locked)", Vector3((XM + X1) / 2, 0.06, (ZM + ZF) / 2))
	_label("nextdoor", "Next door\n(not yours)", Vector3((X1 + X2) / 2, 0.06, (ZB + ZF) / 2))


## The three shop windows on the street, boarded over. Their own spots, so the player pulls
## them off one window at a time; they hang on the outside face of the front wall, so a
## FacadeFader in the room scene fades them with the wall above it.
func _boarded_windows(holder: Node3D) -> void:
	var group := Node3D.new()
	group.name = "front_boards"
	_add(holder, group)
	var i := 0
	for x: float in [X0 + 1.0, X0 + 3.0, X0 + 7.0]:  # the shop-window modules, not the door
		var spot := Node3D.new()
		spot.name = "Spot%d" % i
		spot.position = Vector3(x, 1.25, ZF + T / 2 + 0.07)  # over the glass, under the sign
		_add(group, spot)
		_board_up(spot, i)
		i += 1


## One window boarded over. Whoever did it was in a hurry: thick planks at whatever angle
## came to hand, and a longer one across them. No two windows are boarded alike, so three
## of them in a row never read as a railing.
func _board_up(spot: Node3D, which: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("boards/%d" % which)
	var lays := [
		[Vector3(0, -0.42, 0), 4.0],
		[Vector3(0, 0.02, 0), -6.0],
		[Vector3(0, 0.46, 0), 3.0],
	]
	for row in lays.size():
		var at: Vector3 = lays[row][0] + Vector3(dice.randf_range(-0.05, 0.05), 0, 0)
		var lean: float = float(lays[row][1]) + dice.randf_range(-5.0, 5.0)
		var plank := _chunk(
			spot,
			at + Vector3(0, 0, 0.03 * row),
			Vector3(dice.randf_range(1.9, 2.1), dice.randf_range(0.2, 0.28), 0.06),
			Vector3(0, 0, lean),
			"plank_a" if row % 2 == 0 else "plank_b"
		)
		plank.name = "Plank%d" % row
	# one longer plank across the lot, nailed corner to corner
	var brace := _chunk(
		spot,
		Vector3(0, 0, 0.12),
		Vector3(2.5, 0.22, 0.06),
		Vector3(0, 0, dice.randf_range(28.0, 42.0) * (1.0 if which % 2 == 0 else -1.0)),
		"plank_b"
	)
	brace.name = "Brace"


## Weeds that have come up along the front while the shop stood shut.
func _facade_weeds() -> void:
	var group := _group("Facade")
	var dice := RandomNumberGenerator.new()
	dice.seed = 8801
	for clump in 22:
		var at := Vector3(X0 + dice.randf_range(0.2, 11.6), 0.0, ZF + 0.35)
		at.z += dice.randf_range(-0.12, 0.12)
		_weed_clump(group, "Weed%d" % clump, at, dice, 1.0)


## A clump of weed blades at `at` under `parent`; `scale` > 1 for the rank garden kind.
func _weed_clump(
	parent: Node3D, nm: String, at: Vector3, dice: RandomNumberGenerator, scale: float
) -> void:
	var holder := Node3D.new()
	holder.name = nm
	holder.position = at
	_add(parent, holder)
	for blade in dice.randi_range(5, 9):
		var high := dice.randf_range(0.3, 0.72) * scale
		var reach := 0.12 * scale
		var leaf := _chunk(
			holder,
			Vector3(dice.randf_range(-reach, reach), high / 2.0, dice.randf_range(-0.06, 0.06)),
			Vector3(0.05, high, 0.05),
			Vector3(dice.randf_range(-22, 22), dice.randf_range(0, 180), dice.randf_range(-22, 22)),
			"weed_a" if blade % 2 == 0 else "weed_b"
		)
		leaf.name = "Blade%d" % blade


## What blows up against a shut shop: a broken crate, loose boards, old newspapers.
func _litter(parent: Node3D, dice: RandomNumberGenerator) -> void:
	var crate := _chunk(
		parent,
		Vector3(dice.randf_range(-0.2, 0.2), 0.2, 0),
		Vector3(0.5, 0.4, 0.4),
		Vector3(dice.randf_range(-8, 8), dice.randf_range(0, 360), dice.randf_range(-14, 14)),
		"plank_a"
	)
	crate.name = "Crate"
	for i in dice.randi_range(1, 2):
		var lie := Vector3(dice.randf_range(-0.4, 0.4), 0.03, dice.randf_range(-0.3, 0.3))
		var spin := Vector3(dice.randf_range(0, 6), dice.randf_range(0, 360), 0)
		_chunk(parent, lie, Vector3(dice.randf_range(0.8, 1.1), 0.04, 0.14), spin, "plank_b")
	for i in dice.randi_range(3, 5):
		var at := Vector3(dice.randf_range(-0.55, 0.55), 0.012, dice.randf_range(-0.45, 0.45))
		var spin := Vector3(dice.randf_range(-4, 4), dice.randf_range(0, 360), 0)
		_chunk(parent, at, Vector3(0.34, 0.012, 0.26), spin, "paper")
	for i in dice.randi_range(2, 4):
		var at := Vector3(dice.randf_range(-0.5, 0.5), 0.045, dice.randf_range(-0.4, 0.4))
		var spin := Vector3(dice.randf_range(-12, 12), dice.randf_range(0, 360), 0)
		_chunk(parent, at, Vector3(0.13, 0.012, 0.08), spin, "leaf_a" if i % 2 == 0 else "leaf_b")


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
	body.position = foot
	var looks := Node3D.new()
	looks.name = "Boards"
	_add(body, looks)
	var along_x := size.x > size.z
	var width := maxf(size.x, size.z)
	if id == "nextdoor":
		_brick_infill(looks, width, along_x)
	else:
		_nailed_planks(looks, width, along_x, hash(id))
	var shape := CollisionShape3D.new()
	shape.name = "Col"
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, H, size.z)
	shape.shape = bs
	shape.position = Vector3(0, H / 2, 0)
	_add(body, shape)


## Planks nailed across a doorway, every one below the cut so none hangs in the air when the
## wall above it fades: two across, one on the slant.
func _nailed_planks(parent: Node3D, width: float, along_x: bool, salt: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = salt
	# both doorways in the north-south wall are reached from the west: the planks face that way
	var turn := 0.0 if along_x else -90.0
	var rows := [[0.32, 0.0], [0.78, 0.0], [0.56, 24.0]]
	for i in rows.size():
		var y: float = rows[i][0] + dice.randf_range(-0.03, 0.03)
		var lean: float = rows[i][1] + dice.randf_range(-4.0, 4.0)
		var length := width + (0.5 if lean > 1.0 else 0.28)
		var plank := _chunk(
			parent,
			Vector3(0, y, 0),
			Vector3(length, 0.17, 0.05),
			Vector3(0, turn, lean),
			"plank_a" if i % 2 == 0 else "plank_b"
		)
		plank.position += plank.basis.z * (0.16 + 0.055 * i)  # proud of the wall, one on another


## The party wall before it is knocked through: a low run of brick across the arch.
func _brick_infill(parent: Node3D, width: float, along_x: bool) -> void:
	var turn := 0.0 if along_x else 90.0
	var courses := 5
	var per := 4
	var bw := width / per
	for row in courses:
		for col in per + (row % 2):
			var x := -width / 2 + bw * (col + 0.5) - (bw / 2 if row % 2 == 1 else 0.0)
			x = clampf(x, -width / 2 + bw * 0.25, width / 2 - bw * 0.25)
			var brick := _chunk(
				parent,
				Vector3.ZERO,
				Vector3(bw - 0.03, LOW / courses - 0.03, 0.3),
				Vector3(0, turn, 0),
				"brick" if (row + col) % 3 != 0 else "brick_b"
			)
			brick.position = brick.basis.x * x + Vector3(0, LOW / courses * (row + 0.5), 0)


## A heap of what came down: brick, plaster and slate, and a broken plank or two.
func _rubble_heap(parent: Node3D, dice: RandomNumberGenerator) -> void:
	var kinds := ["brick", "plaster", "slate", "brick_b", "plaster"]
	var count := dice.randi_range(8, 11)
	for i in count:
		var far := dice.randf_range(0.0, 0.55) * (0.4 if i < 3 else 1.0)  # the heart of the heap
		var angle := dice.randf_range(0.0, TAU)
		var edge := dice.randf_range(0.14, 0.34) * (1.25 if i < 3 else 1.0)
		var size := Vector3(edge * dice.randf_range(1.0, 1.7), edge * 0.62, edge)
		var high := size.y / 2 + (0.16 if i < 3 else 0.0) * dice.randf_range(0.4, 1.0)
		var at := Vector3(cos(angle) * far, high, sin(angle) * far)
		var spin := Vector3(
			dice.randf_range(-24, 24), dice.randf_range(0, 360), dice.randf_range(-24, 24)
		)
		_chunk(parent, at, size, spin, kinds[i % kinds.size()])
	for i in dice.randi_range(1, 2):
		var lie := Vector3(dice.randf_range(-0.3, 0.3), 0.2, dice.randf_range(-0.3, 0.3))
		var spin := Vector3(
			dice.randf_range(8, 22), dice.randf_range(0, 360), dice.randf_range(-6, 6)
		)
		_chunk(parent, lie, Vector3(dice.randf_range(0.8, 1.2), 0.045, 0.15), spin, "plank_b")


## What a broom leaves: a couple of low mounds of dust and a few dead leaves.
func _dust_heap(parent: Node3D, dice: RandomNumberGenerator) -> void:
	for i in 3:
		var mound := MeshInstance3D.new()
		mound.name = "Mound%d" % i
		var ball := SphereMesh.new()
		ball.radius = dice.randf_range(0.2, 0.34)
		ball.height = ball.radius * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		ball.material = _mat("dust")
		mound.mesh = ball
		mound.scale = Vector3(1.0, 0.2, 1.0)
		mound.position = Vector3(dice.randf_range(-0.28, 0.28), 0.0, dice.randf_range(-0.22, 0.22))
		_add(parent, mound)
	for i in dice.randi_range(3, 5):
		var at := Vector3(dice.randf_range(-0.5, 0.5), 0.045, dice.randf_range(-0.4, 0.4))
		var spin := Vector3(dice.randf_range(-12, 12), dice.randf_range(0, 360), 0)
		_chunk(parent, at, Vector3(0.13, 0.012, 0.08), spin, "leaf_a" if i % 2 == 0 else "leaf_b")


## The builders are in: a trestle, a ladder against it, a tarp on the floor, pots of paint.
func _builders_kit(parent: Node3D) -> void:
	_chunk(parent, Vector3(0, 0.78, 0), Vector3(1.7, 0.06, 0.5), Vector3.ZERO, "plank_a")
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.18, 0.18]:
			var lean := Vector3(12.0 if sz > 0 else -12.0, 0, 0)
			_chunk(parent, Vector3(sx, 0.39, sz), Vector3(0.06, 0.8, 0.06), lean, "plank_b")
	for side: float in [-0.19, 0.19]:
		_chunk(
			parent,
			Vector3(1.25 + side, 0.85, 0.35),
			Vector3(0.05, 1.75, 0.05),
			Vector3(-16, 0, 0),
			"plank_b"
		)
	for rung in 5:
		var up := 0.3 + 0.3 * rung
		_chunk(
			parent,
			Vector3(1.25, up, 0.58 - up * 0.287),
			Vector3(0.4, 0.04, 0.04),
			Vector3.ZERO,
			"plank_a"
		)
	_chunk(parent, Vector3(-0.2, 0.012, 1.0), Vector3(2.0, 0.02, 1.5), Vector3(0, 8, 0), "tarp")
	for i in 3:
		var pot := MeshInstance3D.new()
		pot.name = "Pot%d" % i
		var can := CylinderMesh.new()
		can.top_radius = 0.11
		can.bottom_radius = 0.11
		can.height = 0.22
		can.radial_segments = 12
		can.material = _mat(["paint_a", "paint_b", "plaster"][i])
		pot.mesh = can
		pot.position = Vector3(-0.9 + 0.27 * i, 0.135, 1.0 + 0.12 * (i % 2))
		_add(parent, pot)


func _chunk(parent: Node, at: Vector3, size: Vector3, spin: Vector3, mat: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	_chunks += 1
	mesh.name = "Chunk%d" % _chunks
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(mat)
	mesh.mesh = box
	mesh.position = at
	mesh.rotation_degrees = spin
	_add(parent, mesh)
	return mesh


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
	var shell_part := parent == _body_meshes or parent == _roof
	if shell_part and not SHOW_SHELL and not nm.begins_with("Floor_"):
		return
	var mesh := MeshInstance3D.new()
	mesh.name = nm
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(mat)
	mesh.mesh = box
	mesh.position = at
	mesh.visible = SHOW_SHELL or not nm.begins_with("Floor_")
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
	if not SHOW_SHELL:
		return  # a greybox aid; the real shop shows its state by itself
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
		"dust": Color(0.58, 0.54, 0.47),
		"brick": Color(0.62, 0.33, 0.25),
		"brick_b": Color(0.52, 0.27, 0.21),
		"plaster": Color(0.80, 0.77, 0.71),
		"slate": Color(0.34, 0.36, 0.40),
		"plank_a": Color(0.55, 0.40, 0.25),
		"plank_b": Color(0.44, 0.31, 0.19),
		"leaf_a": Color(0.70, 0.42, 0.16),
		"leaf_b": Color(0.56, 0.47, 0.18),
		"paint_a": Color(0.30, 0.47, 0.40),
		"paint_b": Color(0.72, 0.60, 0.36),
		"weed_a": Color(0.36, 0.48, 0.22),
		"weed_b": Color(0.46, 0.55, 0.26),
		"tarp": Color(0.30, 0.42, 0.55),
		"paper": Color(0.80, 0.77, 0.66),
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
