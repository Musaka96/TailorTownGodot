extends Node

## Loads the tunables resource and exposes it as `Config.data` (a GameConfig).
## Autoloaded as "Config". Falls back to script defaults if the .tres is missing.

const PATH := "res://data/game_config.tres"

var data: GameConfig


func _ready() -> void:
	var res := load(PATH) if ResourceLoader.exists(PATH) else null
	data = res as GameConfig
	if data == null:
		data = GameConfig.new()
