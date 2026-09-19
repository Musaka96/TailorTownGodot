class_name CoffeeMachine
extends UpgradeStation

## The Coffee Machine upgrade. A cup gives you focus for the next few bench games
## (GameState.focus jobs): wider "perfect" and "good" bands and a steadier hand on the
## cloth. You make the cup yourself — a one-button pour (ui/coffee_pour_minigame.gd), or
## grind / tamp / pour once the Espresso Machine upgrade is in (ui/espresso_minigame.gd).
## A good cup is worth GameConfig.coffee_jobs, a perfect one a job more, a weak one fewer,
## and a spilt one nothing: the cup is used up either way. The pot makes
## GameConfig.coffee_cups a day (the espresso machine one more) and is refilled every
## morning, so it's a small daily treat, not a permanent buff. Cups left save with the
## station.

const PERFECT_CUP := 0.9  # the game's score for "perfect" and "good" cups
const GOOD_CUP := 0.6

var _cups := 2
## Set while the cup being made is for a customer: called with its quality (0 = spilt)
## instead of the player drinking it.
var _guest_cup := Callable()

@onready var _steam: GPUParticles3D = get_node_or_null("Steam")
@onready var _espresso_kit: Node3D = get_node_or_null("Espresso")


func _init() -> void:
	upgrade_id = "shop_coffee"


func _ready() -> void:
	super()
	_cups = _cups_per_day()
	EventBus.day_began.connect(func(_day: int) -> void: _cups = _cups_per_day())


func get_interaction_prompt(_actor) -> String:
	if GameState.focus > 0:
		return "Still buzzing — focus for %d more job(s)" % GameState.focus
	if _cups <= 0:
		return "The pot's empty — fresh coffee tomorrow"
	if Upgrades.has("shop_espresso"):
		return "Pull an espresso (%d left today)" % _cups
	return "Make a coffee (%d left today)" % _cups


func interact(_actor) -> void:
	if GameState.focus > 0 or _cups <= 0:
		Sfx.play("error")
		return
	_cups -= 1  # the cup is used whether or not it ends up on the floor
	UI.open_coffee(self)


## True when a cup can be made for a customer: the machine is in and the pot isn't empty.
func can_serve_guest() -> bool:
	return is_owned() and _cups > 0


## Make a cup for a customer: the same game, but `on_done(quality)` gets the cup (0 if it
## ends up on the floor) and the player's own focus is left alone.
func serve_guest(on_done: Callable) -> void:
	if not can_serve_guest():
		return
	_cups -= 1
	_guest_cup = on_done
	UI.open_coffee(self)


## Called by the coffee game: `quality` is the cup's score (0..1); `success` is false for
## a spilt cup.
func finish_coffee(success: bool, quality: float) -> void:
	if _guest_cup.is_valid():
		var hand_over := _guest_cup
		_guest_cup = Callable()
		if success:
			Sfx.play("coffee_pour")
		hand_over.call(quality if success else 0.0)
		return
	if not success:
		UI.toast("Spilled — no coffee for you")
		return
	GameState.focus = _jobs_for(quality)
	if _steam != null:
		_steam.restart()
	Sfx.play("coffee_pour")
	UI.toast("Coffee! Steady hands for your next %d jobs" % GameState.focus)


## The espresso kit on the counter shows once that upgrade is owned.
func _refresh() -> void:
	super()
	if _espresso_kit != null:
		_espresso_kit.visible = Upgrades.has("shop_espresso")


func _jobs_for(quality: float) -> int:
	var c := Config.data
	var jobs := (c.coffee_jobs if c != null else 3) + int(Upgrades.bonus("coffee_jobs"))
	if quality >= PERFECT_CUP:
		return jobs + (c.coffee_jobs_perfect if c != null else 1)
	if quality >= GOOD_CUP:
		return jobs
	return maxi(1, ceili(jobs * (c.coffee_weak_share if c != null else 0.6)))


func _cups_per_day() -> int:
	var cups: int = Config.data.coffee_cups if Config.data != null else 2
	return cups + int(Upgrades.bonus("coffee_cups"))


func save_state() -> Dictionary:
	return {"cups": _cups}


func load_state(data: Dictionary) -> void:
	_cups = int(data.get("cups", _cups_per_day()))
