@tool
extends EditorPlugin

## Registers the Face Editor dock, where the character's 2D face layout
## (data/face_layout.tres) is tuned with a live preview. Editor-only.

const DockScript := preload("res://addons/face_editor/face_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Face"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
