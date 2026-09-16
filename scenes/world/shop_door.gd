class_name ShopDoor
extends Node3D

## Automatic swing door(s). Put this under a node whose children are door-leaf
## meshes (e.g. the town kit's "<shop>_Doors" group with door_leaf_left/right, whose
## origins sit on the hinges). When the player or a customer comes within `radius`
## the leaves swing open — away from whoever is approaching — and they swing shut
## once nobody is near, with a soft open/close sound played at the doorway.
##
## Nothing needs to be placed by hand: ShopDoor.attach_all(root) (called from
## main.gd) finds every "*_Doors" group in the level and adds one of these to it.

const GROUPS: Array[StringName] = [&"player", &"customer"]

## Horizontal distance from the doorway centre that triggers opening (metres).
@export var radius: float = 2.2
## How far each leaf swings (degrees).
@export var open_angle: float = 100.0
## Seconds for a full open / a full close.
@export var open_time: float = 0.28
@export var close_time: float = 0.45
## Volume trim for the door sounds (on top of Sfx.sfx_volume).
@export var volume_db: float = -2.0

var _leaves: Array[Dictionary] = []  # {node, rest, rest_global, side}
var _t := 0.0  # 0 closed .. 1 open
var _swing := 1.0  # +1 swings toward the leaves' local -Z, -1 toward +Z
var _was_open := false
var _audio: AudioStreamPlayer3D


## Add a ShopDoor to every "*_Doors" group (with door-leaf children) under `root`.
static func attach_all(root: Node) -> void:
	for group in root.find_children("*_Doors", "Node3D", true, false):
		if group.get_node_or_null("ShopDoor") != null:
			continue
		var door := ShopDoor.new()
		door.name = "ShopDoor"
		group.add_child(door)


func _ready() -> void:
	for child in get_parent().get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not String(mesh.name).contains("door_leaf"):
			continue
		# The leaf's free edge lies along its local +X or -X from the hinge.
		var aabb := mesh.get_aabb()
		var side := 1.0 if aabb.get_center().x >= 0.0 else -1.0
		var leaf := {"node": mesh, "rest": mesh.transform, "side": side}
		leaf["rest_global"] = mesh.global_transform
		_leaves.append(leaf)
	if _leaves.is_empty():
		set_physics_process(false)
		return
	var centre := Vector3.ZERO
	for leaf in _leaves:
		var m: MeshInstance3D = leaf["node"]
		centre += m.global_transform * m.get_aabb().get_center()
	global_position = centre / _leaves.size()
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"SFX"
	_audio.unit_size = 12.0
	_audio.max_distance = 40.0
	add_child(_audio)


func _physics_process(delta: float) -> void:
	var nearest := _nearest_actor()
	var want_open := nearest != null
	if want_open and _t <= 0.05:
		# Starting from shut: swing away from whoever is coming through.
		var rest: Transform3D = _leaves[0]["rest_global"]
		_swing = 1.0 if (rest.affine_inverse() * nearest.global_position).z >= 0.0 else -1.0
	var step := delta / (open_time if want_open else close_time)
	_t = move_toward(_t, 1.0 if want_open else 0.0, step)
	if want_open and not _was_open:
		_play("door_open")
	elif not want_open and _was_open and _t <= 0.0:
		_play("door_close")
	if want_open:
		_was_open = true
	elif _t <= 0.0:
		_was_open = false
	_pose()


func _pose() -> void:
	# One smoothstep curve both ways, so reversing mid-swing never jumps.
	var e := _t * _t * (3.0 - 2.0 * _t)
	var angle := deg_to_rad(open_angle) * e * _swing
	for leaf in _leaves:
		var m: MeshInstance3D = leaf["node"]
		var rest: Transform3D = leaf["rest"]
		# Rotating +θ about local Y moves +X toward -Z, so sign by the leaf's side.
		m.transform = Transform3D(
			rest.basis * Basis(Vector3.UP, angle * float(leaf["side"])), rest.origin
		)


func _nearest_actor() -> Node3D:
	var best: Node3D = null
	var best_d := radius * radius
	var here := Vector2(global_position.x, global_position.z)
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var actor := node as Node3D
			if actor == null or not actor.is_visible_in_tree():
				continue
			var d := here.distance_squared_to(
				Vector2(actor.global_position.x, actor.global_position.z)
			)
			if d < best_d:
				best_d = d
				best = actor
	return best


func _play(key: String) -> void:
	var s := Sfx.stream(key)
	if s == null or _audio == null:
		return
	_audio.stream = s
	_audio.volume_db = Sfx.sfx_volume + volume_db
	_audio.pitch_scale = randf_range(0.96, 1.04)
	_audio.play()
