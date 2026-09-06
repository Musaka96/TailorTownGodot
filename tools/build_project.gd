extends SceneTree

## One-shot project generator (run headless, not part of the game).
##
## Run with:
##   godot --headless --path <project> --script res://tools/build_project.gd
##
## It authors the scenes, input map and project settings *through the engine* so
## the resulting .tscn / project.godot are guaranteed valid — no hand-serialised
## Transform3D or InputEvent literals to get wrong. Safe to re-run; it overwrites
## the generated scenes in place. The committed source of truth after this is the
## .tscn / .gd / project.godot files, not this script.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CAMERA_SCENE := "res://scenes/camera/camera_rig.tscn"
const LEVEL_SCENE := "res://scenes/world/level_playground.tscn"
const MAIN_SCENE := "res://main.tscn"


func _initialize() -> void:
	_build_player()
	_build_camera_rig()
	_build_level()
	_build_main()
	_configure_input_map()
	_configure_project_settings()
	var err := ProjectSettings.save()
	if err != OK:
		push_error("Failed to save ProjectSettings: %d" % err)
	print("Build complete.")
	quit()


# --- Scene builders -------------------------------------------------------

func _build_player() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	root.set_script(load("res://scenes/player/player.gd"))

	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)  # capsule sits on the ground
	root.add_child(collision)

	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.20, 0.55, 0.90)
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = capsule_mesh
	body.material_override = body_mat
	body.position = Vector3(0, 0.9, 0)
	model.add_child(body)

	# A "nose" so the facing direction is visible while prototyping.
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.85, 0.25)
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.25, 0.25, 0.35)
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	nose.mesh = nose_mesh
	nose.material_override = nose_mat
	nose.position = Vector3(0, 0.9, 0.45)  # +Z is "forward"
	model.add_child(nose)

	_set_owner_recursive(root, root)
	_save_scene(root, PLAYER_SCENE)


func _build_camera_rig() -> void:
	var root := Node3D.new()
	root.name = "CameraRig"
	root.set_script(load("res://scenes/camera/camera_rig.gd"))

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	# Position up-and-back, then look at the rig origin so the downward angle is
	# baked correctly by the engine (no manual trig).
	# Bake the downward angle without needing the node in a tree.
	camera.look_at_from_position(Vector3(0, 12, 8.4), Vector3.ZERO, Vector3.UP)

	_set_owner_recursive(root, root)
	_save_scene(root, CAMERA_SCENE)


func _build_level() -> void:
	var root := Node3D.new()
	root.name = "LevelPlayground"

	# --- Environment (procedural sky + sky-based ambient) ---
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)

	# --- Sun ---
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.shadow_enabled = true
	root.add_child(sun)

	# --- Ground (visual + collision), top surface at y = 0 ---
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	root.add_child(ground)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.30, 0.34, 0.32)
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(40, 1, 40)
	var ground_mi := MeshInstance3D.new()
	ground_mi.name = "Mesh"
	ground_mi.mesh = ground_mesh
	ground_mi.material_override = ground_mat
	ground_mi.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_mi)

	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(40, 1, 40)
	var ground_col := CollisionShape3D.new()
	ground_col.name = "Collision"
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_col)

	# --- A few greybox obstacles to move around ---
	_add_crate(root, "CrateA", Vector3(4, 0, -3), Vector3(2, 2, 2), Color(0.75, 0.45, 0.30))
	_add_crate(root, "CrateB", Vector3(-5, 0, 2), Vector3(3, 1, 3), Color(0.55, 0.60, 0.35))
	_add_crate(root, "WallC", Vector3(0, 0, -8), Vector3(10, 2, 1), Color(0.50, 0.50, 0.55))

	_set_owner_recursive(root, root)
	_save_scene(root, LEVEL_SCENE)


func _add_crate(parent: Node, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	# Sit the crate on the ground: raise it by half its height.
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	parent.add_child(body)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)


func _build_main() -> void:
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load("res://main.gd"))
	root.process_mode = Node.PROCESS_MODE_ALWAYS  # keep reacting to input while paused

	var level: Node = load(LEVEL_SCENE).instantiate()
	root.add_child(level)

	var player: Node3D = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0, 0.1, 0)
	root.add_child(player)

	var rig: Node = load(CAMERA_SCENE).instantiate()
	rig.set("target_path", NodePath("../Player"))
	root.add_child(rig)

	_set_owner_recursive(root, root)
	_save_scene(root, MAIN_SCENE)


# --- Project configuration ------------------------------------------------

func _configure_input_map() -> void:
	_set_action("move_forward", 0.2, [
		_key(KEY_W), _key(KEY_UP), _stick(JOY_AXIS_LEFT_Y, -1.0)])
	_set_action("move_back", 0.2, [
		_key(KEY_S), _key(KEY_DOWN), _stick(JOY_AXIS_LEFT_Y, 1.0)])
	_set_action("move_left", 0.2, [
		_key(KEY_A), _key(KEY_LEFT), _stick(JOY_AXIS_LEFT_X, -1.0)])
	_set_action("move_right", 0.2, [
		_key(KEY_D), _key(KEY_RIGHT), _stick(JOY_AXIS_LEFT_X, 1.0)])
	_set_action("jump", 0.5, [
		_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_set_action("interact", 0.5, [
		_key(KEY_E), _button(JOY_BUTTON_X)])
	_set_action("pause", 0.5, [
		_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	# "quit" is separate so a future menu can rebind pause without killing the game.
	_set_action("quit", 0.5, [_key(KEY_F10)])


func _set_action(action: String, deadzone: float, events: Array) -> void:
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": deadzone,
		"events": events,
	})


# device = -1 (ALL_DEVICES) is essential: an action only fires if its event
# device is -1 or matches the incoming device. Any other value matches nothing.
func _key(physical_keycode: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = physical_keycode
	return e


func _stick(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e


func _button(button_index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button_index
	return e


func _configure_project_settings() -> void:
	ProjectSettings.set_setting("application/run/main_scene", MAIN_SCENE)
	ProjectSettings.set_setting("autoload/GameState", "*res://globals/game_state.gd")
	ProjectSettings.set_setting("application/config/name", "TailorTown")


# --- Helpers --------------------------------------------------------------

func _set_owner_recursive(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		if node != owner_root:
			pass
		child.owner = owner_root
		_set_owner_recursive(child, owner_root)


func _save_scene(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack() failed for %s: %d" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save() failed for %s: %d" % [path, err])
	else:
		print("Wrote ", path)
