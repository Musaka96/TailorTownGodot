extends Node3D

## Root of the playable scene. Composes the level, player and camera rig, which
## are wired together in main.tscn.
##
## Top-level input (pause / quit) is handled by the GameState autoload, which
## sits above the pausable scene tree. Add cross-scene wiring or level loading
## here as the game grows.


func _ready() -> void:
	# The scene file marks this root "Always"; the shop must obey pause (pause menu,
	# handbook, tutorial mentor), so force it back to pausable here.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Auto-opening shop doors: hook up every "*_Doors" group in the level.
	ShopDoor.attach_all(self)
	# The OPEN / CLOSED sign by the door: flipping it opens the shop and ends the day.
	DoorSign.attach(self)
	# Cosmetic interior recolour (data/shop_looks/); F4 cycles it in debug builds.
	ShopLookApplier.attach(self)
	# A little dust in the light of the sunlit shop windows.
	DustMotes.attach_all(self)
	# The shop scene is fully built now (children _ready before this). Let the save
	# system apply a queued load / start a new day / resume a direct boot.
	SaveManager.notify_game_ready()
