extends Control

## Overcooked-style order tickets across the top of the screen: a horizontal row
## of little paper cards, each with the customer, a fabric swatch of the jacket,
## the spec and the price. New orders pop in; a fulfilled one flashes its payout
## and clears. Driven entirely by EventBus so it stays decoupled from OrderManager.

var _tickets := {}  # SuitOrder -> Control

@onready var _row: HBoxContainer = $Tickets


func _ready() -> void:
	EventBus.order_created.connect(_on_created)
	EventBus.order_fulfilled.connect(_on_fulfilled)


func _on_created(order) -> void:
	var ticket := _make_ticket(order)
	_row.add_child(ticket)
	_tickets[order] = ticket
	_pop_in(ticket)


func _on_fulfilled(order, payout: int) -> void:
	var ticket = _tickets.get(order)
	if ticket == null:
		return
	_tickets.erase(order)
	_float_payout(ticket, payout)
	_complete(ticket)


# --- Ticket building -------------------------------------------------------


func _make_ticket(order) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _ticket_style())
	card.custom_minimum_size = Vector2(150, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S1)
	card.add_child(box)

	box.add_child(_label(order.customer_name, 15, Style.INK, HORIZONTAL_ALIGNMENT_CENTER))

	var swatch := MaterialSwatch.new()
	swatch.swatch_size = 64
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(swatch)
	var mat: MaterialType = order.jacket_material()
	if mat != null:
		swatch.setup(mat, mat.roll_length_m)

	var spec := _label(order.describe(), 12, Style.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	spec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec.custom_minimum_size = Vector2(134, 0)
	box.add_child(spec)

	box.add_child(_label("$%d" % order.price, 18, Style.LEAF, HORIZONTAL_ALIGNMENT_CENTER))
	return card


func _label(text: String, size: int, color: Color, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _ticket_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.96, 0.90)  # paper
	sb.set_corner_radius_all(10)
	sb.border_width_top = 6  # coloured ticket header strip
	sb.border_color = Style.AMBER
	sb.set_content_margin_all(Style.S2)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


# --- Animation -------------------------------------------------------------


func _pop_in(ticket: Control) -> void:
	ticket.modulate.a = 0.0
	ticket.pivot_offset = Vector2(75, 70)
	ticket.scale = Vector2(0.8, 0.8)
	var tween := create_tween().set_parallel()
	tween.tween_property(ticket, "modulate:a", 1.0, 0.2)
	tween.tween_property(ticket, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _complete(ticket: Control) -> void:
	ticket.pivot_offset = ticket.size / 2.0
	var tween := create_tween()
	tween.tween_property(ticket, "modulate", Style.LEAF, 0.12)
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
