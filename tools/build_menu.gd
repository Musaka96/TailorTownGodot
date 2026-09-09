extends SceneTree

## Builds the boot scene: a single Control root carrying ui/main_menu.gd, which
## constructs the whole menu in code. Kept as a builder (like the rest of the
## scenes) so the .tscn is engine-authored, not hand-edited.
##
##   godot --headless --path . --script res://tools/build_menu.gd

const OUT := "res://scenes/menu/main_menu.tscn"


func _initialize() -> void:
	var dir := OUT.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://ui/main_menu.gd"))

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return
	print("Wrote ", OUT)
	quit(0)
