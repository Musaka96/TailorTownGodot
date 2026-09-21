extends SceneTree

## Headless test for interacting through walls. For each shop scene it checks every
## Interactable from a ring of spots around it:
##   - reachable: some spot within arm's reach, standing on open floor, can see it (so the
##     line-of-sight check never locks a station behind a counter or its own shelf);
##   - and from the pavement outside the front wall, nothing inside the shop can be seen.
##   godot --headless --path . --script res://tools/test_reach.gd

const SCENES := ["res://main.tscn", "res://scenes/world/grandpa/main_grandpa.tscn"]
const RING := 1.2  # metres from a station the player tries standing
const SPOTS := 16

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for path: String in SCENES:
		change_scene_to_file(path)
		for _i in 120:
			await physics_frame
			if get_first_node_in_group("player") != null:
				break
		for _i in 6:
			await physics_frame
		await _check_scene(path.get_file())
		if path == SCENES[0]:
			await _rack_from_the_pavement()
	_finish()


## The playtest case: at Mr. Hemming's the clothing rack stands just inside the front wall,
## and a player on the pavement outside could use it through the wall.
func _rack_from_the_pavement() -> void:
	var player := get_first_node_in_group("player") as Node3D
	var eye: Node = player.find_child("Interactor", true, false)
	var rack := current_scene.find_child("ClothingRack", true, false) as Node3D
	var area: Area3D = rack.find_child("Interactable", true, false) if rack != null else null
	_check(area != null, "(setup) Mr. Hemming's has a clothing rack")
	if area == null:
		return
	var seen := false
	for dx: float in [-0.6, 0.0, 0.6]:
		for z: float in [6.5, 6.8, 7.1]:
			player.global_position = Vector3(rack.global_position.x + dx, 0.0, z)
			await physics_frame
			seen = seen or bool(eye.call("_in_sight", area))
	_check(not seen, "the rack can't be reached from the pavement, through the wall")


func _check_scene(label: String) -> void:
	var player := get_first_node_in_group("player") as Node3D
	var eye: Node = player.find_child("Interactor", true, false)
	_check(eye != null and eye.has_method("_in_sight"), "%s: the player has an Interactor" % label)
	if eye == null:
		return
	var home := player.global_position
	var locked: Array[String] = []
	var count := 0
	for node in get_nodes_in_group("interactable"):
		var area := node as Area3D
		if area == null or not area.monitorable or not area.is_visible_in_tree():
			continue
		count += 1
		if not await _reachable(player, eye, area):
			var who: Node = area.target if area.get("target") != null else area.get_parent()
			locked.append(
				"%s %s" % [_what(area), str(area.global_position.snapped(Vector3.ONE * 0.1))]
			)
	player.global_position = home
	_check(count > 5, "%s: (setup) found %d stations" % [label, count])
	_check(locked.is_empty(), "%s: every station can be reached (locked: %s)" % [label, locked])


## Is there an open spot around `area` from which the player can see it?
func _reachable(player: Node3D, eye: Node, area: Area3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	for i in SPOTS:
		var at := area.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / SPOTS) * RING
		at.y = player.global_position.y
		if _blocked(space, at):
			continue
		player.global_position = at
		await physics_frame
		if eye.call("_in_sight", area):
			return true
	return false


## True if a person can't stand at `at` (something solid at chest height).
func _blocked(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var probe := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	probe.shape = shape
	probe.transform = Transform3D(Basis(), at + Vector3.UP * 1.0)
	probe.collision_mask = 1
	for hit in space.intersect_shape(probe, 4):
		var body := hit["collider"] as Node
		if body != null and not body.is_in_group("player"):
			return true
	return false


func _check(condition: bool, text: String) -> void:
	if condition:
		print("  PASS  ", text)
	else:
		print("  FAIL  ", text)
		_failures.append(text)


func _finish() -> void:
	if _failures.is_empty():
		print("test_reach: ALL PASS")
		quit(0)
	else:
		print("test_reach: %d FAILURE(S)" % _failures.size())
		quit(1)


## A readable name for what an Interactable belongs to: its node, or its script's file.
func _what(area: Area3D) -> String:
	var owner_node := area.get_parent()
	var script: Script = owner_node.get_script()
	if String(owner_node.name).begins_with("@") and script != null:
		return script.resource_path.get_file().get_basename()
	return String(owner_node.name)
