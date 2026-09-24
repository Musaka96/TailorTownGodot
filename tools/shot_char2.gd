extends SceneTree

## Dev-only side-by-side of the live character (CHARTGEN1, left) and a replacement model
## (CHARTGEN2 from tools/blender/tripo_character.py, right), both driven by the real
## CharacterRig script and animations, dressed in a pinstripe so the fabric grain can be
## judged. NOT headless (it renders):
##   godot --path . --script res://tools/shot_char2.gd
##   godot --path . --script res://tools/shot_char2.gd -- --glb=res://.dev/x.glb --tag=x
## Writes engine_<tag>_<view>.png to IMPORT/CHARREWORK/report/ (git-ignored).
##
## Cloth is applied here with ClothMaterial.build, because a bare --script run does not
## get the game's outfit pass (see the shot_rig.gd gotcha in the garment-UV notes).

const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const RIG_SCENE := "res://entities/character/character_rig.tscn"
const DEFAULT_GLB := "res://assets/characters/CHARTGEN2.glb"
const OUT_DIR := "res://IMPORT/CHARREWORK/report"
const CLOTH := "res://data/materials/navy_worsted_pinstripe.tres"
const CLOTH_UV_SCALE := 6.0
const SKIN := Color(0.86, 0.72, 0.60)
const SEPARATION := 0.9
# name, animation, time fraction, camera position, look-at target
const SHOTS := [
	["front", "idle", 0.3, Vector3(0.0, 1.1, 5.2), Vector3(0.0, 1.05, 0.0)],
	["back", "idle", 0.3, Vector3(0.0, 1.1, -5.2), Vector3(0.0, 1.05, 0.0)],
	["three_quarter", "idle", 0.3, Vector3(3.4, 1.9, 3.9), Vector3(0.0, 1.0, 0.0)],
	["walk", "walk", 0.25, Vector3(3.6, 1.6, 3.6), Vector3(0.0, 0.95, 0.0)],
	["sleeve", "idle", 0.3, Vector3(1.75, 1.25, 1.0), Vector3(1.35, 0.95, 0.0)],
]

var _rigs: Array[Node3D] = []
var _cam: Camera3D
var _frame := 0
var _shot := 0
var _tag := ""


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1000, 900))
	var glb := DEFAULT_GLB
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glb="):
			glb = arg.trim_prefix("--glb=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=") + "_"
	var world := Node3D.new()
	root.add_child(world)
	_add_lights(world)

	var old_rig := (load(RIG_SCENE) as PackedScene).instantiate() as Node3D
	old_rig.position.x = -SEPARATION
	world.add_child(old_rig)
	_rigs.append(old_rig)

	var model := _load_model(glb)
	if model == null:
		push_error("could not load " + glb)
		quit(1)
		return
	var new_rig := _build_rig(model)
	new_rig.position.x = SEPARATION
	world.add_child(new_rig)
	_rigs.append(new_rig)

	var cloth := load(CLOTH) as Resource
	var cloth_script := load("res://data/scripts/cloth_material.gd")
	for rig in _rigs:
		rig.call("set_palette", SKIN)
		rig.call("set_hair_color", Color(0.25, 0.16, 0.10))
		_dress(rig, cloth_script.call("build", cloth, CLOTH_UV_SCALE, true))
	_report(new_rig, glb)

	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_cam.make_current()
	process_frame.connect(_on_frame)


func _load_model(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## The same wiring as character_rig.tscn, with the model swapped: the rig script finds
## its meshes by name under a child called CHARTGEN1, and the AnimationPlayer's tracks
## are rooted there.
func _build_rig(model: Node3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "CharacterRig2"
	rig.set_script(load(RIG_SCRIPT))
	model.name = "CHARTGEN1"
	rig.add_child(model)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("../CHARTGEN1")
	rig.add_child(player)
	return rig


func _dress(rig: Node3D, cloth: Material) -> void:
	var flats := {
		"shoes": Color(0.16, 0.12, 0.10),
		"buttons": Color(0.75, 0.62, 0.35),
		"tie": Color(0.55, 0.12, 0.14),
		"square": Color(0.92, 0.92, 0.9),
		"left leg": Color(0.16, 0.12, 0.10),
		"right leg": Color(0.16, 0.12, 0.10),
	}
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name in ["jacket", "legs", "shirt"]:
			m.material_override = cloth
		elif flats.has(String(m.name)):
			var flat := StandardMaterial3D.new()
			flat.albedo_color = flats[String(m.name)]
			flat.roughness = 1.0
			m.material_override = flat


func _report(rig: Node3D, glb: String) -> void:
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var names: Array[String] = []
	if skel != null:
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
	print("%s: %d bones %s" % [glb, names.size(), names])
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print(
			(
				"  mesh %-8s skin=%s surfaces=%d"
				% [m.name, m.skin != null, m.mesh.get_surface_count() if m.mesh else 0]
			)
		)


func _pose(shot: Array) -> void:
	for rig in _rigs:
		var player := rig.get_node("AnimationPlayer") as AnimationPlayer
		var clip := String(shot[1])
		if not player.has_animation(clip):
			continue
		player.play(clip)
		player.seek(player.get_animation(clip).length * float(shot[2]), true)
		player.pause()
	_cam.look_at_from_position(shot[3], shot[4], Vector3.UP)


func _on_frame() -> void:
	_frame += 1
	if _frame == 2 and _shot == 0:
		_hide_hud(root)
		for rig in _rigs:
			# the rig's AnimationTree owns the skeleton; switch it off to pose by hand
			for tree in rig.find_children("*", "AnimationTree", true, false):
				(tree as AnimationTree).active = false
			var player := rig.get_node("AnimationPlayer") as AnimationPlayer
			print("%s animations: %s" % [rig.name, player.get_animation_list()])
	if _frame == 4:
		_pose(SHOTS[_shot])
	elif _frame == 10:
		var image := root.get_texture().get_image()
		var path := "%s/engine_%s%s.png" % [OUT_DIR, _tag, SHOTS[_shot][0]]
		if image != null and image.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("Saved " + path)
		_shot += 1
		_frame = 0
		if _shot >= SHOTS.size():
			quit(0)


## The game's autoloads bring their HUD along; the comparison is about the models.
func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is Control:
			(child as Control).visible = false
		else:
			_hide_hud(child)


func _add_lights(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.76, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 200, 0)
	fill.light_energy = 0.4
	world.add_child(fill)
