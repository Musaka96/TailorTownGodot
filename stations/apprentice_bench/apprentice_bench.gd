class_name ApprenticeBench
extends UpgradeStation

## Percy, the apprentice, and his own bench (the "apprentice" upgrade — hidden until he's
## hired). Talk to him to hand over a whole part of an open order: he walks to the shelf
## for a bolt that matches the design, brings the cloth back, cuts it, sews it, and leaves
## the finished piece on his tray, checked off that order. He never uses your stations.
##
## He learns: every cut and every seam he makes counts towards that skill (1 − e^−n/k),
## which makes him both quicker and neater — from about 64% pieces when green to about
## 90% seasoned, never quite your best. Work only moves while the shop is open.
## The job, his experience and the tray all save with the bench.

enum Phase { IDLE, TO_SHELF, FROM_SHELF, CUT, SEW }

const NAME := "Percy"
const WALK_SPEED := 1.8
const TURN_SPEED := 8.0
const PIECE_SCENE := preload("res://entities/items/garment_piece.tscn")
const PHASE_WORD := {
	Phase.TO_SHELF: "Fetching cloth",
	Phase.FROM_SHELF: "Bringing the cloth back",
	Phase.CUT: "Cutting",
	Phase.SEW: "Sewing",
}

var cut_jobs := 0
var sew_jobs := 0

var _phase := Phase.IDLE
var _order_id := 0
var _garment := 0
var _material: MaterialType = null
var _t := 0.0  # seconds into the current cut / sew
var _cut_quality := 1.0
var _tray_item: Node = null

@onready var _person: Node3D = $Apprentice
@onready var _rig: Node = $Apprentice
@onready var _stand: Marker3D = $Stand
@onready var _tray: Marker3D = $Tray
@onready var _label: Label3D = $Status


func _init() -> void:
	upgrade_id = "apprentice"


func _ready() -> void:
	super()
	_dress()
	_person.global_position = _stand.global_position
	_person.rotation.y = _stand.rotation.y


# --- Talking to him --------------------------------------------------------


func get_interaction_prompt(actor) -> String:
	if _tray_item != null:
		if actor.carry.is_empty():
			return "Take the finished %s" % _garment_word(_tray_item.garment_type)
		return "Your hands are full — %s's piece is on the tray" % NAME
	if is_busy():
		return "Talk to %s (%s)" % [NAME, status_text().to_lower()]
	return "Talk to %s" % NAME


func interact(actor) -> void:
	if _tray_item != null:
		if actor.carry.is_empty():
			var item := _tray_item
			_tray_item = null
			actor.carry.take_item(item)
			_say("Here you go — mind, I took all the pins out.")
		else:
			Sfx.play("error")
		return
	UI.open_apprentice_menu(self, actor)


func is_busy() -> bool:
	return _phase != Phase.IDLE


func has_finished_piece() -> bool:
	return _tray_item != null


## Every part of every open order he could be given, with whether the shelf has cloth
## that matches it: [{order: SuitOrder, type: int, cloth: bool}].
func available_jobs() -> Array:
	var out: Array = []
	for order: SuitOrder in Orders.active:
		if order.state != SuitOrder.State.OPEN:
			continue
		for t in order.required_types():
			if order.needs_part(t) and not (is_busy() and order.id == _order_id and t == _garment):
				out.append(
					{"order": order, "type": t, "cloth": not _find_bolt(order, t).is_empty()}
				)
	return out


## Hand him a part. Returns "" when he takes it on, or why he can't.
func assign(order: SuitOrder, garment_type: int) -> String:
	if is_busy():
		return "I'm still on the last one!"
	if _tray_item != null:
		return "Take the finished piece off my tray first."
	if _find_bolt(order, garment_type).is_empty():
		return "There's no matching cloth on the shelf — order some and I'll get on it."
	_order_id = order.id
	_garment = garment_type
	_material = null
	_t = 0.0
	_phase = Phase.TO_SHELF
	_say("Right away — %s's %s!" % [order.customer_name, _garment_word(garment_type)])
	return ""


## How good he is at a kind of job, 0 (green) → 1 (seasoned).
func skill(kind: String) -> float:
	var n := cut_jobs if kind == "cut" else sew_jobs
	return 1.0 - exp(-float(n) / maxf(_cfg("apprentice_learn_jobs", 8.0), 0.1))


## What he's doing now, for the menu and the label over his bench.
func status_text() -> String:
	if _phase == Phase.IDLE:
		return "Waiting for work" if _tray_item == null else "Done — piece on the tray"
	var word: String = PHASE_WORD[_phase]
	if _phase == Phase.CUT or _phase == Phase.SEW:
		word += " · %d%%" % roundi(_t / _step_seconds(_phase) * 100.0)
	return word


func current_job_text() -> String:
	if not is_busy():
		return ""
	var order := Orders.by_id(_order_id)
	var who := order.customer_name if order != null else "a spare"
	return "#%d %s — %s" % [_order_id, who, Enums.garment_type_name(_garment)]


# --- Working ---------------------------------------------------------------


func _process(delta: float) -> void:
	if not is_owned():
		return
	_label.text = "" if _phase == Phase.IDLE and _tray_item == null else status_text()
	if _phase == Phase.IDLE or not _working_hours():
		_rig.set_moving(false)
		return
	match _phase:
		Phase.TO_SHELF:
			if _walk_to(_shelf_spot(), delta):
				_take_cloth()
		Phase.FROM_SHELF:
			if _walk_to(_stand.global_position, delta):
				_person.rotation.y = _stand.rotation.y
				# Back with cloth: get cutting. Back empty-handed: stand by for work.
				_phase = Phase.CUT if _material != null else Phase.IDLE
				_t = 0.0
		Phase.CUT, Phase.SEW:
			_t += delta
			if _t >= _step_seconds(_phase):
				_finish_step()


func _working_hours() -> bool:
	return DayNight.running and Shift.is_open()


func _take_cloth() -> void:
	var order := Orders.by_id(_order_id)
	var bolt := _find_bolt(order, _garment) if order != null else {}
	if bolt.is_empty():
		_say("The cloth's gone from the shelf! Give me another job when there's some.")
		_material = null
		_order_id = 0
		_phase = Phase.FROM_SHELF
		return
	var shelf: Shelf = bolt["shelf"]
	var roll: Node = shelf.stored[bolt["index"]]
	_material = roll.material
	shelf.take_cloth(bolt["index"], Pricing.part_meters(_garment, Enums.Size.M))
	Sfx.play("fabric_unroll")
	_phase = Phase.FROM_SHELF


func _finish_step() -> void:
	if _phase == Phase.CUT:
		_cut_quality = _step_quality("cut")
		cut_jobs += 1
		_phase = Phase.SEW
		_t = 0.0
		Sfx.play("snip")
		return
	var quality := clampf(_cut_quality * _step_quality("sew"), 0.05, 1.0)
	sew_jobs += 1
	_make_piece(quality)


func _make_piece(quality: float) -> void:
	var piece: GarmentPiece = PIECE_SCENE.instantiate()
	piece.material = _material
	piece.garment_type = _garment
	piece.size = Enums.Size.M
	piece.style = "Classic"
	piece.quality = quality
	piece.stage = Enums.Stage.SEWN
	add_child(piece)
	piece.place_on(_tray)
	piece.transform = Transform3D.IDENTITY
	_tray_item = piece
	var order := Orders.register_piece_for(piece, Orders.by_id(_order_id))
	EventBus.piece_sewn.emit(piece)
	_phase = Phase.IDLE
	Sfx.play("sew_stitch_perfect")
	var who := order.customer_name if order != null else "a spare"
	_say(
		(
			"%s's %s is done — %d%%. It's on my tray."
			% [who, _garment_word(_garment), roundi(quality * 100.0)]
		)
	)


## One step's quality: green to seasoned, with a little day-to-day wobble.
func _step_quality(kind: String) -> float:
	var q := lerpf(
		_cfg("apprentice_quality_start", 0.8), _cfg("apprentice_quality_master", 0.95), skill(kind)
	)
	return clampf(q + randf_range(-0.03, 0.03), 0.3, 0.98)


func _step_seconds(phase: Phase) -> float:
	var kind := "cut" if phase == Phase.CUT else "sew"
	return lerpf(
		_cfg("apprentice_step_seconds_start", 40.0),
		_cfg("apprentice_step_seconds_master", 15.0),
		skill(kind)
	)


# --- Finding cloth and getting about ---------------------------------------


## The first bolt on any shelf that matches the order's design for that part exactly
## and has enough left for it: {shelf, index}, or {} if there's none.
func _find_bolt(order: SuitOrder, garment_type: int) -> Dictionary:
	var need := Pricing.part_meters(garment_type, Enums.Size.M)
	for shelf: Shelf in _shelves():
		for i in shelf.stored.size():
			var roll: Node = shelf.stored[i]
			var fits: float = order.part_match(garment_type, {"material": roll.material})
			if fits >= 0.999 and roll.remaining_length_m + 0.001 >= need:
				return {"shelf": shelf, "index": i}
	return {}


func _shelves() -> Array:
	var scene := get_tree().current_scene
	return scene.find_children("*", "Shelf", true, false) if scene != null else []


## Where to stand to reach the nearest shelf: just in front of it, on this bench's side.
func _shelf_spot() -> Vector3:
	var best: Node3D = null
	for shelf: Node3D in _shelves():
		if (
			best == null
			or (
				shelf.global_position.distance_to(global_position)
				< best.global_position.distance_to(global_position)
			)
		):
			best = shelf
	if best == null:
		return _stand.global_position
	var away := global_position - best.global_position
	away.y = 0.0
	return best.global_position + away.normalized() * 0.9


## Walk straight towards `target` (no navmesh, like the customers). True on arrival.
func _walk_to(target: Vector3, delta: float) -> bool:
	var to := Vector3(
		target.x - _person.global_position.x, 0.0, target.z - _person.global_position.z
	)
	var dist := to.length()
	if dist < 0.08:
		_rig.set_moving(false)
		return true
	var dir := to / dist
	_person.global_position += dir * minf(WALK_SPEED * delta, dist)
	_person.rotation.y = lerp_angle(_person.rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)
	_rig.set_moving(true)
	return false


# --- Bits ------------------------------------------------------------------


func _dress() -> void:
	if _rig == null or not _rig.has_method("set_palette"):
		return
	_rig.set_palette(Style.LINEN.lightened(0.35))
	_rig.set_hair(2)
	_rig.set_hair_color(Style.BROWN)
	var rng := RandomNumberGenerator.new()
	rng.seed = NAME.hash()  # the same pair of shoes and street clothes every day
	_rig.set("shoes", ShoeMaterial.random(rng))
	_rig.wear_street(Wardrobe.library().random_street_outfit(Enums.Gender.ANY, rng))


func _say(line: String) -> void:
	Sfx.play("mentor_blip")
	UI.toast('%s: "%s"' % [NAME, line])


func _garment_word(t: int) -> String:
	return Enums.garment_type_name(t).to_lower()


func _cfg(key: String, fallback: float) -> float:
	var c := Config.data
	return float(c.get(key)) if c != null else fallback


# --- Save ------------------------------------------------------------------


func save_state() -> Dictionary:
	return {
		"cut_jobs": cut_jobs,
		"sew_jobs": sew_jobs,
		"phase": int(_phase),
		"order_id": _order_id,
		"garment": _garment,
		"material": SaveCodec.mat_to(_material) if _material != null else {},
		"t": _t,
		"cut_quality": _cut_quality,
		"tray": SaveCodec.item_to(_tray_item) if _tray_item != null else {},
	}


func load_state(data: Dictionary) -> void:
	cut_jobs = int(data.get("cut_jobs", 0))
	sew_jobs = int(data.get("sew_jobs", 0))
	_order_id = int(data.get("order_id", 0))
	_garment = int(data.get("garment", 0))
	_t = float(data.get("t", 0.0))
	_cut_quality = float(data.get("cut_quality", 1.0))
	var mat: Dictionary = data.get("material", {})
	_material = SaveCodec.mat_from(mat) if not mat.is_empty() else null
	_phase = int(data.get("phase", Phase.IDLE)) as Phase
	# Loaded mid-walk: he's back at his bench — fetch again, or get cutting.
	if _phase == Phase.FROM_SHELF:
		_phase = Phase.CUT if _material != null else Phase.IDLE
	_person.global_position = _stand.global_position
	var tray: Dictionary = data.get("tray", {})
	if not tray.is_empty():
		var item := SaveCodec.item_from(tray)
		if item != null:
			add_child(item)
			item.place_on(_tray)
			item.transform = Transform3D.IDENTITY
			_tray_item = item
