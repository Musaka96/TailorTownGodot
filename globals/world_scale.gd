extends Node

## Autoloaded as "WorldScale". The game's proportions dial: it shrinks the characters and
## everything movable by one factor, live, so the real-metre building reads roomier around
## them. DEFAULT (0.85, a 1.90 m character) is what ships; the F3 panel's "World" section
## moves it in debug builds to try other proportions while playing. It scales, by the same
## `factor`:
##  - the player's visual model (Player/Model), never the Player body or its capsule;
##  - every other character rig (customers, the mentor, the apprentice), unless the rig
##    sits inside a prop that is scaled already (the apprentice at his bench);
##  - every movable prop or station, found by a generic rule (see _kind()) that never
##    enters the baked building / town kit / logic subtrees in SKIP_NAMES, each re-grounded
##    so the bottom of its meshes stays on the floor;
##  - the follow camera's home offset (CameraRig.set_offset_scale()).
## Collision stays with its node (a station's own shapes scale with it), but the player's
## capsule, reach, walk speed and the nav are never touched.
##
## Every touched node's base scale and position are remembered here (not on the node, so
## nothing leaks into a scene a tool might pack) and the scaled values are always worked
## out from that base, so moving the slider never compounds and 1.0 puts everything back
## to the authored, real-metre size. If game code moves or re-transforms a node, the next
## pass takes that as its new base. In debug builds the dial persists in
## user://debug_settings.cfg ([debug] world_scale), not in a save; a release build always
## plays at DEFAULT.

signal changed(factor: float)

enum Kind { OPEN, SKIP, PROP, RIG, HOLDER, PLAYER, CAMERA }

const MIN := 0.70
const MAX := 1.00
## What ships: 0.85 puts the character at 1.90 m against the 2.4 m door and 3 m walls.
const DEFAULT := 0.85
## The character's full height at 1.0, for the panel's readout.
const CHARACTER_HEIGHT := 2.24
const CFG_PATH := "user://debug_settings.cfg"
const CFG_SECTION := "debug"
const CFG_KEY := "world_scale"
const SAVE_DELAY := 0.5

## Never scaled and never entered: buildings, terrain, bare floor/street collision,
## waypoint bags and scene-logic nodes that only point into the buildings. Matched by node
## name wherever the walk meets them (dev shop, Mr. Hemming's and grandpa's shop names).
const SKIP_NAMES: Array[String] = [
	"Floor",
	"Walls",
	"Sidewalk",
	"Street",
	"Waypoints",
	"TailorShop",
	"TailorPlot",
	"Town",
	"LawnEdging",
	"NewHouseBase2",
	"GrassPatch",
	"FloraPatch3",
	"GrandpaShop",
	"GrandpaShell",
	"StreetBounds",
	"RenovationDirector",
	"DividerFade",
	"FacadeFader",
	"FrontFade",
	"NookFade",
	"NextFade",
	"RoofManager",
	"DoorBar",
	"OutdoorCollision",
]
## Level wrappers the walk always opens (they are instanced scenes with meshes of their
## own, so the generic rule would take them for one big prop).
const OPEN_NAMES: Array[String] = ["ShopRoom"]

var factor: float = DEFAULT

var _entries := {}  # instance id -> {node, kind, base_scale, base_pos, set_scale, set_pos, drop}
var _cameras: Array[Node] = []
var _pending: Array[Node] = []
var _flush_queued := false
var _reapply_queued := false
var _save_queued := false
var _dial := false  # the slider and its file: debug builds only


func _ready() -> void:
	_dial = OS.is_debug_build()
	if _dial:
		var cfg := ConfigFile.new()
		if cfg.load(CFG_PATH) == OK:
			factor = clampf(float(cfg.get_value(CFG_SECTION, CFG_KEY, DEFAULT)), MIN, MAX)
	get_tree().node_added.connect(_on_node_added)
	Renovation.changed.connect(_queue_reapply)
	Upgrades.changed.connect(_queue_reapply)


## Set the dial (clamped to MIN..MAX) and rescale the current scene right away.
func set_factor(f: float) -> void:
	if not _dial:
		return
	var next := clampf(f, MIN, MAX)
	if next == factor:
		return
	factor = next
	_reapply()
	_queue_save()
	changed.emit(factor)


## The character's height at the current factor, in metres.
func character_height() -> float:
	return CHARACTER_HEIGHT * factor


# --- Passes -------------------------------------------------------------------


func _active() -> bool:
	return factor != 1.0 or not _entries.is_empty() or not _cameras.is_empty()


## Cheap filter: most nodes added during play are UI or happen at 1.0 — ignore them here,
## and batch the rest into one deferred pass (so a whole subtree has its children and has
## run _ready() by the time it is looked at).
func _on_node_added(node: Node) -> void:
	if not (node is Node3D) or not _active():
		return
	_pending.append(node)
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	var batch := _pending
	_pending = []
	var scene := get_tree().current_scene
	if scene == null:
		return
	if batch.has(scene):
		_reapply()  # a new level: one walk covers it
		return
	var cache := {}
	for node: Node in batch:
		if is_instance_valid(node) and node.is_inside_tree() and scene.is_ancestor_of(node):
			_consider(node as Node3D, scene, cache)


func _queue_reapply() -> void:
	if _active() and not _reapply_queued:
		_reapply_queued = true
		_reapply.call_deferred()


## Walk the whole current scene and bring every target to the current factor.
func _reapply() -> void:
	_reapply_queued = false
	for id: int in _entries.keys():
		var e: Dictionary = _entries[id]
		if not is_instance_valid(e["node"]) or not (e["node"] as Node).is_inside_tree():
			_entries.erase(id)
	for i in range(_cameras.size() - 1, -1, -1):
		if not is_instance_valid(_cameras[i]):
			_cameras.remove_at(i)
	var scene := get_tree().current_scene
	if scene is Node3D:
		var cache := {}
		for child in scene.get_children():
			_walk(child, cache)
	if factor == 1.0:
		_entries.clear()  # everything is back at its base: nothing left to track
		_cameras.clear()


func _walk(node: Node, cache: Dictionary) -> void:
	var kind := _kind(node, cache)
	match kind:
		Kind.OPEN:
			for child in node.get_children():
				_walk(child, cache)
		Kind.HOLDER:
			for child in node.get_children():
				if child is CharacterRig:
					_apply(child as Node3D, Kind.RIG)
		Kind.PROP, Kind.RIG:
			_apply(node as Node3D, kind)
		Kind.PLAYER:
			_apply_player(node)
		Kind.CAMERA:
			_apply_camera(node)


## A node added after the level was walked: a target only if every ancestor up to the
## scene root would have let the walk through (so nothing inside a scaled prop, the
## player's hands, a building or a skipped logic node is ever scaled twice).
func _consider(node: Node3D, scene: Node, cache: Dictionary) -> void:
	var chain: Array[Node] = []
	var up := node.get_parent()
	while up != scene:
		chain.push_front(up)
		up = up.get_parent()
	for i in chain.size():
		var kind := _kind(chain[i], cache)
		if kind == Kind.HOLDER and i == chain.size() - 1 and node is CharacterRig:
			_apply(node, Kind.RIG)
			return
		if kind != Kind.OPEN:
			return
	var own := _kind(node, cache)
	match own:
		Kind.PROP, Kind.RIG:
			_apply(node, own)
		Kind.PLAYER:
			_apply_player(node)
		Kind.CAMERA:
			_apply_camera(node)


# --- The rule -------------------------------------------------------------------


## What the walk does with `node`: OPEN (look inside), SKIP (leave it and everything in
## it), PROP (scale it as one piece), RIG (a character), HOLDER (a character's body: only
## its rig is scaled), PLAYER / CAMERA (their own handling).
## A prop is anything with meshes of its own: an instanced scene (station, item, sign)
## with any mesh in it, or a plain / scripted node with meshes built into it. A script's
## runtime spawns (customers under CustomerManager) are other scenes, not its own meshes.
func _kind(node: Node, cache: Dictionary) -> Kind:
	if cache.has(node):
		return cache[node]
	var kind := _classify(node)
	cache[node] = kind
	return kind


func _classify(node: Node) -> Kind:
	var own := _own_handling(node)
	if own != Kind.OPEN:
		return own
	if _is_skipped(node):
		return Kind.SKIP
	if OPEN_NAMES.has(String(node.name)):
		return Kind.OPEN
	if node is GeometryInstance3D or _has_geometry(node, node.scene_file_path != ""):
		return Kind.PROP
	return Kind.HOLDER if _has_rig_child(node) else Kind.OPEN


## The nodes with their own handling: the player (its model), the camera, a character.
func _own_handling(node: Node) -> Kind:
	if node is Player:
		return Kind.PLAYER
	if node is CameraRig:
		return Kind.CAMERA
	if node is CharacterRig:
		return Kind.RIG
	return Kind.OPEN


func _has_rig_child(node: Node) -> bool:
	for child in node.get_children():
		if child is CharacterRig:
			return true
	return false


## Not 3D, a SKIP_NAMES node, or a light, camera, nav region, grid level or anything that
## moves by physics (a scaled body would scale its collision and fight the solver).
func _is_skipped(node: Node) -> bool:
	return (
		not (node is Node3D)
		or SKIP_NAMES.has(String(node.name))
		or node is Light3D
		or node is Camera3D
		or node is NavigationRegion3D
		or node is GridMap
		or node is CharacterBody3D
		or node is RigidBody3D
	)


## Any mesh under `node`, not counting characters, nor other scenes unless `cross` (an
## instanced scene's own model is usually a nested glTF instance).
func _has_geometry(node: Node, cross: bool) -> bool:
	for child in node.get_children():
		if child is CharacterRig:
			continue
		if not cross and child.scene_file_path != "":
			continue
		if child is GeometryInstance3D or _has_geometry(child, cross):
			return true
	return false


# --- Applying -------------------------------------------------------------------


func _apply(node: Node3D, kind: Kind) -> void:
	var id := node.get_instance_id()
	var e: Dictionary = _entries.get(id, {})
	if e.is_empty():
		if factor == 1.0:
			return  # at its base already, and not tracked
		e = {"node": node, "kind": kind}
		_rebase(e)
		_entries[id] = e
	elif not node.scale.is_equal_approx(e["set_scale"]):
		_rebase(e)  # game code re-transformed it (a station moved rooms, an item dropped)
	elif not node.position.is_equal_approx(e["set_pos"]):
		e["base_pos"] = node.position
	node.scale = (e["base_scale"] as Vector3) * factor
	node.position = e["base_pos"]
	if kind == Kind.PROP and factor != 1.0:
		node.global_position += Vector3.UP * (1.0 - factor) * float(e["drop"])
	e["set_scale"] = node.scale
	e["set_pos"] = node.position


## Take the node's current transform as its base. For a prop, also note how far the bottom
## of its meshes sits below its origin, to keep that bottom on the floor when it shrinks.
func _rebase(e: Dictionary) -> void:
	var node: Node3D = e["node"]
	e["base_scale"] = node.scale
	e["base_pos"] = node.position
	e["drop"] = 0.0
	if e["kind"] == Kind.PROP:
		e["drop"] = _mesh_bottom(node) - node.global_position.y


## The lowest world height of any mesh under `node` (its own height if it has none).
func _mesh_bottom(node: Node3D) -> float:
	var bottom := INF
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			var box: AABB = gi.global_transform * gi.get_aabb()
			bottom = minf(bottom, box.position.y)
		stack.append_array(n.get_children())
	return bottom if bottom != INF else node.global_position.y


func _apply_player(player: Node) -> void:
	var model := player.get_node_or_null("Model") as Node3D
	if model != null:
		_apply(model, Kind.RIG)


func _apply_camera(rig: Node) -> void:
	if not rig.has_method("set_offset_scale"):
		return
	rig.call("set_offset_scale", factor)
	if not _cameras.has(rig):
		_cameras.append(rig)


# --- Persistence ------------------------------------------------------------------


## A drag that ends right before quitting still reaches the file.
func _exit_tree() -> void:
	if _dial and _save_queued:
		_save()


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(SAVE_DELAY, true).timeout.connect(_save)


func _save() -> void:
	_save_queued = false
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # keep any other debug keys
	cfg.set_value(CFG_SECTION, CFG_KEY, factor)
	cfg.save(CFG_PATH)
