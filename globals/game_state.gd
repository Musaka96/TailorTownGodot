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

var is_paused := false:
	set(value):
		if value == is_paused:
			return
		is_paused = value
		get_tree().paused = value
		pause_toggled.emit(value)


func _ready() -> void:
	# Keep processing input while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func toggle_pause() -> void:
	is_paused = not is_paused
