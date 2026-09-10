@tool
extends EditorPlugin

## Registers the Tool Runner dock — a one-click launcher for the project's
## res://tools/*.gd command-line tools (build_wardrobe, build_faces, validate, …).
## Editor-only.

const DockScript := preload("res://addons/tool_runner/tool_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Tools"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
