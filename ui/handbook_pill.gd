extends Control

## The little "Handbook" pill in the HUD's bottom-left corner: shows the book's key and
## opens the Tailor's Handbook on a click. Hidden while any menu covers the world. Built
## in code by ui.gd; the key-cap follows the player's binding.

var _pill: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Open the Tailor's Handbook"
	_rebuild()
	Settings.bindings_changed.connect(_rebuild)


func _process(_delta: float) -> void:
	visible = not (UI.any_menu_open() or GameState.input_locked or get_tree().paused)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Craft.bump(_pill, 1.08)
		UI.open_handbook(get_tree().get_first_node_in_group("player"))


func _rebuild() -> void:
	if _pill != null:
		_pill.queue_free()
	_pill = Style.key_pill(Settings.binding_text("handbook"), "Handbook")
	add_child(_pill)
	_ignore_mouse(_pill)
	_fit.call_deferred()


func _fit() -> void:
	var want := _pill.get_combined_minimum_size()
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 20.0
	offset_right = 20.0 + want.x
	offset_bottom = -18.0
	offset_top = -18.0 - want.y


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
