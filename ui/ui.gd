extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

const FONT := preload("res://assets/fonts/Fredoka.ttf")

## Built in code (see _build_orders_menu / _build_clock) so the scene files never
## have to be regenerated to add them.
var orders_menu: Control
var clock: Control
var day_transition: Control

var _toast: Label

@onready var hud: Control = $HUD
@onready var shelf_menu: Control = $ShelfMenu
@onready var phone_order: Control = $PhoneOrder
@onready var worktable_screen: Control = $WorktableScreen
@onready var sewing_screen: Control = $SewingScreen
@onready var suit_builder: Control = $SuitBuilder
@onready var customer_request: Control = $CustomerRequest
@onready var handbook: Control = $Handbook


func _ready() -> void:
	orders_menu = get_node_or_null("OrdersMenu")
	if orders_menu == null:
		orders_menu = _build_orders_menu()
	shelf_menu.visible = false
	phone_order.visible = false
	worktable_screen.visible = false
	sewing_screen.visible = false
	suit_builder.visible = false
	customer_request.visible = false
	handbook.visible = false
	orders_menu.visible = false
	# Apply the rounded font project-wide via a shared theme.
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	hud.theme = theme
	shelf_menu.theme = theme
	phone_order.theme = theme
	worktable_screen.theme = theme
	sewing_screen.theme = theme
	suit_builder.theme = theme
	customer_request.theme = theme
	handbook.theme = theme
	orders_menu.theme = theme
	clock = _build_clock()
	day_transition = _build_day_transition()


func open_shelf_menu(shelf, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("drawer")
	shelf_menu.open(shelf, actor)


func open_phone(phone, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("menu_open")
	phone_order.open(phone, actor)


func open_worktable(worktable, actor, piece) -> void:
	if _shop_closed():
		return
	Sfx.play("chalk")
	worktable_screen.open(worktable, actor, piece)


func open_sewing(machine, actor, piece) -> void:
	if _shop_closed():
		return
	Sfx.play("sew_machine", -3.0)
	sewing_screen.open(machine, actor, piece)


func open_suit_builder(mirror, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("tape")
	suit_builder.open(mirror, actor)


func open_customer_request(customer, actor) -> void:
	if _shop_closed():
		return
	Sfx.play("menu_open")
	customer_request.open(customer, actor)


func open_handbook(actor) -> void:
	Sfx.play("menu_open")
	handbook.open(actor)


func open_orders_menu(actor) -> void:
	Sfx.play("menu_open")
	orders_menu.open(actor)


func play_day_transition(old_day, new_day, earned, on_switch, on_done) -> void:
	day_transition.play(old_day, new_day, earned, on_switch, on_done)


## Brief centred message near the top of the screen (fades out on its own).
func toast(text: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_font_size_override("font_size", 22)
		_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_toast.position.y = 120
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


## True while the shop is shut for the night — work stations refuse and show a hint.
func _shop_closed() -> bool:
	if Shift != null and not Shift.is_open():
		Sfx.play("error")
		toast("The shop's closed — lock up at the door")
		return true
	return false


## Assemble the Orders board node tree in code (Dim + centered Panel with a Title,
## a two-column Pages row of List + Detail, and a Hint) and attach it last so its
## @onready paths resolve. Matches what orders_menu.gd expects. Kept out of the
## .tscn on purpose, so adding this feature never means rebuilding the scenes.
func _build_orders_menu() -> Control:
	var menu := Control.new()
	menu.name = "OrdersMenu"
	menu.set_script(load("res://ui/orders_menu.gd"))
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.name = "Title"
	box.add_child(title)

	var pages := HBoxContainer.new()
	pages.name = "Pages"
	pages.add_theme_constant_override("separation", 16)
	box.add_child(pages)

	var list := VBoxContainer.new()
	list.name = "List"
	list.custom_minimum_size = Vector2(300, 420)
	pages.add_child(list)

	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.custom_minimum_size = Vector2(440, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(detail)

	var hint := Label.new()
	hint.name = "Hint"
	box.add_child(hint)

	add_child(menu)  # attach last so the script's @onready node paths resolve
	return menu


## Analog shift clock, mounted top-left of the HUD. Built in code so the scenes
## never need regenerating to add it.
func _build_clock() -> Control:
	var widget := Control.new()
	widget.name = "Clock"
	widget.set_script(load("res://ui/clock_widget.gd"))
	widget.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(16, 12)
	hud.add_child(widget)
	return widget


## Full-screen day-change animation, attached to the root UI (above the HUD) so it
## covers everything. Built in code — no scene regen needed.
func _build_day_transition() -> Control:
	var overlay := Control.new()
	overlay.name = "DayTransition"
	overlay.set_script(load("res://ui/day_transition.gd"))
	add_child(overlay)
	return overlay
