extends SceneTree

## Headless test for the "two slips in a row" safeguard on the steered benches. A bot
## holds Cut (or the pedal) and drives the tool hard off the line — into the piece with
## the shears, off the raw edge with the needle — and keeps it there:
##   - it may cost two slips, never the third: the piece survives the dive;
##   - the bench then sets the tool back on the line, pointing down it;
##   - it waits for the button to be let go before going on;
##   - and once back on the line, a later dive is a fresh run of two.
##   godot --headless --fixed-fps 60 --path . --script res://tools/test_cut_safeguard.gd

const CUT2 := "res://ui/cut_allowance_minigame.gd"
const SEW2 := "res://ui/sew_pedal_minigame.gd"
const JACKET := 2  # Enums.GarmentType.JACKET
const RUNNING := 1  # CutBench.State.RUNNING
const FRAME_CAP := 60 * 8
const LINE_EPS := 0.004

var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 4:
		await process_frame
	await _dive(CUT2, "shears", -1.0)
	await _dive(SEW2, "needle", 1.0)
	_finish()


## Start `path`'s game and drive the tool off the line on the `side` where the trouble is
## (-1 inside the line for the shears, +1 past the raw edge for the needle).
func _dive(path: String, what: String, side: float) -> void:
	var host := Control.new()
	root.add_child(host)
	var factory: GDScript = load("res://data/scripts/material_factory.gd")
	var game: Control = load(path).new()
	host.add_child(game)
	if game.has_method("start_piece"):
		game.start_piece(JACKET, "Jacket · M", factory.make(1, 0, 0, 3.0))
	else:
		game.start(JACKET, "Jacket · M", factory.make(1, 0, 0, 3.0))
	await process_frame
	game.set("_armed", true)
	Input.action_press("cut")

	# Dive and stay dived until the bench steps in (or the piece is spoiled).
	var frames := 0
	while float(game.get("_rescue_t")) <= 0.0 and int(game.get("_state")) <= RUNNING:
		_steer_off(game, side)
		frames += 1
		if frames > FRAME_CAP:
			break
		await process_frame
	var slips := int(game.get("_mistakes"))
	_check(slips == 2, "%s: a dive costs two slips, not three (got %d)" % [what, slips])
	_check(int(game.get("_state")) <= RUNNING, "%s: the piece survives the dive" % what)
	_check(float(game.get("_rescue_t")) > 0.0, "%s: the bench steps in" % what)

	# Still holding the button: the tool is set back and then waits.
	for _i in 60:
		await process_frame
	var seg := int(game.get("_seg"))
	var p: Vector2 = game.get("_p")
	var off: float = game.call("_offset", seg, p)
	_check(absf(off) < LINE_EPS, "%s: set back on the line (off by %.4f)" % [what, off])
	var along: float = game.call("_seg_dir", seg).angle()
	var turn := absf(angle_difference(along, float(game.get("_heading"))))
	_check(turn < 0.05, "%s: pointing down the line" % what)
	var held_at: Vector2 = game.get("_p")
	for _i in 30:
		await process_frame
	var still := (game.get("_p") as Vector2).distance_to(held_at) < 0.001
	_check(still, "%s: it waits while the button is still held" % what)
	_check(bool(game.get("_caught")), "%s: and says so" % what)

	# Let go and press again: it carries on, and a new dive is a fresh run of two.
	Input.action_release("cut")
	await process_frame
	await process_frame
	Input.action_press("cut")
	for _i in 20:
		await process_frame
	var moved := (game.get("_p") as Vector2).distance_to(held_at) > 0.005
	_check(moved, "%s: let go and press again, and it carries on" % what)
	_check(int(game.get("_slips_in_row")) == 0, "%s: back on the line, the run is cleared" % what)
	frames = 0
	while int(game.get("_state")) <= RUNNING and frames < FRAME_CAP:
		_steer_off(game, side)
		frames += 1
		await process_frame
	_check(int(game.get("_mistakes")) >= 3, "%s: a second dive can still spoil it" % what)
	Input.action_release("cut")
	host.queue_free()
	await process_frame


## Point the tool as far off the line as the game allows, on `side`.
func _steer_off(game: Control, side: float) -> void:
	if float(game.get("_rescue_t")) > 0.0:
		return
	var seg := int(game.get("_seg"))
	var normal: Vector2 = game.call("_seg_normal", seg)
	var along: Vector2 = game.call("_seg_dir", seg)
	game.set("_heading", (along + normal * side * 2.5).angle())


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_cut_safeguard: ALL PASS")
		quit(0)
	else:
		print("test_cut_safeguard: %d FAILURE(S)" % _failures.size())
		quit(1)
