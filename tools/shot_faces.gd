extends SceneTree

## Review sheets for the procedural faces (FaceStyle + face_element_canvas.gdshader), drawn
## in 2D with the rig's own FaceLayout proportions. NOT headless (it renders):
##   godot --path . --script res://tools/shot_faces.gd
## Writes to IMPORT/faces_proc/ (git-ignored):
##   sheet_presets.png  every preset (rows) in every expression state (columns)
##   sheet_scale.png    the presets at game size (~25 px head), upscaled 4x nearest
##   sheet_dials.png    heavy_lid with one dial swept per row
##   sheet_refs.png     each preset's reference face (IMPORT/faces_proc/ref/, two 4 x 3
##                      GPT-Image sheets) beside the preset in a few states, on kraft paper
##                      at the same head-disc size; a last row sets the D1 and J1 mouths
##                      beside the grin and the laugh at twice that size

const OUT_DIR := "res://IMPORT/faces_proc"
const STYLE_DIR := "res://data/face_styles/"
const CANVAS_SHADER := "res://assets/shaders/face_element_canvas.gdshader"
const PRESETS := ["heavy_lid", "old_timer", "moustache", "big_eyes", "wink", "blush", "laugh"]
const STATES := [
	"neutral",
	"blink_half",
	"closed",
	"happy",
	"sad",
	"displeased",
	"angry",
	"surprised",
	"talking",
]
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
const REF_DIR := "res://IMPORT/faces_proc/ref/"
const REF_DISC := 247.0  # head-disc diameter on both reference sheets, px
const REF_CROP := 1.12  # crop side / disc diameter
const KRAFT := Color("b9ab98")
const REF_STATES := ["neutral", "blink_half", "closed", "happy", "sad", "talking"]
# reference row: label, sheet, disc centre (px, measured), preset
const REFS := [
	["H1", "style_sheet_HK.webp", Vector2(1130, 587), "heavy_lid"],
	["K1", "style_sheet_HK.webp", Vector2(813, 951), "old_timer"],
	["F2", "style_sheet_2.webp", Vector2(494, 591), "moustache"],
	["I2", "style_sheet_2.webp", Vector2(177, 956), "big_eyes"],
	["J2", "style_sheet_2.webp", Vector2(495, 956), "wink"],
	["K2", "style_sheet_2.webp", Vector2(816, 956), "blush"],
	["L2", "style_sheet_2.webp", Vector2(1136, 957), "laugh"],
]
# mouth row: label, sheet, disc centre, ours, the dials that size our mouth like the reference
const MOUTH_REFS := [
	[
		"D1",
		"style_sheet_HK.webp",
		Vector2(1130, 227),
		"grin (teeth)",
		{
			"mouth_width": 1.29,
			"mouth_center": Vector2(0.0, 0.076),
			"nose_center": Vector2(0.0, 9.0),
			"mouth_open": 1.0,
			"mouth_depth": 0.8,
			"mouth_curve": 0.12,
			"mouth_teeth": 1.0,
			"mouth_thickness": 0.075,
		},
	],
	[
		"J1",
		"style_sheet_HK.webp",
		Vector2(494, 952),
		"laugh (tongue)",
		{
			"mouth_width": 1.0,
			"mouth_center": Vector2(0.0, 0.19),
			"nose_center": Vector2(0.0, 9.0),
			"mouth_open": 1.0,
			"mouth_depth": 1.12,
			"mouth_curve": 0.3,
			"mouth_tongue": 0.62,
			"mouth_thickness": 0.075,
		},
	],
]
# the mouth crop, in disc diameters from the disc centre (y up): x from, width, y top, height
const MOUTH_BOX := Rect2(-0.3, -0.15, 0.6, 0.3)
const MOUTH_ZOOM := 2.0
# dial row: label, field, from, to
const DIALS := [
	["openness 1>0", "openness", 1.0, 0.0],
	["squint 0>1", "squint", 0.0, 1.0],
	["mouth_curve -1>1", "mouth_curve", -1.0, 1.0],
	["mouth_open 0>1", "mouth_open", 0.0, 1.0],
	["wink 0>1", "wink", 0.0, 1.0],
	["mouth_skew -1>1", "mouth_skew", -1.0, 1.0],
	["mouth_teeth 0>1", "mouth_teeth", 0.0, 1.0],
	["mouth_tongue 0>1", "mouth_tongue", 0.0, 1.0],
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
	await _sheet_dials(styles["heavy_lid"])
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
	var sheets := {}
	for row: Array in REFS + MOUTH_REFS:
		var file: String = row[1]
		if sheets.has(file):
			continue
		var img := Image.new()
		var err := img.load_webp_from_buffer(FileAccess.get_file_as_bytes(REF_DIR + file))
		if err != OK:
			push_error("shot_faces: cannot read %s (%s)" % [file, error_string(err)])
			return
		img.convert(Image.FORMAT_RGBA8)
		sheets[file] = img
	var cols := 1 + REF_STATES.size()
	var disc := CELL / REF_CROP
	var mouth_px := Vector2(MOUTH_BOX.size) * disc * MOUTH_ZOOM
	var mouth_h := int(mouth_px.y) + LABEL_H
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * REFS.size() + mouth_h)
	var board := _board(size)
	board.color = KRAFT
	for r in REFS.size():
		var row: Array = REFS[r]
		var y := r * (CELL + LABEL_H)
		var side := REF_DISC * REF_CROP
		var src := Rect2(row[2] - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		board.add_child(_ref_image(sheets[row[1]], src, Vector2(0, y), Vector2.ONE * CELL))
		board.add_child(_label("reference " + String(row[0]), Vector2(0, y + CELL - 6), CELL))
		var style: FaceStyle = styles[row[3]]
		for c in REF_STATES.size():
			var face := _face(style, style.expression(REF_STATES[c]), disc, false)
			face.position = Vector2((c + 1) * CELL, y) + Vector2.ONE * (CELL - disc) * 0.5
			board.add_child(face)
			var text := "%s / %s" % [row[3], REF_STATES[c]]
			board.add_child(_label(text, Vector2((c + 1) * CELL, y + CELL - 6), CELL))
	# the mouths: reference crop, then ours, the same box of the same-sized disc
	var y0 := (CELL + LABEL_H) * REFS.size()
	var x := 0.0
	for row: Array in MOUTH_REFS:
		var src_px := Rect2(
			row[2] + Vector2(MOUTH_BOX.position.x, -MOUTH_BOX.position.y) * REF_DISC,
			MOUTH_BOX.size * REF_DISC
		)
		board.add_child(_ref_image(sheets[row[1]], src_px, Vector2(x, y0), mouth_px))
		board.add_child(
			_label("reference " + String(row[0]), Vector2(x, y0 + mouth_px.y), mouth_px.x)
		)
		x += mouth_px.x + 8
		var clip := Control.new()
		clip.clip_contents = true
		clip.position = Vector2(x, y0)
		clip.size = mouth_px
		var big := disc * MOUTH_ZOOM
		var face := _face(styles["heavy_lid"], row[4], big, false)
		face.position = (
			-(Vector2(MOUTH_BOX.position.x, -MOUTH_BOX.position.y) + Vector2(0.5, 0.5)) * big
		)
		clip.add_child(face)
		board.add_child(clip)
		board.add_child(_label(String(row[3]), Vector2(x, y0 + mouth_px.y), mouth_px.x))
		x += mouth_px.x + 24
	await _save(board, size, "sheet_refs.png")


## A region of a reference sheet (px), scaled into a TextureRect at `pos` of `size`.
func _ref_image(sheet: Image, src: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var img := sheet.get_region(Rect2i(src))
	img.resize(int(size.x), int(size.y), Image.INTERPOLATE_LANCZOS)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = pos
	return tr


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
