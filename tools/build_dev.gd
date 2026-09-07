extends SceneTree

## Builds ONLY the dev sandbox scene (scenes/dev/dev_shop.tscn) — the one scene
## Claude owns and may regenerate. It NESTS the player's map (shop_room.tscn) as
## an instance, so it is a fully functional shop for testing, yet writing it never
## touches the map or any other scene. Add scratch/test props under "DevProps".
##
## Deliberately separate from build_phase1.gd (which regenerates every scene and
## would clobber the hand-edited map). Run headless:
##   godot --headless --path . --script res://tools/build_dev.gd

const ROOM_SCENE := "res://scenes/world/shop_room.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CAMERA_SCENE := "res://scenes/camera/camera_rig.tscn"
const OUT := "res://scenes/dev/dev_shop.tscn"


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "DevShop"
	root.set_script(load("res://main.gd"))
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	var room: Node = load(ROOM_SCENE).instantiate()
	root.add_child(room)

	var player: Node3D = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0, 0.1, 4.5)
	root.add_child(player)

	var rig: Node = load(CAMERA_SCENE).instantiate()
	rig.set("target_path", NodePath("../Player"))
	root.add_child(rig)

	# Scratch space for whatever is being prototyped/tested — safe to fill freely.
	var props := Node3D.new()
	props.name = "DevProps"
	root.add_child(props)

	_save(root, OUT)
	print("build_dev: done.")
	quit(0)


func _save(root: Node, path: String) -> void:
	_set_owner(root, root)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed: " + path)
		return
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
	else:
		print("wrote ", path)


func _set_owner(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		# Own instance roots only — never recurse into a nested sub-scene, or it
		# becomes an editable-children override and corrupts the instance.
		if child.scene_file_path == "":
			_set_owner(child, owner_root)
