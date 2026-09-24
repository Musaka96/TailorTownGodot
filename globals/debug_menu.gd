extends Node

## Autoloaded as "Debug". A togglable in-game debug console (F3, debug builds only)
## for driving game actions by hand: the world scale, money and reputation, customers and
## order tickets, the minigames, upgrades, renovation and the shift. Built entirely in code
## on its own CanvasLayer above everything, so no scene edits are needed. This is meant to
## grow: a new action gets a row in a section via _view.section() / _view.row() and a
## control from ui/debug_panel.gd, which owns the look.

const SUIT_SCENE := preload("res://entities/items/suit.tscn")
const COFFEE_SCENE := "res://stations/coffee_machine/coffee_machine.tscn"
const IRON_SCENE := "res://stations/ironing_board/ironing_board.tscn"
const BENCH_SCENE := "res://stations/apprentice_bench/apprentice_bench.tscn"

var _layer: CanvasLayer
var _money_label: Label
var _amount: LineEdit
var _rep_label: Label
var _rep_amount: LineEdit
var _rep_tier: OptionButton
var _cut_type: OptionButton
var _cut_variant: OptionButton
var _sew_type: OptionButton
var _trial: CanvasLayer
var _upg_panel: DebugPanel.SidePanel
var _upg_boxes := {}  # upgrade id -> toggle Button
var _reno_panel: DebugPanel.SidePanel
var _reno_status: Label
var _reno_boxes := {}  # project id -> toggle Button
var _review: Node  # the Sound Review panel (F7)
var _view: DebugPanel
var _scale_slider: HSlider
var _scale_label: Label


func _ready() -> void:
	if not OS.is_debug_build():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_review = load("res://globals/sound_review.gd").new()
	add_child(_review)
	_build()
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh_money())
	Upgrades.changed.connect(_refresh_upgrades)
	Renovation.changed.connect(_refresh_renovation)
	EventBus.reputation_changed.connect(func(_p: int, _t: int) -> void: _refresh_reputation())


func _input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("debug_menu"):
		get_viewport().set_input_as_handled()
		if _trial != null:
			_end_trial()
			_note("cutting trial abandoned")
			return
		_toggle()
	elif (
		_layer.visible
		and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"))
	):
		get_viewport().set_input_as_handled()  # Esc closes the panel, not into the pause menu
		_close()


# --- Actions ---------------------------------------------------------------


func _add_money(amount: int) -> void:
	GameState.money += amount
	_note("money %+d" % amount)


func _set_money() -> void:
	if _amount.text.is_valid_int():
		GameState.money = int(_amount.text)
		_note("money set to $%d" % GameState.money)


func _add_reputation(amount: int) -> void:
	Reputation.points += amount
	_note("reputation %+d" % amount)


func _set_reputation() -> void:
	if _rep_amount.text.is_valid_int():
		Reputation.points = int(_rep_amount.text)
		_note("reputation set to %d (%s)" % [Reputation.points, Reputation.tier_name()])


## Jump straight to a rank's threshold.
func _set_reputation_tier(index: int) -> void:
	Reputation.points = int(Reputation.TIERS[index]["at"])
	_note("reputation now %s" % Reputation.tier_name())


func _call_customer() -> void:
	var cm := _customer_manager()
	if cm != null:
		cm.debug_call_shopper()
		_note("called a customer")
	else:
		_note("no customer manager in scene")


func _clear_customers() -> void:
	var cm := _customer_manager()
	if cm != null:
		cm.debug_clear_customers()
		_note("cleared customers")


func _add_ticket() -> void:
	var order := Orders.debug_add_random()
	_note("added ticket for %s" % order.customer_name)


func _solve_first() -> void:
	Orders.debug_complete_first()
	_note("solved the first ticket")


func _solve_all() -> void:
	Orders.debug_complete_all()
	_note("solved all tickets")


func _expire_first() -> void:
	Orders.debug_expire_first()
	_note("expired the first ticket")


## Finish a ticket (or a fresh one), drop its packaged suit on the floor in front of
## the player, and send the customer in to collect it — the whole pickup flow on demand.
func _ready_for_pickup() -> void:
	var cm := _customer_manager()
	if cm == null:
		_note("no customer manager in scene")
		return
	var order := Orders.debug_pickup_candidate()
	Orders.debug_make_ready(order)
	_drop_suit(_make_suit(order))
	cm.debug_send_collector(order)
	_note("order #%d ready — %s is coming" % [order.id, order.customer_name])


## A packaged suit for this order, dressed in its designed cloth.
func _make_suit(order: SuitOrder) -> Suit:
	var suit: Suit = SUIT_SCENE.instantiate()
	suit.order_id = order.id
	suit.quality = 1.0
	suit.parts = {}
	for t in order.required_types():
		var c: Dictionary = order.design[t]
		var mat := MaterialFactory.make(
			int(c.get("fabric", 0)), int(c.get("pattern", 0)), int(c.get("color", 0)), 1.0
		)
		suit.parts[t] = {"material": mat, "quality": 1.0, "size": Enums.Size.M, "style": "Classic"}
	var jacket: Dictionary = suit.parts.get(Enums.GarmentType.JACKET, {})
	if jacket.get("material") != null:
		suit.primary_color = (jacket["material"] as MaterialType).cloth_color
	return suit


## Put the suit on the ground in front of the player (through the player's own drop, so
## it lands and saves like any dropped item); beside them if their hands are full.
func _drop_suit(suit: Suit) -> void:
	var scene := get_tree().current_scene
	var parent: Node = scene.get_node_or_null("ShopRoom") if scene != null else null
	if parent == null:
		parent = scene if scene != null else get_tree().root
	parent.add_child(suit)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		suit.set_pickable(true)
		return
	if player.carry.is_empty() and player.carry.take_item(suit):
		player.drop_held()
		return
	suit.global_position = (player as Node3D).global_position + Vector3(0.7, 0.15, 0.0)
	suit.set_pickable(true)


## Run one of the cutting games on its own, on a random bolt of cloth, over whatever
## scene is up — no walking to the bench, no order needed. F3 abandons it.
func _try_cut(variant: int) -> void:
	var garment := _pick_garment(_cut_type)
	var cloth := _random_cloth(garment)
	var game := CutVariants.create(variant)
	var title := "%s · M" % Enums.garment_type_name(garment)
	if _open_trial(game, CutVariants.NAMES[variant], cloth):
		game.call("start", garment, title, cloth)


## The same for the sewing games, on a freshly cut piece of random cloth.
func _try_sew(variant: int) -> void:
	var garment := _pick_garment(_sew_type)
	var cloth := _random_cloth(garment)
	var game := SewVariants.create(variant)
	var title := "%s · M" % Enums.garment_type_name(garment)
	if _open_trial(game, SewVariants.NAMES[variant], cloth):
		game.call("start_piece", garment, title, cloth)


## The pressing game, on a piece of random cloth (the sewing section's piece picker).
func _try_press() -> void:
	var garment := _pick_garment(_sew_type)
	var cloth := _random_cloth(garment)
	var game := PressMinigame.new()
	if _open_trial(game, "Pressing", cloth):
		game.start_piece(garment, "%s · M" % Enums.garment_type_name(garment), cloth)


## A cup from the coffee machine: the one-button pour, or the three-beat espresso.
func _try_coffee(espresso: bool) -> void:
	var game: CoffeeBench = EspressoMinigame.new() if espresso else CoffeePourMinigame.new()
	var label := "Espresso" if espresso else "Coffee"
	if _open_trial(game, label, null):
		game.start_cup("An espresso" if espresso else "A cup of coffee")


func _pick_garment(picker: OptionButton) -> int:
	var garment := picker.selected - 1
	return garment if garment >= 0 else randi() % 3


## Put a minigame up over the scene on its own layer, with the panel out of the way.
func _open_trial(game: Control, label: String, cloth: MaterialType) -> bool:
	if _trial != null:
		game.free()
		return false
	_layer.visible = false
	GameState.input_locked = true
	_trial = CanvasLayer.new()
	_trial.layer = 240  # over the HUD and the post-process filter, under this panel
	add_child(_trial)
	_trial.add_child(game)
	var on := cloth.display_name if cloth != null else "the counter"
	game.connect("finished", _on_trial_finished.bind(label, on))
	return true


func _on_trial_finished(success: bool, quality: float, label: String, cloth: String) -> void:
	_end_trial()
	var result := "%d%%" % roundi(quality * 100.0) if success else "ruined"
	_note("%s on %s: %s" % [label, cloth, result])


func _set_sew_variant(index: int) -> void:
	if Config.data != null:
		Config.data.sew_variant = index
		_note("sewing machine now runs %s" % SewVariants.NAMES[index])


## Close the trial and bring the panel back, ready for another go.
func _end_trial() -> void:
	if _trial != null:
		_trial.queue_free()
		_trial = null
	_layer.visible = true
	GameState.input_locked = true


## A bolt this part could really be cut from: its fabrics, patterns and colours.
func _random_cloth(garment: int) -> MaterialType:
	var fabrics := Enums.fabrics_for(garment)
	var patterns := Enums.patterns_for(garment)
	var colors := MaterialFactory.colors_for(garment)
	return (
		MaterialFactory
		. make(
			fabrics[randi() % fabrics.size()],
			patterns[randi() % patterns.size()],
			colors[randi() % colors.size()],
			3.0,
		)
	)


func _set_cut_variant(index: int) -> void:
	if Config.data != null:
		Config.data.cut_variant = index
		_note("worktable now runs %s" % CutVariants.NAMES[index])


## Everything ordered on the phone arrives now.
func _deliver_now() -> void:
	var scene := get_tree().current_scene
	var phones := scene.find_children("*", "Phone", true, false) if scene != null else []
	if phones.is_empty():
		_note("no phone in scene")
		return
	var phone: Phone = phones[0]
	var n := phone.pending_count()
	phone.deliver_all_now()
	_note("delivered %d bolt(s)" % n)


## Drop a piece of upgrade furniture beside the player, to try it before it has a home
## in the shop map (it is not saved there — place it in the editor for keeps).
func _spawn_station(path: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if player == null or scene == null:
		_note("no player in scene")
		return
	var parent: Node = scene.get_node_or_null("ShopRoom")
	if parent == null:
		parent = scene
	var station: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(station)
	station.global_position = player.global_position + Vector3(1.3, 0.0, 0.0)
	_note("spawned %s (own its upgrade to see it)" % station.name)


## Give every apprentice in the scene five jobs' worth of experience at both skills.
func _train_apprentice() -> void:
	var scene := get_tree().current_scene
	var benches := scene.find_children("*", "ApprenticeBench", true, false) if scene != null else []
	for bench: ApprenticeBench in benches:
		bench.cut_jobs += 5
		bench.sew_jobs += 5
	_note("apprentice trained (%d bench(es))" % benches.size())


func _toggle_upgrades() -> void:
	_view.set_side(_upg_panel, not _upg_panel.visible)
	_refresh_upgrades()


func _set_upgrade(on: bool, id: String) -> void:
	Upgrades.debug_set(id, on)
	_note("%s %s" % ["granted" if on else "removed", Upgrades.data(id).get("name", id)])


func _set_all_upgrades(on: bool) -> void:
	for id in Upgrades.all_ids():
		Upgrades.debug_set(id, on)
	_note("all upgrades %s" % ("granted" if on else "removed"))


func _refresh_upgrades() -> void:
	for id: String in _upg_boxes:
		(_upg_boxes[id] as Button).set_pressed_no_signal(Upgrades.has(id))


func _end_shift() -> void:
	if DayNight.running:
		DayNight.running = false
		EventBus.shift_ended.emit()
		_note("shift ended")


func _new_day() -> void:
	if Shift.is_after_hours():
		Shift.close_shop()
		_note("starting next day")
	elif not Shift.is_open():
		Shift.open_shop()
		_note("shop opened")


# --- Renovation --------------------------------------------------------------


## Finish the next unfinished project (story order), for free, and report its name.
func _finish_next_job() -> void:
	var id := Renovation.debug_finish_next()
	if id == "":
		_note("Everything is done")
	else:
		_note("finished: %s" % str(Renovation.data(id).get("name", id)))


func _renovate_everything() -> void:
	Renovation.debug_finish_all()
	_note("renovated everything")


## Renovate everything AND grant the three room-gated upgrades, so their furniture can be
## looked at right away without shopping the phone room by room.
func _renovate_everything_and_upgrades() -> void:
	Renovation.debug_finish_all()
	for id: String in ["shop_coffee", "shop_iron", "apprentice"]:
		Upgrades.debug_set(id, true)
	Upgrades.changed.emit()
	_note("renovated everything and granted the room upgrades")


func _reset_renovation() -> void:
	Renovation.reset()
	_note("renovations reset")


func _skip_goal() -> void:
	var id := Guide.debug_skip()
	_note("guide: %s" % (id if id != "" else "finished"))


func _restart_guide() -> void:
	Guide.debug_restart()
	_note("guide: %s" % Guide.current_id())


## Finish every building job the builders are at right now (a show cut short), nothing else.
func _finish_building_now() -> void:
	var state: Dictionary = Renovation.save_state()
	var building: Array = state.get("building", [])
	for id: String in building:
		Renovation.finish_build(id)
	if building.is_empty():
		_note("the builders aren't at anything")
	else:
		_note("builders finished %d job(s)" % building.size())


## Play the builders' show for `id` again: everything it needs is done, it and everything
## after it undone, its price put in the till, the panel shut, and the job ordered.
func _watch_build(id: String) -> void:
	if Renovation.build_started.get_connections().is_empty():
		_note("the builders only work at grandpa's shop")
		return
	var undo := _dependents(id)
	undo.append(id)
	_undo_ids(undo)
	var needs: Array[String] = []
	for need: Variant in Renovation.data(id).get("needs", []):
		needs.append(str(need))
	_finish_ids(_with_needs(needs))
	GameState.money += int(Renovation.data(id).get("cost", 0))
	if _layer.visible:
		_close()
	if not Renovation.order(id):
		_note("couldn't order %s" % id)


## Finish every project of `room`, and every project those depend on (through `needs`),
## so the room opens without ever leaving a done job whose needs are unmet.
func _open_room(room: String) -> void:
	var ids: Array[String] = []
	for id: String in Renovation.PROJECTS:
		if str(Renovation.data(id).get("room", "")) == room:
			ids.append(id)
	_finish_ids(_with_needs(ids))
	var room_name := str((Renovation.ROOMS.get(room, {}) as Dictionary).get("name", room))
	_note("opened %s" % room_name)


## One checklist tick: done also ticks its needs; undone also unticks every dependent.
func _set_project(on: bool, id: String) -> void:
	if on:
		_finish_ids(_with_needs([id]))
	else:
		var ids := _dependents(id)
		ids.append(id)
		_undo_ids(ids)
	var name := str(Renovation.data(id).get("name", id))
	_note("%s: %s" % [name, "done" if on else "undone"])


func _toggle_renovation() -> void:
	_view.set_side(_reno_panel, not _reno_panel.visible)
	_refresh_renovation()


func _refresh_renovation() -> void:
	if _reno_status != null:
		_reno_status.text = _reno_status_text()
	for id: String in _reno_boxes:
		(_reno_boxes[id] as Button).set_pressed_no_signal(Renovation.is_done(id))


## Mark every id in `ids` done for free, and drop them from "building"/"spots" — built
## from save_state()/restore() so nothing else in the save is disturbed.
func _finish_ids(ids: Array[String]) -> void:
	var state: Dictionary = Renovation.save_state()
	var done: Array = state.get("done", [])
	var building: Array = state.get("building", [])
	var spots: Dictionary = state.get("spots", {})
	for id: String in ids:
		if not done.has(id):
			done.append(id)
		building.erase(id)
		spots.erase(id)
	state["done"] = done
	state["building"] = building
	state["spots"] = spots
	Renovation.restore(state)


## Un-finish every id in `ids` (leaves "building"/"spots" alone — none apply to a done id).
func _undo_ids(ids: Array[String]) -> void:
	var state: Dictionary = Renovation.save_state()
	var done: Array = state.get("done", [])
	for id: String in ids:
		done.erase(id)
	state["done"] = done
	Renovation.restore(state)


## `ids` plus everything they (transitively) need.
func _with_needs(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[String] = ids.duplicate()
	while not stack.is_empty():
		var id: String = stack.pop_back()
		if out.has(id) or not Renovation.PROJECTS.has(id):
			continue
		out.append(id)
		for need: Variant in Renovation.data(id).get("needs", []):
			stack.append(str(need))
	return out


## Every project that (transitively) needs `id`.
func _dependents(id: String) -> Array[String]:
	var out: Array[String] = []
	var grew := true
	while grew:
		grew = false
		for pid: String in Renovation.PROJECTS:
			if out.has(pid) or pid == id:
				continue
			var needs: Array = Renovation.data(pid).get("needs", [])
			var depends: bool = needs.has(id)
			if not depends:
				for other: String in out:
					if needs.has(other):
						depends = true
						break
			if depends:
				out.append(pid)
				grew = true
	return out


func _room_word(state: int) -> String:
	match state:
		Renovation.RoomState.SHUT:
			return "shut"
		Renovation.RoomState.ENTERED:
			return "entered"
		Renovation.RoomState.CLEARED:
			return "cleared"
		Renovation.RoomState.DONE:
			return "done"
		_:
			return "?"


func _reno_status_text() -> String:
	if Locations.current == Locations.HEMMING:
		return "Mr. Hemming's — nothing to renovate here"
	var total := Renovation.PROJECTS.size()
	var done := 0
	for id: String in Renovation.PROJECTS:
		if Renovation.is_done(id):
			done += 1
	var rooms: Array[String] = []
	for room: String in Renovation.ROOMS:
		var room_name := str((Renovation.ROOMS[room] as Dictionary).get("name", room))
		rooms.append("%s: %s" % [room_name, _room_word(Renovation.room_state(room))])
	return (
		"Grandpa's shop — %d/%d done\nAppeal %d%%\n%s"
		% [done, total, roundi(Renovation.appeal() * 100.0), ", ".join(rooms)]
	)


# --- Build -----------------------------------------------------------------


## The panel's look lives in ui/debug_panel.gd; this fills it, section by section, with
## one labelled row per control.
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 250  # above the post-process filter so it stays crisp
	_layer.visible = false
	add_child(_layer)
	_view = DebugPanel.new()
	_view.close_requested.connect(_close)
	_layer.add_child(_view)
	_upg_panel = _build_upgrades()
	_reno_panel = _build_renovation()

	_build_world()
	_build_economy()
	_build_shop()
	_build_minigames()
	_build_upgrade_rows()
	_build_renovation_rows()

	var guide := _view.section("Guide")
	var gd_row := _view.row(guide, "Goals")
	_view.button(gd_row, "Skip goal", _skip_goal)
	_view.button(gd_row, "Restart guide", _restart_guide)

	var sound := _view.section("Sound")
	_view.button(_view.row(sound, "Review"), "Rate sounds (F7)", _review.toggle)

	_refresh_money()
	_refresh_reputation()
	_refresh_renovation()
	_refresh_world_scale(WorldScale.factor)


## World scale (WorldScale autoload): characters, props and camera distance, live.
func _build_world() -> void:
	var world := _view.section("World")
	var srow := _view.row(world, "Scale")
	_scale_slider = _view.slider(
		srow, WorldScale.MIN, WorldScale.MAX, 0.01, WorldScale.factor, WorldScale.set_factor
	)
	var hrow := _view.row(world, "Height")
	_scale_label = _view.value(hrow, "")
	_view.button(hrow, "Reset", func() -> void: _scale_slider.value = WorldScale.DEFAULT)
	WorldScale.changed.connect(_refresh_world_scale)


func _build_economy() -> void:
	var money := _view.section("Money")
	_money_label = _view.value(_view.row(money, "Balance"), "")
	var mrow := _view.row(money, "Add")
	_view.button(mrow, "+100", _add_money.bind(100))
	_view.button(mrow, "+1k", _add_money.bind(1000))
	_view.button(mrow, "-100", _add_money.bind(-100))
	var srow := _view.row(money, "Set to")
	_amount = _view.line_edit(srow, "amount")
	_view.button(srow, "Set", _set_money)

	var rep := _view.section("Reputation")
	_rep_label = _view.value(_view.row(rep, "Points"), "")
	var rrow := _view.row(rep, "Add")
	_view.button(rrow, "+10", _add_reputation.bind(10))
	_view.button(rrow, "+50", _add_reputation.bind(50))
	_view.button(rrow, "-10", _add_reputation.bind(-10))
	var rset := _view.row(rep, "Set to")
	_rep_amount = _view.line_edit(rset, "points")
	_view.button(rset, "Set", _set_reputation)
	var tiers: Array[String] = []
	for t: Dictionary in Reputation.TIERS:
		tiers.append("%s (%d)" % [t["name"], int(t["at"])])
	_rep_tier = _view.option(_view.row(rep, "Rank"), tiers, -1, _set_reputation_tier)


func _build_shop() -> void:
	var cust := _view.section("Customers & tickets")
	var crow := _view.row(cust, "Customers")
	_view.button(crow, "Call one", _call_customer)
	_view.button(crow, "Clear", _clear_customers)
	var trow := _view.row(cust, "New ticket")
	_view.button(trow, "Add", _add_ticket)
	_view.button(trow, "Ready + pickup", _ready_for_pickup)
	var solve := _view.row(cust, "Solve")
	_view.button(solve, "First", _solve_first)
	_view.button(solve, "All", _solve_all)
	_view.button(_view.row(cust, "Expire"), "First", _expire_first)

	var shift := _view.section("Shift")
	var shrow := _view.row(shift, "Day")
	_view.button(shrow, "End shift", _end_shift)
	_view.button(shrow, "Next day", _new_day)


func _build_minigames() -> void:
	var pieces := ["Random", "Shirt", "Trousers", "Jacket"]
	var cut := _view.section("Cutting")
	_cut_type = _view.option(_view.row(cut, "Piece"), pieces, 0, func(_i: int) -> void: pass)
	var try_row := _view.row(cut, "Try")
	for v in CutVariants.NAMES.size():
		_view.button(try_row, "v%d" % (v + 1), _try_cut.bind(v))
	_cut_variant = _view.option(
		_view.row(cut, "Worktable"), CutVariants.NAMES, CutVariants.current(), _set_cut_variant
	)

	var sew := _view.section("Sewing & comfort")
	_sew_type = _view.option(_view.row(sew, "Piece"), pieces, 0, func(_i: int) -> void: pass)
	var sew_try := _view.row(sew, "Try")
	for v in SewVariants.NAMES.size():
		_view.button(sew_try, "v%d" % (v + 1), _try_sew.bind(v))
	_view.option(
		_view.row(sew, "Machine"), SewVariants.NAMES, SewVariants.current(), _set_sew_variant
	)
	var comfort := _view.row(sew, "Also try")
	_view.button(comfort, "Press", _try_press)
	_view.button(comfort, "Coffee", _try_coffee.bind(false))
	_view.button(comfort, "Espresso", _try_coffee.bind(true))


func _build_upgrade_rows() -> void:
	var upg := _view.section("Upgrades & deliveries")
	var urow := _view.row(upg, "Upgrades")
	_view.button(urow, "List ▸", _toggle_upgrades)
	_view.button(urow, "Deliver now", _deliver_now)
	var spawn_row := _view.row(upg, "Spawn")
	_view.button(spawn_row, "Coffee", _spawn_station.bind(COFFEE_SCENE))
	_view.button(spawn_row, "Iron", _spawn_station.bind(IRON_SCENE))
	var percy_row := _view.row(upg, "Percy")
	_view.button(percy_row, "Spawn", _spawn_station.bind(BENCH_SCENE))
	_view.button(percy_row, "+5 jobs", _train_apprentice)


func _build_renovation_rows() -> void:
	var reno := _view.section("Renovation")
	_reno_status = _view.text(reno, "")
	var jobs := _view.row(reno, "Jobs")
	_view.button(jobs, "Finish next", _finish_next_job)
	_view.button(jobs, "Builders finish now", _finish_building_now)
	var all := _view.row(reno, "Everything")
	_view.button(all, "Renovate", _renovate_everything)
	_view.button(all, "Renovate + room upgrades", _renovate_everything_and_upgrades)
	var projects := _view.row(reno, "Projects")
	_view.button(projects, "List ▸", _toggle_renovation)
	_view.button(projects, "Reset all", _reset_renovation)
	var rooms := _view.row(reno, "Open room")
	for room: String in Renovation.ROOMS:
		if room == "front":
			continue
		var room_name := str((Renovation.ROOMS[room] as Dictionary).get("name", room))
		_view.button(rooms, room_name, _open_room.bind(room))

	var watch := _view.section("Watch the builders")
	var watch_row := _view.row(watch, "Replay")
	for id: String in Renovation.PROJECTS:
		if int(Renovation.data(id).get("kind", -1)) != Renovation.Kind.BUILD:
			continue
		_view.button(watch_row, str(Renovation.data(id).get("name", id)), _watch_build.bind(id))


## The upgrade list, as a side panel: a tick per upgrade, grouped as the phone groups
## them, granted or taken away for free.
func _build_upgrades() -> DebugPanel.SidePanel:
	var panel := _view.side("Upgrades")
	_view.button(panel.tools, "All", _set_all_upgrades.bind(true))
	_view.button(panel.tools, "None", _set_all_upgrades.bind(false))
	var category := ""
	for id: String in Upgrades.all_ids():
		var d := Upgrades.data(id)
		if str(d.get("category", "")) != category:
			category = str(d.get("category", ""))
			_view.list_heading(panel.list, category)
		var text := "%s  (T%d)" % [d.get("name", id), int(d.get("tier", 0))]
		_upg_boxes[id] = _view.toggle(panel.list, text, _set_upgrade.bind(id))
	return panel


## The renovation checklist, as a side panel: a tick per project, grouped by room in
## story order. Ticking one also ticks what it needs; un-ticking one un-ticks everything
## that (transitively) needs it.
func _build_renovation() -> DebugPanel.SidePanel:
	var panel := _view.side("Renovation")
	var room := ""
	for id: String in Renovation.PROJECTS:
		var d := Renovation.data(id)
		if str(d.get("room", "")) != room:
			room = str(d.get("room", ""))
			var room_name := str((Renovation.ROOMS.get(room, {}) as Dictionary).get("name", room))
			_view.list_heading(panel.list, room_name)
		_reno_boxes[id] = _view.toggle(panel.list, str(d.get("name", id)), _set_project.bind(id))
	return panel


func _toggle() -> void:
	if _layer.visible:
		_close()
		return
	_layer.visible = true
	GameState.input_locked = true
	_refresh_money()
	_refresh_renovation()
	_view.fit_to_screen()


## Shut the panel and hand the keys back to the game (a focused field or slider would
## otherwise keep eating them).
func _close() -> void:
	_layer.visible = false
	GameState.input_locked = false
	get_viewport().gui_release_focus()


func _refresh_money() -> void:
	if _money_label != null:
		_money_label.text = "$%d" % GameState.money


func _refresh_reputation() -> void:
	if _rep_label != null:
		_rep_label.text = "%d pts  ·  %s" % [Reputation.points, Reputation.tier_name()]
		_rep_tier.select(Reputation.tier())


func _refresh_world_scale(f: float) -> void:
	if _scale_label == null:
		return
	_scale_label.text = "%.2f  →  %.2f m" % [f, WorldScale.character_height()]
	_scale_slider.set_value_no_signal(f)


func _note(text: String) -> void:
	if _view != null:
		_view.note(text)


func _customer_manager() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "CustomerManager", true, false)
	return found[0] if not found.is_empty() else null
