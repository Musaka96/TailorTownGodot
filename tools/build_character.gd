extends SceneTree

## Builds the shared Animal-Crossing-style character rig
## (res://entities/character/character_rig.tscn): a segmented "toon" figure —
## big head, stubby limbs — with an AnimationPlayer holding idle / walk / wave.
## AC characters barely deform, so this uses rigid segments under rotation pivots
## (no skinning) which matches the look and is reliable to author headlessly.
##
##   godot --headless --path . --script res://tools/build_character.gd
## Run this BEFORE build_phase1 (the player/customer scenes instance the rig).

const RIG_SCENE := "res://entities/character/character_rig.tscn"

# Default palette (skin/hair recoloured via set_palette; jacket/trousers replaced
# with real cloth via set_outfit — see CharacterRig).
const SKIN := Color(0.87, 0.72, 0.60)
const HAIR := Color(0.34, 0.24, 0.17)
const EYE := Color(0.10, 0.09, 0.11)
const JACKET := Color(0.18, 0.20, 0.28)
const TROUSERS := Color(0.18, 0.20, 0.28)
const SHIRT := Color(0.90, 0.90, 0.87)
const TIE := Color(0.52, 0.16, 0.20)
const SHOE := Color(0.10, 0.09, 0.09)


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "CharacterRig"
	root.set_script(load("res://entities/character/character_rig.gd"))

	var body := _pivot(root, "Body", Vector3.ZERO)
	_build_legs(body)
	var torso := _pivot(body, "Torso", Vector3(0, 0.44, 0))
	_box(torso, "TorsoMesh", Vector3(0.36, 0.42, 0.24), Vector3(0, 0.21, 0), "jacket", JACKET)
	_build_suit_front(torso)
	_build_arms(torso)
	_build_head(torso)

	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _idle())
	lib.add_animation("walk", _walk())
	lib.add_animation("wave", _wave())
	anim.add_animation_library("", lib)
	anim.autoplay = "idle"

	_save(root, RIG_SCENE)
	print("build_character: done.")
	quit(0)


# --- Geometry --------------------------------------------------------------


func _build_legs(body: Node3D) -> void:
	var legs := _pivot(body, "Legs", Vector3.ZERO)
	for side in [["L", -0.12], ["R", 0.12]]:
		var leg := _pivot(legs, "Leg%s" % side[0], Vector3(side[1], 0.44, 0))
		_box(
			leg,
			"Thigh%s" % side[0],
			Vector3(0.15, 0.44, 0.17),
			Vector3(0, -0.22, 0),
			"trousers",
			TROUSERS
		)
		_box(
			leg,
			"Foot%s" % side[0],
			Vector3(0.17, 0.09, 0.24),
			Vector3(0, -0.44, 0.05),
			"shoe",
			SHOE
		)


func _build_arms(torso: Node3D) -> void:
	for side in [["L", -0.24], ["R", 0.24]]:
		var arm := _pivot(torso, "Arm%s" % side[0], Vector3(side[1], 0.38, 0))
		_box(
			arm,
			"Sleeve%s" % side[0],
			Vector3(0.11, 0.36, 0.13),
			Vector3(0, -0.18, 0),
			"jacket",
			JACKET
		)
		_box(arm, "Hand%s" % side[0], Vector3(0.12, 0.11, 0.14), Vector3(0, -0.38, 0), "skin", SKIN)


# Shirt V + tie + lapels on the chest so the torso reads as an open suit jacket.
func _build_suit_front(torso: Node3D) -> void:
	_box(torso, "Shirt", Vector3(0.13, 0.34, 0.02), Vector3(0, 0.22, 0.121), "shirt", SHIRT)
	_box(torso, "Tie", Vector3(0.045, 0.25, 0.02), Vector3(0, 0.20, 0.132), "tie", TIE)
	var lapel_l := _box(
		torso, "LapelL", Vector3(0.08, 0.32, 0.03), Vector3(-0.09, 0.24, 0.125), "jacket", JACKET
	)
	lapel_l.rotation_degrees = Vector3(0, 0, 10)
	var lapel_r := _box(
		torso, "LapelR", Vector3(0.08, 0.32, 0.03), Vector3(0.09, 0.24, 0.125), "jacket", JACKET
	)
	lapel_r.rotation_degrees = Vector3(0, 0, -10)


func _build_head(torso: Node3D) -> void:
	var head := _pivot(torso, "Head", Vector3(0, 0.46, 0))
	_sphere(head, "HeadMesh", 0.30, Vector3(0, 0.30, 0), "skin", SKIN)
	_box(head, "Hair", Vector3(0.52, 0.22, 0.50), Vector3(0, 0.50, -0.02), "hair", HAIR)
	_box(head, "Snout", Vector3(0.14, 0.10, 0.12), Vector3(0, 0.24, 0.30), "skin", SKIN)
	_box(head, "EyeL", Vector3(0.06, 0.10, 0.04), Vector3(-0.12, 0.34, 0.29), "eye", EYE)
	_box(head, "EyeR", Vector3(0.06, 0.10, 0.04), Vector3(0.12, 0.34, 0.29), "eye", EYE)


func _pivot(parent: Node, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


func _box(
	parent: Node, name: String, size: Vector3, pos: Vector3, slot: String, color: Color
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color)
	mi.set_meta("slot", slot)
	parent.add_child(mi)
	return mi


func _sphere(
	parent: Node, name: String, radius: float, pos: Vector3, slot: String, color: Color
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	mi.mesh = m
	mi.position = pos
	mi.material_override = _mat(color)
	mi.set_meta("slot", slot)
	parent.add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


# --- Animations ------------------------------------------------------------


func _idle() -> Animation:
	var a := _anim(2.0, true)
	_track(
		a, "Body:position", [[0.0, Vector3.ZERO], [1.0, Vector3(0, -0.03, 0)], [2.0, Vector3.ZERO]]
	)
	_track(
		a, "Body:scale", [[0.0, Vector3.ONE], [1.0, Vector3(1.02, 0.98, 1.02)], [2.0, Vector3.ONE]]
	)
	_track(
		a,
		"Torso/Head:rotation",
		[[0.0, Vector3.ZERO], [1.0, Vector3(0.04, 0, 0)], [2.0, Vector3.ZERO]]
	)
	_track(
		a,
		"Torso/ArmL:rotation",
		[[0.0, Vector3.ZERO], [1.0, Vector3(0.06, 0, 0)], [2.0, Vector3.ZERO]]
	)
	_track(
		a,
		"Torso/ArmR:rotation",
		[[0.0, Vector3.ZERO], [1.0, Vector3(0.06, 0, 0)], [2.0, Vector3.ZERO]]
	)
	return a


func _walk() -> Animation:
	var a := _anim(0.6, true)
	_track(
		a,
		"Body/Legs/LegL:rotation",
		[[0.0, Vector3(0.55, 0, 0)], [0.3, Vector3(-0.55, 0, 0)], [0.6, Vector3(0.55, 0, 0)]]
	)
	_track(
		a,
		"Body/Legs/LegR:rotation",
		[[0.0, Vector3(-0.55, 0, 0)], [0.3, Vector3(0.55, 0, 0)], [0.6, Vector3(-0.55, 0, 0)]]
	)
	_track(
		a,
		"Torso/ArmL:rotation",
		[[0.0, Vector3(-0.5, 0, 0)], [0.3, Vector3(0.5, 0, 0)], [0.6, Vector3(-0.5, 0, 0)]]
	)
	_track(
		a,
		"Torso/ArmR:rotation",
		[[0.0, Vector3(0.5, 0, 0)], [0.3, Vector3(-0.5, 0, 0)], [0.6, Vector3(0.5, 0, 0)]]
	)
	_track(
		a,
		"Body:position",
		[
			[0.0, Vector3.ZERO],
			[0.15, Vector3(0, 0.05, 0)],
			[0.3, Vector3.ZERO],
			[0.45, Vector3(0, 0.05, 0)],
			[0.6, Vector3.ZERO]
		]
	)
	_track(
		a,
		"Body:rotation",
		[[0.0, Vector3(0, 0, 0.06)], [0.3, Vector3(0, 0, -0.06)], [0.6, Vector3(0, 0, 0.06)]]
	)
	return a


func _wave() -> Animation:
	var a := _anim(1.3, false)
	var keys := [
		[0.0, Vector3.ZERO],
		[0.2, Vector3(0, 0, -2.4)],
		[0.5, Vector3(0.35, 0, -2.4)],
		[0.8, Vector3(-0.35, 0, -2.4)],
		[1.1, Vector3(0, 0, -2.4)],
		[1.3, Vector3.ZERO],
	]
	_track(a, "Torso/ArmR:rotation", keys)
	_track(
		a,
		"Torso/Head:rotation",
		[[0.0, Vector3.ZERO], [0.5, Vector3(-0.1, 0, 0)], [1.3, Vector3.ZERO]]
	)
	return a


func _anim(length: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


func _track(a: Animation, path: String, keys: Array) -> void:
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath(path))
	a.track_set_interpolation_type(ti, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		a.track_insert_key(ti, k[0], k[1])


# --- Save (same pattern as build_phase1) -----------------------------------


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
