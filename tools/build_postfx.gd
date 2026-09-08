extends SceneTree

## Generates the shipped post-process presets in data/postfx/ from the make_*
## factories on PostFxProfile. Run to (re)create or reset them; afterwards they are
## edited in the inspector. Switch the active look at runtime with
## PostFX.set_profile_path("res://data/postfx/<name>.tres").
##   godot --headless --path . --script res://tools/build_postfx.gd

const OUT_DIR := "res://data/postfx/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var presets := {
		"retro_70s": PostFxProfile.make_70s(),
		"vhs_80s": PostFxProfile.make_vhs(),
		"crt_green": PostFxProfile.make_crt_green(),
		"cozy_diorama": PostFxProfile.make_cozy_diorama(),
		"storybook": PostFxProfile.make_storybook(),
		"pixel_toy": PostFxProfile.make_pixel_toy(),
	}
	var failed := 0
	for file_name in presets:
		var path: String = OUT_DIR + str(file_name) + ".tres"
		if ResourceSaver.save(presets[file_name], path) == OK:
			print("  wrote ", path)
		else:
			printerr("  FAILED ", path)
			failed += 1
	print("build_postfx: %d preset(s), %d failed" % [presets.size(), failed])
	quit(1 if failed > 0 else 0)
