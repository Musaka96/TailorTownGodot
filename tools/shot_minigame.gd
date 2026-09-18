extends SceneTree

## Renders one craft minigame on its own, so the screens can be reviewed without
## walking a player to the bench. Like tools/screenshot.gd it captures the real
## framebuffer, so it must run WITHOUT --headless:
##
##   godot --path . --script res://tools/shot_minigame.gd -- cut  res://.dev/cut.png 150
##   godot --path . --script res://tools/shot_minigame.gd -- sew  res://.dev/sew.png 150
##
## Args (after the `--`): which ("cut" / "sew"), out path, frames to settle. The
## frame count matters — each game holds a lead-in of ~1.6s before it starts, so
## capture past ~120 frames to see one actually running.
##
## The minigame scripts are load()ed inside _initialize() rather than named
## directly: a --script tool compiles its dependencies before the autoloads exist,
## and these games reach for Config / Upgrades / Sfx.

const CUT_SCRIPT := "res://ui/cutting_minigame.gd"
const SEW_SCRIPT := "res://ui/sew_minigame.gd"
## The v2 / v3 cutting games ("cut2" / "cut3"): the tool holds Cut down from frame
## PRESS_AT so the capture shows a cut under way rather than the ready screen.
const CUT_VARIANTS := {
	"cut2": "res://ui/cut_allowance_minigame.gd", "cut3": "res://ui/cut_strokes_minigame.gd"
}
const PRESS_AT := 20
const GARMENT_JACKET := 2  # Enums.GarmentType.JACKET
const CLOTH := Color("7a3b3b")  # a burgundy bolt, to show the cloth tinting
const BACKDROP := Color("6f5b46")  # stands in for the shop behind the scrim

var _out := ""
var _frames := 150
var _count := 0
var _hold := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "cut"
	_out = args[1] if args.size() > 1 else "res://.dev/minigame_%s.png" % which
	_frames = int(args[2]) if args.size() > 2 else 150

	DisplayServer.window_set_size(Vector2i(1280, 720))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(host)
	var back := ColorRect.new()
	back.color = BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(back)

	var path: String = CUT_VARIANTS.get(which, SEW_SCRIPT if which == "sew" else CUT_SCRIPT)
	var game: Control = load(path).new()
	host.add_child(game)
	if CUT_VARIANTS.has(which):
		var factory: GDScript = load("res://data/scripts/material_factory.gd")
		game.start(GARMENT_JACKET, "Jacket · M", factory.make(1, 1, 0, 3.0))
		_hold = true
	elif which == "sew":
		game.start("Jacket · M", CLOTH)
	else:
		game.start(GARMENT_JACKET, "Jacket · M")

	print("Rendering %s minigame → %s ..." % [which, _out])
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_count += 1
	if _hold and _count == PRESS_AT:
		Input.action_press("cut")
	if _count < _frames:
		return
	var image := get_root().get_texture().get_image()
	if image == null:
		push_error("No framebuffer — are you running WITHOUT --headless?")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var err := image.save_png(_out)
	if err != OK:
		push_error("save_png failed: %d" % err)
		quit(1)
		return
	print("Saved ", _out)
	quit(0)
