extends Control

## Always-on heads-up display: the interaction prompt (bottom) and what the
## player is currently carrying (top-left). Driven entirely by EventBus signals.

@onready var _prompt: Label = $Prompt
@onready var _held: Label = $Held


func _ready() -> void:
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.item_picked_up.connect(func(item): _show_held(item))
	EventBus.item_taken.connect(func(item, _station): _show_held(item))
	EventBus.item_stored.connect(func(_item, _station): _show_held(null))
	_show_held(null)
	_on_prompt_changed("")


func _on_prompt_changed(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func _show_held(item) -> void:
	if item == null:
		_held.text = ""
		return
	_held.text = "Carrying: %s   (%.1f m left)" % [
		item.material.display_name, item.remaining_length_m]
