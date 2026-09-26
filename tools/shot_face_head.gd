extends SceneTree

## Close-ups of the real character rig with a procedural face (CharacterRig.procedural_faces
## on: the face drawn in the head's skin material at its baked face UV). NOT headless:
##   godot --path . --script res://tools/shot_face_head.gd [-- presets [preset ...]]
## Writes to IMPORT/faces_proc/ (git-ignored):
##   heads_uv.png         every tripo head (+ the Base head) x every preset, neutral
##   heads_uv_states.png  one tripo head x the states, paper_j1 and paper_heavy
##   heads_uv_debug.png   every head with its face rect as a checkerboard (red border),
##                        front and 45 degrees: the projection, and nothing on the back
##   heads_uv_side.png    paper_j1 on one tripo head from 0 / 30 / 60 / 90 / 180 degrees,
##                        bare and with round glasses
##   j1_heads.png         paper_j1 on tripo_head_tl and tripo_bald_tr at face scale 1.0 /
##                        0.85 / 0.8 (the default) / 0.75, front, and at 45 degrees at 0.8
##   noble_head.png       paper_j1 (default hair) beside paper_noble (black hair) on
##                        tripo_bald_tr and tripo_head_tl, front, at portrait size and at the
##                        dialogue size (head about 140 px)
##   lid_fix.png          paper_noble and paper_j1 on tripo_head_tl at portrait size, before
##                        (.dev/before_lid/skin_face.gdshader, when it exists) and after the
##                        lid-as-skin fix, then 3x zooms of one eye: before and after at lid
##                        0.45, and after at blink_half and closed
##   cast_heads.png       the cast (guide section 8) on tripo_head_tl, each with its hair
##                        colour and glasses, at portrait and at dialogue size
##   dimmock_fix.png      Mr. Dimmock before (DIMMOCK_BEFORE) and after the 2026-09-26 retune
##                        beside the noble: flat (face_canvas.gdshader) at 640 px, then on
##                        tripo_head_tl with their hair at portrait and at dialogue size
##   head0_fix.png        every preset in data/face_styles/ on the Base head (0) and on head 2:
##                        the Base face rect as a checkerboard, then each head before
##                        (.dev/before_h0/skin_face.gdshader, the layout stretched to the rect,
##                        and the preset as it was in .dev/before_h0/styles/, when they exist)
##                        and after the unstretched disc fit (2026-09-26)
## With `j1` after `--`, only j1_heads.png; with `noble`, only noble_head.png; with `lid`,
## only lid_fix.png; with `cast`, only cast_heads.png (`vance_whites` swaps in paper_vance_whites);
## with `dimmock`, only dimmock_fix.png; with `head0`, only head0_fix.png (`head0 <preset>
## ...` only those presets, after only, into head0_<first preset>.png).
## With `presets` after `--`: the old per-preset shots, head_<preset>[_<state>].png (only
## the named presets when any are given).
## The outfit goes on one frame after the rig enters the tree (its mesh slots fill in
## _ready; earlier the cloth and skin tint silently miss).

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE_DIR := "res://data/face_styles/"
const PRESETS := ["paper_j1", "paper_j2", "paper_j3", "paper_j4", "paper_heavy", "paper_small"]
const STATES := ["neutral", "blink_half", "closed", "happy", "sad", "surprised", "talking"]
const STATE_PRESETS := ["paper_j1", "paper_heavy"]
const SIDE_ANGLES := [0.0, 30.0, 60.0, 90.0, 180.0]
# j1_heads.png: the heads (display-name prefixes), and the columns: face scale, turn (deg)
const J1_HEADS := ["tripo_head_tl", "tripo_bald_tr"]
const J1_VIEWS := [[1.0, 0.0], [0.85, 0.0], [0.8, 0.0], [0.75, 0.0], [0.8, 45.0]]
const J1_CELL := 400
# noble_head.png: the heads, the noble's hair, and the dialogue cell (a head about 140 px)
const NOBLE_HEADS := ["tripo_bald_tr", "tripo_head_tl"]
const NOBLE_HAIR := Color("1a1410")
const DIALOGUE_CELL := 200
# cast_heads.png: the head, and per character: name, preset, hair colour (null = the
# rig's default), glasses ("" = none; "round" is the wire part), frame colour
const CAST_HEAD := "tripo_head_tl"
const CAST := [
	["J1", "paper_j1", null, "", ""],
	["the noble", "paper_noble", NOBLE_HAIR, "", ""],
	["Mr. Dimmock", "paper_dimmock", Color("2a1d15"), "", ""],
	["Mr. Pettigrew", "paper_pettigrew", Color("e9e4da"), "round", "gold"],
	["Ms. Portobello", "paper_portobello", Color("5e2618"), "round", "tortoise"],
	["Mr. Bellamy", "paper_bellamy", Color("4a4746"), "", ""],
	["Miss Hartley", "paper_hartley", Color("7a4326"), "", ""],
	["Dr. Vance", "paper_vance", Color("15110f"), "round", "black"],
]
const CAST_PER_ROW := 4
# dimmock_fix.png: the fields paper_dimmock had before the 2026-09-26 retune (pupils small
# and sunk low, straight brows), his hair, the flat faces' shader and paper, the cell
const DIMMOCK_BEFORE := {
	"pupil_radius": 0.06,
	"pupil_offset": Vector2(0.0, 0.07),
	"brow_spacing": 0.26,
	"brow_length": 0.24,
	"brow_angle": 0.0,
	"brow_arch": 0.03,
}
const DIMMOCK_HAIR := Color("2a1d15")
const CANVAS_SHADER := "res://assets/shaders/face_canvas.gdshader"
const PAPER_SURFACE := "res://data/paper_surfaces/paper_mache.tres"
const FLAT_SKIN := Color8(229, 176, 128)
const FLAT_PAD := 1.1
const DIMMOCK_CELL := 640
# lid_fix.png: the head, the old head shader, the zoom, and where the viewer's left eye sits
# in the portrait framing (fraction of the viewport, tripo_head_tl at the default face scale)
const LID_HEAD := "tripo_head_tl"
const LID_PRESETS := ["paper_noble", "paper_j1"]
const BEFORE_LID_SHADER := "res://.dev/before_lid/skin_face.gdshader"
const LID_ZOOM := 3.0
const LID_EYE := Vector2(0.425, 0.5)
# head0_fix.png: the heads, and the old shader that stretched the layout to the rect aspect
const H0_HEADS := [0, 2]
const BEFORE_H0_SHADER := "res://.dev/before_h0/skin_face.gdshader"
const BEFORE_H0_STYLES := "res://.dev/before_h0/styles/"
# preset -> states to shoot ("neutral" = the resting face, no suffix), `presets` mode
const SHOTS := {
	"paper_j1": ["neutral", "happy"],
	"paper_j2": ["neutral"],
	"paper_j3": ["neutral"],
	"paper_j4": ["neutral"],
	"paper_heavy": ["neutral"],
	"paper_small": ["neutral"],
}
const OUT_DIR := "res://IMPORT/faces_proc"
const SKIN := Color(0.86, 0.72, 0.60)
const DIST := 2.2
const SIZE := Vector2i(900, 900)
const CELL := 260
const LABEL_H := 24
const SETTLE := 40
const PAPER := Color("f7f1e6")
const INK := Color("3a2418")

var _rig: Node3D  # CharacterRig (untyped: the class pulls in autoloads a --script lacks)
var _vp: SubViewport
var _cam: Camera3D
var _head_y := 1.64


func _initialize() -> void:
	var rig_script: Variant = load(RIG_SCRIPT)
	rig_script.procedural_faces = true
	# own viewport + world: a fixed size, and none of the game's HUD autoloads in the shot
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
	_cam.fov = 35
	world.add_child(_cam)
	_frame_camera(DIST)
	_cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _frame_camera(dist: float) -> void:
	var y := _head_y
	_cam.look_at_from_position(Vector3(0, y, dist), Vector3(0, y, 0.4), Vector3.UP)


func _run() -> void:
	await process_frame
	var suit := load(SUIT) as MaterialType
	_rig.set_palette(SKIN)
	_rig.set_outfit(suit, null, suit, 0, 0)
	(_rig.get("_blink") as Timer).stop()  # no random blink mid-capture
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "presets":
		await _preset_shots(args.slice(1))
	elif not args.is_empty() and args[0] == "j1":
		await _sheet_j1_heads()
	elif not args.is_empty() and args[0] == "noble":
		await _sheet_noble_heads()
	elif not args.is_empty() and args[0] == "lid":
		await _sheet_lid_fix()
	elif not args.is_empty() and args[0] == "dimmock":
		await _sheet_dimmock()
	elif not args.is_empty() and args[0] == "head0":
		await _sheet_head0_fix(args.slice(1))
	elif not args.is_empty() and args[0] == "cast":
		await _sheet_cast_heads(args.has("vance_whites"))
	else:
		await _sheet_j1_heads()
		await _sheet_noble_heads()
		var heads := _head_rows()
		await _sheet_heads(heads)
		await _sheet_states(heads[1])
		await _sheet_debug(heads)
		await _sheet_side(heads[1])
	quit(0)


## Head indices to compare: the Base head (0), then every tripo head. There are no KOSA heads
## in the wardrobe any more, so none is added.
func _head_rows() -> Array:
	var lib := Wardrobe.library()
	var out := [0]
	for i in lib.head_count():
		var n := String(lib.head(i).display_name)
		if n.begins_with("tripo_head") or n.begins_with("tripo_bald"):
			out.append(i)
	return out


func _wear(head: int) -> void:
	_rig.call("set_head", head)
	_rig.call("set_hair", head)
	_rig.set_palette(SKIN)
	var frame: FaceFrame = _rig.get("_face_frame")
	var n := String(Wardrobe.library().head(head).display_name)
	print("face rect %d %s: %s" % [head, n, frame.describe() if frame != null else "none"])


func _sheet_heads(heads: Array) -> void:
	var cells := []
	for r in heads.size():
		_wear(heads[r])
		for c in PRESETS.size():
			_rig.set("face_style", load(STYLE_DIR + PRESETS[c] + ".tres") as FaceStyle)
			await _pose("neutral", 4)
			cells.append([await _grab(), c, r, "%s / %s" % [_short(heads[r]), PRESETS[c]]])
	await _save_grid(cells, PRESETS.size(), heads.size(), "heads_uv.png")


func _sheet_states(head: int) -> void:
	_wear(head)
	var cells := []
	for r in STATE_PRESETS.size():
		_rig.set("face_style", load(STYLE_DIR + STATE_PRESETS[r] + ".tres") as FaceStyle)
		for c in STATES.size():
			await _pose(STATES[c], 30)
			cells.append([await _grab(), c, r, "%s / %s" % [STATE_PRESETS[r], STATES[c]]])
	await _save_grid(cells, STATES.size(), STATE_PRESETS.size(), "heads_uv_states.png")


## paper_j1 on two heads at a few face scales (FaceStyle.face_scale), to pick the size.
func _sheet_j1_heads() -> void:
	var keep: float = FaceStyle.face_scale
	var cells := []
	for r in J1_HEADS.size():
		var head := _find_head(J1_HEADS[r])
		if head < 0:
			push_error("shot_face_head: no head %s" % J1_HEADS[r])
			continue
		_wear(head)
		_rig.set("face_style", load(STYLE_DIR + "paper_j1.tres") as FaceStyle)
		for c in J1_VIEWS.size():
			var view: Array = J1_VIEWS[c]
			FaceStyle.face_scale = view[0]
			_rig.rotation_degrees.y = view[1]
			_rig.call("_push_face")
			await _pose("neutral", 4)
			var label := "%s  scale %.2f" % [_short(head), view[0]]
			if view[0] == keep:
				label += " (default)"
			if view[1] != 0.0:
				label += "  %d deg" % int(view[1])
			cells.append([await _grab(J1_CELL), c, r, label])
	FaceStyle.face_scale = keep
	_rig.rotation_degrees.y = 0.0
	_rig.call("_push_face")
	await _save_grid(cells, J1_VIEWS.size(), J1_HEADS.size(), "j1_heads.png", J1_CELL)


## paper_j1 and paper_noble (black hair) side by side, at portrait and dialogue size.
func _sheet_noble_heads() -> void:
	var keep_hair: Color = _rig.get("_hair_color")
	var cells := []
	for r in NOBLE_HEADS.size():
		var head := _find_head(NOBLE_HEADS[r])
		if head < 0:
			push_error("shot_face_head: no head %s" % NOBLE_HEADS[r])
			continue
		_wear(head)
		for k in 2:
			var preset := "paper_j1" if k == 0 else "paper_noble"
			_rig.call("set_hair_color", keep_hair if k == 0 else NOBLE_HAIR)
			_rig.set("face_style", load(STYLE_DIR + preset + ".tres") as FaceStyle)
			await _pose("neutral", 4)
			var label := "%s / %s" % [_short(head), preset]
			cells.append([await _grab(J1_CELL), k, r, label])
			cells.append([await _grab(DIALOGUE_CELL), k + 2, r, label + " (dialogue)"])
	_rig.call("set_hair_color", keep_hair)
	await _save_grid(cells, 4, NOBLE_HEADS.size(), "noble_head.png", J1_CELL)


## The cast on one head, each with its hair colour and glasses: portrait and dialogue size
## side by side, CAST_PER_ROW characters to a row.
func _sheet_cast_heads(vance_whites: bool) -> void:
	var keep_hair: Color = _rig.get("_hair_color")
	var head := _find_head(CAST_HEAD)
	if head < 0:
		push_error("shot_face_head: no head %s" % CAST_HEAD)
		return
	_wear(head)
	var cells := []
	for i in CAST.size():
		var who: Array = CAST[i]
		var preset: String = who[1]
		if vance_whites and preset == "paper_vance":
			preset = "paper_vance_whites"
		_rig.call("set_hair_color", keep_hair if who[2] == null else who[2])
		_rig.call("set_face_look", "brown", who[3])
		if who[4] != "":
			_rig.set("glasses_color", who[4])
		_rig.set("face_style", load(STYLE_DIR + preset + ".tres") as FaceStyle)
		await _pose("neutral", 4)
		var c := (i % CAST_PER_ROW) * 2
		var r := i / CAST_PER_ROW
		cells.append([await _grab(J1_CELL), c, r, String(who[0])])
		cells.append([await _grab(DIALOGUE_CELL), c + 1, r, "%s (dialogue)" % who[0]])
	_rig.call("set_hair_color", keep_hair)
	_rig.call("set_face_look", "brown", "")
	var rows := ceili(CAST.size() / float(CAST_PER_ROW))
	await _save_grid(cells, CAST_PER_ROW * 2, rows, "cast_heads.png", J1_CELL)


## Mr. Dimmock before and after his retune, beside the noble: flat at 640 px, then on
## tripo_head_tl with each one's hair at portrait size and at dialogue size.
func _sheet_dimmock() -> void:
	var keep_hair: Color = _rig.get("_hair_color")
	var head := _find_head(CAST_HEAD)
	if head < 0:
		push_error("shot_face_head: no head %s" % CAST_HEAD)
		return
	_wear(head)
	var after := load(STYLE_DIR + "paper_dimmock.tres") as FaceStyle
	var before := after.duplicate() as FaceStyle
	for key: String in DIMMOCK_BEFORE:
		before.set(key, DIMMOCK_BEFORE[key])
	var cols := [
		["Mr. Dimmock before", before, DIMMOCK_HAIR],
		["Mr. Dimmock after", after, DIMMOCK_HAIR],
		["the noble", load(STYLE_DIR + "paper_noble.tres") as FaceStyle, NOBLE_HAIR],
	]
	var cell := DIMMOCK_CELL
	var cells := []
	for c in cols.size():
		var col: Array = cols[c]
		cells.append([await _flat(col[1], cell), c, 0, "%s (flat)" % col[0]])
		_rig.call("set_hair_color", col[2])
		_rig.set("face_style", col[1])
		await _pose("neutral", 4)
		cells.append([await _grab(cell), c, 1, "%s (portrait)" % col[0]])
		cells.append([await _grab(DIALOGUE_CELL), c, 2, "%s (dialogue)" % col[0]])
	_rig.call("set_hair_color", keep_hair)
	await _save_grid(cells, cols.size(), 3, "dimmock_fix.png", cell)


## `style` drawn flat on its paper disc (face_canvas.gdshader, as tools/shot_faces.gd does),
## `side` px square.
func _flat(style: FaceStyle, side: int) -> Image:
	var rect := ColorRect.new()
	rect.size = Vector2(side, side)
	var mat := ShaderMaterial.new()
	mat.shader = load(CANVAS_SHADER) as Shader
	mat.set_shader_parameter("pad", FLAT_PAD)
	mat.set_shader_parameter("skin_color", FLAT_SKIN)
	mat.set_shader_parameter("page_color", PAPER)
	style.apply_to_material(mat)
	(load(PAPER_SURFACE) as PaperSurface).apply_pieces_to(mat)
	rect.material = mat
	var vp := SubViewport.new()
	vp.size = Vector2i(side, side)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(rect)
	root.add_child(vp)
	await _frames(4)
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## The lid as skin: before / after at portrait size, then 3x zooms of one eye (lid 0.45 before
## and after, blink_half and closed after).
func _sheet_lid_fix() -> void:
	var keep_hair: Color = _rig.get("_hair_color")
	var head := _find_head(LID_HEAD)
	if head < 0:
		push_error("shot_face_head: no head %s" % LID_HEAD)
		return
	_wear(head)
	var mat: ShaderMaterial = _rig.get("_skin_face")
	var after := mat.shader
	var before: Shader = null
	if FileAccess.file_exists(BEFORE_LID_SHADER):
		before = load(BEFORE_LID_SHADER) as Shader
	# [shader is before, zoomed, state, label]
	var cols := [
		[true, false, "neutral", "before"],
		[false, false, "neutral", "after"],
		[true, true, "lid", "before 3x, lid 0.45"],
		[false, true, "lid", "after 3x, lid 0.45"],
		[false, true, "blink_half", "after 3x, blink_half"],
		[false, true, "closed", "after 3x, closed"],
	]
	var cells := []
	for r in LID_PRESETS.size():
		var preset: String = LID_PRESETS[r]
		_rig.call("set_hair_color", NOBLE_HAIR if preset == "paper_noble" else keep_hair)
		_rig.set("face_style", load(STYLE_DIR + preset + ".tres") as FaceStyle)
		for c in cols.size():
			var col: Array = cols[c]
			mat.shader = before if col[0] and before != null else after
			_zoom_eye(col[1])
			var state: String = col[2]
			await _pose("neutral" if state == "lid" else state, 30)
			if state == "lid":
				_rig.call("_set_dial", 0.45, "lid", FaceStyle.Element.EYE)
				await create_timer(0.3).timeout
			var label := "%s / %s" % [preset.trim_prefix("paper_"), col[3]]
			cells.append([await _grab(J1_CELL), c, r, label])
	mat.shader = after
	_zoom_eye(false)
	_rig.call("set_hair_color", keep_hair)
	await _save_grid(cells, cols.size(), LID_PRESETS.size(), "lid_fix.png", J1_CELL)


## Every preset on the Base head and on head 2, before and after the unstretched disc fit
## (columns: Base face rect, then before / after per head). Before = the old shader with the
## old disc (DISC_SCALE x face_scale rect widths, heights stretched to the rect aspect).
func _sheet_head0_fix(only: Array) -> void:
	var presets := only.duplicate()
	if presets.is_empty():
		for f in DirAccess.get_files_at(STYLE_DIR):
			if f.ends_with(".tres"):
				presets.append(f.trim_suffix(".tres"))
		presets.sort()
	var before: Shader = null
	if only.is_empty() and FileAccess.file_exists(BEFORE_H0_SHADER):
		before = load(BEFORE_H0_SHADER) as Shader
	var cells := []
	for h in H0_HEADS.size():
		_wear(H0_HEADS[h])
		var mat: ShaderMaterial = _rig.get("_skin_face")
		var after := mat.shader
		for r in presets.size():
			var file: String = presets[r] + ".tres"
			var name := "%s / %s" % [_short(H0_HEADS[h]), presets[r].trim_prefix("paper_")]
			if before != null:
				var old := BEFORE_H0_STYLES + file
				_rig.set(
					"face_style", load(old if FileAccess.file_exists(old) else STYLE_DIR + file)
				)
				await _pose("neutral", 4)
				mat.shader = before
				mat.set_shader_parameter("disc_scale", FaceStyle.DISC_SCALE * FaceStyle.face_scale)
				cells.append([await _grab(), 1 + h * 2, r, "%s before" % name])
				mat.shader = after
			_rig.set("face_style", load(STYLE_DIR + file) as FaceStyle)
			await _pose("neutral", 4)
			if h == 0:
				mat.set_shader_parameter("debug_uv", true)
				cells.append([await _grab(), 0, r, "%s rect" % name])
				mat.set_shader_parameter("debug_uv", false)
			cells.append([await _grab(), 2 + h * 2, r, "%s after" % name])
	var file := "head0_fix.png" if only.is_empty() else "head0_%s.png" % only[0]
	await _save_grid(cells, 1 + H0_HEADS.size() * 2, presets.size(), file)


## Portrait framing, or LID_ZOOM times closer on the eye at LID_EYE (same camera position).
func _zoom_eye(on: bool) -> void:
	_cam.fov = 35
	_frame_camera(DIST)
	if on:
		var dir := _cam.project_ray_normal(LID_EYE * Vector2(SIZE))
		_cam.look_at(_cam.global_position + dir, Vector3.UP)
		_cam.fov = 35 / LID_ZOOM


## The wardrobe index of the head whose display name starts with `prefix`, -1 if none.
func _find_head(prefix: String) -> int:
	var lib := Wardrobe.library()
	var head := -1
	for i in lib.head_count():
		if String(lib.head(i).display_name).begins_with(prefix):
			head = i
	return head


func _sheet_debug(heads: Array) -> void:
	var cells := []
	_rig.set("face_style", load(STYLE_DIR + "paper_j1.tres") as FaceStyle)
	for c in heads.size():
		_wear(heads[c])
		var mat: ShaderMaterial = _rig.get("_skin_face")
		mat.set_shader_parameter("debug_uv", true)
		for r in 2:
			_rig.rotation_degrees.y = 45.0 * r
			await _pose("neutral", 4)
			cells.append([await _grab(), c, r, "%s %d deg" % [_short(heads[c]), 45 * r]])
		mat.set_shader_parameter("debug_uv", false)
	_rig.rotation_degrees.y = 0.0
	await _save_grid(cells, heads.size(), 2, "heads_uv_debug.png")


func _sheet_side(head: int) -> void:
	_wear(head)
	_rig.set("face_style", load(STYLE_DIR + "paper_j1.tres") as FaceStyle)
	var cells := []
	for r in 2:
		_rig.call("set_face_look", "brown", "round" if r == 1 else "")
		for c in SIDE_ANGLES.size():
			_rig.rotation_degrees.y = SIDE_ANGLES[c]
			await _pose("neutral", 4)
			var label := "%d deg%s" % [SIDE_ANGLES[c], " + glasses" if r == 1 else ""]
			cells.append([await _grab(), c, r, label])
	_rig.rotation_degrees.y = 0.0
	_rig.call("set_face_look", "brown", "")
	await _save_grid(cells, SIDE_ANGLES.size(), 2, "heads_uv_side.png")


func _preset_shots(only: Array) -> void:
	for preset: String in SHOTS:
		if not only.is_empty() and not only.has(preset):
			continue
		_rig.set("face_style", load(STYLE_DIR + preset + ".tres") as FaceStyle)
		for state: String in SHOTS[preset]:
			await _pose(state, SETTLE)
			var suffix := "" if state == "neutral" else "_" + state
			var path := OUT_DIR + "/head_%s%s.png" % [preset, suffix]
			var err := (await _grab()).save_png(path)
			print("Saved %s (%s)" % [path, error_string(err)])


## Put the face in a FaceStyle.expression() state and let it settle for `frames` frames
## worth of time (60 fps; the tweens run on time, not frames).
func _pose(state: String, frames: int) -> void:
	_rig.call("_proc_expression", "")
	_rig.call("_set_dial", _rig.call("_rest", "lid"), "lid", FaceStyle.Element.EYE)
	_rig.call("set_talking", false)
	await create_timer(0.3 if state != "neutral" else 0.02).timeout  # the reset tween settles
	if state == "closed" or state == "blink_half":
		var style: FaceStyle = _rig.get("face_style")
		var lid: float = style.expression(state)["lid"]
		_rig.call("_set_dial", lid, "lid", FaceStyle.Element.EYE)
	elif state == "talking":
		_rig.call("set_talking", true)
	elif state != "neutral":
		_rig.call("_proc_expression", state)
	await create_timer(frames / 60.0).timeout


func _short(head: int) -> String:
	var n := String(Wardrobe.library().head(head).display_name)
	return n.trim_prefix("tripo_").trim_suffix(" head")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The viewport's current frame, cropped to the head and scaled down to one cell.
func _grab(cell := CELL) -> Image:
	await _frames(2)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.86)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
	return crop


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String, cell := CELL) -> void:
	var size := Vector2i(cell * cols, (cell + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for c: Array in cells:
		var pos := Vector2(int(c[1]) * cell, int(c[2]) * (cell + LABEL_H))
		var img: Image = c[0]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		# a smaller image (the dialogue size) sits centred in its cell
		tr.position = pos + (Vector2(cell, cell) - Vector2(img.get_size())) * 0.5
		board.add_child(tr)
		var lab := Label.new()
		lab.text = c[3]
		lab.position = pos + Vector2(0, cell)
		lab.size = Vector2(cell, LABEL_H)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
