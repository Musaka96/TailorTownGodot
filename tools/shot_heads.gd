extends SceneTree

## Head+hair combos from the wardrobe, rendered for the owner to judge. NOT headless:
##   godot --path . --script res://tools/shot_heads.gd
##   godot --path . --script res://tools/shot_heads.gd -- --tag=old --indices=1,2,3
## One CharacterRig per combo (head i + hair i, one skin, dark brown hair, faces on, a
## plain navy suit), in a row. Shots, saved as IMPORT/CHARREWORK/report/heads/:
##   engine_<tag>lineup_front.png / _three_quarter.png  the gameplay camera's distance
##       and angle (camera_rig.tscn: 6.27 m up, 4.39 m back, fov 75), pulled back to fit
##       the whole row
##   engine_<tag>NN_<name>_front.png / _side.png  a fitting close-up of each combo
## --indices defaults to every wardrobe head except 0 (the base CHARTGEN head).
## --neck: each of --indices in three outfits (the suit, then every street outfit), with
## a close-up of the neck in the collar front and side, saved as
## report/heads_neck/neck_<tag><index>_<outfit>_<front|side>.png.

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const SUIT := "res://data/materials/navy_worsted_solid.tres"
const OUT_DIR := "res://IMPORT/CHARREWORK/report/heads"
const SKIN := Color(0.86, 0.72, 0.60)
const HAIR := Color(0.28, 0.18, 0.10)  # WardrobeLibrary's dark brown
const GAP := 1.3
const GAME_OFFSET := Vector3(0.0, 6.271325, 4.392928)
const SETTLE := 12

var _rigs: Array[Node3D] = []
var _names: Array[String] = []
var _indices: Array[int] = []
var _cam: Camera3D
var _shots: Array = []  # [file name, rig index or -1 for all, camera position, look at, fov]
var _shot := 0
var _frame := 0
var _tag := ""
var _neck := false
var _outfits: Array[String] = []  # per rig in --neck mode: "suit" or a street outfit index


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var wanted := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=") + "_"
		elif arg.begins_with("--indices="):
			wanted = arg.trim_prefix("--indices=")
		elif arg == "--neck":
			_neck = true
	# stand in the calm idle (arms down) like the other character sheets
	CharacterAnimations.calm_idle = true
	var count: int = Wardrobe.head_count()
	if wanted == "":
		for i in range(1, count):
			_indices.append(i)
	else:
		for s in wanted.split(","):
			if int(s) < count:
				_indices.append(int(s))
	print("shot_heads: wardrobe has %d heads, %d hairs" % [count, Wardrobe.hair_count()])
	var world := Node3D.new()
	root.add_child(world)
	_add_lights(world)
	var packed := load(RIG_SCENE) as PackedScene
	if _neck:
		var looks: Array[String] = ["suit"]
		for i in Wardrobe.library().street_outfits.size():
			looks.append(str(i))
		var per_look: Array[int] = []
		for i in _indices:
			for look in looks:
				per_look.append(i)
				_outfits.append(look)
		_indices = per_look
	for k in _indices.size():
		var rig := packed.instantiate() as Node3D
		rig.position.x = (k - (_indices.size() - 1) * 0.5) * GAP
		world.add_child(rig)
		_rigs.append(rig)
		var part: Resource = Wardrobe.head(_indices[k])
		var label := String(part.get("display_name")) if part != null else "head"
		_names.append(label.to_lower().replace(" head", "").replace(" ", "_").replace("+", ""))
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.make_current()
	process_frame.connect(_on_frame)


func _dress() -> void:
	var suit := load(SUIT) as Resource
	for k in _rigs.size():
		var rig := _rigs[k]
		rig.call("set_head", _indices[k])
		rig.call("set_hair", _indices[k])
		rig.call("set_palette", SKIN)
		rig.call("set_hair_color", HAIR)
		rig.call("set_outfit", suit, null, suit, 0, 0)
		if _neck and _outfits[k] != "suit":
			rig.call("wear_street", Wardrobe.library().street_outfit(int(_outfits[k])))
		rig.call("set_face_look", "brown", "", 0, 0)
		rig.call("reset_expression")
		print("  combo %d: %s" % [_indices[k], _names[k]])


func _plan() -> void:
	var width := (_rigs.size() - 1) * GAP + 2.0
	# the gameplay camera's angle, pulled back until the row fits the frame
	var back := maxf(1.0, width / 9.0)
	var target := Vector3(0.0, 0.9, 0.0)
	var front := target + GAME_OFFSET * back
	_shots.append(["lineup_front", -1, front, target, 75.0])
	var quarter := target + GAME_OFFSET.rotated(Vector3.UP, deg_to_rad(35.0)) * back
	_shots.append(["lineup_three_quarter", -1, quarter, target, 75.0])
	if _neck:
		for k in _rigs.size():
			var head := _head_position(_rigs[k])
			var look := _outfits[k]
			if look != "suit":
				look = String(Wardrobe.library().street_outfit(int(look)).display_name).to_lower()
			var name := "neck_%02d_%s" % [_indices[k], look]
			var collar := head + Vector3(0.0, -0.45, 0.0)
			_shots.append([name + "_front", k, collar + Vector3(0.0, 0.1, 1.5), collar, 30.0])
			_shots.append([name + "_side", k, collar + Vector3(1.5, 0.1, 0.0), collar, 30.0])
		return
	for k in _rigs.size():
		var head := _head_position(_rigs[k])
		var name := "%02d_%s" % [_indices[k], _names[k]]
		_shots.append([name + "_front", k, head + Vector3(0.0, 0.05, 2.3), head, 35.0])
		_shots.append([name + "_side", k, head + Vector3(2.3, 0.05, 0.0), head, 35.0])


func _head_position(rig: Node3D) -> Vector3:
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("head_2")
	if bone < 0:
		bone = skel.find_bone("head")
	var p := skel.global_transform * skel.get_bone_global_pose(bone).origin
	return p + Vector3(0.0, 0.35, 0.0)  # the bone sits at the neck; aim at mid-skull


func _on_frame() -> void:
	_frame += 1
	if _frame == 2 and _shot == 0:
		_hide_hud(root)
		_dress()
	if _frame == SETTLE and _shots.is_empty():
		_plan()
	if _shots.is_empty() or _frame < SETTLE:
		return
	if _frame == SETTLE + 1:
		var shot: Array = _shots[_shot]
		for k in _rigs.size():
			_rigs[k].visible = int(shot[1]) < 0 or int(shot[1]) == k
		_cam.fov = float(shot[4])
		_cam.look_at_from_position(shot[2], shot[3], Vector3.UP)
	elif _frame == SETTLE + 5:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		var path := "%s/engine_%s%s.png" % [OUT_DIR, _tag, _shots[_shot][0]]
		if _neck:
			var dir := OUT_DIR.get_base_dir() + "/heads_neck"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			path = "%s/%s%s.png" % [dir, _tag, _shots[_shot][0]]
		var image := root.get_texture().get_image()
		if image != null and image.save_png(ProjectSettings.globalize_path(path)) == OK:
			print("Saved " + path)
		_shot += 1
		_frame = SETTLE
		if _shot >= _shots.size():
			quit(0)


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
