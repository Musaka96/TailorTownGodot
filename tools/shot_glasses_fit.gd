extends SceneTree

## Before/after sheet for the glasses fit (GlassesFit): the cast who wear glasses, dressed
## through the game's own path as tools/shot_live_cast.gd does (customer.tscn dressed by
## CustomerManager._dress; Mr. Hemming as the tutorial's look). "Before" re-creates the old
## placement (the whole mesh scaled across by eye_spacing / 0.226, lenses at the modelled
## height); "after" is the live _place_glasses. NOT headless:
##   godot --path . --script res://tools/shot_glasses_fit.gd
## Writes IMPORT/faces_proc/glasses_fix.png (git-ignored): per character the head in the
## world (portrait size) and the dialogue portrait, before and after; the last row turns
## Dr. Vance 45 degrees (temples and bridge).

const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const RIG_SCENE := "res://entities/character/character_rig.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const PORTRAIT_SCRIPT := "res://ui/customer_portrait.gd"
const MENTOR_SCRIPT := "res://ui/tutorial/mentor_dialog.gd"
const NAMES := ["Mr. Pettigrew", "Ms. Portobello", "Dr. Vance"]
const TURN_WHO := 2  # NAMES index for the 45 degree row
const OLD_SPACING := 0.226
const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(700, 700)
const CELL := 360
const LABEL_H := 40
const SPACING := 3.0
const DIST := 2.2
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
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
	_cam.fov = 35
	_world.add_child(_cam)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var cells := []
	var manager: Node = load(MANAGER_SCRIPT).new()
	var pref_cls: GDScript = load(PREF_SCRIPT)
	var customers := []
	for i in NAMES.size():
		var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
		_world.add_child(cust)
		cust.global_position = Vector3(SPACING * i, 0.0, 0.0)
		cust.set_physics_process(false)
		cust.preference = pref_cls.random_pref(RandomNumberGenerator.new(), NAMES[i])
		manager.call("_dress", cust)
		customers.append(cust)
	manager.free()
	var mentor: Node = load(MENTOR_SCRIPT).new()
	var look: Dictionary = mentor.call("_look")
	mentor.free()
	var hemming: Node3D = (load(RIG_SCENE) as PackedScene).instantiate()
	_world.add_child(hemming)
	hemming.global_position = Vector3(SPACING * NAMES.size(), 0.0, 0.0)
	_configure_look(hemming, look)
	await _frames(3)
	var rigs: Array = []
	for cust: Node3D in customers:
		rigs.append(cust.get_node("Rig"))
	rigs.append(hemming)
	var names: Array = NAMES.duplicate()
	names.append("Mr. Hemming")
	for i in rigs.size():
		var rig: Node = rigs[i]
		_report(names[i], rig)
		for after in [false, true]:
			_fit(rig, after)
			var tag := "after" if after else "before"
			var col := 2 if after else 0
			cells.append([await _close_up(rig, CELL), col, i, "%s, %s" % [names[i], tag]])
			var img: Image
			if i < customers.size():
				img = await _portrait(customers[i], {}, after)
			else:
				img = await _portrait(null, look, after)
			cells.append([img, col + 1, i, "dialogue, %s" % tag])
	var turn: Node3D = customers[TURN_WHO]
	turn.rotation_degrees.y = 45.0
	for after in [false, true]:
		var rig: Node = turn.get_node("Rig")
		_fit(rig, after)
		var label := "%s 45 deg, %s" % [NAMES[TURN_WHO], "after" if after else "before"]
		cells.append([await _close_up(rig, CELL), 2 if after else 0, rigs.size(), label])
	await _save_grid(cells, 4, rigs.size() + 1, "glasses_fix.png")
	quit(0)


## CustomerPortrait.configure_look's steps on a world rig (the mentor's close-up).
func _configure_look(rig: Node, look: Dictionary) -> void:
	rig.call("set_head", int(look.get("head", 0)))
	rig.call("set_hair", int(look.get("hair", 0)))
	if look.has("skin"):
		rig.call("set_palette", look["skin"])
	if look.has("hair_color"):
		rig.call("set_hair_color", look["hair_color"])
	rig.set("glasses_color", str(look.get("glasses_color", "black")))
	rig.call("set_face_look", str(look.get("eyes", "brown")), str(look.get("glasses", "")))
	rig.set("face_style", FaceCast.style(str(look.get("face_style", ""))))
	var suit: MaterialType = look.get("suit")
	if suit != null:
		rig.call("set_outfit", suit, null, suit)


## after = the live fit; before = the old placement (mesh as modelled, scaled across by
## eye_spacing / OLD_SPACING about the head bone, at the same depth).
func _fit(rig: Node, after: bool) -> void:
	rig.call("_place_glasses")
	if after:
		return
	var style: FaceStyle = rig.get("face_style")
	for mi: MeshInstance3D in rig.get("_glasses_meshes"):
		var bind: Transform3D = mi.get_meta("bind")
		var dz := (bind.affine_inverse() * mi.transform).origin.z
		var across := style.eye_spacing / OLD_SPACING
		mi.mesh = mi.get_meta("src")
		mi.transform = (
			bind * Transform3D(Basis.from_scale(Vector3(across, 1, 1)), Vector3(0, 0, dz))
		)


func _report(who: String, rig: Node) -> void:
	var style: FaceStyle = rig.get("face_style")
	var frame: FaceFrame = rig.get("_face_frame")
	var meshes: Array = rig.get("_glasses_meshes")
	if style == null or frame == null or meshes.is_empty():
		print("%s: no fit (style %s, frame %s, glasses %d)" % [who, style, frame, meshes.size()])
		return
	var mi: MeshInstance3D = meshes[0]
	var lens := GlassesFit.measure(mi.get_meta("src"), mi.get_meta("bind"))
	var eye := GlassesFit.eye_point(style, frame)
	var er := GlassesFit.eye_radius(style, frame)
	print(
		(
			"%s (%s, head %d): eye (%.3f, %.3f) r %.3f | lens centre %s r %.3f | grow %.2f"
			% [
				who,
				style.resource_path.get_file(),
				rig.get("_head_index"),
				eye.x,
				eye.y,
				er,
				lens.c,
				lens.r,
				GlassesFit.rim_grow(lens, eye.x, er),
			]
		)
	)


## The rig's head from the front, framed on the head bone, `cell` pixels square.
func _close_up(rig: Node, cell: int) -> Image:
	var blink: Timer = rig.get("_blink")
	if blink != null:
		blink.stop()
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := (rig as Node3D).global_position + Vector3(0, 1.5, 0)
	if skel != null:
		var bone := skel.find_bone("head_2")
		head = skel.global_transform * skel.get_bone_global_pose(bone).origin
	var at := head + Vector3(0, 0.36, 0)
	_cam.look_at_from_position(at + Vector3(0, 0, DIST), at, Vector3.UP)
	await _frames(4)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.8)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	return crop


## The dialogue portrait (CustomerPortrait) for a customer, or for a plain look when
## `cust` is null (the mentor), with the glasses placed before or after.
func _portrait(cust: Node, look: Dictionary, after: bool) -> Image:
	var portrait: Control = load(PORTRAIT_SCRIPT).new()
	root.add_child(portrait)
	await _frames(2)
	if cust != null:
		portrait.call("configure", cust)
	else:
		portrait.call("configure_look", look)
	portrait.call("set_live", true)
	var rig: Node = portrait.get("_rig")
	(rig.get("_blink") as Timer).stop()
	rig.call("set_talking", false)
	_fit(rig, after)
	await _frames(8)
	var view: SubViewport = portrait.get("_view")
	var img := view.get_texture().get_image()
	portrait.queue_free()
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String) -> void:
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * CELL, int(c[2]) * (CELL + LABEL_H))
		var img: Image = c[0]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = pos + (Vector2(CELL, CELL) - Vector2(img.get_size())) * 0.5
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, CELL)
		lab.size = Vector2(CELL, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 14)
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
