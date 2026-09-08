extends Control

## The order board — opened with the Orders key (Tab / menu button). The left page
## lists every open order; selecting one expands it on the right into the full
## per-piece breakdown: each garment's spec and swatch, whether it's been checked
## off yet, plus the deadline, price and state. Read-only — a planning overlay so
## the player can see exactly what still needs making and how long is left.

const CHIP := {
	Enums.GarmentType.JACKET: "J",
	Enums.GarmentType.SHIRT: "S",
	Enums.GarmentType.PANTS: "P",
}

var _actor = null
var _sel := 0
var _tick := 0.0
var _decor_built := false

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _list: VBoxContainer = $Center/Panel/Margin/Box/Pages/List
@onready var _detail: VBoxContainer = $Center/Panel/Margin/Box/Pages/Detail
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func _ready() -> void:
	EventBus.order_created.connect(_on_changed)
	EventBus.order_part_filled.connect(func(_o, _t): _on_changed(null))
	EventBus.order_ready.connect(_on_changed)
	EventBus.order_fulfilled.connect(func(_o, _p): _on_changed(null))
	EventBus.order_expired.connect(_on_changed)


func open(actor) -> void:
	_actor = actor
	_sel = 0
	GameState.input_locked = true
	visible = true
	_style()
	_refresh()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_actor = null


func _on_changed(_order) -> void:
	if visible:
		_refresh()


func _process(delta: float) -> void:
	# Keep the deadline text ticking while the board is open (throttled — a full
	# rebuild every frame would needlessly re-make the swatch meshes).
	if not visible or Orders.active.is_empty():
		return
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		_refresh()


func _style() -> void:
	_panel.custom_minimum_size = Style.FRAME_WIDE
	Style.apply_skin(_panel, Style.MenuSkin.ORDERS)
	_title.add_theme_font_override("font", Style.bold_font())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Style.ACC_ORDERS)
	_list.add_theme_constant_override("separation", Style.S1)
	_detail.add_theme_constant_override("separation", Style.S2)
	_build_decor_once()


## One-time structure: scroll wrapper around the order list (a long queue can't
## grow the board) and the key-cap hint bar. Skin/frame is applied in _style().
func _build_decor_once() -> void:
	if _decor_built:
		return
	_decor_built = true
	var pages := _list.get_parent()
	var pos := _list.get_index()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.remove_child(_list)
	scroll.add_child(_list)
	pages.add_child(scroll)
	pages.move_child(scroll, pos)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.visible = false
	_hint.get_parent().add_child(Style.hint_bar([["W/S", "Select"], ["Esc", "Close"]]))


func _refresh() -> void:
	var orders: Array = Orders.active
	_title.text = "Orders  (%d)" % orders.size()
	_sel = clampi(_sel, 0, maxi(orders.size() - 1, 0))

	for child in _list.get_children():
		child.queue_free()
	if orders.is_empty():
		_list.add_child(_line("No open orders.", 16, Style.INK_SOFT))
	for i in orders.size():
		_list.add_child(_make_list_card(orders[i], i == _sel))

	for child in _detail.get_children():
		child.queue_free()
	if orders.is_empty():
		_detail.add_child(
			_line("Greet a customer and design a suit to take an order.", 16, Style.INK_SOFT)
		)
	else:
		_fill_detail(orders[_sel])


# --- Left page: the order list ---------------------------------------------


func _make_list_card(order, selected: bool) -> Control:
	var card := PanelContainer.new()
	if selected:
		card.add_theme_stylebox_override(
			"panel", Style.card(Style.CARD_SELECTED, 10, 3, Style.ACC_ORDERS)
		)
	else:
		card.add_theme_stylebox_override("panel", Style.card())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S1)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var who := _line(order.customer_name, 17, Style.INK)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	head.add_child(_status_label(order))
	box.add_child(
		_line(
			"%d / %d pieces done" % [_done_count(order), order.required_types().size()],
			13,
			Style.INK_SOFT
		)
	)
	return card


# --- Right page: the expanded order ----------------------------------------


func _fill_detail(order) -> void:
	_detail.add_child(_line(order.customer_name, 22, Style.INK))
	_detail.add_child(_status_line(order))
	_detail.add_child(_line("Agreed price: $%d" % order.price, 16, Style.LEAF))

	var sep := HSeparator.new()
	_detail.add_child(sep)

	for t in order.required_types():
		_detail.add_child(_piece_row(order, t))


func _piece_row(order, garment_type: int) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S2)
	card.add_child(row)

	var swatch := MaterialSwatch.new()
	swatch.swatch_size = 48
	var mat: MaterialType = order.part_material(garment_type)
	if mat != null:
		swatch.setup(mat, mat.roll_length_m)
	row.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_line(Enums.garment_type_name(garment_type), 17, Style.INK))
	text.add_child(_line(order.part_summary(garment_type), 14, Style.INK_SOFT))

	var done: bool = order.is_part_done(garment_type)
	var mark := _line("Done" if done else "To make", 15, Style.LEAF if done else Style.AMBER)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	return card


# --- Bits ------------------------------------------------------------------


func _status_line(order) -> Label:
	var days: int = order.days_left_ceil()
	var noun := "day" if days == 1 else "days"
	if order.state == SuitOrder.State.READY:
		return _line("Ready — collected in %d %s" % [days, noun], 16, Style.LEAF)
	return _line(
		"In progress — due in %d %s" % [days, noun],
		16,
		Style.fill_color(order.days_left / order.deadline_days)
	)


func _status_label(order) -> Label:
	if order.state == SuitOrder.State.READY:
		return _line("READY", 14, Style.LEAF)
	return _line(
		"%dd" % order.days_left_ceil(), 14, Style.fill_color(order.days_left / order.deadline_days)
	)


func _done_count(order) -> int:
	var n := 0
	for t in order.required_types():
		if order.is_part_done(t):
			n += 1
	return n


func _line(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# --- Input -----------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("orders") and not GameState.input_locked:
			open(get_tree().get_first_node_in_group("player"))
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_sel = wrapi(_sel + 1, 0, maxi(Orders.active.size(), 1))
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_sel = wrapi(_sel - 1, 0, maxi(Orders.active.size(), 1))
	elif (
		event.is_action_pressed("orders")
		or event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
	):
		close()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()
