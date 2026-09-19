class_name WorldAnchor
extends Control

## Pins a bit of HUD over something in the 3D world — a customer's patience meter, a
## passer-by's speech bubble. The content is centred on, and sits above, the point
## `height` metres over the target's feet; it follows every frame and frees itself when
## the target goes away.
##   WorldAnchor.pin(customer, meter, 2.5)

var target: Node3D
var height := 2.4


static func pin(to: Node3D, content: Control, at_height := 2.4) -> WorldAnchor:
	var anchor := WorldAnchor.new()
	anchor.target = to
	anchor.height = at_height
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(content)
	if UI != null and UI.hud != null:
		UI.hud.add_child(anchor)
		anchor._follow()
	return anchor


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		queue_free()
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		visible = false
		return
	var point := target.global_position + Vector3.UP * height
	visible = not cam.is_position_behind(point)
	var content := get_child(0) as Control if get_child_count() > 0 else null
	if content == null:
		return
	var box := content.get_combined_minimum_size().max(content.size)
	position = cam.unproject_position(point) - Vector2(box.x * 0.5, box.y)
