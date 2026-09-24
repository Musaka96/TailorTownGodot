extends Control

## Hosts the small one-off bench games that need no config step and no screen of their
## own — pressing at the ironing board, a cup at the coffee machine. The caller hands over
## a fresh game, how to start it, and what to do with the result; the game is thrown away
## when it finishes. Built in code by UI (no scene file).
##
## Esc / B / Start / right click leave mid-game: `on_done` is never called, and if the
## station behind it (the object `on_done` is a method of) has a leave_bench(), that is
## called to undo whatever it set up for the run — the board lets go of the unpressed
## piece, the coffee machine puts the cup back in the pot.

var _minigame: MinigameScreen  # named as the tutorial's bench-flag lookup expects
var _on_done := Callable()
var _leave_hint: BenchLeaveHint


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_leave_hint = BenchLeaveHint.new()
	add_child(_leave_hint)


## `start` is called once the game is in the tree; `on_done` gets (success, quality).
func open(game: MinigameScreen, start: Callable, on_done: Callable) -> void:
	_drop_game()
	_minigame = game
	_on_done = on_done
	GameState.input_locked = true
	visible = true
	add_child(game)
	game.connect("finished", _on_finished)
	game.left.connect(_on_left)
	start.call()
	MousePick.release(self)  # a right click anywhere reaches _unhandled_input as a leave
	move_child(_leave_hint, -1)  # over the game


func close() -> void:
	visible = false
	GameState.input_locked = false
	_on_done = Callable()
	_drop_game()


func _drop_game() -> void:
	if _minigame != null:
		_minigame.queue_free()
		_minigame = null


## The leave keys walk away from the bench (see _on_left). Swallowed even once the game
## is decided, so the pause menu never opens over the stamp.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _minigame == null:
		return
	if not MinigameScreen.is_leave_event(event):
		return
	get_viewport().set_input_as_handled()
	_minigame.request_leave()


## Left mid-game: nothing is judged, `on_done` never runs, and the station gets to put
## its job back as it was (see the class comment).
func _on_left() -> void:
	var station: Object = _on_done.get_object() if _on_done.is_valid() else null
	Sfx.ui_cancel()
	close()
	if station != null and station.has_method("leave_bench"):
		station.call("leave_bench")


func _on_finished(success: bool, quality: float) -> void:
	var done := _on_done
	close()
	if done.is_valid():
		done.call(success, quality)
