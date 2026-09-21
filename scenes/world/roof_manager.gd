class_name RoofManager
extends Node3D

## A tiny roof-fader for the top-down view. While the player stands inside the
## building the roof melts away with a smooth transparency fade, and it fades back in
## the moment they step out — so the player is never lost under the shingles.
##
## Setup: drop this node in the room, point roof_path at the roof to manage, and size
## the interior box. The box is centred on this node (move/rotate the node to place it),
## so the gizmo shows roughly where "inside" begins. Detection just polls the player's
## position — no collision layers or trigger wiring needed.

## While true, the WALL pieces of a roof group (the upper halves of cut street fronts,
## named by `wall_prefixes`) stand back up while the player is inside; the roof proper,
## gables, caps and cornices stay away. For views framed from inside the shop (the
## fitting mirror). Set through hold_walls(); WallCutaway.hold_solid does the lower halves.
static var walls_held := false

## The roof to fade (a MeshInstance3D or a parent holding the roof meshes).
@export_node_path("Node3D") var roof_path: NodePath
## The player to track. Leave empty to grab the first node in the "player" group.
@export_node_path("Node3D") var player_path: NodePath
## Half-size of the interior box, centred on this node. Player inside → roof fades out.
@export var interior_extents := Vector3(3.6, 1.8, 5.9)
## Seconds the fade takes in each direction.
@export var fade_time := 0.45
## Pieces of the roof group that are really walls (see walls_held).
@export var wall_prefixes := PackedStringArray(["_hi", "int_curtains"])

var _roof: Node3D
var _player: Node3D
var _meshes: Array[GeometryInstance3D] = []
var _mats: Array[BaseMaterial3D] = []
var _inside := false
var _established := false
var _fade: Tween
var _walls_up := false  # the held walls are showing


func _ready() -> void:
	_roof = get_node_or_null(roof_path) as Node3D
	if _roof == null:
		push_warning("RoofManager: roof_path is not set to a valid node.")
		set_process(false)
		return
	_collect_meshes(_roof)
	_prime_materials()


## Stand the walls of every roof group back up (true), or let them go again (false).
static func hold_walls(on: bool) -> void:
	walls_held = on


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
		if _player == null:
			return
	var now := _contains(_player.global_position)
	if not _established:
		# The player node readies after us, so snap to the right state (no fade) once.
		_established = true
		_inside = now
		_apply_instant(1.0 if now else 0.0)
		return
	if now != _inside:
		_inside = now
		_fade_to(1.0 if now else 0.0)
	var want := walls_held and _inside
	if want != _walls_up:
		_walls_up = want
		_stand_walls(want)


## Bring the wall pieces back (solid, fading in) with the rest of the roof group left
## hidden — or put everything back as the roof normally is.
func _stand_walls(on: bool) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not on:
		for gi in _meshes:
			gi.visible = true
		_apply_instant(1.0 if _inside else 0.0)
		return
	_roof.visible = true
	_set_fadable(true)
	var walls: Array[GeometryInstance3D] = []
	for gi in _meshes:
		var is_wall := _is_wall(gi.name)
		gi.visible = is_wall
		if is_wall:
			gi.transparency = 1.0
			walls.append(gi)
	if walls.is_empty():
		return
	_fade = create_tween().set_parallel(true)
	for gi in walls:
		_fade.tween_property(gi, "transparency", 0.0, fade_time)
	_fade.chain().tween_callback(_set_fadable.bind(false))


func _is_wall(piece: String) -> bool:
	for p in wall_prefixes:
		if piece.contains(p):
			return true
	return false


func _resolve_player() -> Node3D:
	var p := get_node_or_null(player_path) as Node3D
	if p != null:
		return p
	return get_tree().get_first_node_in_group("player") as Node3D


## True when world_pos falls inside the (possibly rotated) interior box.
func _contains(world_pos: Vector3) -> bool:
	var local := to_local(world_pos)
	return (
		absf(local.x) <= interior_extents.x
		and absf(local.y) <= interior_extents.y
		and absf(local.z) <= interior_extents.z
	)


func _collect_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


## Roof cloth is imported opaque; give each surface its own copy, so this manager can
## switch that copy to alpha for the fade without touching the shared material.
##
## The copies stay OPAQUE while the roof is solid, and that matters beyond tidiness: an
## alpha material is skipped by the depth pre-pass, so a permanently-alpha roof left the
## rooms underneath it in the depth buffer — and the screen-space outline pass happily
## drew their silhouettes straight through the tiles. Solid means solid.
func _prime_materials() -> void:
	for gi in _meshes:
		var mi := gi as MeshInstance3D
		if mi == null:
			continue
		for s in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var dup: BaseMaterial3D = mat.duplicate()
			dup.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			mi.set_surface_override_material(s, dup)
			_mats.append(dup)


## Alpha on only while there is something to see through — see _prime_materials.
func _set_fadable(on: bool) -> void:
	var mode := BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
	for mat in _mats:
		mat.transparency = mode


func _apply_instant(target: float) -> void:
	_set_fadable(target > 0.0)
	for gi in _meshes:
		gi.transparency = target
	_roof.visible = target < 1.0


func _fade_to(target: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if target < 1.0:
		_roof.visible = true  # reveal before it fades back in
	_set_fadable(true)
	_fade = create_tween().set_parallel(true)
	for gi in _meshes:
		_fade.tween_property(gi, "transparency", target, fade_time)
	_fade.chain().tween_callback(_settle.bind(target))


## The fade is over: either the roof is gone, or it is solid again and goes back to
## being an opaque, depth-writing lid.
func _settle(target: float) -> void:
	if target >= 1.0:
		_hide_roof()
		return
	_set_fadable(false)
	for gi in _meshes:
		gi.transparency = 0.0


func _hide_roof() -> void:
	if _roof != null:
		_roof.visible = false
