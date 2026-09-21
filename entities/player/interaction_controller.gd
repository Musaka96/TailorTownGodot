extends Area3D

## Sits on the player as a detection volume. Each physics frame it picks the
## nearest overlapping Interactable, publishes its prompt to the HUD (via
## EventBus), and triggers it on the "interact" action.

const OUTLINE_SHADER := preload("res://assets/shaders/interact_outline.gdshader")
## Line of sight is checked this high off the floor: over counters, tables and benches,
## into the walls. A wall between you and a station means you can't reach it.
const SIGHT_HEIGHT := 1.2
const WORLD_MASK := 1  # walls sit on layer 1 (with floors and furniture; see _is_wall)
const SIGHT_HITS := 6  # furniture the sight line looks past before giving up
const SIGHT_SHORT := 0.4  # the sight line ends this far short of the target (m)

@export var player_path: NodePath

var _player: Node
var _current: Interactable = null
var _last_prompt := ""
var _outline: ShaderMaterial


func _ready() -> void:
	_player = get_node(player_path)
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
	_set_current(_find_nearest())
	_publish_prompt()


func _find_nearest() -> Interactable:
	var best: Interactable = null
	var best_dist := INF
	for area in get_overlapping_areas():
		if area is Interactable and area.is_in_group("interactable"):
			# During the tutorial, ignore stations that aren't the current step's target.
			if Tutorial != null and Tutorial.blocks(area.target):
				continue
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_dist and _in_sight(area):
				best_dist = d
				best = area
	return best


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
	for node in root.find_children("*", "MeshInstance3D", true, false):
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
