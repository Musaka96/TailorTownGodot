extends Control

## Overcooked-style order tickets across the top of the screen: a row of little
## paper cards, one per open order. Each shows the customer, a jacket swatch, the
## jacket spec, a chip per piece that lights up as it's checked off, the days left
## and the price. New orders pop in; when a piece is checked off its chip fills;
## when all are done the card turns "Ready"; when the customer collects it flashes
## the payout and clears. Driven by EventBus so it stays decoupled from Orders.
## The ticket edge (and the tab) is coloured by when the order is due — red today,
## amber tomorrow, green later — and while a station menu is open the tickets fold up
## into small numbered tabs so they never cover the work.

# GarmentType -> single-letter chip label.
const CHIP := {
	Enums.GarmentType.JACKET: "J",
	Enums.GarmentType.SHIRT: "S",
	Enums.GarmentType.PANTS: "P",
}

var _tickets := {}  # SuitOrder -> { card, days, chips, order, details, state }
var _collapsed := false

@onready var _row: HBoxContainer = $Tickets


func _ready() -> void:
	# Visual only — keep folding/unfolding while menus pause the game (handbook, mentor).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Stack tickets from the left (clearing the clock), not centred.
	_row.anchor_left = 0.0
	_row.anchor_right = 0.0
	_row.offset_left = 140.0
	_row.offset_top = 30.0  # room for the strings the tickets hang from
	_row.add_theme_constant_override("separation", Style.S3)
	_row.grow_horizontal = Control.GROW_DIRECTION_END
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	EventBus.order_created.connect(_on_created)
	EventBus.order_part_filled.connect(func(order, _t): _refresh(order))
	EventBus.order_pieces_ready.connect(_refresh)
	EventBus.order_ready.connect(_refresh)
	EventBus.order_due.connect(_refresh)
	EventBus.order_fulfilled.connect(_on_fulfilled)
	EventBus.order_expired.connect(_on_expired)
	# The HUD outlives the game scene: drop every ticket when the session ends or the
	# order book is rebuilt, or a reload would stack duplicates.
	EventBus.orders_cleared.connect(clear_tickets)
	EventBus.session_ended.connect(clear_tickets)


func _process(_delta: float) -> void:
	var fold: bool = UI != null and UI.any_menu_open()
	if fold != _collapsed:
		_collapsed = fold
		for order in _tickets:
			_apply_fold(_tickets[order])
	# Live-update the due badge + colour on each open ticket.
	for order in _tickets:
		_update_days(_tickets[order])


## Folded: just "#1 · Today" on the coloured tag. Unfolded: the full ticket.
func _apply_fold(ticket: Dictionary) -> void:
	for node: Control in ticket["details"]:
		node.visible = not _collapsed
	var card: CraftPanel = ticket["card"]
	card.custom_minimum_size.x = 0.0 if _collapsed else 116.0
	card.string_len = 16.0 if _collapsed else 34.0
	card.reset_size()
	Craft.bump(card, 1.06)


func clear_tickets() -> void:
	for order in _tickets:
		var card: Control = _tickets[order]["card"]
		if is_instance_valid(card):
			card.queue_free()
	_tickets.clear()
	# Also catch any card still fading out from a collection/expiry.
	for child in _row.get_children():
		child.queue_free()


func _on_created(order) -> void:
	if _tickets.has(order):
		return
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
	var card: CraftPanel = ticket["card"]
	Craft.wiggle(card, 4.0, card.rotation_degrees)
	_rebuild_chips(ticket)
	_update_days(ticket)


# --- Ticket building -------------------------------------------------------


func _make_ticket(order) -> Dictionary:
	# A paper swing ticket hanging on a string; its edge colour shows the order state.
	var card := CraftPanel.new()
	card.eyelet = true
	card.string_len = 34.0
	card.pad = Vector2(7, 7)
	card.setup(CraftPanel.Shape.TICKET, Style.CARD, Style.due_color(order.days_left_ceil()))
	card.stitch_color = Style.CREAM_DARK
	card.line_width = 2.5
	card.custom_minimum_size = Vector2(116, 0)
	card.rotation_degrees = 2.0 if _row.get_child_count() % 2 == 0 else -2.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", Style.S1)
	box.add_child(head)
	var who := _label(
		"#%d %s" % [order.id, order.customer_name], 13, Style.INK, HORIZONTAL_ALIGNMENT_LEFT
	)
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

	var state := _label("", 12, Style.BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(state)
	var price := _label("$%d" % order.price, 15, Style.LEAF, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(price)

	var ticket := {
		"card": card,
		"days": days,
		"chips": chips,
		"order": order,
		"details": [strip, spec, chips, state, price],
		"state": state,
	}
	_apply_fold(ticket)
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
	var left: int = order.days_left_ceil()
	var col := Style.due_color(left)
	days.text = Style.due_text(left)
	days.add_theme_color_override("font_color", col)
	var card: CraftPanel = ticket["card"]
	if card.line != col:
		card.line = col
	var state: Label = ticket["state"]
	if order.state == SuitOrder.State.READY:
		state.text = "READY FOR PICKUP"
		state.add_theme_color_override("font_color", Style.LEAF)
	elif order.is_complete():
		state.text = "ASSEMBLE AT MANNEQUIN"
		state.add_theme_color_override("font_color", Style.BRASS)
	else:
		state.text = ""
	state.visible = state.text != "" and not _collapsed


func _chip(text: String, done: bool) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(
		"panel", Style.card(Style.LEAF if done else Style.CREAM_DARK, 7)
	)
	var lbl := _label(
		text, 12, Style.CHALK if done else Style.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER
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


# --- Animation -------------------------------------------------------------


func _pop_in(ticket: Control) -> void:
	ticket.modulate.a = 0.0
	ticket.pivot_offset = Vector2(58, 0)
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
