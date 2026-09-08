extends Node

## Autoloaded as "Debug". A togglable in-game debug console (F3, debug builds only)
## for driving game actions by hand: manage money, call customers, add/solve order
## tickets, and control the shift. Built entirely in code as its own CanvasLayer
## above everything, so no scene edits are needed. This is meant to grow — new
## in-game actions get a button here via _button()/_section().

const PANEL_BG := Color(0.10, 0.11, 0.15, 0.94)
const HEADING := Color(0.62, 0.78, 1.0)
const LABEL := Color(0.90, 0.92, 0.98)

var _layer: CanvasLayer
var _money_label: Label
var _status: Label
var _amount: LineEdit


func _ready() -> void:
	if not OS.is_debug_build():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh_money())


func _input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("debug_menu"):
		_toggle()
		get_viewport().set_input_as_handled()


# --- Actions ---------------------------------------------------------------


func _add_money(amount: int) -> void:
	GameState.money += amount
	_note("money %+d" % amount)


func _set_money() -> void:
	if _amount.text.is_valid_int():
		GameState.money = int(_amount.text)
		_note("money set to $%d" % GameState.money)


func _call_customer() -> void:
	var cm := _customer_manager()
	if cm != null:
		cm.debug_call_shopper()
		_note("called a customer")
	else:
		_note("no customer manager in scene")


func _clear_customers() -> void:
	var cm := _customer_manager()
	if cm != null:
		cm.debug_clear_customers()
		_note("cleared customers")


func _add_ticket() -> void:
	var order := Orders.debug_add_random()
	_note("added ticket for %s" % order.customer_name)


func _solve_first() -> void:
	Orders.debug_complete_first()
	_note("solved the first ticket")


func _solve_all() -> void:
	Orders.debug_complete_all()
	_note("solved all tickets")


func _expire_first() -> void:
	Orders.debug_expire_first()
	_note("expired the first ticket")


func _end_shift() -> void:
	if DayNight.running:
		DayNight.running = false
		EventBus.shift_ended.emit()
		_note("shift ended")


func _new_day() -> void:
	if not Shift.is_open():
		Shift.close_shop()
		_note("starting next day")


# --- Build -----------------------------------------------------------------


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 250  # above the post-process filter so it stays crisp
	_layer.visible = false
	add_child(_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_layer.add_child(margin)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(232, 0)
	panel.add_child(box)

	_heading(box, "DEBUG  ·  F3 to close")

	var money := _section(box, "Money")
	_money_label = _make_label("", 16, LABEL)
	money.add_child(_money_label)
	var mrow := _row(money)
	_button(mrow, "+100", _add_money.bind(100))
	_button(mrow, "+1k", _add_money.bind(1000))
	_button(mrow, "-100", _add_money.bind(-100))
	var srow := _row(money)
	_amount = LineEdit.new()
	_amount.placeholder_text = "amount"
	_amount.custom_minimum_size = Vector2(96, 0)
	srow.add_child(_amount)
	_button(srow, "Set", _set_money)

	var cust := _section(box, "Customers")
	var crow := _row(cust)
	_button(crow, "Call customer", _call_customer)
	_button(crow, "Clear", _clear_customers)

	var tickets := _section(box, "Tickets")
	var trow := _row(tickets)
	_button(trow, "Add", _add_ticket)
	_button(trow, "Solve 1st", _solve_first)
	var trow2 := _row(tickets)
	_button(trow2, "Solve all", _solve_all)
	_button(trow2, "Expire 1st", _expire_first)

	var shift := _section(box, "Shift")
	var shrow := _row(shift)
	_button(shrow, "End shift", _end_shift)
	_button(shrow, "Next day", _new_day)

	_status = _make_label("", 12, Color(0.7, 0.75, 0.85))
	box.add_child(_status)

	_refresh_money()


func _toggle() -> void:
	_layer.visible = not _layer.visible
	GameState.input_locked = _layer.visible
	if _layer.visible:
		_refresh_money()


func _refresh_money() -> void:
	if _money_label != null:
		_money_label.text = "Balance:  $%d" % GameState.money


func _note(text: String) -> void:
	if _status != null:
		_status.text = text


# --- Small UI builders -----------------------------------------------------


func _customer_manager() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "CustomerManager", true, false)
	return found[0] if not found.is_empty() else null


func _heading(parent: Node, text: String) -> void:
	var lbl := _make_label(text, 16, HEADING)
	parent.add_child(lbl)


func _section(parent: Node, title: String) -> VBoxContainer:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 4)
	parent.add_child(sec)
	sec.add_child(_make_label(title, 12, HEADING))
	return sec


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl
