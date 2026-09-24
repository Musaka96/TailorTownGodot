extends SceneTree

## Review sheets for the procedural faces (FaceStyle + face_element_canvas.gdshader), drawn
## in 2D with the rig's own FaceLayout proportions. NOT headless (it renders):
##   godot --path . --script res://tools/shot_faces.gd
## Writes to IMPORT/faces_proc/ (git-ignored):
##   sheet_presets.png  every preset (rows) in every expression state (columns)
##   sheet_scale.png    the presets at game size (~25 px head), upscaled 4x nearest
##   sheet_dials.png    the "round" preset with one dial swept per row
##   sheet_refs.png     the owner's reference faces H and K (IMPORT/faces_proc/ref/, a 4 x 3
##                      GPT-Image sheet) beside heavy_lid and old_timer in a few states, on
##                      kraft paper at the same head-disc size

const OUT_DIR := "res://IMPORT/faces_proc"
const STYLE_DIR := "res://data/face_styles/"
const CANVAS_SHADER := "res://assets/shaders/face_element_canvas.gdshader"
const PRESETS := ["round", "heavy_lid", "old_timer", "almond", "sleepy", "sparkle", "dots", "grump"]
const STATES := ["neutral", "blink_half", "closed", "happy", "sad", "angry", "surprised", "talking"]
const SKIN := Color("f2c9a6")
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")
const CELL := 256
const LABEL_H := 26
const FACE_SPAN := 0.78  # metres of face (FaceLayout units) across the skin disc
const FACE_MID_Y := -0.035  # FaceLayout y at the disc centre
const GAME_HEAD_PX := 25
const UPSCALE := 4
const DIAL_STEPS := 7
const REF_SHEET := "res://IMPORT/faces_proc/ref/style_sheet_HK.webp"
const REF_COLS := 4
const REF_ROWS := 3
const REF_MARGIN := Vector2(0.0175, 0.0471)  # sheet margin, fraction of the image size
const REF_DISC_Y := 0.474  # disc centre down each cell (the letter sits under it)
const REF_DISC := 0.783  # disc diameter / cell width
const REF_CROP := 1.12  # crop side / disc diameter
const KRAFT := Color("b9ab98")
const REF_STATES := ["neutral", "blink_half", "closed", "happy", "talking"]
# reference row: letter, column, row, preset
const REFS := [["H", 3, 1, "heavy_lid"], ["K", 2, 2, "old_timer"]]
# dial row: label, field, from, to
const DIALS := [
	["openness 1>0", "openness", 1.0, 0.0],
	["squint 0>1", "squint", 0.0, 1.0],
	["mouth_curve -1>1", "mouth_curve", -1.0, 1.0],
	["mouth_open 0>1", "mouth_open", 0.0, 1.0],
	["gaze x L>R", "gaze", -0.22, 0.22],
	["iris_radius", "iris_radius", 0.3, 0.56],
]

var _shader: Shader
var _layout: FaceLayout


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	_shader = load(CANVAS_SHADER) as Shader
	_layout = FaceProfiles.load_or_default().layout_for(0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var styles := {}
	for p: String in PRESETS:
		styles[p] = load(STYLE_DIR + p + ".tres") as FaceStyle
	var t := Time.get_ticks_msec()
	await _sheet_presets(styles)
	print("sheet_presets: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	await _sheet_scale(styles)
	print("sheet_scale: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	await _sheet_dials(styles["round"])
	print("sheet_dials: %d ms" % (Time.get_ticks_msec() - t))
	await _sheet_refs(styles)
	quit(0)


func _sheet_presets(styles: Dictionary) -> void:
	var size := Vector2i(CELL * STATES.size(), (CELL + LABEL_H) * PRESETS.size())
	var board := _board(size)
	for r in PRESETS.size():
		var style: FaceStyle = styles[PRESETS[r]]
		for c in STATES.size():
			var pos := Vector2(c * CELL, r * (CELL + LABEL_H))
			var face := _face(style, style.expression(STATES[c]), CELL - 24, false)
			face.position = pos + Vector2(12, 8)
			board.add_child(face)
			var text := "%s / %s" % [PRESETS[r], STATES[c]]
			board.add_child(_label(text, pos + Vector2(0, CELL - 14), CELL))
	await _save(board, size, "sheet_presets.png")


func _sheet_scale(styles: Dictionary) -> void:
	# game size: hard-edged (as the alpha-cut sprites draw) above, soft below
	var cell := GAME_HEAD_PX + 9
	var small := Vector2i(cell * PRESETS.size(), cell * 2)
	var board := _board(small)
	for c in PRESETS.size():
		for row in 2:
			var style: FaceStyle = styles[PRESETS[c]]
			var face := _face(style, {}, GAME_HEAD_PX, row == 0)
			face.position = Vector2(c * cell + 4, row * cell + 4)
			board.add_child(face)
	var img := await _render(board, small)
	img.resize(small.x * UPSCALE, small.y * UPSCALE, Image.INTERPOLATE_NEAREST)
	# label the upscaled strip
	var size := Vector2i(img.get_width() + 150, img.get_height() + LABEL_H + 8)
	var sheet := _board(size)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = Vector2(150, LABEL_H + 8)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.add_child(tr)
	for c in PRESETS.size():
		sheet.add_child(_label(PRESETS[c], Vector2(150 + c * cell * UPSCALE, 4), cell * UPSCALE))
	sheet.add_child(_label("alpha cut", Vector2(0, LABEL_H + 8 + cell * UPSCALE * 0.4), 150))
	sheet.add_child(_label("soft", Vector2(0, LABEL_H + 8 + cell * UPSCALE * 1.4), 150))
	await _save(sheet, size, "sheet_scale.png")


func _sheet_dials(style: FaceStyle) -> void:
	var cell := 200
	var size := Vector2i(160 + cell * DIAL_STEPS, (cell + 8) * DIALS.size())
	var board := _board(size)
	for r in DIALS.size():
		var d: Array = DIALS[r]
		var y := r * (cell + 8)
		board.add_child(_label(d[0], Vector2(0, y + cell * 0.45), 160))
		for c in DIAL_STEPS:
			var k := float(c) / float(DIAL_STEPS - 1)
			var val := lerpf(d[2], d[3], k)
			var dials := {}
			dials[d[1]] = Vector2(val, style.gaze.y) if d[1] == "gaze" else val
			var face := _face(style, dials, cell - 16, false)
			face.position = Vector2(160 + c * cell + 8, y + 4)
			board.add_child(face)
	await _save(board, size, "sheet_dials.png")


func _sheet_refs(styles: Dictionary) -> void:
	var ref := Image.new()
	var err := ref.load_webp_from_buffer(FileAccess.get_file_as_bytes(REF_SHEET))
	if err != OK:
		push_error("shot_faces: cannot read %s (%s)" % [REF_SHEET, error_string(err)])
		return
	var cols := 1 + REF_STATES.size()
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * REFS.size())
	var board := _board(size)
	board.color = KRAFT
	var disc := CELL / REF_CROP
	for r in REFS.size():
		var row: Array = REFS[r]
		var y := r * (CELL + LABEL_H)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_ref_cell(ref, row[1], row[2]))
		tr.position = Vector2(0, y)
		board.add_child(tr)
		board.add_child(_label("reference " + String(row[0]), Vector2(0, y + CELL - 6), CELL))
		var style: FaceStyle = styles[row[3]]
		for c in REF_STATES.size():
			var face := _face(style, style.expression(REF_STATES[c]), disc, false)
			face.position = Vector2((c + 1) * CELL, y) + Vector2.ONE * (CELL - disc) * 0.5
			board.add_child(face)
			var text := "%s / %s" % [row[3], REF_STATES[c]]
			board.add_child(_label(text, Vector2((c + 1) * CELL, y + CELL - 6), CELL))
	await _save(board, size, "sheet_refs.png")


## Square crop of one lettered face on the reference sheet, the disc REF_CROP times
## smaller than the crop, scaled to CELL.
func _ref_cell(ref: Image, col: int, row: int) -> Image:
	var full := Vector2(ref.get_size())
	var margin := full * REF_MARGIN
	var cell := (full - margin * 2.0) / Vector2(REF_COLS, REF_ROWS)
	var centre := margin + cell * Vector2(col + 0.5, row + REF_DISC_Y)
	var side := roundi(cell.x * REF_DISC * REF_CROP)
	var rect := Rect2i(Vector2i(centre - Vector2.ONE * side * 0.5), Vector2i(side, side))
	var img := ref.get_region(rect)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return img


## One face: a skin disc with both eyes, both brows, the nose and the mouth laid out from
## the rig's FaceLayout (metres mapped onto the disc).
func _face(style: FaceStyle, dials: Dictionary, diameter: float, alpha_cut: bool) -> Control:
	var root := Control.new()
	root.size = Vector2(diameter, diameter)
	var disc := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SKIN
	sb.set_corner_radius_all(int(diameter * 0.5))
	sb.corner_detail = 32
	sb.anti_aliasing = not alpha_cut
	disc.add_theme_stylebox_override("panel", sb)
	disc.size = root.size
	root.add_child(disc)
	var m2p := diameter / FACE_SPAN
	var l := _layout
	var e := FaceStyle.Element
	var parts := [
		[e.BROW, -l.brow_gap * 0.5 + l.brow_x, l.brow_y, l.brow_px, false, l.brow_scale],
		[e.BROW, l.brow_gap * 0.5 + l.brow_x, l.brow_y, l.brow_px, true, l.brow_scale],
		[e.EYE, -l.eye_gap * 0.5 + l.eye_x, l.eye_y, l.eye_px, false, l.eye_scale],
		[e.EYE, l.eye_gap * 0.5 + l.eye_x, l.eye_y, l.eye_px, true, l.eye_scale],
		[e.NOSE, l.nose_x, l.nose_y, l.nose_px, false, l.nose_scale],
		[e.MOUTH, l.mouth_x, l.mouth_y, l.mouth_px, false, l.mouth_scale],
	]
	for part: Array in parts:
		var el: int = part[0]
		var side: float = FaceStyle.QUAD_PX[el] * float(part[3]) * m2p
		var rect := ColorRect.new()
		rect.size = Vector2(side, side)
		rect.pivot_offset = rect.size * 0.5
		var centre := Vector2(float(part[1]), -(float(part[2]) - FACE_MID_Y)) * m2p
		rect.position = root.size * 0.5 + centre - rect.size * 0.5
		var scl: Vector3 = part[5]
		rect.scale = Vector2(-scl.x if part[4] else scl.x, scl.y)
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("alpha_cut", alpha_cut)
		rect.material = mat
		style.apply(rect, el, dials, part[4])
		root.add_child(rect)
	return root


func _board(size: Vector2i) -> Control:
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	return board


func _label(text: String, pos: Vector2, width: float) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.size = Vector2(width, LABEL_H)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", INK)
	lab.add_theme_font_size_override("font_size", 16)
	return lab


func _render(board: Control, size: Vector2i) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(board)
	root.add_child(vp)
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _save(board: Control, size: Vector2i, file: String) -> void:
	var img := await _render(board, size)
	var path := OUT_DIR + "/" + file
	var err := img.save_png(path)
	print("Saved %s (%s)" % [path, error_string(err)])
