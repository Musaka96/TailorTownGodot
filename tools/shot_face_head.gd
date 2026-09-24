extends SceneTree

## Close-up of the real character rig with a procedural face (CharacterRig.procedural_faces
## on), framed like the char preview's face view, for each preset in SHOTS. NOT headless:
##   godot --path . --script res://tools/shot_face_head.gd [-- preset ...]
## Writes IMPORT/faces_proc/head_<preset>[_<state>].png; with preset names after `--` only
## those presets are shot.
## The outfit goes on one frame after the rig enters the tree (its mesh slots fill in
## _ready; earlier the cloth and skin tint silently miss).

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const RIG_SCRIPT := "res://entities/character/character_rig.gd"
const SUIT := "res://data/materials/navy_worsted_pinstripe.tres"
const STYLE_DIR := "res://data/face_styles/"
# preset -> states to shoot ("neutral" = the resting face, no suffix)
const SHOTS := {
	"round": ["neutral", "happy", "closed"],
	"heavy_lid": ["neutral", "happy"],
	"old_timer": ["neutral", "talking"],
}
const OUT_DIR := "res://IMPORT/faces_proc"
const SKIN := Color(0.86, 0.72, 0.60)
const DIST := 1.7
const SIZE := Vector2i(900, 900)
const SETTLE := 40

var _rig: Node3D  # CharacterRig (untyped: the class pulls in autoloads a --script lacks)
var _vp: SubViewport


func _initialize() -> void:
	var rig_script: Variant = load(RIG_SCRIPT)
	rig_script.procedural_faces = true
	# own viewport + world: a fixed size, and none of the game's HUD autoloads in the shot
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
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
	var y: float = FaceProfiles.load_or_default().layout_for(0).head_y
	var cam := Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, y, DIST), Vector3(0, y, 0.4), Vector3.UP)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var suit := load(SUIT) as MaterialType
	_rig.set_palette(SKIN)
	_rig.set_outfit(suit, null, suit, 0, 0)
	(_rig.get("_blink") as Timer).stop()  # no random blink mid-capture
	var only := OS.get_cmdline_user_args()
	for preset: String in SHOTS:
		if not only.is_empty() and not only.has(preset):
			continue
		_rig.set("face_style", load(STYLE_DIR + preset + ".tres") as FaceStyle)
		for state: String in SHOTS[preset]:
			await _pose(state)
			var suffix := "" if state == "neutral" else "_" + state
			await _shot("head_%s%s.png" % [preset, suffix])
	_report()
	quit(0)


## Put the face in a FaceStyle.expression() state (the rig tweens there during the settle).
func _pose(state: String) -> void:
	_rig.call("_proc_expression", "")
	_rig.call("_set_dial", _rig.call("_rest", "openness"), "openness", FaceStyle.Element.EYE)
	await _frames(20)
	if state == "closed":
		_rig.call("_set_dial", 0.0, "openness", FaceStyle.Element.EYE)
	elif state != "neutral":
		_rig.call("_proc_expression", state)


## Confirms the instance uniforms landed on the Sprite3D nodes.
func _report() -> void:
	for n: String in ["eye_l", "mouth"]:
		var s := _rig.find_child(n, true, false) as Sprite3D
		print(
			(
				"%s: element=%s fp0=%s override=%s"
				% [
					n,
					s.get_instance_shader_parameter("element"),
					s.get_instance_shader_parameter("fp0"),
					s.material_override != null,
				]
			)
		)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await _frames(SETTLE)
	var t := Time.get_ticks_msec()
	var img := _vp.get_texture().get_image()
	var path := OUT_DIR + "/" + file
	var err := img.save_png(path)
	print("Saved %s (%s, %d ms)" % [path, error_string(err), Time.get_ticks_msec() - t])
