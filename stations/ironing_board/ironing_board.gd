class_name IroningBoard
extends UpgradeStation

## The Pressing Iron upgrade: "press as you sew". Bring a cut or sewn garment piece to the
## board and press it — the pressing minigame (ui/press_minigame.gd). A clean press adds
## GameConfig.press_bonus_best to the piece's quality (never past 100%), each scorch halves
## that, and a press scorched three times costs the piece press_scorch_penalty instead.
## Once per piece, however it went; the piece itself is never lost.

var _piece_on_board: GarmentPiece

@onready var _steam: GPUParticles3D = get_node_or_null("Steam")


func _init() -> void:
	upgrade_id = "shop_iron"


func get_interaction_prompt(actor) -> String:
	var piece := _piece(actor)
	if piece == null:
		return "Ironing board — bring a cut or sewn piece to press"
	if piece.pressed:
		return "Already pressed"
	return "Press the %s" % Enums.garment_type_name(piece.garment_type).to_lower()


func interact(actor) -> void:
	var piece := _piece(actor)
	if piece == null or piece.pressed:
		Sfx.play("error")
		return
	_piece_on_board = piece
	UI.open_pressing(self, piece)


## Called by the pressing game: `quality` is 1.0 for a clean press, 0.5 with one scorch,
## 0.0 with two; `success` is false when the press was scorched right through.
func finish_press(success: bool, quality: float) -> void:
	var piece := _piece_on_board
	_piece_on_board = null
	if piece == null or not is_instance_valid(piece):
		return
	var before := piece.quality
	var change := _best() * quality if success else -_penalty()
	piece.pressed = true
	piece.quality = clampf(piece.quality + change, 0.05, 1.0)
	if _steam != null:
		_steam.restart()
	var word := "Pressed" if success else "Scorched"
	UI.toast(
		"%s — quality %d%% → %d%%" % [word, roundi(before * 100.0), roundi(piece.quality * 100.0)]
	)


func _piece(actor) -> GarmentPiece:
	if actor == null or actor.carry == null:
		return null
	return actor.carry.get_held() as GarmentPiece


func _best() -> float:
	return Config.data.press_bonus_best if Config.data != null else 0.08


func _penalty() -> float:
	return Config.data.press_scorch_penalty if Config.data != null else 0.05
