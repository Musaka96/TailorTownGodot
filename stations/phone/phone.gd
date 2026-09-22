class_name Phone
extends Node3D

## Ordering station. Opens the phone menu. Ordered bolts are *on the way* for a while
## (GameConfig.delivery_hours of shop time; the Courier Account upgrade makes it minutes)
## and then turn up at the delivery spot beside the phone with a door chime, each in a
## postal box that unpacks itself. An order that would land after closing arrives first
## thing next morning. The tutorial's bolts come at once so the lesson never stalls.
## Pending deliveries save with the station.

const ROLL_SCENE := preload("res://entities/items/material_roll.tscn")

## [{mat: MaterialType, length: float, day: int, hour: float}] — when each one lands.
var _pending: Array = []

@onready var _delivery: Node3D = $DeliverySpot


func get_interaction_prompt(_actor) -> String:
	return "Use phone"


func interact(actor) -> void:
	UI.open_phone(self, actor)


## Order a bolt: it arrives after the delivery time, or at once during the tutorial.
## Returns when it lands as a short phrase for the phone ("at 10:30", "tomorrow morning",
## "now").
func order_roll(mat: MaterialType, length: float) -> String:
	if _instant():
		deliver_roll(mat, length)
		return "now"
	var eta := _eta()
	_pending.append({"mat": mat, "length": length, "day": int(eta.x), "hour": eta.y})
	return _eta_text(eta)


## Bolts still on the way.
func pending_count() -> int:
	return _pending.size()


## Every bolt on the way: [{mat, length, day, hour}] (a copy).
func pending() -> Array:
	return _pending.duplicate()


## When the next bolt lands, as a phrase ("" when nothing is coming).
func next_arrival_text() -> String:
	if _pending.is_empty():
		return ""
	var best: Dictionary = _pending[0]
	for p: Dictionary in _pending:
		if p["day"] < best["day"] or (p["day"] == best["day"] and p["hour"] < best["hour"]):
			best = p
	return _eta_text(Vector2(best["day"], best["hour"]))


## Debug: everything on the way arrives now.
func deliver_all_now() -> void:
	var due := _pending.duplicate()
	_pending.clear()
	for p: Dictionary in due:
		_arrive(p)


## Spawn a full bolt of `mat` with `length` metres at the delivery spot.
func deliver_roll(mat: MaterialType, length: float) -> Node:
	var roll: Node = ROLL_SCENE.instantiate()
	roll.material = mat
	roll.remaining_length_m = length
	get_parent().add_child(roll)
	# Small jitter so stacked deliveries don't perfectly overlap.
	var base := _delivery.global_position
	roll.global_position = base + Vector3(randf_range(-0.25, 0.25), 0.13, randf_range(-0.25, 0.25))
	DeliveryBox.wrap(roll as Node3D)
	EventBus.order_delivered.emit(roll)
	return roll


func _process(_delta: float) -> void:
	if _pending.is_empty() or not DayNight.running:
		return
	var due: Array = []
	for p: Dictionary in _pending:
		if Shift.day > int(p["day"]) or (Shift.day == int(p["day"]) and DayNight.hour >= p["hour"]):
			due.append(p)
	for p: Dictionary in due:
		_pending.erase(p)
		_arrive(p)


func _arrive(p: Dictionary) -> void:
	var mat: MaterialType = p["mat"]
	deliver_roll(mat, p["length"])
	Sfx.play("door_chime")
	if UI != null:
		UI.toast("Delivery!  %s has arrived by the phone" % mat.display_name)


func _instant() -> bool:
	if Tutorial != null and Tutorial.is_active():
		return true
	return Upgrades.delivery_hours() <= 0.0


## (day, hour) the order lands: later today, or first thing tomorrow if that's after
## closing — or if the shop is already shut for the night.
func _eta() -> Vector2:
	var at := DayNight.hour + Upgrades.delivery_hours()
	if not DayNight.running or at >= DayNight.end_hour():
		return Vector2(Shift.day + 1, DayNight.start_hour())
	return Vector2(Shift.day, at)


func _eta_text(eta: Vector2) -> String:
	if int(eta.x) > Shift.day:
		return "tomorrow morning"
	var h := int(eta.y)
	var m := int(fmod(eta.y, 1.0) * 60.0)
	return "at %02d:%02d" % [h, m]


# --- Save ------------------------------------------------------------------


func save_state() -> Dictionary:
	var out: Array = []
	for p: Dictionary in _pending:
		out.append(
			{
				"mat": SaveCodec.mat_to(p["mat"]),
				"length": p["length"],
				"day": p["day"],
				"hour": p["hour"]
			}
		)
	return {"pending": out}


func load_state(data: Dictionary) -> void:
	_pending.clear()
	for d: Dictionary in data.get("pending", []):
		var mat := SaveCodec.mat_from(d.get("mat", {}))
		if mat == null:
			continue
		(
			_pending
			. append(
				{
					"mat": mat,
					"length": float(d.get("length", 0.0)),
					"day": int(d.get("day", 1)),
					"hour": float(d.get("hour", 0.0)),
				}
			)
		)
