extends Area3D

## Sits on the player as a detection volume. Each physics frame it picks the
## nearest overlapping Interactable, publishes its prompt to the HUD (via
## EventBus), and triggers it on the "interact" action.

@export var player_path: NodePath

var _player: Node
var _current: Interactable = null
var _last_prompt := ""


func _ready() -> void:
	_player = get_node(player_path)


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
	_current = interactable


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
