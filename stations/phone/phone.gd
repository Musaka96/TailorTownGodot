class_name Phone
extends Node3D

## Ordering station. Opens the phone menu. Ordered bolts are *on the way* for a while
## (GameConfig.delivery_hours of shop time; the Courier Account upgrade makes it minutes)
## and then turn up at the delivery spot beside the phone with a door chime, in a postal
## box that unpacks itself; bolts that land together share one box, side by side. A
## same-day order placed soon after another rides along with it (GameConfig
## .delivery_merge_hours) and lands at the first one's time. An order that would land
## after closing arrives first thing next morning. The tutorial's
## bolts come at once so the lesson never stalls. Pending deliveries save with the station.

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
	var eta := _batch_eta(_eta())
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
	_arrive(due)


## Spawn a full bolt of `mat` with `length` metres at the delivery spot.
func deliver_roll(mat: MaterialType, length: float) -> Node:
	return deliver_rolls([{"mat": mat, "length": length}])[0]


## Spawn several full bolts ([{mat, length}]) side by side at the delivery spot, all in one
## box. Returns the rolls in the same order.
func deliver_rolls(specs: Array) -> Array:
	var rolls: Array = []
	var base := _delivery.global_position
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var roll: MaterialRoll = ROLL_SCENE.instantiate()
		roll.material = spec["mat"]
		roll.remaining_length_m = spec["length"]
		get_parent().add_child(roll)
		# In a row across the bolts (the box's width), with a little jitter so it looks packed
		# by hand.
		var across := Vector3(roll.global_basis.x.x, 0.0, roll.global_basis.x.z).normalized()
		var slot := (i - (specs.size() - 1) * 0.5) * DeliveryBox.SLOT
		var jitter := Vector3(randf_range(-0.04, 0.04), 0.13, randf_range(-0.04, 0.04))
		roll.global_position = base + across * slot + jitter
		rolls.append(roll)
	if not rolls.is_empty():
		DeliveryBox.wrap_all(rolls)
	for roll: Node in rolls:
		EventBus.order_delivered.emit(roll)
	return rolls


func _process(_delta: float) -> void:
	if _pending.is_empty() or not DayNight.running:
		return
	var due: Array = []
	for p: Dictionary in _pending:
		if Shift.day > int(p["day"]) or (Shift.day == int(p["day"]) and DayNight.hour >= p["hour"]):
			due.append(p)
	for p: Dictionary in due:
		_pending.erase(p)
	_arrive(due)


## Everything due at once lands together: one box, one chime, one toast.
func _arrive(due: Array) -> void:
	if due.is_empty():
		return
	var specs: Array = []
	for p: Dictionary in due:
		specs.append({"mat": p["mat"], "length": p["length"]})
	deliver_rolls(specs)
	Sfx.play("door_chime")
	if UI == null:
		return
	if due.size() == 1:
		var mat: MaterialType = due[0]["mat"]
		UI.toast("Delivery!  %s has arrived by the phone" % mat.display_name)
	else:
		UI.toast("Delivery!  %d bolts have arrived by the phone" % due.size())


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


## A same-day order due within GameConfig.delivery_merge_hours after an earlier delivery
## still on its way rides along with the earliest such batch and lands at its time, so
## later orders never push a batch back. Tomorrow's orders already share the opening hour.
func _batch_eta(eta: Vector2) -> Vector2:
	if int(eta.x) != Shift.day:
		return eta
	var c: GameConfig = Config.data if Config != null else null
	var merge := c.delivery_merge_hours if c != null else 1.0
	var best := eta
	for p: Dictionary in _pending:
		var hour := float(p["hour"])
		if int(p["day"]) != Shift.day or hour < DayNight.hour:
			continue
		if eta.y - hour <= merge and hour < best.y:
			best = Vector2(Shift.day, hour)
	return best


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
