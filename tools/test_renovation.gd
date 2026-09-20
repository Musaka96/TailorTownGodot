extends SceneTree

## Renovation, end to end: the gating and bookkeeping of the autoload, and what the
## RenovationDirector really does to grandpa's shop (boards, mess, stations, upgrades).
##   godot --headless --path . --script res://tools/test_renovation.gd

const SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
# Renovation.RoomState, as plain ints (autoload enums aren't visible to a tool script).
const SHUT := 0
const ENTERED := 1
const CLEARED := 2
const DONE := 3

var _fails := 0
var _reno: Node
var _rep: Node
var _game: Node
var _upg: Node
var _main: Node
var _finished: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_reno = root.get_node("Renovation")
	_rep = root.get_node("Reputation")
	_game = root.get_node("GameState")
	_upg = root.get_node("Upgrades")
	_reno.project_finished.connect(func(id: String) -> void: _finished.append(id))
	_main = load(SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	root.get_node("Locations").sync_to_scene(SCENE)
	for _i in 4:
		await process_frame

	_fresh()
	_gating()
	_by_hand()
	_by_phone()
	_rooms_and_stations()
	_upgrades_wait_for_rooms()
	_save_round_trip()
	_reset_puts_it_back()
	print("test_renovation: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


func _fresh() -> void:
	_reno.reset()
	_rep.points = 0
	_check(_reno.room_state("front") == DONE, "the front room is open from the first morning")
	_check(_reno.room_state("workroom") == SHUT, "fresh: the workroom is shut")
	_check(is_zero_approx(_reno.appeal()), "fresh: appeal is 0")
	_check(_solid("workroom"), "day 1: boards across the workroom door are solid")
	_check(_solid("nextdoor"), "day 1: the party wall is solid")
	_check(not _usable("Worktable"), "day 1: the worktable sleeps under a dust sheet")
	_check(_node("RenovationDirector/DustSheet_Worktable").visible, "day 1: its sheet shows")
	_check(not _node("Bookshelf").visible, "day 1: no bookshelf yet")
	_check(not _node("Shelf2").visible, "day 1: the cloth store shelves are not there")
	_check(not _node("CoffeeMachine").visible, "day 1: no coffee machine")
	_check(_usable("Shelf"), "day 1: the one cloth shelf works")
	_check(_usable("Phone"), "day 1: the phone works")


func _gating() -> void:
	_check(_reno.available("front_sheets"), "dust sheets can be pulled off at once")
	_check(not _reno.available("front_sweep"), "sweeping waits for the sheets (needs)")
	_check(not _reno.available("workroom_boards"), "workroom boards wait for reputation")
	_check(not _reno.tier_met("workroom_boards"), "…because the tier isn't met")
	_rep.points = int(_rep.TIERS[1]["at"])
	_check(_reno.available("workroom_boards"), "at tier 1 the boards can come off")
	_check(not _reno.available("cloth_boards"), "the cloth store waits for the workroom")
	_check(not _reno.available("no_such_project"), "an unknown project is never available")
	_check(not _reno.clear_spot("front_window"), "building work can't be done by hand")


func _by_hand() -> void:
	_finished.clear()
	_check(_reno.clear_spot("front_sheets"), "first sheet off")
	_check(_reno.spots_cleared("front_sheets") == 1, "one spot counted")
	_check(not _reno.is_done("front_sheets"), "not done after one of three")
	_check(_usable("Worktable"), "the worktable under the first sheet wakes up")
	_check(not _usable("Mirror"), "the mirror is still covered")
	_reno.clear_spot("front_sheets")
	_reno.clear_spot("front_sheets")
	_check(_reno.is_done("front_sheets"), "done after the third sheet")
	_check(_finished == ["front_sheets"], "project_finished fired exactly once")
	_check(not _reno.clear_spot("front_sheets"), "a finished project can't be worked again")
	_check(_usable("Mirror") and _usable("SewingMachine"), "every sheeted station is usable")
	_check(not _node("RenovationDirector/DustSheet_Mirror").visible, "the sheets are gone")
	_check(_reno.available("front_sweep"), "now the floor can be swept")
	_reno.clear_spot("front_sweep")
	var piles := _node("GrandpaShell/Spots/front_sweep").get_children()
	var hidden := 0
	for pile: Node3D in piles:
		hidden += 0 if pile.visible else 1
	_check(piles.size() == 3 and hidden == 1, "one of three dust piles has gone")
	_reno.clear_spot("front_sweep")
	_reno.clear_spot("front_sweep")


func _by_phone() -> void:
	_game.money = 0
	_check(not _reno.can_order("front_window"), "no money: the glazier can't be ordered")
	_check(not _reno.order("front_window"), "…and order() refuses")
	_game.money = 1000
	_check(_reno.can_order("front_window"), "with money it can")
	_check(_reno.order("front_window"), "ordered")
	_check(_game.money == 1000 - 150, "the cost came off, exactly once")
	_check(_reno.nights_left("front_window") == 1, "the builders need a night")
	_check(not _reno.order("front_window"), "it can't be ordered twice")
	_check(_game.money == 850, "…and no second charge")
	_check(not _reno.is_done("front_window"), "not done the same day")
	root.get_node("EventBus").day_began.emit(2)
	_check(_reno.is_done("front_window"), "done at dawn")
	_check(_reno.nights_left("front_window") == 0, "no nights left on a finished job")


func _rooms_and_stations() -> void:
	var table := _node("Worktable")
	var home: Vector3 = table.global_position
	_reno.clear_spot("workroom_boards")
	_check(_reno.room_state("workroom") == ENTERED, "boards off: the workroom can be entered")
	_check(not _solid("workroom"), "…the doorway is really open (no body, not shown)")
	for _i in 4:
		_reno.clear_spot("workroom_clear")
	_check(_reno.room_state("workroom") == CLEARED, "rubble out: the workroom is cleared")
	_check(table.global_position.is_equal_approx(home), "the worktable has not moved yet")
	_game.money = 5000
	_check(_reno.order("workroom_build"), "the builders are booked for the workroom")
	_check(_node("GrandpaShell/Wip_workroom").visible, "their clutter stands in the room")
	root.get_node("EventBus").day_began.emit(3)
	_check(_reno.room_state("workroom") == CLEARED, "two nights: not done after one")
	root.get_node("EventBus").day_began.emit(4)
	_check(_reno.room_state("workroom") == DONE, "done after the second night")
	_check(not _node("GrandpaShell/Wip_workroom").visible, "the builders have packed up")
	_check(not _node("GrandpaShell/Label_workroom").visible, "the 'locked' label is gone")
	_check(
		table.global_position.distance_to(Vector3(-1.8, 0, -2.5)) < 0.01, "the worktable moved in"
	)
	_check(_node("Bookshelf").visible and _usable("Bookshelf"), "the bookshelf arrived")
	_check(_node("ClothingRack2").visible, "and a second rack")
	_check(not _node("Shelf2").visible, "the cloth store is still not there")
	# The cloth store is reached through the workroom AND asks for a better name (tier 2).
	_check(_reno.needs_met("cloth_boards"), "the workroom no longer holds the cloth store up")
	_check(not _reno.available("cloth_boards"), "…but at tier 1 its door still can't be tackled")
	_rep.points = int(_rep.TIERS[2]["at"])
	_check(_reno.available("cloth_boards"), "at tier 2 it can")


func _upgrades_wait_for_rooms() -> void:
	_rep.points = int(_rep.TIERS[_rep.TIERS.size() - 1]["at"])
	_game.money = 100000
	_check(not _upg.can_buy("shop_coffee"), "no nook yet: the coffee machine can't be bought")
	_upg.debug_set("shop_coffee", true)
	_upg.changed.emit()
	_check(not _node("CoffeeMachine").visible, "even if owned, it waits for its room")
	_upg.debug_set("shop_coffee", false)
	for id: String in ["nook_boards", "nook_clear", "nook_clear", "nook_clear"]:
		_reno.clear_spot(id)
	_reno.order("nook_build")
	root.get_node("EventBus").day_began.emit(5)
	root.get_node("EventBus").day_began.emit(6)
	_check(_reno.room_state("nook") == DONE, "the nook is fitted out")
	_check(_upg.can_buy("shop_coffee"), "now the coffee machine can be bought")
	_check(not _node("CoffeeMachine").visible, "not bought yet: still not there")
	_check(_upg.buy("shop_coffee"), "bought")
	_check(_node("CoffeeMachine").visible, "and there it stands")


func _save_round_trip() -> void:
	for id: String in ["cloth_boards", "cloth_clear"]:
		_reno.clear_spot(id)
	_reno.order("cloth_build")
	var snap: Dictionary = _reno.save_state()
	var state_before := [
		_reno.room_state("workroom"), _reno.room_state("cloth"), _reno.nights_left("cloth_build")
	]
	_reno.reset()
	_check(_reno.room_state("workroom") == SHUT, "reset really empties it")
	snap["done"].append("not_a_project")
	_reno.restore(snap)
	var state_after := [
		_reno.room_state("workroom"), _reno.room_state("cloth"), _reno.nights_left("cloth_build")
	]
	_check(state_after == state_before, "restore brings back rooms and the builders' nights")
	_check(_reno.spots_cleared("cloth_clear") == 1, "…and the half-finished scrubbing")
	_check(not _reno.is_done("not_a_project"), "unknown ids in a save are ignored")
	_check(_node("Bookshelf").visible, "the shop follows the restored state")


func _reset_puts_it_back() -> void:
	_reno.debug_finish_all()
	_check(is_equal_approx(_reno.appeal(), 1.0), "everything done: appeal is 1")
	_check(not _solid("nextdoor"), "the party wall is through")
	_check(_node("Mannequin").visible, "the window mannequin stands next door")
	_reno.reset()
	_check(_solid("workroom"), "reset: the boards are back and solid")
	_check(_node("Worktable").global_position.z > 1.5, "reset: the worktable is back in front")
	_check(not _node("Bookshelf").visible, "reset: no bookshelf")


# --- helpers -------------------------------------------------------------------


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


## A station the player can walk up to and use: at least one live Interactable.
func _usable(station: String) -> bool:
	for area in _node(station).find_children("*", "Area3D", true, false):
		if area.is_in_group("interactable") and (area as Area3D).monitorable:
			return true
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
