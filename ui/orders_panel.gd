extends Control

## Top-centre HUD list of open bespoke orders, plus a short "paid" toast when one
## is fulfilled. Driven entirely by EventBus so it stays decoupled from the
## OrderManager.

var _orders: Array = []
var _cards: VBoxContainer
var _toasts: VBoxContainer

@onready var _stack: VBoxContainer = $Stack


func _ready() -> void:
	_cards = VBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", Style.S1)
	_stack.add_child(_cards)
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", Style.S1)
	_stack.add_child(_toasts)
	EventBus.order_created.connect(_on_created)
	EventBus.order_fulfilled.connect(_on_fulfilled)
	_refresh()


func _on_created(order) -> void:
	_orders.append(order)
	_refresh()


func _on_fulfilled(order, payout: int) -> void:
	_orders.erase(order)
	_refresh()
	_toast("Paid $%d  ·  %s" % [payout, order.customer_name])


func _refresh() -> void:
	for child in _cards.get_children():
		child.queue_free()
	if _orders.is_empty():
		return
	_cards.add_child(_make_header())
	for order in _orders:
		_cards.add_child(_make_card(order))


func _make_header() -> Control:
	var label := Label.new()
	label.text = "Orders (%d)" % _orders.size()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Style.AMBER)
	return label


func _make_card(order) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card(Style.CARD, 12, 3, Style.LEAF))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = "%s  ·  %s  ·  $%d" % [order.customer_name, order.describe(), order.price]
	label.add_theme_color_override("font_color", Style.INK)
	label.add_theme_font_size_override("font_size", 16)
	card.add_child(label)
	return card


func _toast(text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card(Style.CREAM, 12, 3, Style.AMBER))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Style.INK)
	label.add_theme_font_size_override("font_size", 16)
	card.add_child(label)
	_toasts.add_child(card)
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(card.queue_free)
