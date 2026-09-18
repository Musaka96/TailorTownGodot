class_name CoffeeMachine
extends UpgradeStation

## The Coffee Machine upgrade. A cup gives you focus for the next few bench games
## (GameState.focus jobs): wider "perfect" and "good" bands and a steadier hand on the
## cloth. The pot makes GameConfig.coffee_cups a day and is refilled every morning, so
## it's a small daily treat, not a permanent buff. Cups left save with the station.

const POUR_SECONDS := 1.4

var _cups := 2

@onready var _steam: GPUParticles3D = get_node_or_null("Steam")


func _init() -> void:
	upgrade_id = "shop_coffee"


func _ready() -> void:
	super()
	_cups = _cups_per_day()
	EventBus.shift_started.connect(func(_h: float) -> void: _cups = _cups_per_day())


func get_interaction_prompt(_actor) -> String:
	if GameState.focus > 0:
		return "Still buzzing — focus for %d more job(s)" % GameState.focus
	if _cups <= 0:
		return "The pot's empty — fresh coffee tomorrow"
	return "Have a coffee (%d left today)" % _cups


func interact(_actor) -> void:
	if GameState.focus > 0 or _cups <= 0:
		Sfx.play("error")
		return
	_cups -= 1
	GameState.focus = _jobs()
	if _steam != null:
		_steam.restart()
	Sfx.play("coffee_pour")
	UI.toast("Coffee! Steady hands for your next %d jobs" % GameState.focus)
	_busy(POUR_SECONDS)


func _cups_per_day() -> int:
	return Config.data.coffee_cups if Config.data != null else 2


func _jobs() -> int:
	return Config.data.coffee_jobs if Config.data != null else 3


func save_state() -> Dictionary:
	return {"cups": _cups}


func load_state(data: Dictionary) -> void:
	_cups = int(data.get("cups", _cups_per_day()))
