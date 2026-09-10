extends Node3D

## The game's front door — the boot scene (project.godot run/main_scene). A 3D scene
## (authored by tools/build_main_menu.gd, then editable): the starting shop nested as a
## backdrop, a Camera that eases between Marker3D "Viewpoints", and a left-anchored menu.
## This script only DRIVES it — it eases the camera to the current page's viewpoint and
## fills the button list. It pauses the tree so the autoloaded sim stays frozen behind the
## menu, and runs anyway (PROCESS_MODE_ALWAYS). New/Load hand off to SaveManager.

## How fast the camera eases toward the active viewpoint (higher = snappier).
const CAM_SPEED := 3.2
## Which viewpoint marker each page frames.
const VIEW_MAIN := "View_Main"
const VIEW_LOAD := "View_Load"
const VIEW_SETTINGS := "View_Settings"

var _sub := false  # true while the Load slot list is showing (Esc goes back)
var _target: Node3D

@onready var _camera: Camera3D = $Camera
@onready var _viewpoints: Node3D = $Viewpoints
@onready var _title: Label = $MenuLayer/Root/Left/Margin/Content/Title
@onready var _buttons: VBoxContainer = $MenuLayer/Root/Left/Margin/Content/Buttons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	# The in-game HUD/newspaper autoload draws above the scene — hide it behind the
	# menu (SaveManager shows it again once a game is running).
	if UI != null:
		UI.visible = false
	_target = _view(VIEW_MAIN)
	if _target != null:
		_camera.global_transform = _target.global_transform
	_show_main()


## Ease the camera toward the active page's viewpoint (position + rotation).
func _process(delta: float) -> void:
	if _target == null:
		return
	var w := clampf(delta * CAM_SPEED, 0.0, 1.0)
	_camera.global_transform = _camera.global_transform.interpolate_with(
		_target.global_transform, w
	)


func _view(nm: String) -> Node3D:
	return _viewpoints.get_node_or_null(nm) as Node3D


func _unhandled_input(event: InputEvent) -> void:
	# A stray event can arrive mid scene-swap once we've handed off. Cache the viewport
	# up front so both branches use a verified-non-null reference.
	var vp := get_viewport()
	if vp == null:
		return
	# Esc backs out of the load list; on the main page it's swallowed so it can't reach
	# GameState and unpause the frozen sim behind the menu.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if _sub:
			_show_main()
		vp.set_input_as_handled()
		return
	if MenuKit.handle_nav(event, _buttons):
		vp.set_input_as_handled()


func _show_main() -> void:
	_sub = false
	_target = _view(VIEW_MAIN)
	_clear()
	_title.text = "TailorTown"
	_buttons.add_child(MenuKit.button("New Game", _new_game))
	if SaveManager.has_any_save():
		_buttons.add_child(MenuKit.button("Continue", _continue))
	_buttons.add_child(MenuKit.button("Load Game", _show_load))
	_buttons.add_child(MenuKit.button("Settings", _show_settings))
	_buttons.add_child(MenuKit.button("Quit", func() -> void: get_tree().quit()))
	_focus_first()


func _show_settings() -> void:
	_sub = true
	_target = _view(VIEW_SETTINGS)
	_clear()
	_title.text = "Settings"
	SettingsUI.build(_buttons)
	_buttons.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _show_load() -> void:
	_sub = true
	_target = _view(VIEW_LOAD)
	_clear()
	_title.text = "Load a save"
	for info: Dictionary in SaveManager.slot_infos():
		var slot: Variant = info["slot"]
		if bool(info.get("exists", false)):
			_buttons.add_child(MenuKit.slot_row(info, func() -> void: _load(slot)))
		else:
			var empty := MenuKit.slot_row(info, Callable())
			empty.disabled = true
			_buttons.add_child(empty)
	_buttons.add_child(MenuKit.button("Back", _show_main))
	_focus_first()


func _new_game() -> void:
	_hand_off()
	SaveManager.new_game()


func _continue() -> void:
	var slot: Variant = SaveManager.latest_slot()
	if slot != null:
		_hand_off()
		SaveManager.load_from(slot)


func _load(slot: Variant) -> void:
	_hand_off()
	SaveManager.load_from(slot)


## About to swap scenes — stop reacting to input so no stray event hits this menu
## while it's being torn down.
func _hand_off() -> void:
	set_process_unhandled_input(false)


func _clear() -> void:
	# queue_free (not free): _clear runs from a button's own pressed handler, and a node
	# can't be freed while it's mid-emit. Hide now so the container drops it from layout
	# this frame and the new buttons don't briefly overlap the old.
	for child in _buttons.get_children():
		child.hide()
		child.queue_free()


func _focus_first() -> void:
	await get_tree().process_frame
	for child in _buttons.get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			return
