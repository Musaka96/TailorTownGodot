extends SceneTree

## Adds the "cut" input action (F / gamepad Y) to the project's input map without
## disturbing the others. Run headless, then --import:
##   godot --headless --path . --script res://tools/build_input.gd

func _initialize() -> void:
	var key := InputEventKey.new()
	key.device = -1
	key.physical_keycode = KEY_F

	var pad := InputEventJoypadButton.new()
	pad.device = -1
	pad.button_index = JOY_BUTTON_Y

	ProjectSettings.set_setting("input/cut", {"deadzone": 0.5, "events": [key, pad]})
	if ProjectSettings.save() != OK:
		push_error("build_input: save failed")
	else:
		print("build_input: added 'cut' (F / pad Y)")
	quit(0)
