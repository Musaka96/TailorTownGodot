extends CanvasLayer

## Root of all in-game UI — autoloaded as "UI" so any station can reach it.
## Holds the always-on HUD and the (hidden) shelf browse menu.

@onready var hud: Control = $HUD
@onready var shelf_menu: Control = $ShelfMenu


func _ready() -> void:
	shelf_menu.visible = false


func open_shelf_menu(shelf, actor) -> void:
	shelf_menu.open(shelf, actor)
