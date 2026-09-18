extends Control

## Hosts the sewing minigame (no config step — the garment is already cut).
## Applies the result to the sewing machine.

var _machine = null
var _actor = null
var _piece = null
var _minigame: MinigameScreen
var _minigame_variant := -1


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
	_minigame.visible = true
	var title := (
		"%s · %s" % [Enums.garment_type_name(piece.garment_type), Enums.size_name(piece.size)]
	)
	_minigame.call("start_piece", int(piece.garment_type), title, piece.material)


func close() -> void:
	visible = false
	GameState.input_locked = false
	_machine = null
	_piece = null


func _on_finished(success: bool, quality: float) -> void:
	if _minigame:
		_minigame.visible = false
	if _machine:
		_machine.finish_sew(success, quality)
	close()
