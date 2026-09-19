extends Control

## Hosts the small one-off bench games that need no config step and no screen of their
## own — pressing at the ironing board, a cup at the coffee machine. The caller hands over
## a fresh game, how to start it, and what to do with the result; the game is thrown away
## when it finishes. Built in code by UI (no scene file).

var _minigame: MinigameScreen  # named as the tutorial's bench-flag lookup expects
var _on_done := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## `start` is called once the game is in the tree; `on_done` gets (success, quality).
func open(game: MinigameScreen, start: Callable, on_done: Callable) -> void:
	_drop_game()
	_minigame = game
	_on_done = on_done
	GameState.input_locked = true
	visible = true
	add_child(game)
	game.connect("finished", _on_finished)
	start.call()


func close() -> void:
	visible = false
	GameState.input_locked = false
	_on_done = Callable()
	_drop_game()


func _drop_game() -> void:
	if _minigame != null:
		_minigame.queue_free()
		_minigame = null


func _on_finished(success: bool, quality: float) -> void:
	var done := _on_done
	close()
	if done.is_valid():
		done.call(success, quality)
