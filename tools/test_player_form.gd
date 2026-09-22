extends SceneTree

## Headless test for PlayerForm (globals/player_form.gd): it counts greetings, mirror
## verdicts, orders, pickups, late and lost orders, cloth and sewing quality per day; its
## readings lean the right way; the report file is written with every section; and its
## state survives a save round trip (a load counts as a new session).
##   godot --headless --path . --script res://tools/test_player_form.gd

const ORDER_SCRIPT := "res://data/scripts/suit_order.gd"
const PREF_SCRIPT := "res://data/scripts/customer_preference.gd"
const MAT_SCRIPT := "res://data/scripts/material_type.gd"

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var form: Node = root.get_node("PlayerForm")
	var bus: Node = root.get_node("EventBus")
	var shift: Node = root.get_node("Shift")
	form.reset()
	shift.reset_to(1)
	bus.day_began.emit(1)
	_greet(bus)
	_mirror(bus)
	_orders(bus, form)
	_report(form)
	_save_round_trip(form)
	_finish()


func _greet(bus: Node) -> void:
	var cust := _fake_customer()
	bus.customer_answered.emit("take", cust)
	bus.customer_answered.emit("refer", cust)
	bus.customer_answered.emit("decline", cust)
	cust.free()


func _mirror(bus: Node) -> void:
	bus.design_judged.emit(false, "Not quite: the jacket colour isn't right for a wedding.")
	bus.design_judged.emit(false, "Not quite: it's over my budget")
	bus.design_judged.emit(true, "")


func _orders(bus: Node, form: Node) -> void:
	var paid := _order(1, "Mr. Ellison", 300)
	bus.order_created.emit(paid)
	bus.order_fulfilled.emit(paid, 270)
	var late := _order(2, "Ms. Ito", 280)
	bus.order_late.emit(late)
	var gone := _order(3, "Dr. Vance", 280)
	gone.set("ignored", true)
	bus.order_expired.emit(gone)
	var mat: Resource = load(MAT_SCRIPT).new()
	mat.display_name = "Charcoal Worsted Wool"
	bus.order_placed.emit(mat, 7.0, 140)
	var holder := GDScript.new()
	holder.source_code = "extends Node\nvar quality := 0.5\n"
	holder.reload()
	var sewn := Node.new()
	sewn.set_script(holder)
	bus.piece_sewn.emit(sewn)
	sewn.free()
	var rec: Dictionary = form.call("_rec", 1)
	_check(int(rec["walk_ins"]) == 3, "three greetings counted (%d)" % rec["walk_ins"])
	_check(int(rec["took"]) == 1 and int(rec["referred"]) == 1, "take and refer counted")
	_check(int(rec["declined"]) == 1, "decline counted")
	_check(int(rec["proposals"]) == 3 and int(rec["yes"]) == 1, "3 designs shown, 1 yes")
	_check(int(rec["collected"]) == 1 and int(rec["paid"]) == 270, "pickup and payout")
	_check(int(rec["late"]) == 1, "late order counted")
	_check(int(rec["lost"]) == 1 and int(rec["walk_outs"]) == 1, "walk-out counted as lost")
	_check(is_equal_approx(float(rec["cloth_m"]), 7.0), "cloth metres counted")
	_check(int(rec["quality_n"]) == 1, "a sewn piece's quality counted")
	# Give the day some open time so the readings have a window to read.
	rec["open_s"] = 120.0
	rec["swamped_s"] = 60.0
	var r: Dictionary = form.readings()
	_check(float(r["time"]) > 0.4, "late + lost + swamped reads as time trouble (%.2f)" % r["time"])
	_check(float(r["craft"]) > 0.0, "quality 0.5 and 90%% pay reads as craft trouble")
	_check(float(r["clients"]) > 0.4, "3 designs per yes reads as struggling with clients")
	_check(form.verdict(-0.6) == "easy" and form.verdict(0.0) == "about right", "verdict words")


func _report(form: Node) -> void:
	var path: String = form.write_report()
	_check(path != "" and FileAccess.file_exists(path), "report file written (%s)" % path)
	var text: String = FileAccess.get_file_as_string(path)
	for part in [
		"TAILORTOWN PLAYTEST REPORT",
		"HOW IT'S GOING",
		"DAY BY DAY",
		"WHAT HAPPENED",
		"CSV",
		"Ms. Ito",
		"walked out",
		"the jacket colour isn't right",
		"Charcoal Worsted Wool",
	]:
		_check(text.contains(part), "report mentions '%s'" % part)
	var csv_rows := 0
	for line in text.split("\n"):
		if line.begins_with("1,"):
			csv_rows += 1
	_check(csv_rows == 1, "one CSV row for day 1 (%d)" % csv_rows)


func _save_round_trip(form: Node) -> void:
	var saved: Dictionary = form.save_state()
	var path: String = form.report_path()
	form.reset()
	var json: Variant = JSON.parse_string(JSON.stringify(saved))  # saves go through JSON
	form.restore(json)
	var rec: Dictionary = form.call("_rec", 1)
	_check(int(rec["walk_ins"]) == 3, "day records survive a save (%d)" % rec["walk_ins"])
	_check(form.report_path() == path, "a loaded run keeps its report file")
	_check(form.report_text().contains("session 2"), "a load counts as a new session")
	DirAccess.remove_absolute(path)  # don't leave test runs in the tester's report folder


func _fake_customer() -> Node:
	var holder := GDScript.new()
	holder.source_code = "extends Node\nvar preference\n"
	holder.reload()
	var cust := Node.new()
	cust.set_script(holder)
	var pref: Resource = load(PREF_SCRIPT).new()
	pref.display_name = "Mr. Rossi"
	cust.set("preference", pref)
	return cust


func _order(id: int, who: String, price: int) -> Resource:
	var o: Resource = load(ORDER_SCRIPT).new()
	o.id = id
	o.customer_name = who
	o.price = price
	o.due_day = 3
	o.design = {2: {"fabric": 0, "pattern": 0, "color": 1}, 0: {"fabric": 5, "color": 10}}
	return o


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYER FORM: all checks passed")
		quit(0)
	else:
		print("PLAYER FORM: %d failed" % _failures.size())
		quit(1)
