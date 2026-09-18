extends Node

## Autoloaded as "Debug". A togglable in-game debug console (F3, debug builds only)
## for driving game actions by hand: manage money, call customers, add/solve order
## tickets, and control the shift. Built entirely in code as its own CanvasLayer
## above everything, so no scene edits are needed. This is meant to grow — new
## in-game actions get a button here via _button()/_section().

const PANEL_BG := Color(0.10, 0.11, 0.15, 0.94)
const HEADING := Color(0.62, 0.78, 1.0)
const LABEL := Color(0.90, 0.92, 0.98)
const SUIT_SCENE := preload("res://entities/items/suit.tscn")

var _layer: CanvasLayer
var _money_label: Label
var _status: Label
var _amount: LineEdit
var _cut_type: OptionButton
var _cut_variant: OptionButton
var _trial: CanvasLayer


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
		get_viewport().set_input_as_handled()
		if _trial != null:
			_end_trial()
			_note("cutting trial abandoned")
			return
		_toggle()


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


## Finish a ticket (or a fresh one), drop its packaged suit on the floor in front of
## the player, and send the customer in to collect it — the whole pickup flow on demand.
func _ready_for_pickup() -> void:
	var cm := _customer_manager()
	if cm == null:
		_note("no customer manager in scene")
		return
	var order := Orders.debug_pickup_candidate()
	Orders.debug_make_ready(order)
	_drop_suit(_make_suit(order))
	cm.debug_send_collector(order)
	_note("order #%d ready — %s is coming" % [order.id, order.customer_name])


## A packaged suit for this order, dressed in its designed cloth.
func _make_suit(order: SuitOrder) -> Suit:
	var suit: Suit = SUIT_SCENE.instantiate()
	suit.order_id = order.id
	suit.quality = 1.0
	suit.parts = {}
	for t in order.required_types():
		var c: Dictionary = order.design[t]
		var mat := MaterialFactory.make(
			int(c.get("fabric", 0)), int(c.get("pattern", 0)), int(c.get("color", 0)), 1.0
		)
		suit.parts[t] = {"material": mat, "quality": 1.0, "size": Enums.Size.M, "style": "Classic"}
	var jacket: Dictionary = suit.parts.get(Enums.GarmentType.JACKET, {})
	if jacket.get("material") != null:
		suit.primary_color = (jacket["material"] as MaterialType).cloth_color
	return suit


## Put the suit on the ground in front of the player (through the player's own drop, so
## it lands and saves like any dropped item); beside them if their hands are full.
func _drop_suit(suit: Suit) -> void:
	var scene := get_tree().current_scene
	var parent: Node = scene.get_node_or_null("ShopRoom") if scene != null else null
	if parent == null:
		parent = scene if scene != null else get_tree().root
	parent.add_child(suit)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		suit.set_pickable(true)
		return
	if player.carry.is_empty() and player.carry.take_item(suit):
		player.drop_held()
		return
	suit.global_position = (player as Node3D).global_position + Vector3(0.7, 0.15, 0.0)
	suit.set_pickable(true)


## Run one of the cutting games on its own, on a random bolt of cloth, over whatever
## scene is up — no walking to the bench, no order needed. F3 abandons it.
func _try_cut(variant: int) -> void:
	if _trial != null:
		return
	var garment := _cut_type.selected - 1
	if garment < 0:
		garment = randi() % 3
	var cloth := _random_cloth(garment)
	_layer.visible = false
	GameState.input_locked = true
	_trial = CanvasLayer.new()
	_trial.layer = 240  # over the HUD and the post-process filter, under this panel
	add_child(_trial)
	var game := CutVariants.create(variant)
	_trial.add_child(game)
	game.connect("finished", _on_trial_finished.bind(variant, cloth.display_name))
	var title := "%s · M" % Enums.garment_type_name(garment)
	game.call("start", garment, title, cloth)


func _on_trial_finished(success: bool, quality: float, variant: int, cloth: String) -> void:
	_end_trial()
	var result := "%d%%" % roundi(quality * 100.0) if success else "ruined"
	_note("%s on %s: %s" % [CutVariants.NAMES[variant], cloth, result])


## Close the trial and bring the panel back, ready for another go.
func _end_trial() -> void:
	if _trial != null:
		_trial.queue_free()
		_trial = null
	_layer.visible = true
	GameState.input_locked = true


## A bolt this part could really be cut from: its fabrics, patterns and colours.
func _random_cloth(garment: int) -> MaterialType:
	var fabrics := Enums.fabrics_for(garment)
	var patterns := Enums.patterns_for(garment)
	var colors := MaterialFactory.colors_for(garment)
	return (
		MaterialFactory
		. make(
			fabrics[randi() % fabrics.size()],
			patterns[randi() % patterns.size()],
			colors[randi() % colors.size()],
			3.0,
		)
	)


func _set_cut_variant(index: int) -> void:
	if Config.data != null:
		Config.data.cut_variant = index
		_note("worktable now runs %s" % CutVariants.NAMES[index])


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
	var trow3 := _row(tickets)
	_button(trow3, "Ready + pickup", _ready_for_pickup)

	var cut := _section(box, "Cutting minigame")
	var cut_row := _row(cut)
	cut_row.add_child(_make_label("Piece", 13, LABEL))
	_cut_type = OptionButton.new()
	for item in ["Random", "Shirt", "Pants", "Jacket"]:
		_cut_type.add_item(item)
	cut_row.add_child(_cut_type)
	var try_row := _row(cut)
	try_row.add_child(_make_label("Try", 13, LABEL))
	for v in CutVariants.NAMES.size():
		_button(try_row, "v%d" % (v + 1), _try_cut.bind(v))
	var use_row := _row(cut)
	use_row.add_child(_make_label("Worktable", 13, LABEL))
	_cut_variant = OptionButton.new()
	for v in CutVariants.NAMES:
		_cut_variant.add_item(v)
	_cut_variant.selected = CutVariants.current()
	_cut_variant.item_selected.connect(_set_cut_variant)
	use_row.add_child(_cut_variant)

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
