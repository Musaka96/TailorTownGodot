extends Node3D

## Root of the playable scene. Composes the level, player and camera rig, which
## are wired together in main.tscn.
##
## Top-level input (pause / quit) is handled by the GameState autoload, which
## sits above the pausable scene tree. Add cross-scene wiring or level loading
## here as the game grows.


func _ready() -> void:
	# The shop scene is fully built now (children _ready before this). Let the save
	# system apply a queued load / start a new day / resume a direct boot.
	SaveManager.notify_game_ready()
