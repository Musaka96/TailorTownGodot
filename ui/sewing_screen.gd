extends Control

## Hosts the sewing minigame (no config step — the garment is already cut).
## Applies the result to the sewing machine.

var _machine = null
var _actor = null
var _piece = null
var _minigame: SewMinigame


func open(machine, actor, piece) -> void:
	_machine = machine
	_actor = actor
	_piece = piece
	GameState.input_locked = true
	visible = true
	if _minigame == null:
		_minigame = SewMinigame.new()
		add_child(_minigame)
		_minigame.finished.connect(_on_finished)
	_minigame.visible = true
	var title := "%s · %s" % [
		Enums.garment_type_name(piece.garment_type), Enums.size_name(piece.size)]
	var cloth := SewMinigame.CLOTH_DEFAULT
	if piece.material != null:
		cloth = piece.material.cloth_color
	_minigame.start(title, cloth)


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
