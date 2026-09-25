class_name CrtPowerOn
extends CanvasLayer
## The screen switching on like an old television, over whatever scene is under it.
## Added to the tree root, so it outlives a scene change: the intro drops it in, swaps
## to the main menu, and the menu warms up out of black. Frees itself when done.

const SHADER := preload("res://assets/shaders/crt_power_on.gdshader")
const HOLD := 0.35  # seconds of black before the dot, so the menu can finish building
const DURATION := 1.7

var _mat: ShaderMaterial = null


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS  # the main menu pauses the tree
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("progress", 0.0)
	rect.material = _mat
	add_child(rect)
	var tw := create_tween()
	tw.tween_interval(HOLD)
	tw.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tw.tween_callback(queue_free)


func _set_progress(value: float) -> void:
	_mat.set_shader_parameter("progress", value)
