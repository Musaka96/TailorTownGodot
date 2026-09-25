extends SceneTree

## Paper skin and hair on the real rig (CharacterRig.procedural_faces on; guide
## docs/FACE_STYLE_GUIDE.md, "Paper skin and hair"). NOT headless:
##   godot --path . --script res://tools/shot_paper_char.gd
## Writes to IMPORT/faces_proc/ (git-ignored):
##   paper_char.png       tripo_bald_tr and tripo_head_tl (paper_j1, face scale 0.8), columns
##                        before | paper skin | paper skin + hair, strands kept | paper skin
##                        + hair, flat; per head a portrait row (head ~500 px) and a gameplay
##                        row (head ~25 px, upscaled 4x nearest)
##   paper_char_zoom.png  4x closer (rendered, not upscaled) on tripo_head_tl: cheek, hair
##                        edge with and without strands, hand, the eye wedge (straight cuts),
##                        the nose (jagged cut)
## "before" is the J1 commit's head shader when .dev/before/skin_face.gdshader exists (the
## committed shaders copied there, a dev-only snapshot), else today's shader with no skin
## grain; either way the arms and hair are the old flat material.

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE := "res://data/face_styles/paper_j1.tres"
const BEFORE_SHADER := "res://.dev/before/skin_face.gdshader"
const HEADS := ["tripo_bald_tr", "tripo_head_tl"]
const ZOOM_HEAD := "tripo_head_tl"
const VARIANTS := ["before", "paper skin", "skin + hair, strands", "skin + hair, flat"]
const OUT_DIR := "res://IMPORT/faces_proc"
const SKIN := Color(0.86, 0.72, 0.60)
const HAIR := Color(0.28, 0.18, 0.1)
const SIZE := Vector2i(1000, 1000)
const FOV := 35.0
const DIST := 2.4  # portrait: the head (hair included) ~580 px in the 1000 px view
const PORTRAIT_HEAD_PX := 580.0  # measured on the sheet
const GAME_HEAD_PX := 25.0
const GAME_CROP := 96  # px round the character at gameplay size, shown 4x
const UPSCALE := 4
const CELL := 720
const ZOOM := 4.0
const ZOOM_CELL := 400
# the zoom targets: label, variant, point on the portrait (px in the 1000 px view), or a bone
const ZOOMS := [
	["cheek", 3, Vector2(640, 600)],
	["hair edge, strands", 2, Vector2(470, 320)],
	["hair edge, flat", 3, Vector2(470, 320)],
	["hand", 3, "hand.r"],
	["eye wedge (straight cuts)", 3, Vector2(462, 452)],
	["nose (jagged cut)", 3, Vector2(522, 538)],
]
const LABEL_H := 26
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _rig: Node3D  # CharacterRig (untyped: the class pulls in autoloads a --script lacks)
var _rig_script: Variant
var _vp: SubViewport
var _cam: Camera3D
var _head_y := 1.64
var _before: Shader


func _initialize() -> void:
	_rig_script = load(RIG_SCRIPT)
	_rig_script.procedural_faces = true
	if ResourceLoader.exists(BEFORE_SHADER):
		_before = load(BEFORE_SHADER) as Shader
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as Node3D
	world.add_child(_rig)
	_head_y = FaceProfiles.load_or_default().layout_for(0).head_y
	_cam = Camera3D.new()
	_cam.fov = FOV
	world.add_child(_cam)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var suit := load(SUIT) as MaterialType
	_rig.set_palette(SKIN)
	_rig.set_outfit(suit, null, suit, 0, 0)
	_rig.call("set_hair_color", HAIR)
	_rig.set("face_style", load(STYLE) as FaceStyle)
	(_rig.get("_blink") as Timer).stop()  # no random blink mid-capture
	await _sheet_char()
	await _sheet_zoom()
	_rig_script.paper_hair_strands = true
	quit(0)


func _sheet_char() -> void:
	var cells := []
	for h in HEADS.size():
		_wear(_find_head(HEADS[h]))
		for v in VARIANTS.size():
			_variant(v)
			await _settle()
			_portrait(1.0, _head_y)
			cells.append([await _grab_center(CELL), v, 2 * h, "%s  %s" % [_short(h), VARIANTS[v]]])
			_portrait(PORTRAIT_HEAD_PX / GAME_HEAD_PX, _head_y)
			var small := await _grab_game()
			cells.append([small, v, 2 * h + 1, "%s  %s  (25 px, 4x)" % [_short(h), VARIANTS[v]]])
	await _save_grid(cells, VARIANTS.size(), 2 * HEADS.size(), "paper_char.png", CELL)


func _sheet_zoom() -> void:
	_wear(_find_head(ZOOM_HEAD))
	var cells := []
	for i in ZOOMS.size():
		var z: Array = ZOOMS[i]
		_variant(z[1])
		await _settle()
		_portrait(1.0, _head_y)
		var target: Vector3
		if z[2] is Vector2:
			target = _cam.project_position(z[2], DIST - 0.25)
		else:
			var skel: Skeleton3D = _rig.get("_skel")
			var bone := skel.find_bone(z[2])
			target = skel.global_transform * skel.get_bone_global_pose(bone).origin
		_cam.fov = FOV / ZOOM
		_cam.look_at(target, Vector3.UP)
		await _frames(3)
		cells.append([await _grab_center(ZOOM_CELL), i % 3, i / 3, z[0]])
	_cam.fov = FOV
	await _save_grid(cells, 3, 2, "paper_char_zoom.png", ZOOM_CELL)


## Frame the head from the front; `mult` x the portrait distance (the gameplay row backs
## off until the head is ~25 px).
func _portrait(mult: float, y: float) -> void:
	_cam.fov = FOV
	_cam.look_at_from_position(Vector3(0, y, DIST * mult), Vector3(0, y, 0), Vector3.UP)


## Materials for one column (see VARIANTS): the rig's paper look, then the old flat
## materials put back where the column wants them.
func _variant(v: int) -> void:
	_rig_script.paper_hair_strands = v != 3
	_rig.call("_apply_skin")
	_rig.call("_apply_hair_color")
	var head_mat: ShaderMaterial = _rig.get("_skin_face")
	head_mat.shader = load("res://assets/shaders/skin_face.gdshader") as Shader
	head_mat.set_shader_parameter("skin_grain", 0.1)
	if v == 0:
		if _before != null:
			head_mat.shader = _before
		else:
			head_mat.set_shader_parameter("skin_grain", 0.0)
		var arms: Variant = (_rig.get("_top") as Dictionary).get("arms", _rig.get("_base_arms"))
		if arms is MeshInstance3D:
			arms.material_override = _rig.call("_flat", SKIN, 0.7)
	if v <= 1:
		var hair: Variant = (_rig.get("_hair") as Dictionary).get("hair")
		if hair is MeshInstance3D:
			hair.material_override = _rig.call("_flat", HAIR, 0.85)
	_rig.call("_push_face")


func _wear(head: int) -> void:
	_rig.call("set_head", head)
	_rig.call("set_hair", head)
	_rig.set_palette(SKIN)
	_rig.call("set_hair_color", HAIR)


func _find_head(prefix: String) -> int:
	var lib := Wardrobe.library()
	for i in lib.head_count():
		if String(lib.head(i).display_name).begins_with(prefix):
			return i
	push_error("shot_paper_char: no head %s" % prefix)
	return 0


func _short(h: int) -> String:
	return String(HEADS[h]).trim_prefix("tripo_")


func _settle() -> void:
	_rig.call("_proc_expression", "")
	await create_timer(0.1).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A `side` px square from the middle of the view.
func _grab_center(side: int) -> Image:
	await _frames(3)
	var img := _vp.get_texture().get_image()
	return img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))


## The gameplay-size crop round the head (a little below it, so the hands show), 4x nearest.
func _grab_game() -> Image:
	await _frames(3)
	var img := _vp.get_texture().get_image()
	var c := Vector2i(SIZE.x / 2, SIZE.y / 2 + GAME_CROP / 4)
	var side := Vector2i(GAME_CROP, GAME_CROP)
	var crop := img.get_region(Rect2i(c - side / 2, side))
	crop.resize(GAME_CROP * UPSCALE, GAME_CROP * UPSCALE, Image.INTERPOLATE_NEAREST)
	return crop


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String, cell: int) -> void:
	var size := Vector2i(cell * cols, (cell + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * cell, int(c[2]) * (cell + LABEL_H))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(c[0])
		tr.position = pos + (Vector2(cell, cell) - Vector2(c[0].get_size())) / 2.0
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, cell)
		lab.size = Vector2(cell, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", INK)
		lab.add_theme_font_size_override("font_size", 15)
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
