extends SceneTree

## Review sheets for the cut-paper faces (FaceStyle + face_canvas.gdshader: the same
## face_paper code the head runs, drawn flat on a paper disc). NOT headless (it renders):
##   godot --path . --script res://tools/shot_faces.gd
## Writes to IMPORT/faces_proc/ (git-ignored):
##   sheet_refs.png     each preset: its reference face (the J row of style_sheet_3_GIJ.webp)
##                      beside it in the idle and the shared states, same disc size and page
##   sheet_presets.png  every preset (rows) in every state (columns)
##   sheet_scale.png    the presets at game size (~25 px head), upscaled 4x nearest
##   sheet_paper.png    paper_j1 at three zooms (the face, one eye, one brow): grain, rim and
##                      the shadows

const OUT_DIR := "res://IMPORT/faces_proc"
const STYLE_DIR := "res://data/face_styles/"
const CANVAS_SHADER := "res://assets/shaders/face_canvas.gdshader"
const PRESETS := ["paper_j1", "paper_j2", "paper_j3", "paper_j4", "paper_heavy", "paper_small"]
const STATES := [
	"neutral",
	"blink_half",
	"closed",
	"happy",
	"sad",
	"displeased",
	"surprised",
	"talking",
]
const REF_STATES := ["neutral", "blink_half", "closed", "happy", "sad", "surprised", "talking"]
const SKIN := Color8(229, 176, 128)  # the reference discs' paper
const PAGE := Color8(247, 237, 225)  # the reference sheet's page
const INK := Color("3a2418")
const CELL := 256
const LABEL_H := 26
const PAD := 1.1  # rect side / disc diameter (face_canvas.gdshader `pad`)
const GAME_HEAD_PX := 25
const UPSCALE := 4
const REF_SHEET := "res://IMPORT/faces_proc/ref/style_sheet_3_GIJ.webp"
# reference disc per preset: label, disc centre (px, measured), disc diameter (px)
const REFS := {
	"paper_j1": ["J1", Vector2(134, 792), 210.0],
	"paper_j2": ["J2", Vector2(382.5, 792.5), 211.0],
	"paper_j3": ["J3", Vector2(638.5, 793.5), 221.0],
	"paper_j4": ["J4", Vector2(888, 794), 212.0],
	"paper_heavy": ["J1", Vector2(134, 792), 210.0],
	"paper_small": ["J1", Vector2(134, 792), 210.0],
}
const PAPER_CELL := 420
# the paper sheet's views: label, zoom, centre (face units, from the disc centre, y down)
const PAPER_VIEWS := [
	["face", 1.0, Vector2.ZERO],
	["left eye", 4.0, Vector2(-0.228, -0.01)],
	["left brow", 5.0, Vector2(-0.248, -0.28)],
]

var _shader: Shader


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	_shader = load(CANVAS_SHADER) as Shader
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var styles := {}
	for p: String in PRESETS:
		styles[p] = load(STYLE_DIR + p + ".tres") as FaceStyle
	await _sheet_refs(styles)
	await _sheet_presets(styles)
	await _sheet_scale(styles)
	await _sheet_paper(styles["paper_j1"])
	quit(0)


func _sheet_refs(styles: Dictionary) -> void:
	var sheet := Image.new()
	var err := sheet.load_webp_from_buffer(FileAccess.get_file_as_bytes(REF_SHEET))
	if err != OK:
		push_error("shot_faces: cannot read %s (%s)" % [REF_SHEET, error_string(err)])
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var cols := 1 + REF_STATES.size()
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * PRESETS.size())
	var board := _board(size)
	for r in PRESETS.size():
		var key: String = PRESETS[r]
		var ref: Array = REFS[key]
		var y := r * (CELL + LABEL_H)
		var side: float = float(ref[2]) * PAD
		var src := Rect2(Vector2(ref[1]) - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		board.add_child(_ref_image(sheet, src, Vector2(0, y), Vector2.ONE * CELL))
		board.add_child(_label("reference " + String(ref[0]), Vector2(0, y + CELL), CELL))
		var style: FaceStyle = styles[key]
		for c in REF_STATES.size():
			var face := _face(style, style.expression(REF_STATES[c]), CELL)
			face.position = Vector2((c + 1) * CELL, y)
			board.add_child(face)
			var text := "%s / %s" % [key, REF_STATES[c]]
			board.add_child(_label(text, Vector2((c + 1) * CELL, y + CELL), CELL))
	await _save(board, size, "sheet_refs.png")


func _sheet_presets(styles: Dictionary) -> void:
	var size := Vector2i(CELL * STATES.size(), (CELL + LABEL_H) * PRESETS.size())
	var board := _board(size)
	for r in PRESETS.size():
		var style: FaceStyle = styles[PRESETS[r]]
		for c in STATES.size():
			var pos := Vector2(c * CELL, r * (CELL + LABEL_H))
			var face := _face(style, style.expression(STATES[c]), CELL)
			face.position = pos
			board.add_child(face)
			var text := "%s / %s" % [PRESETS[r], STATES[c]]
			board.add_child(_label(text, pos + Vector2(0, CELL), CELL))
	await _save(board, size, "sheet_presets.png")


## Game size: the idle, a blink and happy per preset at a 25 px head, upscaled.
func _sheet_scale(styles: Dictionary) -> void:
	var states := ["neutral", "closed", "happy"]
	var cell := int(ceil(GAME_HEAD_PX * PAD)) + 3
	var small := Vector2i(cell * PRESETS.size(), cell * states.size())
	var board := _board(small)
	for c in PRESETS.size():
		var style: FaceStyle = styles[PRESETS[c]]
		for r in states.size():
			var face := _face(style, style.expression(states[r]), GAME_HEAD_PX * PAD)
			face.position = Vector2(c * cell + 1, r * cell + 1)
			board.add_child(face)
	var img := await _render(board, small)
	img.resize(small.x * UPSCALE, small.y * UPSCALE, Image.INTERPOLATE_NEAREST)
	var left := 110
	var size := Vector2i(img.get_width() + left, img.get_height() + LABEL_H + 8)
	var out := _board(size)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = Vector2(left, LABEL_H + 8)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	out.add_child(tr)
	for c in PRESETS.size():
		var x := left + c * cell * UPSCALE
		out.add_child(_label(PRESETS[c], Vector2(x, 4), cell * UPSCALE))
	for r in states.size():
		var y := LABEL_H + 8 + (r + 0.4) * cell * UPSCALE
		out.add_child(_label(states[r], Vector2(0, y), left))
	await _save(out, size, "sheet_scale.png")


func _sheet_paper(style: FaceStyle) -> void:
	var size := Vector2i(PAPER_CELL * PAPER_VIEWS.size(), PAPER_CELL + LABEL_H)
	var board := _board(size)
	for c in PAPER_VIEWS.size():
		var view: Array = PAPER_VIEWS[c]
		var face := _face(style, {}, PAPER_CELL)
		var mat := face.material as ShaderMaterial
		mat.set_shader_parameter("zoom", view[1])
		mat.set_shader_parameter("zoom_center", view[2])
		face.position = Vector2(c * PAPER_CELL, 0)
		board.add_child(face)
		var text := "paper_j1 / %s x%d" % [view[0], int(view[1])]
		board.add_child(_label(text, Vector2(c * PAPER_CELL, PAPER_CELL), PAPER_CELL))
	await _save(board, size, "sheet_paper.png")


## A region of a reference sheet (px), scaled into a TextureRect at `pos` of `size`.
func _ref_image(sheet: Image, src: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var img := sheet.get_region(Rect2i(src))
	img.resize(int(size.x), int(size.y), Image.INTERPOLATE_LANCZOS)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = pos
	return tr


## One face: a square rect `side` px wide, the paper disc 1 / PAD of it.
func _face(style: FaceStyle, dials: Dictionary, side: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(side, side)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("pad", PAD)
	mat.set_shader_parameter("skin_color", SKIN)
	mat.set_shader_parameter("page_color", PAGE)
	style.apply_to_material(mat, dials)
	rect.material = mat
	return rect


func _board(size: Vector2i) -> Control:
	var board := ColorRect.new()
	board.color = PAGE
	board.size = Vector2(size)
	return board


func _label(text: String, pos: Vector2, width: float) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.position = pos
	lab.size = Vector2(width, LABEL_H)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", INK)
	lab.add_theme_font_size_override("font_size", 15)
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
