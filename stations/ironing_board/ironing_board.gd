class_name IroningBoard
extends UpgradeStation

## The Pressing Iron upgrade: "press as you sew". Bring a cut or sewn garment piece to the
## board and give it a press — a puff of steam, a moment's work, and the piece keeps a
## little more of its quality (GameConfig.press_bonus, once per piece, never past 100%).

const PRESS_SECONDS := 1.2

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
	var before := piece.quality
	piece.pressed = true
	piece.quality = minf(1.0, piece.quality + _bonus())
	if _steam != null:
		_steam.restart()
	Sfx.play("steam_hiss")
	UI.toast(
		"Pressed — quality %d%% → %d%%" % [roundi(before * 100.0), roundi(piece.quality * 100.0)]
	)
	_busy(PRESS_SECONDS)


func _piece(actor) -> GarmentPiece:
	if actor == null or actor.carry == null:
		return null
	return actor.carry.get_held() as GarmentPiece


func _bonus() -> float:
	return Config.data.press_bonus if Config.data != null else 0.05
