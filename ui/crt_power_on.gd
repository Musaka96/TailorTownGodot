class_name CrtPowerOn
extends CanvasLayer
## The screen switching on like an old television, over whatever scene is under it.
## Added to the tree root, so it outlives a scene change: the intro drops it in, swaps
## to the main menu, and the menu warms up out of black. It stays black until the new
## scene has built and a few frames have settled (so a load hitch can't eat the
## animation), then plays with its sound and the menu theme fading in. Frees itself.

const SHADER := preload("res://assets/shaders/crt_power_on.gdshader")
const SETTLE_FRAMES := 4
const DURATION := 0.75

var keep: Array = []  # resources held alive until this frees (the intro's preloads)
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
	await get_tree().scene_changed
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	Sfx.play("crt_on")
	Sfx.start_menu_audio(1.5)
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tw.tween_callback(queue_free)


func _set_progress(value: float) -> void:
	_mat.set_shader_parameter("progress", value)
