extends SceneTree

## Writes res://data/game_config.tres from GameConfig's defaults so the user has
## a file to edit. Run once (headless); won't overwrite an existing edited file
## unless you delete it first.
##   godot --headless --path . --script res://tools/build_config.gd

const PATH := "res://data/game_config.tres"


func _initialize() -> void:
	if FileAccess.file_exists(PATH):
		print("build_config: %s already exists, leaving it." % PATH)
		quit(0)
		return
	var cfg: Resource = load("res://data/scripts/game_config.gd").new()
	if ResourceSaver.save(cfg, PATH) != OK:
		push_error("build_config: save failed")
	else:
		print("build_config: wrote ", PATH)
	quit(0)
