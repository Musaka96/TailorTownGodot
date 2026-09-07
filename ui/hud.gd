extends Control

## Always-on heads-up display: the interaction prompt (bottom) and what the
## player is currently carrying (top-left). Driven entirely by EventBus signals.

@onready var _prompt: Label = $Prompt
@onready var _held: Label = $Held
@onready var _money: Label = $Money


func _ready() -> void:
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.item_picked_up.connect(func(item): _show_held(item))
	EventBus.item_taken.connect(func(item, _station): _show_held(item))
	EventBus.item_stored.connect(func(_item, _station): _show_held(null))
	EventBus.money_changed.connect(_show_money)
	_show_held(null)
	_show_money(GameState.money)
	_on_prompt_changed("")


func _show_money(balance: int) -> void:
	_money.text = "$ %d" % balance


func _on_prompt_changed(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""


func _show_held(item) -> void:
	if item == null:
		_held.text = ""
		return
	# Rolls report remaining_length_m; cut pieces report length_m.
	var meters = item.get("remaining_length_m")
	var noun := "left"
	if meters == null:
		meters = item.get("length_m")
		noun = "piece"
	var mat_name: String = item.material.display_name if item.material else "cloth"
	_held.text = "Carrying: %s   (%.1f m %s)" % [mat_name, float(meters), noun]
