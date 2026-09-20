class_name WallCutaway
extends Node3D

## The dollhouse cutaway, eased out instead of sawn off. While the player is inside, the
## walls of the group at `walls_path` thin away to nothing above `cut_height` over
## `fade_band` metres; when they step out, the walls come back solid.
##
## Why: the street fronts are cut at 1.1 m in Blender (build_v8_grandpa.py, CUT = 1.1)
## and RoofManager hides the upper half while you are inside. What is left ends in a hard
## horizontal line with a dark cap on it, and from inside the shop it reads as a wall
## somebody sawed in half rather than as a wall the camera is seeing past. The fade turns
## that edge into an effect. See materials/wall_cutaway.gdshader.
##
## Pieces named in `skip_prefixes` are not walls (the roof itself, gables, the sign, and
## the caps that sit on the old flat cut) — they keep the plain "gone while you're
## inside" behaviour instead. Setup mirrors RoofManager: drop the node in the room,
## point it at the glTF group, size the interior box.

const SHADER := preload("res://materials/wall_cutaway.gdshader")

## The wall group to cut (a glTF group node, e.g. `..._Roof` or `..._Divider`).
@export_node_path("Node3D") var walls_path: NodePath
## Pieces whose name contains one of these are hidden outright rather than cut — the
## roof proper, and the caps that only existed to dress the old flat cut.
@export var skip_prefixes := PackedStringArray(["roof_", "gable_", "ShopSign", "wall_cap"])
## Which pieces of `walls_path` to fade — everything when left empty. Naming the cut
## walls (e.g. "_lo") keeps the fade off the interior walls that were never cut.
@export var only_prefixes: PackedStringArray = []
## More groups holding the same walls (the lower halves of an already-split wall, and
## the caps sitting on the old flat cut). `skip_prefixes` applies here too, so the caps
## are hidden while the wall is down and the halves become one continuous surface.
@export var shared_paths: Array[NodePath] = []
## Pieces of `shared_paths` to convert — everything when left empty.
@export var shared_prefixes: PackedStringArray = []
## The player to track. Leave empty to grab the first node in the "player" group.
@export_node_path("Node3D") var player_path: NodePath
## Half-size of the interior box, centred on this node — same test as RoofManager.
@export var interior_extents := Vector3(9.4, 1.8, 5.1)
## World Y the wall has faded away to nothing by while the player is inside.
@export var cut_height := 1.35
## World Y that counts as "whole" — above the ridge, so nothing is cut.
@export var up_height := 99.0
## Seconds the wall takes to sink or grow back.
@export var fade_time := 0.45
## Metres below `cut_height` where the wall starts thinning. Bigger = softer melt.
@export var fade_band := 0.55
## 0 = a level fade line; higher lets it wander so it does not look ruled.
@export var wobble := 0.25
## Wobbles per metre along the wall.
@export var wobble_scale := 0.9
## How much the thinning wall pales out on its way to nothing.
@export var haze := 0.35
## How much sooner the wall gives out right where the player stands (0 = level).
@export var dip := 0.0
@export var dip_radius := 1.8
## Invert: cut only while the player is inside the box (the street fronts), or only
## while they are NOT (a divider you want gone when you stand behind it).
@export var cut_when_inside := true

var _walls: Node3D
var _player: Node3D
var _cut_mats: Array[ShaderMaterial] = []
var _by_src := {}
var _plain: Array[GeometryInstance3D] = []
var _inside := false
var _established := false
var _tween: Tween


func _ready() -> void:
	_walls = get_node_or_null(walls_path) as Node3D
	if _walls == null:
		push_warning("WallCutaway: walls_path is not set to a valid node.")
		set_process(false)
		return
	_convert(_walls, skip_prefixes, only_prefixes)
	for path in shared_paths:
		var extra := get_node_or_null(path) as Node3D
		if extra != null:
			_convert(extra, skip_prefixes, shared_prefixes)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
		if _player == null:
			return
	# The dip follows the player every frame; the cut height only moves on a crossing.
	for mat in _cut_mats:
		mat.set_shader_parameter("player_pos", _player.global_position)
	var now := _contains(_player.global_position) == cut_when_inside
	if not _established:
		# The player node readies after us, so snap to the right state (no slide) once.
		_established = true
		_inside = now
		_apply_instant(now)
		return
	if now != _inside:
		_inside = now
		_slide_to(now)


# --- Setup -----------------------------------------------------------------


## Swap every wall surface under `root` for a ShaderMaterial on the cutaway shader,
## carrying the imported glTF material across so nothing changes until the cut moves.
## Surfaces matching `skip` are collected for the plain hide instead; when `only` is
## non-empty, pieces that match none of it are left completely alone.
func _convert(root: Node, skip: PackedStringArray, only: PackedStringArray) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if _matches(mi.name, skip):
			_plain.append(mi)
			continue
		if mi.mesh == null or (not only.is_empty() and not _matches(mi.name, only)):
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as StandardMaterial3D
			if src == null or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue  # glass and the like stay exactly as imported
			mi.set_surface_override_material(s, _material_for(src))


func _matches(piece: String, prefixes: PackedStringArray) -> bool:
	for p in prefixes:
		if piece.contains(p):
			return true
	return false


## One cutaway material per imported material, cached per node — so this wall group's
## pieces all move on one tween, while a second WallCutaway elsewhere in the shop (the
## divider, say) keeps its own cut height even though it draws the same plaster.
func _material_for(src: StandardMaterial3D) -> ShaderMaterial:
	if _by_src.has(src):
		return _by_src[src]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo", src.albedo_color)
	if src.albedo_texture != null:
		mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("normal_on", src.normal_enabled and src.normal_texture != null)
	if src.normal_texture != null:
		mat.set_shader_parameter("normal_tex", src.normal_texture)
	mat.set_shader_parameter("normal_strength", src.normal_scale)
	mat.set_shader_parameter("rough_tex_on", src.roughness_texture != null)
	if src.roughness_texture != null:
		mat.set_shader_parameter("rough_tex", src.roughness_texture)
	mat.set_shader_parameter("roughness", src.roughness)
	mat.set_shader_parameter("metallic", src.metallic)
	mat.set_shader_parameter("uv1_scale", src.uv1_scale)
	mat.set_shader_parameter("uv1_offset", src.uv1_offset)
	mat.set_shader_parameter("cut_height", up_height)
	_push(mat)
	_cut_mats.append(mat)
	_by_src[src] = mat
	return mat


## Push the fade dials into the live materials after changing them at runtime.
func retune() -> void:
	for mat in _cut_mats:
		_push(mat)


func _push(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fade_band", fade_band)
	mat.set_shader_parameter("wobble", wobble)
	mat.set_shader_parameter("wobble_scale", wobble_scale)
	mat.set_shader_parameter("haze", haze)
	mat.set_shader_parameter("dip", dip)
	mat.set_shader_parameter("dip_radius", dip_radius)


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


# --- The cut ---------------------------------------------------------------


func _apply_instant(cut: bool) -> void:
	_set_cut(cut_height if cut else up_height)
	_show_plain(not cut)


func _slide_to(cut: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# The roof goes the moment the walls start sinking and only lands once they are back
	# up — either way it is never left hanging over open air.
	if cut:
		_show_plain(false)
	var from: float = _cut_mats[0].get_shader_parameter("cut_height") if _cut_mats else up_height
	var to := cut_height if cut else up_height
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_cut, from, to, fade_time)
	if not cut:
		_tween.tween_callback(_show_plain.bind(true))


func _set_cut(height: float) -> void:
	for mat in _cut_mats:
		mat.set_shader_parameter("cut_height", height)


func _show_plain(on: bool) -> void:
	for gi in _plain:
		gi.visible = on
