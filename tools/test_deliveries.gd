extends SceneTree

## Headless test for phone deliveries batching: a same-day order placed while an earlier
## one is on its way, and due within GameConfig.delivery_merge_hours after it, lands with
## it at the first one's time (one box); a later one keeps its own time; after closing an
## order rolls to the next morning; pending entries survive save_state/load_state; and
## merge_hours 0 merges nothing.
##   godot --headless --path . --script res://tools/test_deliveries.gd

var _failures: Array[String] = []
var _dn: Node
var _shift: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame

	var phone: Node = main.find_child("Phone", true, false)
	var rolls := _find(main, "MaterialRoll")
	if phone == null or rolls.is_empty():
		_check(false, "phone + a roll present")
		_finish()
		return
	var mat: Resource = rolls[0].material
	_dn = root.get_node("DayNight")
	_shift = root.get_node("Shift")
	var cfg: Resource = root.get_node("Config").data
	var tut: Node = root.get_node("Tutorial")
	tut.set("_active", false)
	var upgrades: Node = root.get_node("Upgrades")
	upgrades.set("_owned", {})
	cfg.delivery_hours = 2.0
	cfg.delivery_merge_hours = 1.0
	cfg.shift_start_hour = 8.0
	cfg.shift_end_hour = 17.0
	phone.load_state({})

	# --- Merging within the window ------------------------------------------
	_at(8.0)
	var a_text: String = phone.order_roll(mat, 10.0)
	_check(a_text == "at 10:00", "A arrives at 10:00 (got %s)" % a_text)
	_at(8.0 + 40.0 / 60.0)
	var b_text: String = phone.order_roll(mat, 11.0)
	_check(b_text == "at 10:00", "B rides with A at 10:00 (got %s)" % b_text)
	_at(9.5)
	var c_text: String = phone.order_roll(mat, 12.0)
	_check(c_text == "at 11:30", "C keeps its own 11:30 (got %s)" % c_text)
	var hours := _hours(phone)
	_check(hours == [10.0, 10.0, 11.5], "pending hours 10, 10, 11.5 (got %s)" % [hours])

	# --- Save round trip ------------------------------------------------------
	var saved: Dictionary = phone.save_state()
	phone.load_state({})
	_check(phone.pending_count() == 0, "load_state({}) clears pending")
	phone.load_state(saved)
	_check(_hours(phone) == hours, "pending hours survive save/load (got %s)" % [_hours(phone)])
	_check(phone.pending_count() == 3, "three entries after load")

	# --- A and B land together at 10:00, C still coming -------------------------
	var rolls_before := _find(main, "MaterialRoll").size()
	var boxes_before := _find(main, "DeliveryBox").size()
	_at(10.01)
	await process_frame
	var new_rolls := _find(main, "MaterialRoll").size() - rolls_before
	var new_boxes := _find(main, "DeliveryBox").size() - boxes_before
	_check(new_rolls == 2, "two rolls arrived at 10:00 (got %d)" % new_rolls)
	_check(new_boxes == 1, "in one box (got %d)" % new_boxes)
	_check(_hours(phone) == [11.5], "C still pending at 11:30 (got %s)" % [_hours(phone)])

	# --- An already-due entry is not joined -------------------------------------
	phone.load_state({})
	_at(9.0)
	phone.order_roll(mat, 5.0)  # due 11:00
	_dn.hour = 11.2  # past it but not yet collected (no frame has run)
	var late: Vector2 = _batch(phone)
	_check(is_equal_approx(late.y, 13.2), "an already-due batch is not joined (got %s)" % late.y)

	# --- After closing: next morning ----------------------------------------
	phone.load_state({})
	_dn.hold_evening()
	var day: int = _shift.day
	var t_text: String = phone.order_roll(mat, 6.0)
	var p: Dictionary = phone.pending()[0]
	_check(t_text == "tomorrow morning", "after closing says tomorrow (got %s)" % t_text)
	_check(int(p["day"]) == day + 1, "after closing lands next day")
	_check(is_equal_approx(float(p["hour"]), 8.0), "after closing lands at opening")

	# --- merge_hours 0 merges nothing -----------------------------------------
	phone.load_state({})
	cfg.delivery_merge_hours = 0.0
	_at(8.0)
	phone.order_roll(mat, 10.0)
	_at(8.5)
	phone.order_roll(mat, 10.0)
	_check(_hours(phone) == [10.0, 10.5], "merge 0: 10, 10.5 (got %s)" % [_hours(phone)])
	cfg.delivery_merge_hours = 1.0

	phone.load_state({})
	_finish()


## Put the running clock at `h` today.
func _at(h: float) -> void:
	var start: float = _dn.start_hour()
	_dn.start_shift((h - start) / (_dn.end_hour() - start))
	_dn.hour = h


## What a fresh same-day order would get right now (the phone's own rule).
func _batch(phone: Node) -> Vector2:
	return phone.call("_batch_eta", phone.call("_eta"))


func _hours(phone: Node) -> Array:
	var out: Array = []
	for p: Dictionary in phone.pending():
		out.append(snappedf(float(p["hour"]), 0.001))
	out.sort()
	return out


func _find(node: Node, type_name: String) -> Array:
	return node.find_children("*", type_name, true, false)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("DELIVERIES: all checks passed")
	else:
		print("DELIVERIES: %d failure(s): %s" % [_failures.size(), _failures])
	quit(1 if not _failures.is_empty() else 0)
