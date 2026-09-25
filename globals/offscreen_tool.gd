extends Node
## Keeps tool runs off the owner's desktop.
##
## Screenshot and report scripts (`godot --script res://tools/...gd` without
## --headless) need a real window for the GPU, and that window used to open on top
## of whatever the owner was doing. This autoload runs first: when the engine was
## started with `--script`, or with TT_OFFSCREEN=1 in the environment, it moves the
## main window far outside every screen on the first frame. Rendering continues
## there (DisplayServer.window_can_draw stays true), so screenshots still come out.
## Normal play is untouched: no --script, no env var, no move. The command-line
## `--position` flag cannot do this; the 4.7.2 build ignores it under --script.
## Set TT_OFFSCREEN=0 to force a visible window for a tool run.

const OFFSCREEN := Vector2i(9000, 9000)
## Frames during which the move is re-asserted: the Settings autoload re-centres
## the window when it applies the saved window size, one frame after boot.
const HOLD_FRAMES := 90

var _frames_left := 0


func _ready() -> void:
	if not _wanted():
		set_process(false)
		return
	_frames_left = HOLD_FRAMES
	_move()


func _process(_delta: float) -> void:
	_frames_left -= 1
	if DisplayServer.window_get_position() != OFFSCREEN:
		_move()
	if _frames_left <= 0:
		set_process(false)


func _wanted() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var env := OS.get_environment("TT_OFFSCREEN")
	if env == "0":
		return false
	if env == "1":
		return true
	return "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()


func _move() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(OFFSCREEN)
