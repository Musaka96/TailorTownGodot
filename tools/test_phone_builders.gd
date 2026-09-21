extends SceneTree

## Headless test for the phone's Builders screen (ui/phone_order.gd Screen.BUILDERS):
## the hub card appears only at grandpa's, lists BUILD projects only (grouped by room,
## never the CLEANUP ones), shows the right status/preview text in every state, orders
## spend money and start the builders' nights exactly once, and the screen keeps itself
## honest when a job finishes at dawn while it is open.
##   godot --headless --path . --script res://tools/test_phone_builders.gd

const HEMMING_SCENE := "res://main.tscn"
const GRANDPA_SCENE := "res://scenes/world/grandpa/main_grandpa.tscn"
## The BUILD projects of globals/renovation.gd, in ROOMS order — everything else there
## is CLEANUP (done by hand in the shop, never ordered from the phone).
const BUILD_IDS := [
	"front_window",
	"front_lights",
	"front_paper",
	"facade_paint",
	"workroom_build",
	"cloth_build",
	"nook_build",
	"next_buy",
	"next_knock",
	"next_build",
]

var _fails := 0
var _sections_ended := 0  # every section reports in at its last line
var _reno: Node
var _rep: Node
var _game: Node
var _locations: Node
var _event_bus: Node
var _menu: Control
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	for _i in 3:
		await process_frame
	_reno = root.get_node("Renovation")
	_rep = root.get_node("Reputation")
	_game = root.get_node("GameState")
	_locations = root.get_node("Locations")
	_event_bus = root.get_node("EventBus")
	_menu = root.find_child("PhoneOrder", true, false) as Control

	await _at_hemmings()
	await _at_grandpas()

	_check(_sections_ended == 7, "every section ran to its last line (%d of 7)" % _sections_ended)
	print("test_phone_builders: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	quit(1 if _fails > 0 else 0)


# --- b. Hemming's shop: the hub is untouched ----------------------------------


func _at_hemmings() -> void:
	_main = load(HEMMING_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	_locations.sync_to_scene(HEMMING_SCENE)
	for _i in 3:
		await process_frame

	_menu.open(null, null)
	var titles := _titles(_menu._hub_options())
	_check(
		titles == ["Order Textiles", "Shop Upgrades", "Shop Sign"],
		"Hemming's: hub cards unchanged, no Builders card"
	)
	_check(int(_menu.HUB_SIGN) == 2, "Hemming's: HUB_SIGN is still index 2 (the sign card)")
	_menu.close()

	_main.queue_free()
	await process_frame
	current_scene = null
	_sections_ended += 1


# --- a, c, d, e, f. grandpa's shop --------------------------------------------


func _at_grandpas() -> void:
	_main = load(GRANDPA_SCENE).instantiate()
	root.add_child(_main)
	current_scene = _main
	_locations.sync_to_scene(GRANDPA_SCENE)
	for _i in 4:
		await process_frame

	_test_hub_and_listing()
	_test_status_states()
	_test_order_success()
	_test_order_refused()
	_test_finish_autorefresh()

	_menu.close()
	_sections_ended += 1


## (a) The hub gains a Builders card only at grandpa's, and it lists exactly the BUILD
## projects, grouped by room, none of the CLEANUP ones.
func _test_hub_and_listing() -> void:
	_reno.reset()
	_rep.points = 0
	_menu.open(null, null)
	var opts: Array = _menu._hub_options()
	var titles := _titles(opts)
	_check(titles.size() == 4, "grandpa's: the hub has 4 cards")
	_check(titles.size() > 3 and titles[3] == "Builders", "grandpa's: card 3 is 'Builders'")
	_check(
		titles.slice(0, 3) == ["Order Textiles", "Shop Upgrades", "Shop Sign"],
		"grandpa's: the first 3 cards keep their titles and order"
	)

	# Open the Builders card: W/S to it (row 3), then E (mirrors _open_hub_choice's own
	# reading of _hub_sel, set by _refresh_hub from _row).
	_menu._row = 3
	_menu._refresh()
	_menu._confirm()
	_check(
		int(_menu._screen) == int(_menu.Screen.BUILDERS),
		"E on the Builders card opens Screen.BUILDERS"
	)
	_check(
		_menu._build_ids == BUILD_IDS, "Builders lists exactly the BUILD projects, in room order"
	)
	for id: String in _menu._build_ids:
		_check(
			int(_reno.data(id).get("kind", -1)) == int(_reno.Kind.BUILD),
			"%s in the Builders list is a BUILD project" % id
		)
	for id: String in _reno.all_ids():
		if int(_reno.data(id).get("kind", -1)) == int(_reno.Kind.CLEANUP):
			_check(not _menu._build_ids.has(id), "%s (cleanup) is not in the Builders list" % id)
	_sections_ended += 1


## (e) The status text of a builders row for every state, read from the row the screen
## actually builds (_make_builder_row), not reimplemented in the test.
func _test_status_states() -> void:
	_reno.reset()
	_rep.points = 0
	_game.money = 0

	# "After: <job>": front_window's `needs` (front_boards) is unmet, so this isolates the
	# earlier-job lock text (reputation gates nothing here any more).
	_check(
		_row_status_text("front_window") == "After: %s" % str(_reno.data("front_boards")["name"]),
		"status: locked by an earlier job reads 'After: <job name>'"
	)

	# Clear the earlier jobs so workroom_build becomes available; reputation never enters
	# into it.
	for id: String in ["front_sheets", "front_sheets", "front_sheets"]:
		_reno.clear_spot(id)
	for id: String in ["front_sweep", "front_sweep", "front_sweep"]:
		_reno.clear_spot(id)
	for id: String in ["front_boards", "front_boards", "front_boards"]:
		_reno.clear_spot(id)
	_check(_reno.clear_spot("workroom_boards"), "setup: workroom boards cleared at 0 reputation")
	for id: String in ["workroom_clear", "workroom_clear", "workroom_clear", "workroom_clear"]:
		_reno.clear_spot(id)
	_check(_reno.available("workroom_build"), "setup: workroom_build is now available")

	# "$<price>" (orderable, can afford).
	_game.money = 5000
	_check(
		_row_status_text("workroom_build") == "$%d" % int(_reno.data("workroom_build")["cost"]),
		"status: orderable reads its price"
	)

	# Same price, but the 'unaffordable' colour (CLAY) when the player can't cover it.
	_game.money = 0
	var unaffordable := _status_label("workroom_build")
	_check(unaffordable != null, "setup: the unaffordable row built a status label")
	if unaffordable != null:
		_check(
			unaffordable.text == "$%d" % int(_reno.data("workroom_build")["cost"]),
			"status: unaffordable still shows the price"
		)
		_check(
			unaffordable.get_theme_color("font_color") == Style.CLAY,
			"status: unaffordable price uses the CLAY 'can't afford' colour"
		)

	# Order it, then check the under-way and done text.
	_game.money = 5000
	_check(_reno.order("workroom_build"), "setup: workroom_build ordered for the state test")
	_check(
		_row_status_text("workroom_build") == "The builders are at it",
		"status: under way reads 'The builders are at it'"
	)
	_reno.finish_build("workroom_build")
	_check(_reno.is_done("workroom_build"), "setup: workroom_build finished")
	_check(_row_status_text("workroom_build") == "Done", "status: a finished project reads 'Done'")

	_reno.reset()
	_rep.points = 0
	_game.money = 0
	_sections_ended += 1


## (c) Confirming an orderable row spends exactly the cost once, sets nights_left, and
## the row's own status text flips to the under-way text.
func _test_order_success() -> void:
	_reno.reset()
	_rep.points = int(_rep.TIERS[1]["at"])
	for id: String in ["front_sheets", "front_sheets", "front_sheets"]:
		_reno.clear_spot(id)
	for id: String in ["front_sweep", "front_sweep", "front_sweep"]:
		_reno.clear_spot(id)
	for id: String in ["front_boards", "front_boards", "front_boards"]:
		_reno.clear_spot(id)
	_check(_reno.available("front_window"), "setup: front_window is available")

	_game.money = 1000
	_open_builders()
	var idx: int = _menu._build_ids.find("front_window")
	_check(idx >= 0, "setup: front_window is in the Builders list")
	_menu._row = idx
	_menu._refresh()

	var cost := int(_reno.data("front_window")["cost"])
	var before := int(_game.money)
	_menu._confirm()
	_check(int(_game.money) == before - cost, "ordering front_window spends exactly its cost, once")
	_check(_reno.is_building("front_window"), "ordering front_window leaves it building")
	_check(
		_row_status_text("front_window") == "The builders are at it",
		"after ordering, the row reads the under-way text"
	)

	# Confirming it again (already under way) must not spend or re-order.
	var again := int(_game.money)
	_menu._confirm()
	_check(int(_game.money) == again, "confirming an under-way row spends nothing more")

	_reno.reset()
	_rep.points = 0
	_game.money = 0
	_sections_ended += 1


## (d) Confirming a locked or unaffordable row spends nothing and orders nothing.
func _test_order_refused() -> void:
	_reno.reset()
	_rep.points = 0
	_game.money = 100000

	# Locked by an earlier job: front_window's needs (front_boards) aren't met yet.
	_open_builders()
	var idx: int = _menu._build_ids.find("front_window")
	_menu._row = idx
	_menu._refresh()
	var before := int(_game.money)
	_menu._confirm()
	_check(
		int(_game.money) == before, "confirming a locked row (needs an earlier job) spends nothing"
	)
	_check(not _reno.is_done("front_window"), "…and does not order it")
	_check(not _reno.is_building("front_window"), "…and never starts building")

	# Available but unaffordable.
	for id: String in ["front_sheets", "front_sheets", "front_sheets"]:
		_reno.clear_spot(id)
	for id: String in ["front_sweep", "front_sweep", "front_sweep"]:
		_reno.clear_spot(id)
	for id: String in ["front_boards", "front_boards", "front_boards"]:
		_reno.clear_spot(id)
	_check(_reno.available("front_window"), "setup: front_window is now available")
	_game.money = 0
	_open_builders()
	idx = _menu._build_ids.find("front_window")
	_menu._row = idx
	_menu._refresh()
	before = int(_game.money)
	_menu._confirm()
	_check(int(_game.money) == before, "confirming an unaffordable row spends nothing")
	_check(not _reno.is_done("front_window"), "…and does not order it")
	_check(not _reno.is_building("front_window"), "…and never starts building")

	_reno.reset()
	_rep.points = 0
	_game.money = 0
	_sections_ended += 1


## (f) A job finishing (finish_build, however it is called — the builders' show or the F3
## panel) while the Builders screen is open updates the row to Done without the test ever
## calling _refresh() itself; day_began no longer has anything to do with it.
func _test_finish_autorefresh() -> void:
	_reno.reset()
	_rep.points = 0
	for id: String in ["front_sheets", "front_sheets", "front_sheets"]:
		_reno.clear_spot(id)
	for id: String in ["front_sweep", "front_sweep", "front_sweep"]:
		_reno.clear_spot(id)
	for id: String in ["front_boards", "front_boards", "front_boards"]:
		_reno.clear_spot(id)
	_game.money = 1000
	_check(_reno.order("front_window"), "setup: front_window booked ahead of the finish test")

	_open_builders()
	var idx: int = _menu._build_ids.find("front_window")
	_menu._row = idx
	_menu._refresh()
	_check(_row_status_text("front_window") != "Done", "before finishing: the row is not yet Done")
	_check(visible_row_text(idx) != "Done", "before finishing: the on-screen row is not yet Done")

	_event_bus.day_began.emit(2)
	_check(not _reno.is_done("front_window"), "day_began no longer finishes a building job")
	_check(visible_row_text(idx) != "Done", "…so the row still isn't Done")

	_reno.finish_build("front_window")  # Renovation.changed should reach the still-open
	# screen on its own (Renovation.changed -> _on_renovation_changed).
	_check(_reno.is_done("front_window"), "setup: front_window finished")
	_check(
		visible_row_text(idx) == "Done",
		"the open screen's own row shows Done right away, with no _refresh() call from the test"
	)

	_reno.reset()
	_rep.points = 0
	_game.money = 0
	_sections_ended += 1


# --- helpers -------------------------------------------------------------------


## Drive the phone from the hub into the Builders screen (row 3's card).
func _open_builders() -> void:
	_menu.open(null, null)
	_menu._row = 3
	_menu._refresh()
	_menu._confirm()


func _titles(opts: Array) -> Array:
	var out: Array = []
	for o: Dictionary in opts:
		out.append(str(o["title"]))
	return out


## The status text of `id`'s row as _make_builder_row itself would build it — the exact
## function the live screen uses, not a re-implementation.
func _row_status_text(id: String) -> String:
	var label := _status_label(id)
	return label.text if label != null else ""


func _status_label(id: String) -> Label:
	var card: Control = _menu._make_builder_row(id, false)
	if card.get_child_count() == 0:
		return null
	var hbox: Control = card.get_child(0)
	if hbox.get_child_count() < 2:
		return null
	return hbox.get_child(1) as Label


## The status text of `id`'s row as currently laid out on screen (_rows' live children),
## to prove the *open* screen refreshed itself, not just that _make_builder_row would.
func visible_row_text(build_index: int) -> String:
	var id: String = _menu._build_ids[build_index]
	var seen := 0
	for child in _menu._rows.get_children():
		if child.is_queued_for_deletion() or child.get_child_count() == 0:
			continue
		var hbox: Control = child.get_child(0)
		if not (hbox is HBoxContainer) or hbox.get_child_count() < 2:
			continue  # a room header, not a project row
		if seen == build_index:
			var label := hbox.get_child(1) as Label
			return label.text if label != null else ""
		seen += 1
	_check(false, "visible_row_text: row %d not found for %s" % [build_index, id])
	return ""


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
