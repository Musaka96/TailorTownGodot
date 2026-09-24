extends Control

## Hosts the sewing minigame (no config step — the garment is already cut).
## Applies the result to the sewing machine. Esc / B / Start / right click leave the
## bench mid-seam, and the cut piece stays on the machine unsewn.

var _machine = null
var _actor = null
var _piece = null
var _minigame: MinigameScreen
var _minigame_variant := -1
var _leave_hint: BenchLeaveHint


func _ready() -> void:
	_leave_hint = BenchLeaveHint.new()
	add_child(_leave_hint)


func open(machine, actor, piece) -> void:
	_machine = machine
	_actor = actor
	_piece = piece
	GameState.input_locked = true
	visible = true
	var variant := SewVariants.current()
	if _minigame == null or _minigame_variant != variant:
		if _minigame != null:
			_minigame.queue_free()
		_minigame = SewVariants.create(variant)
		_minigame_variant = variant
		add_child(_minigame)
		_minigame.connect("finished", _on_finished)
		_minigame.left.connect(_on_left)
	_minigame.visible = true
	var title := (
		"%s · %s" % [Enums.garment_type_name(piece.garment_type), Enums.size_name(piece.size)]
	)
	_minigame.call("start_piece", int(piece.garment_type), title, piece.material)
	MousePick.release(self)  # a right click anywhere reaches _unhandled_input as a leave
	move_child(_leave_hint, -1)  # over the game


func close() -> void:
	visible = false
	GameState.input_locked = false
	_machine = null
	_piece = null


## The leave keys walk away from the bench (see _on_left). Swallowed even once the seam
## is decided, so the pause menu never opens over the stamp.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _minigame == null or not _minigame.visible:
		return
	if not MinigameScreen.is_leave_event(event):
		return
	get_viewport().set_input_as_handled()
	_minigame.request_leave()


## Left mid-seam: nothing is judged and the cut piece stays on the machine, unsewn.
func _on_left() -> void:
	_minigame.visible = false
	Sfx.ui_cancel()
	close()


func _on_finished(success: bool, quality: float) -> void:
	if not visible:
		return  # a run that was left can't report back (the F2 cheat on a hidden game)
	if _minigame:
		_minigame.visible = false
	if _machine:
		_machine.finish_sew(success, quality)
	close()
