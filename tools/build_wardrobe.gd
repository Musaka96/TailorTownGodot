extends SceneTree

## Generates the editable wardrobe asset data/wardrobe/default_wardrobe.tres from
## WardrobeLibrary.make_default(). Run after changing the code-side defaults; once
## saved, the .tres is the source of truth and the user edits it in the inspector.
##   godot --headless --path . --script res://tools/build_wardrobe.gd

const OUT_PATH := "res://data/wardrobe/default_wardrobe.tres"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/wardrobe"))
	var lib := WardrobeLibrary.make_default()
	var err := ResourceSaver.save(lib, OUT_PATH)
	if err == OK:
		print("build_wardrobe: wrote ", OUT_PATH)
		print(
			(
				"  hairs=%d tops=%d bottoms=%d skins=%d hair_colors=%d"
				% [
					lib.hairs.size(),
					lib.tops.size(),
					lib.bottoms.size(),
					lib.skin_colors.size(),
					lib.hair_colors.size(),
				]
			)
		)
		quit(0)
	else:
		printerr("build_wardrobe: save failed, error ", err)
		quit(1)
