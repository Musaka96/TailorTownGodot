extends SceneTree

## Before/after sheet for the neck cut (NeckCut, skin_face.gdshader): the head's neck stub
## hidden inside each top's collar. Columns: the four tops (single- and double-breasted
## suit, overshirt, overcoat), each from the front and from 30 degrees, close on the
## collar. Rows: the player with the head skin tinted magenta, cut off then on (the
## diagnostic: every magenta pixel is neck); the player and a customer in their own skin,
## cut off then on; then the player in the single-breasted suit with the cut on, tinted
## and not, nodding, shaking and on three frames of the walk (a gap between collar and neck
## shows as the backdrop or the shaded inside of the neck). Studio light (grey backdrop,
## colour ambient, one sun). NOT headless:
##   godot --path . --script res://tools/shot_neck_fix.gd
## Writes IMPORT/faces_proc/neck_fix.png (git-ignored).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const WARDROBE_SCRIPT := "res://data/scripts/wardrobe.gd"
const OUT_DIR := "res://IMPORT/faces_proc"
const SUIT_CLOTH := &"navy_worsted_pinstripe"
const CUSTOMER_NAME := "Mr. Dimmock"
const CUSTOMER_HEAD := 6
const TOPS := ["single", "double", "overshirt", "overcoat"]
const ANGLES := [0.0, 30.0]
const TINT := Color(1, 0, 1)
const SIZE := Vector2i(640, 640)
const CELL := 220
const LABEL_H := 26
const FOV := 11.0
const DIST := 2.4
const NOD := 0.30  # CharacterRig.NOD_ANGLE
const NOD_BACK := -0.105  # the nod's swing back up: -0.35 x NOD_ANGLE
const SHAKE := 0.34
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _cells := []


func _initialize() -> void:
	DisplayServer.window_set_size(SIZE)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	_world.add_child(sun)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var player: Node3D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.set_physics_process(false)
	_world.add_child(player)
	for c: Camera3D in player.find_children("*", "Camera3D", true, false):
		c.current = false  # the player's own follow camera
	_cam.current = true
	await _frames(3)
	var prig: Node = player.get_node("Model")
	var skin: Color = player.get("skin_color")
	await _tops(prig, 0, "player tinted", TINT)
	await _tops(prig, 2, "player", skin)
	player.queue_free()

	var cust := await _customer()
	var crig: Node = cust.get_node("Rig")
	await _tops(crig, 4, "customer", crig.get("_skin_color"))
	cust.queue_free()

	player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.set_physics_process(false)
	_world.add_child(player)
	for c: Camera3D in player.find_children("*", "Camera3D", true, false):
		c.current = false
	_cam.current = true
	await _frames(3)
	prig = player.get_node("Model")
	await _motion(prig, 6, TINT, "tinted")
	await _motion(prig, 7, skin, "")
	await _save_grid(8, 8, "neck_fix.png")
	quit(0)


## A customer (the cast face of CUSTOMER_NAME) on a different head from the player's.
func _customer() -> Node3D:
	var manager: Node = load(MANAGER_SCRIPT).new()
	var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
	_world.add_child(cust)
	cust.set_physics_process(false)
	cust.preference = load(PREF_SCRIPT).random_pref(RandomNumberGenerator.new(), CUSTOMER_NAME)
	manager.call("_dress", cust)
	manager.free()
	var rig: Node = cust.get_node("Rig")
	rig.call("set_head", CUSTOMER_HEAD)
	rig.call("set_hair", CUSTOMER_HEAD)
	await _frames(3)
	print("customer %s: head %d" % [CUSTOMER_NAME, CUSTOMER_HEAD])
	return cust


## Rows `row` (cut off) and `row + 1` (cut on): every top from each angle, skin `tint`.
func _tops(rig: Node, row: int, tag: String, tint: Color) -> void:
	for t in TOPS.size():
		_wear(rig, t)
		rig.call("set_palette", tint)
		await _frames(3)
		var mat: ShaderMaterial = rig.get("_skin_face")
		var cut: float = mat.get_shader_parameter("neck_cut")
		print("%s %s: neck_cut %.3f" % [tag, TOPS[t], cut])
		for after in [false, true]:
			mat.set_shader_parameter("neck_cut", cut if after else -1.0)
			for a in ANGLES.size():
				var label := (
					"%s, %s %d, %s" % [tag, TOPS[t], ANGLES[a], "after" if after else "before"]
				)
				var img := await _shot(rig, ANGLES[a])
				_cells.append([img, t * 2 + a, row + int(after), label])
		mat.set_shader_parameter("neck_cut", cut)


## The single-breasted suit with the cut on: nod down and up, shake, walk.
func _motion(rig: Node, row: int, tint: Color, tag: String) -> void:
	_wear(rig, 0)
	rig.call("set_palette", tint)
	await _frames(3)
	var wobble: Node = rig.get("_wobble")
	var poses := [["pitch", NOD, "nod down"], ["pitch", NOD_BACK, "nod back"]]
	poses += [["yaw", SHAKE, "shake"], ["yaw", -SHAKE, "shake other way"]]
	var col := 0
	for p: Array in poses:
		wobble.set(p[0], p[1])
		await _frames(2)
		_cells.append([await _shot(rig, 30.0), col, row, "%s %s" % [p[2], tag]])
		wobble.set(p[0], 0.0)
		col += 1
	rig.call("set_locomotion", 1.0)
	await _frames(40)
	for f in 3:
		_cells.append([await _shot(rig, 30.0), col, row, "walk %d %s" % [f + 1, tag]])
		await _frames(7)
		col += 1
	rig.call("set_locomotion", 0.0)
	await _frames(40)
	_cells.append([await _shot(rig, 20.0, 0.9), col, row, "from above %s" % tag])


func _wear(rig: Node, top: int) -> void:
	var wardrobe: GDScript = load(WARDROBE_SCRIPT)
	if top < 2:
		var suit: Resource = root.get_node("Catalog").call("get_material", SUIT_CLOTH)
		rig.call("set_outfit", suit, null, suit, top, 0)
	else:
		rig.call("wear_street", wardrobe.street_outfit(top - 2))
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()


## The collar, framed on the head bone (the idle moves it), `ang` degrees round from the
## front and `up` of the way above it.
func _shot(rig: Node, ang: float, up := 0.1) -> Image:
	var body := rig.get_parent()
	body.process_mode = Node.PROCESS_MODE_DISABLED  # a still: the idle holds its pose
	await _frames(1)
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("head_2")
	var neck := skel.global_transform * skel.get_bone_global_pose(bone)
	var at := neck * Vector3(0, -0.02, 0.05)
	var turn := skel.global_transform.basis.get_euler().y
	var dir := Vector3(sin(deg_to_rad(ang) + turn), up, cos(deg_to_rad(ang) + turn)).normalized()
	_cam.fov = FOV
	_cam.look_at_from_position(at + dir * DIST, at, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	img.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cols: int, rows: int, file: String) -> void:
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in _cells:
		var pos := Vector2(int(c[1]) * CELL, int(c[2]) * (CELL + LABEL_H))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(c[0])
		tr.position = pos
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, CELL)
		lab.size = Vector2(CELL, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 11)
		board.add_child(lab)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(board)
	root.add_child(vp)
	await _frames(4)
	var path := OUT_DIR + "/" + file
	var err := vp.get_texture().get_image().save_png(path)
	vp.queue_free()
	print("Saved %s (%s)" % [path, error_string(err)])
