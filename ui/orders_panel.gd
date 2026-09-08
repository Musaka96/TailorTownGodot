extends Control

## Overcooked-style order tickets across the top of the screen: a row of little
## paper cards, one per open order. Each shows the customer, a jacket swatch, the
## jacket spec, a chip per piece that lights up as it's checked off, the days left
## and the price. New orders pop in; when a piece is checked off its chip fills;
## when all are done the card turns "Ready"; when the customer collects it flashes
## the payout and clears. Driven by EventBus so it stays decoupled from Orders.

# GarmentType -> single-letter chip label.
const CHIP := {
	Enums.GarmentType.JACKET: "J",
	Enums.GarmentType.SHIRT: "S",
	Enums.GarmentType.PANTS: "P",
}

var _tickets := {}  # SuitOrder -> { card, days, chips, order }

@onready var _row: HBoxContainer = $Tickets


func _ready() -> void:
	# Stack tickets from the left (clearing the clock), not centred.
	_row.anchor_left = 0.0
	_row.anchor_right = 0.0
	_row.offset_left = 124.0
	_row.grow_horizontal = Control.GROW_DIRECTION_END
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	EventBus.order_created.connect(_on_created)
	EventBus.order_part_filled.connect(func(order, _t): _refresh(order))
	EventBus.order_ready.connect(_refresh)
	EventBus.order_due.connect(_refresh)
	EventBus.order_fulfilled.connect(_on_fulfilled)
	EventBus.order_expired.connect(_on_expired)


func _process(_delta: float) -> void:
	# Live-update the days-left badge on each open ticket.
	for order in _tickets:
		_update_days(_tickets[order])


func _on_created(order) -> void:
	var ticket := _make_ticket(order)
	_row.add_child(ticket["card"])
	_tickets[order] = ticket
	_pop_in(ticket["card"])


func _on_fulfilled(order, payout: int) -> void:
	var ticket = _tickets.get(order)
	if ticket == null:
		return
	_tickets.erase(order)
	_float_payout(ticket["card"], payout)
	_complete(ticket["card"], Style.LEAF)


func _on_expired(order) -> void:
	var ticket = _tickets.get(order)
	if ticket == null:
		return
	_tickets.erase(order)
	_complete(ticket["card"], Style.CLAY)


func _refresh(order) -> void:
	var ticket = _tickets.get(order)
	if ticket == null:
		return
	ticket["card"].add_theme_stylebox_override("panel", _ticket_style(order))
	_rebuild_chips(ticket)
	_update_days(ticket)


# --- Ticket building -------------------------------------------------------


func _make_ticket(order) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _ticket_style(order))
	card.custom_minimum_size = Vector2(116, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Style.S1)
	box.add_child(head)
	var who := _label(order.customer_name, 13, Style.INK, HORIZONTAL_ALIGNMENT_LEFT)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var days := _label("", 12, Style.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(days)

	# Slim fabric-colour strip — the look at a glance, no roll/durability meter.
	var mat: MaterialType = order.jacket_material()
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 9)
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = mat.cloth_color if mat != null else Style.CREAM_DARK
	strip_style.set_corner_radius_all(4)
	strip.add_theme_stylebox_override("panel", strip_style)
	box.add_child(strip)

	var spec := _label(order.describe(), 11, Style.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec.custom_minimum_size = Vector2(100, 0)
	box.add_child(spec)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", Style.S1)
	box.add_child(chips)

	box.add_child(_label("$%d" % order.price, 15, Style.LEAF, HORIZONTAL_ALIGNMENT_CENTER))

	var ticket := {"card": card, "days": days, "chips": chips, "order": order}
	_rebuild_chips(ticket)
	_update_days(ticket)
	return ticket


func _rebuild_chips(ticket: Dictionary) -> void:
	var chips: HBoxContainer = ticket["chips"]
	var order = ticket["order"]
	for child in chips.get_children():
		child.queue_free()
	for t in order.required_types():
		chips.add_child(_chip(CHIP.get(t, "?"), order.is_part_done(t)))


func _update_days(ticket: Dictionary) -> void:
	var order = ticket["order"]
	var days: Label = ticket["days"]
	if order.state == SuitOrder.State.READY:
		days.text = "READY"
		days.add_theme_color_override("font_color", Style.LEAF)
		return
	var left: int = order.days_left_ceil()
	days.text = "%dd" % left
	days.add_theme_color_override(
		"font_color", Style.fill_color(order.days_left / order.deadline_days)
	)


func _chip(text: String, done: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(
		"panel", Style.card(Style.LEAF if done else Style.CREAM_DARK, 7)
	)
	var lbl := _label(
		text, 12, Color.WHITE if done else Style.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER
	)
	lbl.custom_minimum_size = Vector2(16, 0)
	chip.add_child(lbl)
	return chip


func _label(text: String, size: int, color: Color, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _ticket_style(order) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.96, 0.90)  # paper
	sb.set_corner_radius_all(10)
	sb.border_width_top = 6  # coloured ticket header strip: state at a glance
	sb.border_color = _state_color(order)
	sb.set_content_margin_all(7)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _state_color(order) -> Color:
	if order.state == SuitOrder.State.READY:
		return Style.LEAF
	if order.days_left_ceil() <= 1:
		return Style.CLAY
	return Style.AMBER


# --- Animation -------------------------------------------------------------


func _pop_in(ticket: Control) -> void:
	ticket.modulate.a = 0.0
	ticket.pivot_offset = Vector2(58, 50)
	ticket.scale = Vector2(0.8, 0.8)
	var tween := create_tween().set_parallel()
	tween.tween_property(ticket, "modulate:a", 1.0, 0.2)
	tween.tween_property(ticket, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _complete(ticket: Control, flash: Color) -> void:
	ticket.pivot_offset = ticket.size / 2.0
	var tween := create_tween()
	tween.tween_property(ticket, "modulate", flash, 0.12)
	tween.tween_interval(0.4)
	tween.tween_property(ticket, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ticket.queue_free)


func _float_payout(ticket: Control, payout: int) -> void:
	var lbl := _label("+$%d" % payout, 24, Style.LEAF, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(lbl)
	lbl.global_position = ticket.global_position + Vector2(45, 30)
	var tween := create_tween().set_parallel()
	tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 45, 0.9)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(lbl.queue_free)
