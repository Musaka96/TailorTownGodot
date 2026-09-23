extends Control

## The key pills in the HUD's bottom-left corner — Newspaper, Orders and Handbook stacked
## up from the corner. Each shows its key and opens its page on a click. Hidden while any
## menu covers the world. Built in code by ui.gd; the key-caps follow the player's bindings.

## [action, label, tooltip], top to bottom.
const PILLS := [
	["newspaper", "Newspaper", "Read today's paper"],
	["orders", "Orders", "Open the orders board"],
	["handbook", "Handbook", "Open the Tailor's Handbook"],
]

var _stack: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()
	Settings.bindings_changed.connect(_rebuild)


func _process(_delta: float) -> void:
	visible = not (
		UI.key_pills_hidden or UI.any_menu_open() or GameState.input_locked or get_tree().paused
	)


func _rebuild() -> void:
	if _stack != null:
		remove_child(_stack)
		_stack.queue_free()
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", Style.S1)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	for spec: Array in PILLS:
		var pill := Style.key_pill(Settings.binding_text(spec[0]), spec[1])
		_ignore_mouse(pill)
		pill.mouse_filter = Control.MOUSE_FILTER_STOP
		pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pill.tooltip_text = spec[2]
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pill.gui_input.connect(_on_pill_input.bind(pill, String(spec[0])))
		_stack.add_child(pill)
	_fit.call_deferred()


func _on_pill_input(event: InputEvent, pill: Control, action: String) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	pill.accept_event()
	Craft.bump(pill, 1.08)
	var player := get_tree().get_first_node_in_group("player")
	match action:
		"newspaper":
			UI.newspaper.open()
		"orders":
			Sfx.play("menu_open")
			UI.open_orders_menu(player)
		_:
			UI.open_handbook(player)


func _fit() -> void:
	var want := _stack.get_combined_minimum_size()
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 20.0
	offset_right = 20.0 + want.x
	offset_bottom = -18.0
	offset_top = -18.0 - want.y
	_stack.size = want


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
