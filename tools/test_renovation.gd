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
var _director: Node3D
var _finished: Array[String] = []
## pricing.gd, loaded at run time: naming the Pricing class here would compile it before the
## autoloads it uses exist, which leaves it broken for the whole run.
var _pricing: Variant
var _sections_begun := 0
var _sections_ended := 0


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
	_director = _main.get_node("ShopRoom/RenovationDirector") as Node3D

	_pricing = load("res://data/scripts/pricing.gd")
	for section: Callable in [
		_fresh,
		_gating,
		_by_hand,
		_by_phone,
		_ordering_and_building,
		_rooms_and_stations,
		_upgrades_wait_for_rooms,
		_save_round_trip,
		_reset_puts_it_back,
		_sheets_ride_along,
		_humbler_customers,
	]:
		_sections_begun += 1
		section.call()
	_check(
		_sections_ended == _sections_begun,
		"every section ran to its last line (%d of %d)" % [_sections_ended, _sections_begun]
	)
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
	var boards := _node("GrandpaShell/Blockers/Blocker_workroom").get_node("Work")
	_check(
		boards.get_interaction_prompt(null) == "Boarded up — a job for the builders",
		"day 1: the doorway boards' own prompt"
	)
	_check(not _usable("Worktable"), "day 1: the worktable sleeps under a dust sheet")
	_check(_node("Worktable/DustSheet").visible, "day 1: its sheet shows")
	_check(not _node("Bookshelf").visible, "day 1: no bookshelf yet")
	_check(not _node("Shelf2").visible, "day 1: the cloth store shelves are not there")
	_check(not _node("CoffeeMachine").visible, "day 1: no coffee machine")
	_check(_usable("Shelf"), "day 1: the one cloth shelf works")
	_check(_usable("Phone"), "day 1: the phone works")
	_sections_ended += 1


func _gating() -> void:
	_check(_reno.available("front_sheets"), "dust sheets can be pulled off at once")
	_check(not _reno.available("front_sweep"), "sweeping waits for the sheets (needs)")
	_check(not _reno.available("workroom_build"), "workroom_build waits for the front room")
	_check(not _reno.needs_met("workroom_build"), "…the front room is tidied first")
	_check(not _reno.available("cloth_build"), "the cloth store waits for the workroom's build")
	_check(not _reno.available("no_such_project"), "an unknown project is never available")
	_check(not _reno.clear_spot("front_window"), "building work can't be done by hand")
	_sections_ended += 1


func _by_hand() -> void:
	_finished.clear()
	_check(_reno.clear_spot("front_sheets"), "first sheet off")
	_check(_reno.spots_cleared("front_sheets") == 1, "one spot counted")
	_check(not _reno.is_done("front_sheets"), "not done after one of three")
	_check(_usable("Worktable"), "the worktable under the first sheet wakes up")
	_check(not _usable("ClothingRack"), "the rack is still covered")
	_reno.clear_spot("front_sheets")
	_reno.clear_spot("front_sheets")
	_check(_reno.is_done("front_sheets"), "done after the third sheet")
	_check(_finished == ["front_sheets"], "project_finished fired exactly once")
	_check(not _reno.clear_spot("front_sheets"), "a finished project can't be worked again")
	_check(_usable("ClothingRack") and _usable("SewingMachine"), "every sheeted station is usable")
	_check(not _node("ClothingRack/DustSheet").visible, "the sheets are gone")
	_check(_usable("Mirror"), "the mirror is never sheeted: customers can be measured at once")
	_check(_reno.available("front_sweep"), "now the floor can be swept")
	_reno.clear_spot("front_sweep")
	var piles := _node("GrandpaShell/Spots/front_sweep").get_children()
	var hidden := 0
	for pile: Node3D in piles:
		hidden += 0 if pile.visible else 1
	_check(piles.size() == 3 and hidden == 1, "one of three dust piles has gone")
	_check(not _reno.available("workroom_build"), "half swept: the workroom build still waits")
	_reno.clear_spot("front_sweep")
	_reno.clear_spot("front_sweep")
	_check(
		_reno.available("workroom_build"),
		"front room swept: now the builders can be sent in (no reputation needed)"
	)
	_check(_reno.available("front_boards"), "…and the shop windows can be unboarded")
	_check(not _reno.can_order("front_window"), "no glazier while the boards are still up")
	for _i in 3:
		_reno.clear_spot("front_boards")
	_check(_reno.is_done("front_boards"), "all three windows unboarded")
	_check(_reno.available("nook_build"), "the nook can also be tackled: the front room gates it")
	_game.money = 100000
	_check(
		_reno.can_order("workroom_build"),
		"0 reputation, front room swept, money in hand: workroom_build can be ordered"
	)
	for id: String in _reno.all_ids():
		var room := str(_reno.data(id).get("room", ""))
		if room in ["workroom", "cloth", "nook", "nextdoor"]:
			_check(
				int(_reno.data(id).get("kind", -1)) == int(_reno.Kind.BUILD),
				"%s: no hand job left in the back rooms" % id
			)
	_game.money = 0
	_sections_ended += 1


func _by_phone() -> void:
	_game.money = 0
	_check(not _reno.can_order("front_window"), "no money: the glazier can't be ordered")
	_check(not _reno.order("front_window"), "…and order() refuses")
	_check(_game.money == 0, "…and nothing was spent")
	_game.money = 1000
	_check(_reno.can_order("front_window"), "with money it can")
	var cost := int(_reno.data("front_window")["cost"])
	_check(_reno.order("front_window"), "ordered")
	_check(_game.money == 1000 - cost, "the cost came off, exactly once")
	_check(not _reno.order("front_window"), "it can't be ordered twice")
	_check(_game.money == 1000 - cost, "…and no second charge")
	_check(
		_reno.is_building("front_window") and not _reno.is_done("front_window"),
		"the builders are at it, not done the same moment"
	)
	_reno.finish_build("front_window")
	_check(
		_reno.is_done("front_window") and not _reno.is_building("front_window"),
		"finish_build completes it"
	)
	_sections_ended += 1


## The bookkeeping either shape of the world uses: nobody listening to build_started (a
## fresh headless test, Mr. Hemming's shop) finishes the job at once; something listening
## (the RenovationDirector at grandpa's) leaves it building until finish_build says so, and
## day_began no longer has any say in it at all.
func _ordering_and_building() -> void:
	var director_cb := Callable(_director, "_on_build_started")
	_reno.build_started.disconnect(director_cb)

	# Nobody listening: order() finishes the job at once and spends exactly the cost.
	_finished.clear()
	_game.money = 1000
	var cost := int(_reno.data("front_lights")["cost"])
	_check(_reno.order("front_lights"), "no listener: front_lights orders")
	_check(_game.money == 1000 - cost, "…spending exactly its cost")
	_check(
		_reno.is_done("front_lights") and not _reno.is_building("front_lights"),
		"…and finishing at once"
	)
	_check(_finished == ["front_lights"], "…project_finished fired exactly once")

	# Unaffordable: order() refuses and spends nothing.
	_game.money = 10
	var before := int(_game.money)
	_check(not _reno.can_order("front_paper"), "front_paper can't be afforded on 10")
	_check(not _reno.order("front_paper"), "…so order() refuses")
	_check(int(_game.money) == before, "…and nothing was spent")

	# Something listening: order() leaves the job building, not done, until finish_build.
	var dummy := func(_id: String) -> void: pass
	_reno.build_started.connect(dummy)
	_finished.clear()
	_game.money = 1000
	_check(_reno.order("facade_paint"), "with a listener: facade_paint orders")
	_check(
		_reno.is_building("facade_paint") and not _reno.is_done("facade_paint"),
		"…and is left building, not done"
	)
	_check(_finished.is_empty(), "…project_finished has not fired yet")

	# day_began no longer touches it.
	root.get_node("EventBus").day_began.emit(99)
	_check(
		_reno.is_building("facade_paint") and not _reno.is_done("facade_paint"),
		"day_began no longer finishes a building job"
	)

	_reno.finish_build("facade_paint")
	_check(
		_reno.is_done("facade_paint") and not _reno.is_building("facade_paint"),
		"finish_build completes it"
	)
	_check(_finished == ["facade_paint"], "…and project_finished fires exactly once")

	# finish_build on anything not currently building does nothing.
	_finished.clear()
	_reno.finish_build("facade_paint")
	_check(_finished.is_empty(), "finish_build on an already-done id does nothing")
	_reno.finish_build("next_build")
	_check(_finished.is_empty(), "finish_build on a job never ordered does nothing")

	_reno.build_started.disconnect(dummy)
	_reno.build_started.connect(director_cb)
	_sections_ended += 1


func _rooms_and_stations() -> void:
	var table := _node("Worktable")
	var home: Vector3 = table.global_position
	_check(_reno.room_state("workroom") == SHUT, "before its build: the workroom stays shut")
	_check(_solid("workroom"), "…the boards stay solid")
	_check(
		_node("GrandpaShell/Spots/workroom_clear").visible, "…and its rubble shows through the door"
	)
	_check(table.global_position.is_equal_approx(home), "the worktable has not moved yet")
	_game.money = 5000
	_check(_reno.order("workroom_build"), "the builders are booked for the workroom")
	_check(_node("GrandpaShell/Wip_workroom").visible, "their clutter stands in the room")
	_check(_reno.room_state("workroom") == SHUT, "ordered but not finished: still shut")
	_check(_solid("workroom"), "…the boards are still up while they work")
	_reno.finish_build("workroom_build")
	_check(_reno.room_state("workroom") == DONE, "finish_build brings the room home")
	_check(not _solid("workroom"), "…the boards come down")
	_check(not _node("GrandpaShell/Wip_workroom").visible, "the builders have packed up")
	_check(
		not _node("GrandpaShell/Spots/workroom_clear").visible, "…and the rubble is gone with them"
	)
	# The floor label is a greybox aid: the real shop has none (the shell builder's SHOW_SHELL).
	var label := _main.get_node_or_null("ShopRoom/GrandpaShell/Label_workroom") as Node3D
	_check(label == null or not label.visible, "no 'locked' label on a finished room")
	_check(
		table.global_position.distance_to(Vector3(-2.6, 0, -1.45)) < 0.01, "the worktable moved in"
	)
	_check(_node("Bookshelf").visible and _usable("Bookshelf"), "the bookshelf arrived")
	_check(_node("ClothingRack2").visible, "and a second rack")
	_check(not _node("Shelf2").visible, "the cloth store is still not there")
	# The cloth store is reached through the workroom; reputation gates nothing here.
	_check(_reno.needs_met("cloth_build"), "the workroom's build unlocks the cloth store's")
	_check(_reno.available("cloth_build"), "…so it can be tackled at once")
	_sections_ended += 1


func _upgrades_wait_for_rooms() -> void:
	_rep.points = int(_rep.TIERS[_rep.TIERS.size() - 1]["at"])
	_game.money = 100000
	_check(not _upg.can_buy("shop_coffee"), "no nook yet: the coffee machine can't be bought")
	_upg.debug_set("shop_coffee", true)
	_upg.changed.emit()
	_check(not _node("CoffeeMachine").visible, "even if owned, it waits for its room")
	_upg.debug_set("shop_coffee", false)
	_reno.order("nook_build")
	_reno.finish_build("nook_build")
	_check(_reno.room_state("nook") == DONE, "the nook is fitted out")
	_check(_upg.can_buy("shop_coffee"), "now the coffee machine can be bought")
	_check(not _node("CoffeeMachine").visible, "not bought yet: still not there")
	_check(_upg.buy("shop_coffee"), "bought")
	_check(_node("CoffeeMachine").visible, "and there it stands")
	_sections_ended += 1


func _save_round_trip() -> void:
	_game.money = 5000
	_reno.clear_spot("yard_rubbish")  # one of three: left half-finished on purpose
	_check(_reno.order("cloth_build"), "setup: cloth_build ordered")
	_check(
		_reno.is_building("cloth_build") and not _reno.is_done("cloth_build"),
		"setup: still mid-build when it is saved"
	)
	var snap: Dictionary = _reno.save_state()
	_check(snap["building"] is Array, "save_state's building list is an Array")
	_check(snap["building"] == ["cloth_build"], "…naming the job the builders are at")
	var workroom_before: int = _reno.room_state("workroom")
	_reno.reset()
	_check(_reno.room_state("workroom") == SHUT, "reset really empties it")
	snap["done"].append("not_a_project")
	_reno.restore(snap)
	_check(
		_reno.room_state("workroom") == workroom_before, "restore brings the finished rooms back"
	)
	# A job still building when it was saved was paid for, so restore simply finishes it.
	_check(_reno.is_done("cloth_build"), "restore finishes a job that was still building")
	_check(_reno.room_state("cloth") == DONE, "…and the cloth store comes with it")
	_check(_reno.spots_cleared("yard_rubbish") == 1, "…and the half-finished cleanup")
	_check(not _reno.is_done("not_a_project"), "unknown ids in a save are ignored")
	_check(_node("Bookshelf").visible, "the shop follows the restored state")

	# An old save's building dict (id -> nights left) is still accepted the same way: any
	# id it names was paid for, so it is simply done.
	_reno.reset()
	_reno.restore({"building": {"front_window": 2}})
	_check(_reno.is_done("front_window"), "an old-format building dict still marks its job done")
	_reno.reset()
	_sections_ended += 1


func _reset_puts_it_back() -> void:
	_reno.debug_finish_all()
	_check(is_equal_approx(_reno.appeal(), 1.0), "everything done: appeal is 1")
	_check(not _solid("nextdoor"), "the party wall is through")
	_check(_node("Mannequin").visible, "the window mannequin stands next door")
	_reno.reset()
	_check(_solid("workroom"), "reset: the boards are back and solid")
	_check(_node("Worktable").global_position.z > 2.34, "reset: the worktable is back in front")
	_check(not _node("Bookshelf").visible, "reset: no bookshelf")
	_sections_ended += 1


## A dust sheet is its station's own. The F3 panel can finish the workroom while the front
## room's sheets are still on; the benches then move rooms, and their sheets must go with
## them (they were once left behind in the front room, covering nothing) and stay pullable.
func _sheets_ride_along() -> void:
	_reno.reset()
	var sheet := _node("Worktable/DustSheet")
	var pull := 0
	for area in sheet.find_children("*", "Area3D", true, false):
		if area.is_in_group("interactable") and (area as Area3D).monitorable:
			pull += 1
	_check(pull == 1, "day 1: the sheet over the worktable can itself be pulled off")
	_check(not _usable("Worktable"), "…while the worktable under it can't be used")
	_reno.restore({"done": ["workroom_build"]})
	var table := _node("Worktable")
	_check(table.global_position.z < 2.34, "workroom done, sheets still on: the table moved in")
	_check(sheet.visible, "…still under its sheet")
	_check(
		sheet.global_position.distance_to(table.global_position) < 1.0,
		"…and the sheet moved with it (not left behind in the front room)"
	)
	_reno.restore({"done": ["front_sheets", "workroom_build"]})
	_check(not sheet.visible and _usable("Worktable"), "sheets off: usable in the workroom")
	_reno.reset()
	_sections_ended += 1


## The one thing a shabby shop costs: customers with less to spend. Reputation picks the
## budget band, but never a better one than the shop is fit to receive.
func _humbler_customers() -> void:
	var cfg: Resource = root.get_node("Config").data
	var lows: Array = cfg.budget_min_by_tier
	var highs: Array = cfg.budget_max_by_tier
	var best := lows.size() - 1
	_rep.points = int(_rep.TIERS[_rep.TIERS.size() - 1]["at"])  # a master's name...
	_reno.reset()  # ...over a shop still under dust sheets
	_check(_pricing.shop_tier_ceiling() == 0, "a fresh shop receives tier-0 customers only")
	var band := _budget_band()
	_check(
		band.x >= int(lows[0]) and band.y <= int(highs[0]),
		"…so even a master's customers bring tier-0 budgets (%d..%d)" % [band.x, band.y]
	)
	_check(band.x >= int(lows[0]), "a shabby shop never pays worse than a new one does")
	for id: String in ["front_sheets", "front_sweep", "front_window", "front_lights"]:
		while not _reno.is_done(id):
			_reno.debug_finish_next()
	_check(_pricing.shop_tier_ceiling() == 1, "a tidy front room welcomes tier-1 customers")
	_reno.debug_finish_all()
	_check(_pricing.shop_tier_ceiling() >= best, "the finished shop receives anyone")
	band = _budget_band()
	_check(
		band.x >= int(lows[best]) and band.y <= int(highs[best]),
		"…and the master's customers bring top budgets (%d..%d)" % [band.x, band.y]
	)
	# Explicit tiers (tools, tests) are never capped, and neither is Mr. Hemming's shop.
	_reno.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_check(_pricing.random_budget(rng, best) >= int(lows[best]), "an explicit tier is not capped")
	root.get_node("Locations").sync_to_scene("res://main.tscn")
	_check(_pricing.shop_tier_ceiling() > best, "no ceiling at Mr. Hemming's")
	band = _budget_band()
	_check(band.x >= int(lows[best]), "…his customers' budgets follow reputation alone")
	root.get_node("Locations").sync_to_scene(SCENE)
	_sections_ended += 1


## Lowest and highest of many budgets drawn the way the game draws them.
func _budget_band() -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var low := 1 << 30
	var high := 0
	for _i in 300:
		var b: int = _pricing.random_budget(rng)
		low = mini(low, b)
		high = maxi(high, b)
	return Vector2i(low, high)


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
		# A dust sheet is the station's child; pulling it off isn't using the station.
		if str(area.get_path()).contains("/DustSheet/"):
			continue
		if area.is_in_group("interactable") and (area as Area3D).monitorable:
			return true
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
