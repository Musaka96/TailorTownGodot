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
const KICKER := "Orders board"
## The selected ticket has been taken off the board and is being held: it straightens up,
## comes forward a little, and gets the board's burgundy edge and stitching all round.
## (A brighter pin alone was far too quiet to find at a glance.)
const TILT := 1.2  # degrees the others hang at
const SEL_LINE := 5.0  # the held ticket's edge, against 1.5 for the rest
const SEL_GROW := 1.04

var _actor = null
var _sel := 0
var _tick := 0.0
var _decor_built := false
var _head: TitleBlock
var _count_meta: Label

var _calendar: HBoxContainer
@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/Box/Title
@onready var _list: VBoxContainer = $Center/Panel/Margin/Box/Pages/List
@onready var _detail: VBoxContainer = $Center/Panel/Margin/Box/Pages/Detail
@onready var _hint: Label = $Center/Panel/Margin/Box/Hint


func _ready() -> void:
	EventBus.order_created.connect(_on_changed)
	EventBus.order_part_filled.connect(func(_o, _t): _on_changed(null))
	EventBus.order_pieces_ready.connect(_on_changed)
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
	if _head == null:
		_head = TitleBlock.adopt(_title, KICKER, Style.ACC_ORDERS)
		_count_meta = TitleBlock.meta_label("", true)
		_head.meta.add_child(_count_meta)
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
	# The order book: the next few days at a glance (pickups due + booked fittings).
	_calendar = HBoxContainer.new()
	_calendar.add_theme_constant_override("separation", Style.S2)
	_calendar.alignment = BoxContainer.ALIGNMENT_CENTER
	var box := _head.get_parent()
	box.add_child(_calendar)
	box.move_child(_calendar, _head.get_index() + 1)
	_hint.get_parent().add_child(Style.hint_bar([["W/S", "Select"], ["Esc", "Close"]]))


## One little ticket per upcoming day: "Today · 2 pickups · 1 fitting", coloured like the
## due-date tickets (red today, amber tomorrow, green later) when anything is due.
func _refresh_calendar() -> void:
	if _calendar == null:
		return
	for c in _calendar.get_children():
		c.queue_free()
	var first := true
	for d: Dictionary in FrontDesk.calendar(5):
		var left := int(d["day"]) - Shift.day + 1
		var due := int(d["due"])
		var appts := int(d["appointments"])
		var card := CraftPanel.new()
		card.pad = Vector2(Style.S2, Style.S1)
		card.setup(CraftPanel.Shape.TICKET, Style.CARD)
		card.line = Style.due_color(left) if due > 0 else Style.CREAM_DARK
		card.line_width = 2.5 if due > 0 else 1.5
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		card.add_child(col)
		var head := "Today" if first else "Day %d" % int(d["day"])
		col.add_child(_line(head, Style.T_CAPTION, Style.INK))
		col.add_child(
			_line("%d pickup%s" % [due, "" if due == 1 else "s"], Style.T_MICRO, Style.INK_SOFT)
		)
		if appts > 0:
			col.add_child(
				_line(
					"%d fitting%s" % [appts, "" if appts == 1 else "s"], Style.T_MICRO, Style.BRASS
				)
			)
		_calendar.add_child(card)
		first = false
	if FrontDesk.booked:
		_calendar.add_child(_stamp("FULLY BOOKED", Style.BURGUNDY))


func _refresh() -> void:
	_refresh_calendar()
	var orders: Array = Orders.active
	_title.text = "Orders"
	_count_meta.text = "%d open" % orders.size()
	_sel = clampi(_sel, 0, maxi(orders.size() - 1, 0))

	for child in _list.get_children():
		child.queue_free()
	if orders.is_empty():
		_list.add_child(_line("No open orders.", Style.T_BODY, Style.INK_SOFT))
	for i in orders.size():
		_list.add_child(_make_list_card(orders[i], i == _sel, i))

	for child in _detail.get_children():
		child.queue_free()
	if orders.is_empty():
		_detail.add_child(
			_line(
				"Greet a customer and design a suit to take an order.", Style.T_BODY, Style.INK_SOFT
			)
		)
	else:
		_fill_detail(orders[_sel])


# --- Left page: the order list ---------------------------------------------


## An order as a paper ticket pinned to the cork board, each hung at its own slight
## angle; the selected one is pulled off the board — straightened, a size up, brightened,
## stitched and edged in burgundy, and held by a brass pin.
func _make_list_card(order, selected: bool, index: int) -> Control:
	var card := CraftPanel.new()
	card.pad = Vector2(Style.S3, Style.S2)
	card.setup(CraftPanel.Shape.TICKET, Style.CARD_SELECTED if selected else Style.CARD)
	card.line = Style.ACC_ORDERS if selected else Style.BROWN
	card.line_width = SEL_LINE if selected else 1.5
	card.stitch_color = Style.ACC_ORDERS if selected else Style.NONE
	card.pin_color = Style.BRASS if selected else Style.BURGUNDY
	card.pad = Vector2(Style.S3, Style.S2 + 8)
	card.rotation_degrees = 0.0 if selected else (TILT if index % 2 == 0 else -TILT)
	card.scale = Vector2.ONE * (SEL_GROW if selected else 1.0)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S1)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var who := _line("#%d  %s" % [order.id, order.customer_name], Style.T_BODY, Style.INK)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	head.add_child(_status_label(order))
	box.add_child(
		_line(
			"%d / %d pieces done" % [_done_count(order), order.required_types().size()],
			Style.T_CAPTION,
			Style.INK_SOFT
		)
	)
	return card


# --- Right page: the expanded order ----------------------------------------


func _fill_detail(order) -> void:
	_detail.add_child(
		_line("Order #%d  ·  %s" % [order.id, order.customer_name], Style.T_NAME, Style.INK)
	)
	_detail.add_child(_status_line(order))
	_detail.add_child(_price_row(order))

	_detail.add_child(StitchRule.make(Style.ACC_ORDERS, false, 2.0))

	for t in order.required_types():
		_detail.add_child(_piece_row(order, t))


## "Agreed price" as a soft label beside the bold, forest figure — never the price alone.
func _price_row(order) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S1)
	row.add_child(_line("Agreed price", Style.T_BODY, Style.INK_SOFT))
	row.add_child(Style.money(order.price, Style.T_BODY, Style.FOREST))
	return row


func _piece_row(order, garment_type: int) -> Control:
	var card := CraftPanel.new()
	card.setup(CraftPanel.Shape.PINKED, Style.CARD, Style.CREAM_DARK)
	card.line_width = 1.5
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
	text.add_child(_line(Enums.garment_type_name(garment_type), Style.T_BODY, Style.INK))
	text.add_child(_line(order.part_summary(garment_type), Style.T_CAPTION, Style.INK_SOFT))

	var done: bool = order.is_part_done(garment_type)
	row.add_child(_stamp("DONE" if done else "TO MAKE", Style.FOREST if done else Style.AMBER))
	return card


## A rubber-stamp mark: bold caps in a rounded ink border, set at a jaunty angle.
func _stamp(text: String, ink: Color) -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.NONE
	sb.set_border_width_all(2)
	sb.border_color = ink
	sb.set_corner_radius_all(6)
	sb.content_margin_left = Style.S2
	sb.content_margin_right = Style.S2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	box.add_theme_stylebox_override("panel", sb)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.rotation_degrees = -8.0
	box.add_child(_line(text, Style.T_CAPTION, ink, true))
	return box


# --- Bits ------------------------------------------------------------------


## The in-progress line splits off the due-date word so only that reads bold — the
## sentence around it stays plain (the bold rule: never a whole sentence).
func _status_line(order) -> Control:
	var days: int = order.days_left_ceil()
	if order.state == SuitOrder.State.READY:
		return _line("Ready for pickup — order #%d" % order.id, Style.T_BODY, Style.FOREST)
	if order.is_complete():
		return _line("Pieces made — assemble at the mannequin", Style.T_BODY, Style.BRASS)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.add_child(_line("In progress — due ", Style.T_BODY, Style.INK_SOFT))
	var due_word := ("in " if days > 2 else "") + Style.due_text(days).to_lower()
	row.add_child(_line(due_word, Style.T_BODY, Style.due_color(days), true))
	return row


## The ticket's status chip: a short word (or the due date), always bold like a stamp.
func _status_label(order) -> Label:
	if order.state == SuitOrder.State.READY:
		return _line("READY", Style.T_CAPTION, Style.FOREST, true)
	if order.is_complete():
		return _line("ASSEMBLE", Style.T_CAPTION, Style.BRASS, true)
	var left: int = order.days_left_ceil()
	return _line(Style.due_text(left), Style.T_CAPTION, Style.due_color(left), true)


func _done_count(order) -> int:
	var n := 0
	for t in order.required_types():
		if order.is_part_done(t):
			n += 1
	return n


func _line(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if bold:
		lbl.add_theme_font_override("font", Style.font_bold())
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


# --- Input -----------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("orders") and not GameState.input_locked:
			Sfx.play("menu_open")
			open(get_tree().get_first_node_in_group("player"))
			get_viewport().set_input_as_handled()
		return
	Sfx.ui(event)
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
