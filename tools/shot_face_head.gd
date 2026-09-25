extends SceneTree

## Close-ups of the real character rig with a procedural face (CharacterRig.procedural_faces
## on: the face drawn in the head's skin material at its baked face UV). NOT headless:
##   godot --path . --script res://tools/shot_face_head.gd [-- presets [preset ...]]
## Writes to IMPORT/faces_proc/ (git-ignored):
##   heads_uv.png         every tripo head (+ the Base head) x every preset, neutral
##   heads_uv_states.png  one tripo head x the states, heavy_lid and laugh
##   heads_uv_debug.png   every head with its face rect as a checkerboard (red border),
##                        front and 45 degrees: the projection, and nothing on the back
##   heads_uv_side.png    heavy_lid on one tripo head from 0 / 30 / 60 / 90 / 180 degrees,
##                        bare and with round glasses
## With `presets` after `--`: the old per-preset shots, head_<preset>[_<state>].png (only
## the named presets when any are given).
## The outfit goes on one frame after the rig enters the tree (its mesh slots fill in
## _ready; earlier the cloth and skin tint silently miss).

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE_DIR := "res://data/face_styles/"
const PRESETS := ["heavy_lid", "old_timer", "moustache", "big_eyes", "wink", "blush", "laugh"]
const STATES := ["neutral", "blink_half", "closed", "happy", "sad", "talking"]
const STATE_PRESETS := ["heavy_lid", "laugh"]
const SIDE_ANGLES := [0.0, 30.0, 60.0, 90.0, 180.0]
# preset -> states to shoot ("neutral" = the resting face, no suffix), `presets` mode
const SHOTS := {
	"heavy_lid": ["neutral"],
	"old_timer": ["neutral"],
	"moustache": ["neutral"],
	"big_eyes": ["neutral", "talking"],
	"wink": ["neutral", "happy"],
	"blush": ["neutral"],
	"laugh": ["neutral"],
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
	else:
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


func _sheet_debug(heads: Array) -> void:
	var cells := []
	_rig.set("face_style", load(STYLE_DIR + "heavy_lid.tres") as FaceStyle)
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
	_rig.set("face_style", load(STYLE_DIR + "heavy_lid.tres") as FaceStyle)
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
	_rig.call("_set_dial", _rig.call("_rest", "openness"), "openness", FaceStyle.Element.EYE)
	_rig.call("set_talking", false)
	await create_timer(0.3 if state != "neutral" else 0.02).timeout  # the reset tween settles
	if state == "closed":
		_rig.call("_set_dial", 0.0, "openness", FaceStyle.Element.EYE)
	elif state == "blink_half":
		_rig.call("_set_dial", 0.4, "openness", FaceStyle.Element.EYE)
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
func _grab() -> Image:
	await _frames(2)
	var img := _vp.get_texture().get_image()
	var side := int(SIZE.x * 0.86)
	var crop := img.get_region(Rect2i((SIZE.x - side) / 2, (SIZE.y - side) / 2, side, side))
	crop.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return crop


## Lay out [image, column, row, label] cells on paper and save the sheet.
func _save_grid(cells: Array, cols: int, rows: int, file: String) -> void:
	var size := Vector2i(CELL * cols, (CELL + LABEL_H) * rows)
	var board := ColorRect.new()
	board.color = PAPER
	board.size = Vector2(size)
	for cell: Array in cells:
		var pos := Vector2(int(cell[1]) * CELL, int(cell[2]) * (CELL + LABEL_H))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(cell[0])
		tr.position = pos
		board.add_child(tr)
		var lab := Label.new()
		lab.text = cell[3]
		lab.position = pos + Vector2(0, CELL)
		lab.size = Vector2(CELL, LABEL_H)
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
