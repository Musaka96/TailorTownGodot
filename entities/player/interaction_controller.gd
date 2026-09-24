extends Area3D

## Sits on the player as a detection volume. Each physics frame it picks one overlapping
## Interactable as the target, publishes its prompt to the HUD (via EventBus), and
## triggers it on the "interact" action; with no target, interact sets a carried thing down.
##
## Targeting follows the way the character faces (the model's +Z, flat on the floor):
##   - a new target is taken only inside a cone of ACQUIRE_COS (60 degrees either side),
##     preferring what you face over what is merely a little closer
##     (score = distance * (FACING_BIAS - dot), lowest wins);
##   - the current target is kept while it still overlaps, can still be seen and stays
##     inside the wider KEEP_COS cone (80 degrees), so it doesn't flicker at the edge —
##     turn further away and it lets go, which frees interact to "Set down";
##   - anything within NEAR_ANY (standing on or against it: a renovation spot, a mess
##     pile, the carpet) is in reach whichever way you face.
## A tutorial step can hide stations that aren't its target, and a wall between you and
## a thing always hides it (_in_sight).

const OUTLINE_SHADER := preload("res://assets/shaders/interact_outline.gdshader")
## Line of sight is checked this high off the floor: over counters, tables and benches,
## into the walls. A wall between you and a station means you can't reach it.
const SIGHT_HEIGHT := 1.2
const WORLD_MASK := 1  # walls sit on layer 1 (with floors and furniture; see _is_wall)
const SIGHT_HITS := 6  # furniture the sight line looks past before giving up
const SIGHT_SHORT := 0.4  # the sight line ends this far short of the target (m)
const ACQUIRE_COS := 0.5  # cos(60 deg): a new target must be this far in front
const KEEP_COS := 0.1736482  # cos(80 deg): the current target holds out to here
const NEAR_ANY := 0.55  # m (flat): closer than this, facing doesn't matter
const FACING_BIAS := 1.6  # score = distance * (FACING_BIAS - dot)

@export var player_path: NodePath

var _player: Node
## The node whose rotation is the character's facing (the player's Model; it faces +Z).
var _facing_node: Node3D
var _current: Interactable = null
var _last_prompt := ""
var _outline: ShaderMaterial


func _ready() -> void:
	_player = get_node(player_path)
	_facing_node = _player.get_node_or_null("Model") as Node3D
	if _facing_node == null:
		_facing_node = _player as Node3D
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("outline_color", Style.BRASS)


func _physics_process(_delta: float) -> void:
	# The targeted station can be freed under us (e.g. the day rolls over and the
	# shop rebuilds). Drop the dead reference before anything passes it to a typed
	# parameter, which errors on a freed object before any validity check runs.
	if _current != null and not is_instance_valid(_current):
		_current = null
	if GameState.input_locked:
		_set_current(null)
		return
	_set_current(_find_target())
	_publish_prompt()


## Keep the current target while it still qualifies, else take the best one in front
## (see the class comment).
func _find_target() -> Interactable:
	var fwd := _facing()
	var areas := get_overlapping_areas()
	if _current != null and areas.has(_current) and _usable(_current):
		if _facing_dot(_current, fwd) >= KEEP_COS and _in_sight(_current):
			return _current
	var best: Interactable = null
	var best_score := INF
	for area in areas:
		var it := area as Interactable
		if it == null or not _usable(it):
			continue
		var dot := _facing_dot(it, fwd)
		if dot < ACQUIRE_COS:
			continue
		var score := _flat_to(it).length() * (FACING_BIAS - dot)
		if score < best_score and _in_sight(it):
			best_score = score
			best = it
	return best


## Whether `it` can be a target at all, facing aside.
func _usable(it: Interactable) -> bool:
	if not it.is_in_group("interactable"):
		return false
	# During the tutorial, ignore stations that aren't the current step's target.
	return not (Tutorial != null and Tutorial.blocks(it.target))


## How squarely the player faces `it`: 1 dead ahead, 0 square to the side, -1 behind.
## Anything within NEAR_ANY counts as dead ahead.
func _facing_dot(it: Interactable, fwd: Vector3) -> float:
	var to := _flat_to(it)
	var dist := to.length()
	if dist < NEAR_ANY:
		return 1.0
	return fwd.dot(to / dist)


func _flat_to(it: Interactable) -> Vector3:
	var to := it.global_position - global_position
	to.y = 0.0
	return to


## The way the character faces, flat on the floor. The player's model turns toward the
## way it moves and faces its own +Z (Player.drop_held sets things down along it too).
func _facing() -> Vector3:
	if _facing_node == null:
		return Vector3.BACK
	var fwd := _facing_node.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return Vector3.BACK
	return fwd.normalized()


## True unless something solid (a wall, most often) stands between the player and `area`
## at chest height — so nothing inside the shop can be used from the pavement outside.
func _in_sight(area: Interactable) -> bool:
	var body := _player as Node3D
	if body == null:
		return true
	var from := body.global_position
	from.y += SIGHT_HEIGHT
	var to := area.global_position
	to.y = from.y
	var gap := from.distance_to(to)
	if gap <= SIGHT_SHORT:
		return true
	# Stop just short: a thing set down against a wall has its middle inside the wall's
	# thick collider, and must still be reachable from the room side.
	to = from.move_toward(to, gap - SIGHT_SHORT)
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	var skip: Array[RID] = []
	if body is CollisionObject3D:
		skip.append((body as CollisionObject3D).get_rid())
	var space := get_world_3d().direct_space_state
	# Look past furniture (up to a few pieces) for a wall behind it.
	for _i in SIGHT_HITS:
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		if _is_wall(hit["collider"] as Node):
			return false
		skip.append(hit["rid"])
	return true


## Only the building's shell blocks: the shops' wall bodies ("Walls", "Wall…") and the bar
## across the door. Furniture, stations, rubble and customers never do, so you can always
## reach over a counter or round your own shelf.
func _is_wall(node: Node) -> bool:
	if node == null:
		return false
	var nm := String(node.name)
	return nm.begins_with("Wall") or nm == "DoorBar"


func _set_current(interactable: Interactable) -> void:
	if interactable == _current:
		return
	_highlight(_current, false)
	_current = interactable
	_highlight(_current, true)


## Toggle the brass outline on every mesh under an interactable's target object.
func _highlight(interactable: Object, on: bool) -> void:
	if not is_instance_valid(interactable):
		return
	var root: Node = interactable.target if interactable.target != null else interactable
	if not is_instance_valid(root):
		return
	# A target that is only a handler (a renovation job) names the thing to outline.
	if root.has_method("outline_root"):
		root = root.outline_root()
		if not is_instance_valid(root):
			return
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)  # a dust sheet is its own mesh
	for node in meshes:
		var mesh := node as MeshInstance3D
		mesh.material_overlay = _outline if on else null


## Prompts can depend on carry state (e.g. "Place roll" vs "Browse shelf"), so
## recompute every frame and only emit when the text actually changes. With nothing
## to interact with but something in hand, offer to set it down.
func _publish_prompt() -> void:
	var text := ""
	if _current:
		text = _current.get_prompt(_player)
	elif _is_carrying():
		text = "Set down"
	if text != _last_prompt:
		_last_prompt = text
		EventBus.interaction_prompt_changed.emit(text)


func _is_carrying() -> bool:
	return _player != null and _player.get("carry") != null and not _player.carry.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	if not event.is_action_pressed("interact"):
		return
	# A targeted station wins; otherwise interact sets a carried item down.
	if is_instance_valid(_current):
		_current.do_interact(_player)
		get_viewport().set_input_as_handled()
	elif _is_carrying() and _player.has_method("drop_held"):
		_player.drop_held()
		get_viewport().set_input_as_handled()
