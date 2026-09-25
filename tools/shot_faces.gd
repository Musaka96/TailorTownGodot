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
##   j1_match.png       reference J1 beside paper_j1 (640 px each), then paired zooms of
##                      the reference and ours: eye, brow, nose, mouth
##   j1_states.png      paper_j1 in the states at 400 px, and at game size (25 px, 4x)
##   j1_paper_zoom.png  paper_j1's nose, eye and brow end at 5x: the cut edges, grain, shadow
##   noble.png          paper_j1 beside paper_noble (640 px each), then paper_noble in the
##                      states at 400 px and at game size (25 px, 4x)
##   cast.png           the cast (guide section 8): each character (rows) in the states
##                      (columns) at 256 px, then all eight at game size (25 px, 4x)
##   cast_zoom.png      one piece per new cast character at 3x: dimmock's lids,
##                      pettigrew's cheek and nose, portobello's and hartley's brows,
##                      bellamy's mouth, vance's eyes
##   happy_options.png  the happy eye modes (FaceStyle.HappyEye) side by side: five of the
##                      cast (rows) idle and happy in each mode at 300 px, then J1 in each
##                      at game size (25 px, 4x)
## With `j1` after `--`, only the three j1 sheets; with `noble`, only noble.png; with
## `cast`, only cast.png and cast_zoom.png (`vance_whites` swaps in paper_vance_whites);
## with `happy`, only happy_options.png.

const OUT_DIR := "res://IMPORT/faces_proc"
const STYLE_DIR := "res://data/face_styles/"
const CANVAS_SHADER := "res://assets/shaders/face_canvas.gdshader"
# the pieces' sheet paper comes from the default PaperSurface, as on the head
const SURFACE := "res://data/paper_surfaces/paper_mache.tres"
const PRESETS := [
	"paper_j1",
	"paper_j2",
	"paper_j3",
	"paper_j4",
	"paper_heavy",
	"paper_small",
	"paper_noble",
]
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
	"paper_j1": ["J1", Vector2(133.98, 792.62), 211.0],
	"paper_j2": ["J2", Vector2(382.5, 792.5), 211.0],
	"paper_j3": ["J3", Vector2(638.5, 793.5), 221.0],
	"paper_j4": ["J4", Vector2(888, 794), 212.0],
	"paper_heavy": ["J1", Vector2(134, 792), 210.0],
	"paper_small": ["J1", Vector2(134, 792), 210.0],
	"paper_noble": ["J1", Vector2(134, 792), 210.0],
}
# the cast (guide section 8): character, preset
const CAST := [
	["J1", "paper_j1"],
	["the noble", "paper_noble"],
	["Mr. Dimmock", "paper_dimmock"],
	["Mr. Pettigrew", "paper_pettigrew"],
	["Ms. Portobello", "paper_portobello"],
	["Mr. Bellamy", "paper_bellamy"],
	["Miss Hartley", "paper_hartley"],
	["Dr. Vance", "paper_vance"],
]
# cast_zoom.png: label, preset, centre (face units from the disc centre, y down)
const CAST_ZOOMS := [
	["dimmock / lids", "paper_dimmock", Vector2(-0.25, 0.04)],
	["pettigrew / cheek + nose", "paper_pettigrew", Vector2(-0.18, 0.24)],
	["portobello / brows", "paper_portobello", Vector2(0.2, -0.28)],
	["bellamy / mouth", "paper_bellamy", Vector2(0.0, 0.32)],
	["hartley / brows", "paper_hartley", Vector2(-0.2, -0.3)],
	["vance / eyes", "paper_vance", Vector2(-0.18, -0.08)],
]
const CAST_ZOOM := 3.0
# happy_options.png: the rows (character, preset) and the columns (label, HappyEye mode as
# an int, -1 = the idle)
const HAPPY_ROWS := [
	["J1", "paper_j1"],
	["the noble", "paper_noble"],
	["Mr. Dimmock", "paper_dimmock"],
	["Mr. Pettigrew", "paper_pettigrew"],
	["Miss Hartley", "paper_hartley"],
]
const HAPPY_COLS := [
	["idle", -1],
	["X cut (now)", 0],
	["A bright", 1],
	["B soft lids", 2],
	["C closed arcs", 3],
	["D bright + tilt", 4],
]
const HAPPY_CELL := 300
const CAST_ZOOM_CELL := 420
const PAPER_CELL := 420
# J1 on the reference sheet, measured (px): disc centre and diameter
const J1_CENTER := Vector2(133.98, 792.62)
const J1_DIAM := 211.0
const J1_CELL := 640
const J1_ZOOM_CELL := 320
# the paired zooms: label, centre (face units: x from the midline, y from the disc top), side
const J1_ZOOMS := [
	["eye", Vector2(-0.226, 0.49), 0.4],
	["brow", Vector2(-0.255, 0.223), 0.34],
	["nose", Vector2(0.0, 0.673), 0.26],
	["mouth", Vector2(0.0, 0.8), 0.26],
]
const J1_STATE_CELL := 400
# the paper zooms at 5x: label, centre (face units from the disc centre, y down)
const J1_PAPER := [
	["nose", Vector2(0.0, 0.173)],
	["left eye", Vector2(-0.17, -0.01)],
	["left brow, inner end", Vector2(-0.17, -0.27)],
]
const J1_PAPER_CELL := 500
# the paper sheet's views: label, zoom, centre (face units, from the disc centre, y down)
const PAPER_VIEWS := [
	["face", 1.0, Vector2.ZERO],
	["left eye", 4.0, Vector2(-0.228, -0.01)],
	["left brow", 5.0, Vector2(-0.248, -0.28)],
]

var _shader: Shader
var _surface: PaperSurface


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	_shader = load(CANVAS_SHADER) as Shader
	_surface = load(SURFACE) as PaperSurface
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	var styles := {}
	for p: String in PRESETS:
		styles[p] = load(STYLE_DIR + p + ".tres") as FaceStyle
	if OS.get_cmdline_user_args().has("happy"):
		await _sheet_happy()
		quit(0)
		return
	if OS.get_cmdline_user_args().has("cast"):
		await _sheet_cast()
		await _sheet_cast_zoom()
		quit(0)
		return
	if OS.get_cmdline_user_args().has("noble"):
		await _sheet_pair(styles["paper_j1"], styles["paper_noble"], "paper_noble", "noble.png")
		quit(0)
		return
	var sheet := _ref_sheet()
	if sheet != null:
		await _sheet_j1_match(styles["paper_j1"], sheet)
	await _sheet_j1_states(styles["paper_j1"])
	await _sheet_j1_paper(styles["paper_j1"])
	if OS.get_cmdline_user_args().has("j1"):
		quit(0)
		return
	await _sheet_refs(styles)
	await _sheet_presets(styles)
	await _sheet_scale(styles)
	await _sheet_paper(styles["paper_j1"])
	await _sheet_pair(styles["paper_j1"], styles["paper_noble"], "paper_noble", "noble.png")
	quit(0)


## The cast preset for a row: `vance_whites` after `--` shows Dr. Vance's other try.
func _cast_preset(key: String) -> String:
	if key == "paper_vance" and OS.get_cmdline_user_args().has("vance_whites"):
		return "paper_vance_whites"
	return key


## The cast in the states (rows = characters), then every idle at game size (25 px, 4x).
func _sheet_cast() -> void:
	var small := int(ceil(GAME_HEAD_PX * PAD)) + 3
	var up := small * UPSCALE
	var rows_h := (CELL + LABEL_H) * CAST.size()
	var size := Vector2i(CELL * REF_STATES.size(), rows_h + up + 2 * LABEL_H)
	var board := _board(size)
	var tiny_board := _board(Vector2i(small * CAST.size(), small))
	for r in CAST.size():
		var who: Array = CAST[r]
		var key := _cast_preset(who[1])
		var style := load(STYLE_DIR + key + ".tres") as FaceStyle
		for c in REF_STATES.size():
			var pos := Vector2(c * CELL, r * (CELL + LABEL_H))
			var face := _face(style, style.expression(REF_STATES[c]), CELL)
			face.position = pos
			board.add_child(face)
			var text := "%s / %s" % [who[0], REF_STATES[c]]
			board.add_child(_label(text, pos + Vector2(0, CELL), CELL))
		var tiny := _face(style, {}, GAME_HEAD_PX * PAD)
		tiny.position = Vector2(r * small + 1, 1)
		tiny_board.add_child(tiny)
		var x := float(r * size.x) / CAST.size()
		var y := rows_h + LABEL_H + up
		board.add_child(_label(String(who[0]), Vector2(x, y), float(size.x) / CAST.size()))
	var img := await _render(tiny_board, Vector2i(small * CAST.size(), small))
	for r in CAST.size():
		var one := img.get_region(Rect2i(r * small, 0, small, small))
		one.resize(up, up, Image.INTERPOLATE_NEAREST)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(one)
		var cx := (r + 0.5) * size.x / CAST.size()
		tr.position = Vector2(cx - up * 0.5, rows_h + LABEL_H)
		board.add_child(tr)
	board.add_child(_label("game size (25 px head, 4x)", Vector2(0, rows_h), size.x))
	await _save(board, size, "cast.png")


## The happy eye modes: HAPPY_ROWS (rows) idle and happy in each HappyEye mode (columns),
## then J1 in each column at game size (25 px, 4x).
func _sheet_happy() -> void:
	var keep := FaceStyle.happy_eye
	var cell := HAPPY_CELL
	var cols := HAPPY_COLS.size()
	var small := int(ceil(GAME_HEAD_PX * PAD)) + 3
	var up := small * UPSCALE
	var rows_h := (cell + LABEL_H) * HAPPY_ROWS.size()
	var size := Vector2i(cell * cols, rows_h + LABEL_H + up + 8)
	var board := _board(size)
	var tiny_board := _board(Vector2i(small * cols, small))
	var j1 := load(STYLE_DIR + "paper_j1.tres") as FaceStyle
	for r in HAPPY_ROWS.size():
		var who: Array = HAPPY_ROWS[r]
		var style := load(STYLE_DIR + String(who[1]) + ".tres") as FaceStyle
		for c in cols:
			var col: Array = HAPPY_COLS[c]
			var pos := Vector2(c * cell, r * (cell + LABEL_H))
			var face := _face(style, _happy_dials(style, col[1]), cell)
			face.position = pos
			board.add_child(face)
			board.add_child(_label("%s / %s" % [who[0], col[0]], pos + Vector2(0, cell), cell))
	for c in cols:
		var tiny := _face(j1, _happy_dials(j1, HAPPY_COLS[c][1]), GAME_HEAD_PX * PAD)
		tiny.position = Vector2(c * small + 1, 1)
		tiny_board.add_child(tiny)
	FaceStyle.happy_eye = keep
	var img := await _render(tiny_board, Vector2i(small * cols, small))
	for c in cols:
		var one := img.get_region(Rect2i(c * small, 0, small, small))
		one.resize(up, up, Image.INTERPOLATE_NEAREST)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(one)
		tr.position = Vector2(c * cell + (cell - up) * 0.5, rows_h + LABEL_H + 4)
		board.add_child(tr)
	var text := "J1 at game size (25 px head, 4x), same columns"
	board.add_child(_label(text, Vector2(0, rows_h), size.x))
	await _save(board, size, "happy_options.png")


## The dials for one happy_options.png cell: {} for the idle (mode -1), else the happy state
## with FaceStyle.happy_eye switched to `mode`.
func _happy_dials(style: FaceStyle, mode: int) -> Dictionary:
	if mode < 0:
		return {}
	FaceStyle.happy_eye = mode as FaceStyle.HappyEye
	return style.expression("happy")


## One distinctive piece per new cast character at 3x.
func _sheet_cast_zoom() -> void:
	var cell := CAST_ZOOM_CELL
	var size := Vector2i(cell * CAST_ZOOMS.size(), cell + LABEL_H)
	var board := _board(size)
	for c in CAST_ZOOMS.size():
		var view: Array = CAST_ZOOMS[c]
		var style := load(STYLE_DIR + _cast_preset(view[1]) + ".tres") as FaceStyle
		var face := _face(style, {}, cell)
		var mat := face.material as ShaderMaterial
		mat.set_shader_parameter("zoom", CAST_ZOOM)
		mat.set_shader_parameter("zoom_center", view[2])
		face.position = Vector2(c * cell, 0)
		board.add_child(face)
		var text := "%s x%d" % [view[0], int(CAST_ZOOM)]
		board.add_child(_label(text, Vector2(c * cell, cell), cell))
	await _save(board, size, "cast_zoom.png")


func _ref_sheet() -> Image:
	var sheet := Image.new()
	var err := sheet.load_webp_from_buffer(FileAccess.get_file_as_bytes(REF_SHEET))
	if err != OK:
		push_error("shot_faces: cannot read %s (%s)" % [REF_SHEET, error_string(err)])
		return null
	sheet.convert(Image.FORMAT_RGBA8)
	return sheet


## Reference J1 against paper_j1: the whole face, then each feature zoomed side by side.
func _sheet_j1_match(style: FaceStyle, sheet: Image) -> void:
	var z := J1_ZOOM_CELL
	var size := Vector2i(2 * J1_CELL, J1_CELL + LABEL_H + 2 * (z + LABEL_H))
	var board := _board(size)
	var side := J1_DIAM * PAD
	var src := Rect2(J1_CENTER - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	board.add_child(_ref_image(sheet, src, Vector2.ZERO, Vector2.ONE * J1_CELL))
	board.add_child(_label("reference J1", Vector2(0, J1_CELL), J1_CELL))
	var face := _face(style, {}, J1_CELL)
	face.position = Vector2(J1_CELL, 0)
	board.add_child(face)
	board.add_child(_label("paper_j1 / neutral", Vector2(J1_CELL, J1_CELL), J1_CELL))
	for i in J1_ZOOMS.size():
		var zoom: Array = J1_ZOOMS[i]
		var at: Vector2 = zoom[1]
		var region: float = zoom[2]
		var pos := Vector2((i % 2) * 2 * z, J1_CELL + LABEL_H + (i / 2) * (z + LABEL_H))
		var px_side := region * J1_DIAM
		var c := J1_CENTER + Vector2(at.x, at.y - 0.5) * J1_DIAM
		var zsrc := Rect2(c - Vector2.ONE * px_side * 0.5, Vector2.ONE * px_side)
		board.add_child(_ref_image(sheet, zsrc, pos, Vector2.ONE * z))
		var ours := _face(style, {}, z)
		var mat := ours.material as ShaderMaterial
		mat.set_shader_parameter("zoom", PAD / region)
		mat.set_shader_parameter("zoom_center", Vector2(at.x, at.y - 0.5))
		ours.position = pos + Vector2(z, 0)
		board.add_child(ours)
		var mag := z / px_side
		board.add_child(_label("ref %s x%.1f" % [zoom[0], mag], pos + Vector2(0, z), z))
		board.add_child(_label("ours %s" % zoom[0], pos + Vector2(z, z), z))
	await _save(board, size, "j1_match.png")


## paper_j1 in the states at 400 px, and under each its 25 px game-size face at 4x.
func _sheet_j1_states(style: FaceStyle) -> void:
	var small := int(ceil(GAME_HEAD_PX * PAD)) + 3
	var size := Vector2i(J1_STATE_CELL * REF_STATES.size(), _states_h(small))
	var board := _board(size)
	await _states_row(board, style, "paper_j1", 0.0, small)
	await _save(board, size, "j1_states.png")


## A second character against J1: both idles at 640 px, then its states row (as j1_states).
func _sheet_pair(j1: FaceStyle, style: FaceStyle, key: String, file: String) -> void:
	var small := int(ceil(GAME_HEAD_PX * PAD)) + 3
	var top := J1_CELL + LABEL_H
	var size := Vector2i(J1_STATE_CELL * REF_STATES.size(), top + _states_h(small))
	var board := _board(size)
	for c in 2:
		var face := _face(j1 if c == 0 else style, {}, J1_CELL)
		face.position = Vector2(c * J1_CELL, 0)
		board.add_child(face)
		var text := "%s / neutral" % ("paper_j1" if c == 0 else key)
		board.add_child(_label(text, Vector2(c * J1_CELL, J1_CELL), J1_CELL))
	await _states_row(board, style, key, top, small)
	await _save(board, size, file)


func _states_h(small: int) -> int:
	return J1_STATE_CELL + LABEL_H + small * UPSCALE + 8


## `style` in REF_STATES at 400 px from height `y`, each with its 25 px face (4x) under it.
func _states_row(board: Control, style: FaceStyle, key: String, y: float, small: int) -> void:
	var c400 := J1_STATE_CELL
	var up := small * UPSCALE
	for c in REF_STATES.size():
		var dials := style.expression(REF_STATES[c])
		var face := _face(style, dials, c400)
		face.position = Vector2(c * c400, y)
		board.add_child(face)
		var text := "%s / %s" % [key, REF_STATES[c]]
		board.add_child(_label(text, Vector2(c * c400, y + c400), c400))
		var tiny_board := _board(Vector2i(small, small))
		var tiny := _face(style, dials, GAME_HEAD_PX * PAD)
		tiny.position = Vector2.ONE
		tiny_board.add_child(tiny)
		var img := await _render(tiny_board, Vector2i(small, small))
		img.resize(up, up, Image.INTERPOLATE_NEAREST)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = Vector2(c * c400 + (c400 - up) / 2, y + c400 + LABEL_H + 4)
		board.add_child(tr)


## paper_j1 up close (5x): the hand-cut edges, the grain and the shadows.
func _sheet_j1_paper(style: FaceStyle) -> void:
	var cell := J1_PAPER_CELL
	var size := Vector2i(cell * J1_PAPER.size(), cell + LABEL_H)
	var board := _board(size)
	for c in J1_PAPER.size():
		var view: Array = J1_PAPER[c]
		var face := _face(style, {}, cell)
		var mat := face.material as ShaderMaterial
		mat.set_shader_parameter("zoom", 5.0)
		mat.set_shader_parameter("zoom_center", view[1])
		face.position = Vector2(c * cell, 0)
		board.add_child(face)
		var text := "paper_j1 / %s x5" % view[0]
		board.add_child(_label(text, Vector2(c * cell, cell), cell))
	await _save(board, size, "j1_paper_zoom.png")


func _sheet_refs(styles: Dictionary) -> void:
	var sheet := _ref_sheet()
	if sheet == null:
		return
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
	_surface.apply_pieces_to(mat)
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
