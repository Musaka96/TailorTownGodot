extends Node

## Global game state — autoloaded as the singleton "GameState".
##
## Keep this LEAN. It's for cross-cutting state that many systems read (pause,
## current level, score, run settings) — not for gameplay logic, which belongs
## on the entities themselves. Access it from anywhere as `GameState.<thing>`.
##
## It also owns the top-level pause/quit input. Being an autoload, it lives above
## the paused scene tree, so it keeps receiving input even while the game is
## paused (see the PROCESS_MODE_ALWAYS in _ready).

signal pause_toggled(is_paused: bool)

## Set by modal UI (e.g. the shelf menu) to freeze player movement/interaction
## without pausing the whole tree.
var input_locked := false

## Shop wallet. Setter clamps at 0 and announces changes for the HUD.
var money: int = 500:
	set(value):
		money = maxi(value, 0)
		EventBus.money_changed.emit(money)

var is_paused := false:
	set(value):
		if value == is_paused:
			return
		is_paused = value
		get_tree().paused = value
		pause_toggled.emit(value)


func can_afford(cost: int) -> bool:
	return money >= cost


## Deduct cost if affordable; returns whether it went through.
func spend(cost: int) -> bool:
	if cost > money:
		return false
	money -= cost
	return true


func earn(amount: int) -> void:
	money += maxi(amount, 0)


func _ready() -> void:
	# Keep processing input while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Config.data:
		money = Config.data.starting_money


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func toggle_pause() -> void:
	is_paused = not is_paused
