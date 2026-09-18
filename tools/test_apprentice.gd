extends SceneTree

## Headless test for the apprentice (stations/apprentice_bench): hired, handed a part of
## an order, he walks to the shelf, takes the matching cloth, cuts and sews it, and
## leaves a SEWN piece on his tray that is checked off that order. Edges: he refuses a
## part with no matching cloth, refuses a second job while busy, a job doesn't move while
## the shop is shut, experience grows, and the job survives a save/load round trip.
##   godot --headless --path . --script res://tools/test_apprentice.gd

const PANTS := 1
const SEWN := 3  # Enums.Stage.SEWN

var _main: Node
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main  # the bench finds the shelves through the current scene
	for _i in 8:
		await process_frame
	var upgrades := root.get_node("Upgrades")
	var orders := root.get_node("Orders")
	var config: Resource = root.get_node("Config").data
	var clock := root.get_node("DayNight")
	var shelf: Node = _main.find_child("Shelf", true, false)
	_check(shelf != null, "the shop has a shelf")
	if shelf == null:
		_finish()
		return

	upgrades.debug_set("apprentice", true)
	var bench: Node3D = load("res://stations/apprentice_bench/apprentice_bench.tscn").instantiate()
	shelf.get_parent().add_child(bench)
	bench.global_position = shelf.global_position + Vector3(2.0, 0.0, 0.0)
	await process_frame
	_check(bench.visible, "the bench shows once he's hired")

	# Quick steps so the test doesn't wait out a real shift.
	config.apprentice_step_seconds_start = 0.3
	config.apprentice_step_seconds_master = 0.2
	var design := {PANTS: {"fabric": 0, "pattern": 0, "color": 0}}
	var order = orders.create_order("Mr Test", design, 300, Color.WHITE)
	var mf: GDScript = load("res://data/scripts/material_factory.gd")

	# --- No matching cloth: he says so ---
	_check(bench.assign(order, PANTS) != "", "refuses a part with no matching cloth")

	var roll: Node = load("res://entities/items/material_roll.tscn").instantiate()
	roll.material = mf.make(0, 0, 0, 10.0)
	roll.remaining_length_m = 10.0
	root.add_child(roll)
	shelf.stock(roll)
	var jobs: Array = bench.available_jobs()
	_check(jobs.size() >= 1 and jobs[0]["cloth"], "the job list sees the bolt on the shelf")

	# --- Shut shop: he takes the job but nothing moves ---
	clock.running = false
	_check(bench.assign(order, PANTS) == "", "takes the part once the cloth is there")
	_check(bench.assign(order, PANTS) != "", "refuses a second job while busy")
	for _i in 30:
		await process_frame
	_check(bench.get("_phase") == 1, "no work while the shop is shut")

	# --- Open: fetch, cut, sew ---
	clock.running = true
	var left_before: float = roll.remaining_length_m
	var frames := 0
	while not bench.has_finished_piece() and frames < 1800:
		await process_frame
		frames += 1
	_check(bench.has_finished_piece(), "finishes the piece (%d frames)" % frames)
	_check(roll.remaining_length_m < left_before, "took cloth off the bolt")
	var piece: Node = bench.get("_tray_item")
	if piece != null:
		_check(int(piece.stage) == SEWN, "the piece is sewn")
		_check(int(piece.order_id) == int(order.id), "it's checked off the order")
		_check(piece.quality > 0.5 and piece.quality < 0.95, "green quality: %.2f" % piece.quality)
	_check(order.is_part_done(PANTS), "the order's part is done")
	_check(bench.cut_jobs == 1 and bench.sew_jobs == 1, "one job of each counted")
	_check(bench.skill("cut") > 0.0, "he learned something")

	# --- Save / load keeps his experience and the tray ---
	var saved: Dictionary = bench.save_state()
	bench.cut_jobs = 0
	bench.load_state(saved)
	_check(bench.cut_jobs == 1, "experience survives save/load")
	_check(bench.has_finished_piece(), "the tray survives save/load")
	_finish()


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("test_apprentice: ALL PASS")
	else:
		print("test_apprentice: %d FAILURE(S)" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
