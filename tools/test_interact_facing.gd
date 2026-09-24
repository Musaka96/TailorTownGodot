extends SceneTree

## Headless test for the interaction controller's facing rule (entities/player/
## interaction_controller.gd): a stand-in player (a body with a "Model" child that turns)
## and a few Interactables in an empty world. Checks that what you face is taken, that a
## thing you face beats a slightly closer one at the edge of the cone, that the current
## target holds inside the wider keep cone, that turning well away lets go (so interact
## would "Set down"), and that a spot you stand against is in reach whichever way you face.
##   godot --headless --path . --script res://tools/test_interact_facing.gd

const INTERACTABLE_LAYER := 4

var _failures: Array[String] = []
var _model: Node3D
var _ctrl: Area3D


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var player := Node3D.new()
	player.name = "Player"
	world.add_child(player)
	_model = Node3D.new()
	_model.name = "Model"
	player.add_child(_model)
	_ctrl = Area3D.new()
	_ctrl.set_script(load("res://entities/player/interaction_controller.gd"))
	_ctrl.set("player_path", NodePath(".."))
	_ctrl.collision_layer = 0
	_ctrl.collision_mask = INTERACTABLE_LAYER
	_ctrl.monitorable = false
	_ctrl.add_child(_sphere(1.6))
	player.add_child(_ctrl)

	# Ahead (+Z) at 1.2 m, and 50 degrees to the right at 0.9 m.
	var ahead := _thing(world, "Ahead", Vector3(0.0, 0.0, 1.2))
	var side_dir := Vector3(sin(deg_to_rad(50.0)), 0.0, cos(deg_to_rad(50.0)))
	var side := _thing(world, "Side", side_dir * 0.9)

	await _face(0.0)
	_check(_target() == ahead, "facing it: the thing ahead is targeted, not the closer one at 50")

	await _face(70.0)
	_check(_target() == ahead, "turned 70: the current target is kept (inside the keep cone)")

	_ctrl.call("_set_current", null)
	await _physics(3)
	_check(_target() == side, "turned 70 with nothing held: the thing now in front is taken")

	await _face(0.0)
	_ctrl.call("_set_current", null)
	await _physics(3)
	_check(_target() == ahead, "back to facing ahead")
	await _face(-120.0)
	_check(_target() == null, "turned 120 away: the target drops (interact would set down)")

	# A spot 0.4 m behind the player: standing on it counts whichever way you face.
	var fwd := Vector3(sin(deg_to_rad(-120.0)), 0.0, cos(deg_to_rad(-120.0)))
	var spot := _thing(world, "Spot", -fwd * 0.4)
	await _physics(3)
	_check(_target() == spot, "a spot 0.4 m behind is still targeted")

	world.free()
	_finish()


func _thing(world: Node3D, nm: String, at: Vector3) -> Interactable:
	var target := Node3D.new()
	target.name = nm
	world.add_child(target)
	target.position = at
	var it := Interactable.new()
	it.collision_layer = INTERACTABLE_LAYER
	it.collision_mask = 0
	it.add_child(_sphere(0.2))
	target.add_child(it)
	return it


func _sphere(radius: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	return shape


## Turn the model to `degrees` of yaw (0 = facing +Z) and let the controller look.
func _face(degrees: float) -> void:
	_model.rotation.y = deg_to_rad(degrees)
	await _physics(3)


func _physics(n: int) -> void:
	for _i in n:
		await physics_frame


func _target() -> Interactable:
	return _ctrl.get("_current") as Interactable


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("test_interact_facing: ALL PASS")
	else:
		print("test_interact_facing: %d FAILURE(S)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
