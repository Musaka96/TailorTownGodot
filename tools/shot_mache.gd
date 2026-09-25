extends SceneTree

## The papier-mache surface experiment on the real rig (CharacterRig.procedural_faces on;
## guide docs/FACE_STYLE_GUIDE.md, "Papier-mache surface"). NOT headless:
##   godot --path . --script res://tools/shot_mache.gd [-- drop | variants | zoom | flat]
##   ... -- variants only=a_grain,e_mache12   (columns / zoom rows from those presets instead)
##   ... -- variants zoom zoom_only=h_gpt_t3 out=mache_gpt   (zoom rows from their own list;
##   the sheets are then <out>.png and <out>_zoom.png)
## Writes to IMPORT/faces_proc/ (git-ignored), all on tripo_head_tl with paper_j1 at face
## scale 0.8, lit by the paper_char lights plus one raking key from the viewer's right:
##   mache_variants.png  columns = the PaperSurface presets in VARIANTS; rows = portrait
##                       (head ~500 px), normal view (head ~140 px, 1:1, like a dialogue
##                       portrait or the fitting screen), gameplay (head ~25 px, 4x nearest),
##                       and the hair from a raised three-quarter view
##   mache_zoom.png      3x closer (rendered, not upscaled) on the cheek, a hand, the hair and
##                       a face piece's edge, for the variants in ZOOM_VARIANTS
##   face_drop.png       the face 0.00 / 0.05 / 0.08 rect heights lower (FaceStyle.face_drop)
##                       on tripo_head_tl and tripo_bald_tr
##   pieces_flat.png     the default surface with the scan under the face pieces (before) and
##                       without it (after: each piece one flat sheet), then 3x on an eye, the
##                       nose and the mouth (after); only with `-- flat`
## The hair strand overlay is off throughout (it hides the surface; the owner's strands pick
## is still pending).

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE := "res://data/face_styles/paper_j1.tres"
const SURF_DIR := "res://data/paper_surfaces/"
const VARIANTS := [
	"a_grain",
	"b_paper001",
	"c_cardboard002",
	"d_paper003",
	"e_mache12",
	"e_mache20",
	"f_mache_scan",
	"g_mache_strong",
]
const ZOOM_VARIANTS := ["f_mache_scan", "g_mache_strong"]
const HEAD := "tripo_head_tl"
const DROP_HEADS := ["tripo_head_tl", "tripo_bald_tr"]
const DROPS := [0.0, 0.05, 0.08]
const OUT_DIR := "res://IMPORT/faces_proc"
const SKIN := Color(0.86, 0.72, 0.60)
const HAIR := Color(0.28, 0.18, 0.1)
const SIZE := Vector2i(1000, 1000)
const FOV := 35.0
const DIST := 2.4  # the head (hair included) ~580 px in the 1000 px view
const DIST_HEAD_PX := 580.0
const PORTRAIT_PX := 500.0
const NORMAL_PX := 140.0
const GAME_PX := 25.0
const GAME_CROP := 96
const UPSCALE := 4
const COL_W := 540
# row heights: portrait, normal view, gameplay, hair
const ROW_H := [540, 220, 390, 540]
const ROWS := ["portrait ~500 px", "normal view ~140 px (1:1)", "gameplay 25 px (4x)", "hair"]
const HAIR_VIEW := Vector2(40.0, 25.0)  # yaw, elevation (deg) of the hair row's camera
const ZOOM := 3.0
const ZOOM_CELL := 420
# zoom targets: label, point on the DIST portrait (px in the 1000 px view) or a bone
# (the camera then sits in front of it at the same distance)
const ZOOMS := [
	["cheek", Vector2(628, 600)],
	["hand", "hand.l"],
	["hair", Vector2(430, 262)],
	["nose / brow edge", Vector2(540, 540)],
]
const DROP_CELL := 420
# pieces_flat zoom targets, points on the DIST portrait (px in the 1000 px view)
const FLAT_ZOOMS := [
	["eye", Vector2(438, 498)],
	["nose", Vector2(524, 570)],
	["mouth", Vector2(530, 622)],
]
const FLAT_CELL := 540
const LABEL_H := 40
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _rig: Node3D  # CharacterRig (untyped: the class pulls in autoloads a --script lacks)
var _rig_script: Variant
var _vp: SubViewport
var _cam: Camera3D
var _head_y := 1.64
var _variants: Array = VARIANTS
var _zoom_variants: Array = ZOOM_VARIANTS
var _out := "mache"


func _initialize() -> void:
	_rig_script = load(RIG_SCRIPT)
	_rig_script.procedural_faces = true
	_rig_script.paper_hair_strands = false
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
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	# the raking key: low, from the viewer's right, so relief shows
	var rake := DirectionalLight3D.new()
	rake.rotation_degrees = Vector3(-12, 78, 0)
	rake.light_energy = 0.9
	world.add_child(rake)
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
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("only="):
			_variants = Array(a.trim_prefix("only=").split(","))
			_zoom_variants = _variants
	for a in args:
		if a.begins_with("zoom_only="):
			_zoom_variants = Array(a.trim_prefix("zoom_only=").split(","))
		elif a.begins_with("out="):
			_out = a.trim_prefix("out=")
	var all := not ("variants" in args or "zoom" in args or "drop" in args or "flat" in args)
	if all or "variants" in args:
		await _sheet_variants()
	if all or "zoom" in args:
		await _sheet_zoom()
	if all or "drop" in args:
		await _sheet_drop()
	if "flat" in args:
		await _sheet_flat()
	quit(0)


func _sheet_variants() -> void:
	_wear(_find_head(HEAD))
	var cells := []
	for c in _variants.size():
		var surf := _surface(_variants[c])
		await _settle()
		var label := _label(_variants[c], surf)
		_portrait(DIST_HEAD_PX / PORTRAIT_PX)
		cells.append([await _grab_center(ROW_H[0]), c, 0, label])
		_portrait(DIST_HEAD_PX / NORMAL_PX)
		cells.append([await _grab_center(ROW_H[1]), c, 1, label])
		_portrait(DIST_HEAD_PX / GAME_PX)
		cells.append([await _grab_game(), c, 2, label])
		_hair_view(DIST_HEAD_PX / PORTRAIT_PX)
		cells.append([await _grab_center(ROW_H[3]), c, 3, label])
	var file := "mache_variants.png" if _out == "mache" else _out + ".png"
	await _save_rows(cells, file)


func _sheet_zoom() -> void:
	_wear(_find_head(HEAD))
	var cells := []
	for r in _zoom_variants.size():
		_surface(_zoom_variants[r])
		await _settle()
		for c in ZOOMS.size():
			var z: Array = ZOOMS[c]
			_aim_zoom(z[1])
			var label := "%s  %s" % [z[0], _zoom_variants[r]]
			cells.append([await _grab_center(ZOOM_CELL), c, r, label])
	_cam.fov = FOV
	var n := _zoom_variants.size()
	await _save_grid(cells, ZOOMS.size(), n, _out + "_zoom.png", ZOOM_CELL)


## Aim the zoom camera at a point on the DIST portrait (Vector2, px) or at a bone (String),
## from the portrait's distance.
func _aim_zoom(at: Variant) -> void:
	_portrait(1.0)
	var target: Vector3
	if at is Vector2:
		target = _cam.project_position(at, DIST - 0.25)
	else:
		var skel := _rig.get("_skel") as Skeleton3D
		var pose := skel.get_bone_global_pose(skel.find_bone(at))
		target = skel.global_transform * pose.origin
		_cam.position = target + Vector3(0, 0, DIST - 0.25)
	_cam.fov = FOV / ZOOM
	_cam.look_at(target, Vector3.UP)


func _sheet_drop() -> void:
	var keep: float = FaceStyle.face_drop
	_surface("paper_mache")
	var cells := []
	for r in DROP_HEADS.size():
		_wear(_find_head(DROP_HEADS[r]))
		for c in DROPS.size():
			FaceStyle.face_drop = DROPS[c]
			_rig.call("_push_face")
			await _settle()
			_portrait(DIST_HEAD_PX / 400.0)
			var label := (
				"%s  face %.2f lower" % [String(DROP_HEADS[r]).trim_prefix("tripo_"), DROPS[c]]
			)
			if DROPS[c] == keep:
				label += " (default)"
			cells.append([await _grab_center(DROP_CELL), c, r, label])
	FaceStyle.face_drop = keep
	_rig.call("_push_face")
	await _save_grid(cells, DROPS.size(), DROP_HEADS.size(), "face_drop.png", DROP_CELL)


## The default surface with the scan under the face pieces (before) and without (after),
## then the after zoomed on an eye, the nose and the mouth.
func _sheet_flat() -> void:
	_wear(_find_head(HEAD))
	var after := load(SURF_DIR + "paper_mache.tres") as PaperSurface
	var before := after.duplicate() as PaperSurface
	before.piece_scan = 1.0
	before.piece_relief = 0.0
	var cells := []
	_use(before)
	await _settle()
	_portrait(DIST_HEAD_PX / PORTRAIT_PX)
	cells.append([await _grab_center(FLAT_CELL), 0, 0, "before: the scan runs under the pieces"])
	_use(after)
	await _settle()
	_portrait(DIST_HEAD_PX / PORTRAIT_PX)
	cells.append([await _grab_center(FLAT_CELL), 1, 0, "after: each piece one flat sheet"])
	for c in FLAT_ZOOMS.size():
		var z: Array = FLAT_ZOOMS[c]
		_aim_zoom(z[1])
		cells.append([await _grab_center(FLAT_CELL), c, 1, "%s 3x (after)" % z[0]])
	_cam.fov = FOV
	var file := "pieces_flat.png" if _out == "mache" else _out + ".png"
	await _save_grid(cells, FLAT_ZOOMS.size(), 2, file, FLAT_CELL)


## Put preset `key` on the skin and hair (CharacterRig.paper_surface) and return it.
func _surface(key: String) -> PaperSurface:
	var surf := load(SURF_DIR + key + ".tres") as PaperSurface
	_use(surf)
	return surf


## Put `surf` on the skin and hair.
func _use(surf: PaperSurface) -> void:
	_rig_script.paper_surface = surf
	_rig.call("_apply_skin")
	_rig.call("_apply_hair_color")
	_rig.call("_push_face")


## A preset's name and its numbers.
func _label(key: String, s: PaperSurface) -> String:
	var parts: Array[String] = [key]
	if s.scan_albedo_tex != null:
		var id := s.scan_albedo_tex.resource_path.get_file().trim_suffix("_albedo.jpg")
		parts.append(
			"%s x%.0f alb %.1f nrm %.1f" % [id, s.scan_scale, s.scan_albedo, s.normal_strength]
		)
	if s.mache_strength > 0.0 or s.mache_seam > 0.0 or s.mache_tone > 0.0:
		parts.append(
			(
				"strips %.1f/fu relief %.1f seam %.1f tone %.2f piece %.1f"
				% [s.mache_scale, s.mache_strength, s.mache_seam, s.mache_tone, s.piece_relief]
			)
		)
	if parts.size() == 1:
		parts.append("grain 0.10 only")
	return "\n".join([parts[0], " | ".join(parts.slice(1))])


## Frame the head from the front, `mult` x the portrait distance.
func _portrait(mult: float) -> void:
	_cam.fov = FOV
	var y := _head_y
	_cam.look_at_from_position(Vector3(0, y, DIST * mult), Vector3(0, y, 0), Vector3.UP)


## The hair from a raised three-quarter view.
func _hair_view(mult: float) -> void:
	_cam.fov = FOV
	var yaw := deg_to_rad(HAIR_VIEW.x)
	var el := deg_to_rad(HAIR_VIEW.y)
	var d := DIST * mult
	var at := Vector3(0, _head_y + 0.08, 0)
	var off := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el)) * d
	_cam.look_at_from_position(at + off, at, Vector3.UP)


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
	push_error("shot_mache: no head %s" % prefix)
	return 0


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


## The variants sheet: COL_W wide columns, ROW_H tall rows, a label under each column's top
## cell and a row name down the left.
func _save_rows(cells: Array, file: String) -> void:
	var y0 := [LABEL_H * 2]
	for r in ROW_H.size() - 1:
		y0.append(y0[r] + ROW_H[r] + LABEL_H)
	var size := Vector2i(COL_W * _variants.size(), y0[-1] + ROW_H[-1] + LABEL_H)
	var board := _board(size)
	for c: Array in cells:
		var col := int(c[1])
		var row := int(c[2])
		var img: Image = c[0]
		var pos := Vector2(col * COL_W, y0[row])
		_image(board, img, pos + (Vector2(COL_W, ROW_H[row]) - Vector2(img.get_size())) / 2.0)
		if row == 0:
			_text(board, c[3], Vector2(col * COL_W, 0), Vector2(COL_W, LABEL_H * 2))
		if col == 0:
			var at := Vector2(0, y0[row] + ROW_H[row])
			_text(board, ROWS[row], at, Vector2(COL_W, LABEL_H), HORIZONTAL_ALIGNMENT_LEFT)
	await _save_board(board, size, file)


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String, cell: int) -> void:
	var size := Vector2i(cell * cols, (cell + LABEL_H) * rows)
	var board := _board(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * cell, int(c[2]) * (cell + LABEL_H))
		var img: Image = c[0]
		_image(board, img, pos + (Vector2(cell, cell) - Vector2(img.get_size())) / 2.0)
		_text(board, c[3], pos + Vector2(0, cell), Vector2(cell, LABEL_H))
	await _save_board(board, size, file)


func _board(size: Vector2i) -> ColorRect:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	return board


func _image(board: Control, img: Image, pos: Vector2) -> void:
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = pos
	board.add_child(tr)


func _text(
	board: Control,
	text: String,
	pos: Vector2,
	size: Vector2,
	align := HORIZONTAL_ALIGNMENT_CENTER,
) -> void:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.size = size
	lab.horizontal_alignment = align
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_color_override("font_color", INK)
	lab.add_theme_font_size_override("font_size", 13)
	board.add_child(lab)


func _save_board(board: Control, size: Vector2i, file: String) -> void:
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
