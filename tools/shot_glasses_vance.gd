extends SceneTree

## Before/after sheet for the pince-nez fit (GlassesFit.TEMPLE_MIN_SCALE): Dr. Vance and
## Ms. Portobello, whose rims shrink to fit their close-set eyes, dressed through the game's
## own path (customer.tscn dressed by CustomerManager._dress). "Before" is the fit with its
## temples kept (GlassesFit._build with bare = false); "after" is the live _place_glasses.
## Each is shown at 0, 30, 45 and 90 degrees and in the dialogue portrait. The last rows
## are twelve passers-by dressed by _dress, re-rolled until each wears glasses (as if
## GLASSES_CHANCE were 1), with the kinds they got; the retired styles never show. NOT
## headless:
##   godot --path . --script res://tools/shot_glasses_vance.gd
## Writes IMPORT/faces_proc/glasses_vance.png (git-ignored).

const CUSTOMER_SCENE := "res://entities/customer/customer.tscn"
const MANAGER_SCRIPT := "res://entities/customer/customer_manager.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const PORTRAIT_SCRIPT := "res://ui/customer_portrait.gd"
const NAMES := ["Dr. Vance", "Ms. Portobello"]
## The head combo each wears (-1: as dressed). Dr. Vance's rims shrink on every head but
## 0 (0.74 to 0.82); head 3 is his 0.82. Ms. Portobello's one head keeps her rims at 1.
const HEADS := [3, -1]
const ANGLES := [0.0, 30.0, 45.0, 90.0]
const PASSERS := 12
const PASSER_COLS := 6
const STAT_ROLLS := 400
const OUT_DIR := "res://IMPORT/faces_proc"
const SIZE := Vector2i(700, 700)
const CELL := 300
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
	var y := 0
	for i in NAMES.size():
		var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
		_world.add_child(cust)
		cust.set_physics_process(false)
		cust.preference = pref_cls.random_pref(RandomNumberGenerator.new(), NAMES[i])
		manager.call("_dress", cust)
		var rig: Node = cust.get_node("Rig")
		if HEADS[i] >= 0:
			cust.call("set_hair", HEADS[i])
			rig.call("set_head", HEADS[i])
		await _frames(3)
		var grow := _grow(rig)
		for after in [false, true]:
			var tag := "after" if after else "before"
			for a in ANGLES.size():
				cust.rotation_degrees.y = ANGLES[a]
				_fit(rig, after)
				var label := (
					"%s %d deg, %s (head %d, rims %.2f)"
					% [NAMES[i], ANGLES[a], tag, rig.get("_head_index"), grow]
				)
				cells.append([await _close_up(rig, CELL), Vector2i(a * CELL, y), label])
			cust.rotation_degrees.y = 0.0
			var img: Image = await _portrait(cust, after)
			cells.append([img, Vector2i(ANGLES.size() * CELL, y), "dialogue, %s" % tag])
			y += CELL + LABEL_H
		cust.queue_free()
	await _frames(2)
	y = await _passers(manager, cells, y)
	manager.free()
	await _save_grid(cells, Vector2i(CELL * (ANGLES.size() + 1), y), "glasses_vance.png")
	quit(0)


## Twelve passers-by through _dress, each re-rolled (a new seed) until it wears glasses,
## laid out PASSER_COLS to a row; prints the kinds over STAT_ROLLS dressed passers-by.
func _passers(manager: Node, cells: Array, y: int) -> int:
	var rng: RandomNumberGenerator = manager.get("_rng")
	var counts := {}
	var probe: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
	_world.add_child(probe)
	probe.set_physics_process(false)
	for s in STAT_ROLLS:
		rng.seed = 1000 + s
		manager.call("_dress", probe)
		var kind: String = probe.get("glasses")
		counts[kind] = int(counts.get(kind, 0)) + 1
	probe.queue_free()
	print("glasses kinds over %d passers-by: %s" % [STAT_ROLLS, counts])
	var cell := CELL * (ANGLES.size() + 1) / PASSER_COLS
	var next_seed := 5000
	var got := PackedStringArray()
	for n in PASSERS:
		var cust: Node3D = (load(CUSTOMER_SCENE) as PackedScene).instantiate()
		_world.add_child(cust)
		cust.set_physics_process(false)
		while true:
			next_seed += 1
			rng.seed = next_seed
			manager.call("_dress", cust)
			if cust.get("glasses") != "":
				break
		await _frames(3)
		var kind: String = cust.get("glasses")
		got.append(kind)
		var pos := Vector2i((n % PASSER_COLS) * cell, y + (n / PASSER_COLS) * (cell + LABEL_H))
		var label := "passer-by %d: %s" % [n + 1, kind]
		cells.append([await _close_up(cust.get_node("Rig"), cell), pos, label])
		cust.queue_free()
	print("twelve passers-by wear: %s" % ", ".join(got))
	var rows := ceili(float(PASSERS) / PASSER_COLS)
	y += rows * (cell + LABEL_H)
	var dealt := ", ".join(Wardrobe.wearable_glasses_kinds())
	var note := (
		"A customer's glasses come from: %s (never %s). Over %d passers-by: %s"
		% [dealt, ", ".join(Wardrobe.library().retired_glasses), STAT_ROLLS, counts]
	)
	cells.append([null, Vector2i(0, y), note])
	return y + LABEL_H


## The rim scale the fit uses for this rig's frames.
func _grow(rig: Node) -> float:
	var meshes: Array = rig.get("_glasses_meshes")
	if meshes.is_empty():
		return 1.0
	var mi: MeshInstance3D = meshes[0]
	var style: FaceStyle = rig.get("face_style")
	var frame: FaceFrame = rig.get("_face_frame")
	var lens := GlassesFit.measure(mi.get_meta("src"), mi.get_meta("bind"))
	var eye := GlassesFit.eye_point(style, frame)
	return GlassesFit.rim_grow(lens, eye.x, GlassesFit.eye_radius(style, frame))


## after = the live fit; before = the same fit with the temples kept.
func _fit(rig: Node, after: bool) -> void:
	rig.call("_place_glasses")
	if after:
		return
	var style: FaceStyle = rig.get("face_style")
	var frame: FaceFrame = rig.get("_face_frame")
	for mi: MeshInstance3D in rig.get("_glasses_meshes"):
		var src: Mesh = mi.get_meta("src")
		var bind: Transform3D = mi.get_meta("bind")
		var lens := GlassesFit.measure(src, bind)
		var eye := GlassesFit.eye_point(style, frame)
		var grow := GlassesFit.rim_grow(lens, eye.x, GlassesFit.eye_radius(style, frame))
		var at := Vector2(eye.x, eye.y - GlassesFit.GLASSES_HANG)
		mi.mesh = GlassesFit._build(src, bind, lens, at, grow, false)


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


## The dialogue portrait (CustomerPortrait) for a customer, glasses before or after.
func _portrait(cust: Node, after: bool) -> Image:
	var portrait: Control = load(PORTRAIT_SCRIPT).new()
	root.add_child(portrait)
	await _frames(2)
	portrait.call("configure", cust)
	portrait.call("set_live", true)
	var rig: Node = portrait.get("_rig")
	(rig.get("_blink") as Timer).stop()
	rig.call("set_talking", false)
	_fit(rig, after)
	await _frames(8)
	var view: SubViewport = portrait.get("_view")
	var img := view.get_texture().get_image()
	img.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	portrait.queue_free()
	return img


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Lay out [image (or null for a text line), top-left, label] cells on paper and save.
func _save_grid(cells: Array, size: Vector2i, file: String) -> void:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(c[1])
		var img: Image = c[0]
		var w := float(size.x)
		if img != null:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.position = pos
			board.add_child(tr)
			pos.y += img.get_height()
			w = img.get_width()
		var lab := Label.new()
		lab.text = c[2]
		lab.position = pos
		lab.size = Vector2(w, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 13)
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
