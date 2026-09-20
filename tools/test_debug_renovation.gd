extends SceneTree

## The F3 debug panel's "Renovation" section (globals/debug_menu.gd): the buttons and
## checklist that let a playtester jump around grandpa's renovation progression, driven
## straight off the autoload with no UI clicks needed.
##   godot --headless --path . --script res://tools/test_debug_renovation.gd

const GRANDPA_SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
const HEMMING_SCENE := "res://main.tscn"
# Renovation.RoomState, as plain ints (autoload enums aren't visible to a tool script).
const SHUT := 0

var _fails := 0
var _sections_ended := 0  # every section reports in at its last line
var _reno: Node
var _rep: Node
var _game: Node
var _upg: Node
var _debug: Node
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_reno = root.get_node("Renovation")
	_rep = root.get_node("Reputation")
	_game = root.get_node("GameState")
	_upg = root.get_node("Upgrades")
	_debug = root.get_node("Debug")

	await _hemming_is_safe()
	await _boot_grandpa()

	_finish_next_advances_one()
	_renovate_everything_finishes_all()
	_renovate_and_upgrades_grants_upgrades()
	_reset_returns_to_day_one()
	_open_room_finishes_chain()
	_unticking_cascades()
	_builders_finish_only_underway()

	_check(_sections_ended == 9, "every section ran to its last line (%d of 9)" % _sections_ended)
	print("test_debug_renovation: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


# --- Mr. Hemming's: no RenovationDirector in the scene -----------------------------


## Every Renovation button/checkbox action has to be safe with no RenovationDirector in
## the scene at all — it only ever touches the Renovation/Upgrades autoloads.
func _hemming_is_safe() -> void:
	var main: Node = load(HEMMING_SCENE).instantiate()
	root.add_child(main)
	current_scene = main
	root.get_node("Locations").sync_to_scene(HEMMING_SCENE)
	for _i in 4:
		await process_frame
	_reno.reset()
	var status: String = _debug._reno_status_text()
	_check(status.find("Hemming") != -1, "hemming: status line says nothing to renovate here")
	_debug._finish_next_job()
	_debug._renovate_everything()
	_debug._renovate_everything_and_upgrades()
	_debug._reset_renovation()
	_debug._finish_building_now()
	_debug._open_room("workroom")
	_debug._set_project(true, "workroom_boards")
	_debug._set_project(false, "workroom_boards")
	_debug._toggle_renovation()
	_debug._toggle_renovation()
	_debug._refresh_renovation()
	_check(true, "hemming: every renovation action ran without error")
	_reno.reset()
	_upg.reset()
	main.queue_free()
	await process_frame
	_sections_ended += 1


# --- Grandpa's shop -----------------------------------------------------------------


func _boot_grandpa() -> void:
	_main = load(GRANDPA_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(GRANDPA_SCENE)
	for _i in 4:
		await process_frame
	_sections_ended += 1


func _finish_next_advances_one() -> void:
	_reno.reset()
	var ids: Array = _reno.all_ids()
	var first: String = ids[0]
	_debug._finish_next_job()
	_check(_reno.is_done(first), "finish next: the first project in story order is done")
	var done_count := 0
	for id: String in ids:
		if _reno.is_done(id):
			done_count += 1
	_check(done_count == 1, "finish next: exactly one project is done")
	var job_name: String = str(_reno.data(first).get("name", first))
	_check(
		(_debug._status as Label).text.find(job_name) != -1,
		"finish next: the status label reports its name (%s)" % job_name
	)
	_check_invariant("finish next")
	_sections_ended += 1


func _renovate_everything_finishes_all() -> void:
	_reno.reset()
	_upg.reset()
	_debug._renovate_everything()
	var all_done := true
	for id: String in _reno.all_ids():
		if not _reno.is_done(id):
			all_done = false
	_check(all_done, "renovate everything: every project is done")
	_check(is_equal_approx(_reno.appeal(), 1.0), "renovate everything: appeal is 1.0")
	_check_invariant("renovate everything")
	_check(not _upg.has("shop_coffee"), "renovate everything: no side effects on Upgrades")
	_sections_ended += 1


func _renovate_and_upgrades_grants_upgrades() -> void:
	_reno.reset()
	_upg.reset()
	_debug._renovate_everything_and_upgrades()
	_check(is_equal_approx(_reno.appeal(), 1.0), "…and upgrades: still renovates everything")
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		_check(_upg.has(id), "…and upgrades: %s granted" % id)
	_sections_ended += 1


func _reset_returns_to_day_one() -> void:
	_debug._renovate_everything()
	_debug._reset_renovation()
	_check(_reno.room_state("workroom") == SHUT, "reset: the workroom is shut again")
	_check(_solid("workroom"), "reset: the workroom boards are back and solid")
	_check_invariant("reset")
	_sections_ended += 1


func _open_room_finishes_chain() -> void:
	_reno.reset()
	_debug._open_room("cloth")
	var chain := [
		"workroom_boards",
		"workroom_clear",
		"workroom_build",
		"cloth_boards",
		"cloth_clear",
		"cloth_build"
	]
	for id: String in chain:
		_check(_reno.is_done(id), "open cloth store: %s is done" % id)
	_check(not _reno.is_done("nook_boards"), "open cloth store: the nook is left alone")
	_check(_node("Bookshelf").visible, "open cloth store: the workroom's own stations arrived too")
	_check_invariant("open cloth store")
	_sections_ended += 1


func _unticking_cascades() -> void:
	# Continues from the state _open_room_finishes_chain left behind: the cloth store open.
	_debug._set_project(false, "workroom_build")
	for id: String in ["workroom_build", "cloth_boards", "cloth_clear", "cloth_build"]:
		_check(not _reno.is_done(id), "untick workroom_build: %s is undone" % id)
	_check(
		_reno.is_done("workroom_boards") and _reno.is_done("workroom_clear"),
		"untick workroom_build: its own needs stay done (only dependents are undone)"
	)
	_check(not _node("Bookshelf").visible, "untick workroom_build: the bookshelf is hidden again")
	_check_invariant("untick workroom_build")
	_sections_ended += 1


func _builders_finish_only_underway() -> void:
	_reno.reset()
	_rep.points = int(_rep.TIERS[1]["at"])
	for _i in 3:
		_reno.clear_spot("front_sheets")
	for _i in 3:
		_reno.clear_spot("front_sweep")
	_game.money = 10000
	_check(_reno.order("front_window"), "builders tonight: front_window ordered")
	_check(_reno.order("front_lights"), "builders tonight: front_lights ordered")
	_check(
		_reno.available("workroom_boards") and not _reno.is_done("workroom_boards"),
		"builders tonight: workroom_boards is only available, not under way"
	)
	_debug._finish_building_now()
	_check(
		_reno.is_done("front_window") and _reno.is_done("front_lights"),
		"builders tonight: both ordered jobs are finished"
	)
	_check(
		_reno.nights_left("front_window") == 0 and _reno.nights_left("front_lights") == 0,
		"builders tonight: no nights left on either"
	)
	_check(not _reno.is_done("workroom_boards"), "builders tonight: workroom_boards untouched")
	_check_invariant("builders finish tonight")
	_sections_ended += 1


# --- helpers -------------------------------------------------------------------


## Nothing done should ever leave a `needs` entry undone — checked over every project.
func _check_invariant(where: String) -> void:
	for id: String in _reno.all_ids():
		if not _reno.is_done(id):
			continue
		for need: Variant in _reno.data(id).get("needs", []):
			_check(_reno.is_done(str(need)), "%s: %s done implies %s done" % [where, id, str(need)])


func _node(path: String) -> Node3D:
	var found := _main.get_node_or_null("ShopRoom/" + path) as Node3D
	if found == null:
		_check(false, "node exists: " + path)
		return Node3D.new()
	return found


## The boards of `room` are shown and really block the way.
func _solid(room: String) -> bool:
	var body := _node("GrandpaShell/Blockers/Blocker_" + room)
	return body.visible and body.process_mode != Node.PROCESS_MODE_DISABLED


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
