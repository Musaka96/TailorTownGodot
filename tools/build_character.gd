extends SceneTree

## Builds the shared character rig (res://entities/character/character_rig.tscn)
## from the CHARTGEN1 character (res://assets/characters/CHARTGEN1.glb: a Rig_Medium
## skeleton with the body split into separate mesh parts — head, arms, jacket, shirt,
## legs, …). It wires geometry only: an empty AnimationPlayer is added (its root_node
## pointed at the model), and character_rig.gd fills it at runtime from the editable
## animation asset (data/animations/default_animations.tres via CharAnims) — so the
## animation set can be changed by editing that asset without rerunning this builder.
## Per-part suit materials are likewise applied at runtime (UV-mapped cloth).
##
##   godot --headless --path . --script res://tools/build_character.gd

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const CHAR_SOURCE := "res://assets/characters/CHARTGEN1.glb"
const CHAR_NAME := "CHARTGEN1"


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "CharacterRig"
	root.set_script(load("res://entities/character/character_rig.gd"))

	var model: Node = load(CHAR_SOURCE).instantiate()
	model.name = CHAR_NAME
	root.add_child(model)
	_report_size(model)

	# Empty player; the rig installs the animation library from the asset at runtime.
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	anim.root_node = NodePath("../" + CHAR_NAME)

	_save(root, RIG_SCENE)
	print("build_character: done.")
	quit(0)


func _report_size(model: Node) -> void:
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = mi.global_transform * b
		if first:
			aabb = b
			first = false
		else:
			aabb = aabb.merge(b)
	print("CHAR AABB size=%s  min=%s  max=%s" % [aabb.size, aabb.position, aabb.end])


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
		if child.scene_file_path == "":
			_set_owner(child, owner_root)
