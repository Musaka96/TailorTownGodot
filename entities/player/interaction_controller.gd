extends Area3D

## Sits on the player as a detection volume. Each physics frame it picks the
## nearest overlapping Interactable, publishes its prompt to the HUD (via
## EventBus), and triggers it on the "interact" action.

const OUTLINE_SHADER := preload("res://assets/shaders/interact_outline.gdshader")

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
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best = area
	return best


func _set_current(interactable: Interactable) -> void:
	if interactable == _current:
		return
	_highlight(_current, false)
	_current = interactable
	_highlight(_current, true)


## Toggle the brass outline on every mesh under an interactable's target object.
func _highlight(interactable: Interactable, on: bool) -> void:
	if not is_instance_valid(interactable):
		return
	var root: Node = interactable.target if interactable.target != null else interactable
	if not is_instance_valid(root):
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_overlay = _outline if on else null


## Prompts can depend on carry state (e.g. "Place roll" vs "Browse shelf"), so
## recompute every frame and only emit when the text actually changes.
func _publish_prompt() -> void:
	var text := _current.get_prompt(_player) if _current else ""
	if text != _last_prompt:
		_last_prompt = text
		EventBus.interaction_prompt_changed.emit(text)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	if event.is_action_pressed("interact") and _current:
		_current.do_interact(_player)
		get_viewport().set_input_as_handled()
