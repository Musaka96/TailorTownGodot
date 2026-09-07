extends SceneTree

## Builds the shared character rig (res://entities/character/character_rig.tscn)
## from the user's modified KayKit mannequin (assets/characters/CHAR2.glb: a
## Rig_Medium skeleton with the body split into separate mesh parts) plus the
## KayKit Rig_Medium animation clips merged into one AnimationPlayer.
##
## Because CHAR2 and the animation .glb share the same Rig_Medium skeleton
## (tracks target "Rig_Medium/Skeleton3D:<bone>"), the clips drive CHAR1 directly
## with no retargeting. Per-part suit materials are applied at runtime by
## character_rig.gd (triplanar cloth), so this only wires geometry + animation.
##
##   godot --headless --path . --script res://tools/build_character.gd

const RIG_SCENE := "res://entities/character/character_rig.tscn"
const CHAR_SOURCE := "res://assets/characters/CHAR2.glb"
const CHAR_NAME := "CHAR2"
const ANIM_DIR := "res://assets/characters/anim/"

# our name -> [source glb, clip name, loop]
const ANIMS := {
	"idle": ["Rig_Medium_General.glb", "Idle_A", true],
	"walk": ["Rig_Medium_MovementBasic.glb", "Walking_A", true],
	"wave": ["Rig_Medium_General.glb", "Interact", false],
}


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "CharacterRig"
	root.set_script(load("res://entities/character/character_rig.gd"))

	var model: Node = load(CHAR_SOURCE).instantiate()
	model.name = CHAR_NAME
	root.add_child(model)
	_report_size(model)

	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	anim.root_node = NodePath("../" + CHAR_NAME)
	var lib := AnimationLibrary.new()
	for our_name in ANIMS:
		var spec: Array = ANIMS[our_name]
		var clip := _load_clip(spec[0], spec[1])
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
			lib.add_animation(our_name, clip)
			print("  + %s <- %s / %s" % [our_name, spec[0], spec[1]])
	anim.add_animation_library("", lib)
	anim.autoplay = "idle"

	_save(root, RIG_SCENE)
	print("build_character: done.")
	quit(0)


func _load_clip(file: String, clip: String) -> Animation:
	var scene: Node = load(ANIM_DIR + file).instantiate()
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("no AnimationPlayer in " + file)
		return null
	var ap := players[0] as AnimationPlayer
	if not ap.has_animation(clip):
		push_error("no clip %s in %s" % [clip, file])
		return null
	return ap.get_animation(clip).duplicate() as Animation


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
