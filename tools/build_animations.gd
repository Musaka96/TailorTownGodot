extends SceneTree

## Generates the editable animation asset data/animations/default_animations.tres
## from CharacterAnimations.make_default(). Run after changing the code-side default
## set; once saved, the .tres is the source of truth and is edited in the inspector.
## CharacterRig loads it at runtime, so no character rebuild is needed to change an
## animation — only rerun this if you want to reset the asset to the defaults.
##   godot --headless --path . --script res://tools/build_animations.gd

const OUT_PATH := "res://data/animations/default_animations.tres"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/animations"))
	var res := CharacterAnimations.make_default()
	var err := ResourceSaver.save(res, OUT_PATH)
	if err == OK:
		print("build_animations: wrote ", OUT_PATH, "  entries=", res.entries.size())
		for entry in res.entries:
			print("  %-8s <- %s" % [entry.name, entry.clip])
		quit(0)
	else:
		printerr("build_animations: save failed, error ", err)
		quit(1)
