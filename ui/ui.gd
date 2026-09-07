extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

const FONT := preload("res://assets/fonts/Fredoka.ttf")

@onready var hud: Control = $HUD
@onready var shelf_menu: Control = $ShelfMenu
@onready var phone_order: Control = $PhoneOrder
@onready var worktable_screen: Control = $WorktableScreen
@onready var sewing_screen: Control = $SewingScreen
@onready var suit_builder: Control = $SuitBuilder


func _ready() -> void:
	shelf_menu.visible = false
	phone_order.visible = false
	worktable_screen.visible = false
	sewing_screen.visible = false
	suit_builder.visible = false
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
