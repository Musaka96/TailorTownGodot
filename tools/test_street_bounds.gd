extends SceneTree

## The player can walk grandpa's plot and the pavement in front of it, and nothing else:
## the road, the neighbours' gardens and the far ends of the street are walled off
## (scenes/world/street_bounds.gd). Customers walk in along the pavement from x +/- 22, so
## those spots must stay clear.
##   godot --headless --path . --script res://tools/test_street_bounds.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const PLAYER_R := 0.32
const PLAYER_H := 1.5
const STAND := 0.12  # how far above the ground the test capsule's foot sits
## The ground the flood fill covers, and how fine: a player-sized capsule is dropped in
## every cell, then walkable cells are filled from where the player starts.
const AREA := Rect2(-32.0, -16.0, 64.0, 44.0)
const CELL := 0.4
## How many cells either side of a FREE spot may stand in for it (props sit on pavements).
const NEAR := 2
## Where the player must be able to stand: the pavement, the forecourt, the side garden,
## the back yard, the workshop's yard, and both ends of the pavement customers use.
const FREE := {
	"the pavement outside the door": Vector3(0.5, 0, 12.0),
	"the forecourt": Vector3(0.5, 0, 9.6),
	"the side garden": Vector3(-7.0, 0, 5.0),
	"the back yard": Vector3(2.0, 0, -4.0),
	"the workshop's yard": Vector3(11.0, 0, 9.0),
	"where customers come from, west": Vector3(-22.0, 0, 12.4),
	"where customers come from, east": Vector3(22.0, 0, 11.8),
}
## And where it must not get to (nothing walls these off on their own: they must simply be
## out of reach from where the player stands).
const BLOCKED = {
	"the road": Vector3(0.5, 0, 18.0),
	"past the west end": Vector3(-28.0, 0, 12.0),
	"past the east end": Vector3(28.0, 0, 12.0),
	"the neighbour's garden, west": Vector3(-14.0, 0, 6.0),
	"the neighbour's garden, east": Vector3(20.0, 0, 6.0),
	"behind the back wall": Vector3(2.0, 0, -12.0),
}

var _fails := 0
var _checks := 0
var _space: PhysicsDirectSpaceState3D
var _exclude: Array[RID] = []
var _cols := 0
var _rows := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load(SCENE).instantiate()
	root.add_child(main)
	current_scene = main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 4:
		await physics_frame
	var player := main.find_child("Player", true, false) as CollisionObject3D
	_exclude = [player.get_rid()]
	_space = (main as Node3D).get_world_3d().direct_space_state
	var free := _free_cells()
	var seen := _flood(free, player.global_position)
	_check(seen.size() > 200, "the player has somewhere to walk (%d cells)" % seen.size())
	for what: String in FREE:
		_check(_near(seen, FREE[what]), "%s can be reached" % what)
	for what: String in BLOCKED:
		_check(not seen.has(_cell(BLOCKED[what])), "%s cannot be reached" % what)
	_check(_checks == FREE.size() + BLOCKED.size() + 1, "every spot was checked")
	print("test_street_bounds: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


func _cell(at: Vector3) -> int:
	var col := int((at.x - AREA.position.x) / CELL)
	var row := int((at.z - AREA.position.y) / CELL)
	return row * _cols + col


## Every cell a player-sized capsule fits in, as cell index -> true.
func _free_cells() -> Dictionary:
	_cols = int(AREA.size.x / CELL)
	_rows = int(AREA.size.y / CELL)
	var shape := CapsuleShape3D.new()
	shape.radius = PLAYER_R
	shape.height = PLAYER_H
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = _exclude
	var free := {}
	for row in _rows:
		for col in _cols:
			var at := Vector3(
				AREA.position.x + (col + 0.5) * CELL,
				STAND + PLAYER_H / 2.0,
				AREA.position.y + (row + 0.5) * CELL
			)
			query.transform = Transform3D(Basis.IDENTITY, at)
			if _space.intersect_shape(query, 1).is_empty():
				free[row * _cols + col] = true
	return free


## Whether the fill reached `at` or a cell within NEAR of it: street furniture (a cafe
## table, a barrow) may stand on the exact spot, and that is fine as long as the player
## can get beside it.
func _near(seen: Dictionary, at: Vector3) -> bool:
	for dx in range(-NEAR, NEAR + 1):
		for dz in range(-NEAR, NEAR + 1):
			if seen.has(_cell(at + Vector3(dx * CELL, 0.0, dz * CELL))):
				return true
	return false


## Walk out from `from` through the free cells, four ways.
func _flood(free: Dictionary, from: Vector3) -> Dictionary:
	var start := _cell(from)
	var seen := {}
	if not free.has(start):
		return seen
	var queue: Array[int] = [start]
	seen[start] = true
	while not queue.is_empty():
		var at: int = queue.pop_back()
		var col := at % _cols
		for step: int in [-1, 1, -_cols, _cols]:
			var next := at + step
			if absi(step) == 1 and absi((next % _cols) - col) != 1:
				continue  # don't step round the end of a row
			if next < 0 or next >= _cols * _rows or seen.has(next) or not free.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
