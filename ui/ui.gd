extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

const FONT := preload("res://assets/fonts/Fredoka.ttf")

@onready var hud: Control = $HUD
@onready var shelf_menu: Control = $ShelfMenu
@onready var phone_order: Control = $PhoneOrder
@onready var worktable_screen: Control = $WorktableScreen


func _ready() -> void:
	shelf_menu.visible = false
	phone_order.visible = false
	worktable_screen.visible = false
	# Apply the rounded font project-wide via a shared theme.
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	hud.theme = theme
	shelf_menu.theme = theme
	phone_order.theme = theme
	worktable_screen.theme = theme


func open_shelf_menu(shelf, actor) -> void:
	shelf_menu.open(shelf, actor)


func open_phone(phone, actor) -> void:
	phone_order.open(phone, actor)


func open_worktable(worktable, actor, piece) -> void:
	worktable_screen.open(worktable, actor, piece)
