@tool
extends EditorPlugin

## Registers the News Editor dock, where newspaper events (NewsEvent resources under
## data/news/) are authored without hand-writing .tres. Editor-only.

const DockScript := preload("res://addons/news_editor/news_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "News"
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.free()
		_dock = null
