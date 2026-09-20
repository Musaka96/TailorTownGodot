extends SceneTree

## "Cramped must never mean stuck" (docs/STORY_AND_RENOVATION.md §6.5), measured instead of
## eyeballed. For several renovation stages of grandpa's shop this flood-fills the floor with
## a player-sized body against the real colliders and checks that, from where the player
## starts, they can walk to a spot in reach of every station that is there, into every room
## that is open, and out of the street door — also while customers stand at the counter and
## at the mirror. It then repeats the customer's own route with a wider body (the aisle rule).
##   godot --headless --path . --script res://tools/test_shop_clearance.gd [-- verbose]

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const CELL := 0.15
const PLAYER_R := 0.34  # scenes/player/player.tscn capsule radius
const AISLE_R := 0.6  # half of the 1.2 m the customer route must keep clear
const WORK_R := 0.45  # half of the 0.9 m every station keeps free on its working side
const REACH := 1.6  # the player's Interactor radius
const FRONT := 0.9  # how far in front of a station's origin the player stands to use it
const X_MIN := -4.6
const X_MAX := 13.9
const Z_MIN := -1.9
const Z_MAX := 10.3
const ROOM_CENTRES := {
	"workroom": Vector3(-0.35, 0, 0.34),
	"cloth": Vector3(5.65, 0, 0.34),
	"nook": Vector3(5.65, 0, 5.34),
	"nextdoor": Vector3(10.65, 0, 3.34),
}
const STATIONS := [
	"Shelf",
	"Phone",
	"Worktable",
	"SewingMachine",
	"ClothingRack",
	"Mirror",
	"TrashCan",
	"Bookshelf",
	"ClothingRack2",
	"Shelf2",
	"Shelf3",
	"Shelf4",
	"CoffeeMachine",
	"IroningBoard",
	"ApprenticeBench",
	"Mannequin",
	"ClothingRack3",
]
## Stage name -> the last project finished ("" = the first morning, "*" = everything).
const STAGES := {
	"day 1": "",
	"front room tidy": "front_lights",
	"workroom entered": "workroom_boards",
	"workroom done": "workroom_build",
	"cloth store done": "cloth_build",
	"nook done": "nook_build",
	"everything": "*",
}

var _fails := 0
var _verbose := false
var _main: Node
var _space: PhysicsDirectSpaceState3D
var _exclude: Array[RID] = []
var _stages_done := 0  # a stage that errors out midway must not pass silently


func _initialize() -> void:
	_verbose = "verbose" in OS.get_cmdline_user_args()
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 4:
		await physics_frame
	var player := _main.find_child("Player", true, false) as CollisionObject3D
	_exclude = [player.get_rid()]
	_space = (_main as Node3D).get_world_3d().direct_space_state
	var start := player.global_position
	for stage: String in STAGES:
		await _set_stage(STAGES[stage])
		_check_stage(stage, start)
	_check(
		_stages_done == STAGES.size(),
		"every stage was checked to the end (%d of %d)" % [_stages_done, STAGES.size()]
	)
	print("test_shop_clearance: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


func _set_stage(upto: String) -> void:
	var reno: Node = root.get_node("Renovation")
	var upgrades: Node = root.get_node("Upgrades")
	reno.reset()
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		upgrades.debug_set(id, upto == "*")
	if upto == "*":
		reno.debug_finish_all()
	elif upto != "":
		while true:
			var done: String = reno.debug_finish_next()
			if done == "" or done == upto:
				break
	upgrades.changed.emit()
	for _i in 3:
		await physics_frame


func _check_stage(stage: String, start: Vector3) -> void:
	var reno: Node = root.get_node("Renovation")
	var free := _free_cells(PLAYER_R, [])
	var seen := _flood(free, start)
	_check(not seen.is_empty(), "%s: the player's starting spot is free" % stage)
	for station: String in STATIONS:
		var node := _main.get_node_or_null("ShopRoom/" + station) as Node3D
		if node == null or not node.visible:
			continue
		_check(_in_reach(seen, node), "%s: can walk up to %s" % [stage, station])
	for room: String in ROOM_CENTRES:
		var entered: bool = reno.room_state(room) >= 1
		var reached := _near(seen, ROOM_CENTRES[room], 1.2)
		if entered:
			_check(reached, "%s: can walk into the %s" % [stage, room])
		else:
			_check(not reached, "%s: the %s is really shut" % [stage, room])
	var out := (_main.find_child("DoorOutside", true, false) as Node3D).global_position
	_check(_near(seen, out, 0.6), "%s: can walk out of the street door" % stage)

	# With a customer at the counter and another at the mirror, nothing may be cut off.
	var greet := (_main.find_child("GreetSpot", true, false) as Node3D).global_position
	var mirror := (_main.find_child("MirrorSpot", true, false) as Node3D).global_position
	var crowded := _flood(_free_cells(PLAYER_R, [greet, mirror]), start)
	for station: String in STATIONS:
		var node := _main.get_node_or_null("ShopRoom/" + station) as Node3D
		if node == null or not node.visible:
			continue
		_check(
			_in_reach(crowded, node), "%s: with customers in, can still reach %s" % [stage, station]
		)
	# Every station must be reachable along corridors at least 0.9 m wide, not by squeezing.
	var roomy := _flood(_free_cells(WORK_R, []), start)
	for station: String in STATIONS:
		var node := _main.get_node_or_null("ShopRoom/" + station) as Node3D
		if node == null or not node.visible:
			continue
		_check(_in_reach(roomy, node), "%s: 0.9 m of room all the way to %s" % [stage, station])
	# The customer's own route, walked with a body as wide as the aisle has to be.
	var inside := (_main.find_child("DoorInside", true, false) as Node3D).global_position
	var wide := _flood(_free_cells(AISLE_R, []), inside)
	_check(_near(wide, greet, 0.45), "%s: 1.2 m aisle from the door to the counter" % stage)
	_check(_near(wide, mirror, 0.45), "%s: 1.2 m aisle from the door to the mirror" % stage)
	if _verbose:
		_draw(free, seen, stage)
	_stages_done += 1


# --- the floor as a grid -------------------------------------------------------------


func _free_cells(radius: float, people: Array) -> Dictionary:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = _exclude
	query.collide_with_areas = false
	var free := {}
	var ix := 0
	var x := X_MIN
	while x <= X_MAX:
		var iz := 0
		var z := Z_MIN
		while z <= Z_MAX:
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.75, z))
			var blocked := not _space.intersect_shape(query, 1).is_empty()
			for who: Vector3 in people:  # a customer's body: about the player's size
				if Vector2(x - who.x, z - who.z).length() < radius + PLAYER_R:
					blocked = true
			if not blocked:
				free[Vector2i(ix, iz)] = true
			iz += 1
			z += CELL
		ix += 1
		x += CELL
	return free


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi((at.x - X_MIN) / CELL), roundi((at.z - Z_MIN) / CELL))


func _flood(free: Dictionary, from: Vector3) -> Dictionary:
	var first := _nearest_free(free, from, 0.5)
	var seen := {}
	if first == Vector2i(-1, -1):
		return seen
	var todo: Array[Vector2i] = [first]
	seen[first] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if free.has(n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen


func _nearest_free(cells: Dictionary, at: Vector3, within: float) -> Vector2i:
	var centre := _cell(at)
	var span := ceili(within / CELL)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var c := centre + Vector2i(dx, dz)
			var d := Vector2(dx, dz).length() * CELL
			if cells.has(c) and d <= within and d < best_d:
				best = c
				best_d = d
	return best


func _near(cells: Dictionary, at: Vector3, within: float) -> bool:
	return _nearest_free(cells, at, within) != Vector2i(-1, -1)


## The player can stand in front of `station` (its +Z side, where it is used from), within
## arm's reach of it. Standing behind a wall near its back doesn't count.
func _in_reach(cells: Dictionary, station: Node3D) -> bool:
	var front := station.global_position + station.global_basis.z * FRONT
	var spot := _nearest_free(cells, front, FRONT)
	if spot == Vector2i(-1, -1):
		return false
	var at := Vector3(X_MIN + spot.x * CELL, 0, Z_MIN + spot.y * CELL)
	return at.distance_to(station.global_position * Vector3(1, 0, 1)) <= REACH


func _draw(free: Dictionary, seen: Dictionary, stage: String) -> void:
	print("--- %s   ('.' walkable from the start, 'o' free but cut off, '#' blocked)" % stage)
	var iz := 0  # back of the shop first, the street last: the way the game camera sees it
	while iz <= roundi((Z_MAX - Z_MIN) / CELL):
		var line := ""
		var ix := 0
		while ix <= roundi((X_MAX - X_MIN) / CELL):
			var c := Vector2i(ix, iz)
			line += "." if seen.has(c) else ("o" if free.has(c) else "#")
			ix += 2
		print(line)
		iz += 2


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	if not ok or _verbose:
		print("  %s  %s" % ["PASS" if ok else "FAIL", what])
