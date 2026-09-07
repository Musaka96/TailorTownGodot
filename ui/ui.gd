extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

const FONT := preload("res://assets/fonts/Fredoka.ttf")

## Built in code (see _build_orders_menu) so the scene files never have to be
## regenerated to add it.
var orders_menu: Control

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


func open_shelf_menu(shelf, actor) -> void:
	shelf_menu.open(shelf, actor)


func open_phone(phone, actor) -> void:
	phone_order.open(phone, actor)


func open_worktable(worktable, actor, piece) -> void:
	worktable_screen.open(worktable, actor, piece)


func open_sewing(machine, actor, piece) -> void:
	sewing_screen.open(machine, actor, piece)


func open_suit_builder(mirror, actor) -> void:
	suit_builder.open(mirror, actor)


func open_customer_request(customer, actor) -> void:
	customer_request.open(customer, actor)


func open_handbook(actor) -> void:
	handbook.open(actor)


func open_orders_menu(actor) -> void:
	orders_menu.open(actor)


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
