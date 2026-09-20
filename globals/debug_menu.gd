extends Node

## Autoloaded as "Debug". A togglable in-game debug console (F3, debug builds only)
## for driving game actions by hand: manage money and reputation, call customers, add/solve order
## tickets, and control the shift. Built entirely in code as its own CanvasLayer
## above everything, so no scene edits are needed. This is meant to grow — new
## in-game actions get a button here via _button()/_section().

const PANEL_BG := Color(0.10, 0.11, 0.15, 0.94)
const HEADING := Color(0.62, 0.78, 1.0)
const LABEL := Color(0.90, 0.92, 0.98)
const SUIT_SCENE := preload("res://entities/items/suit.tscn")
const COFFEE_SCENE := "res://stations/coffee_machine/coffee_machine.tscn"
const IRON_SCENE := "res://stations/ironing_board/ironing_board.tscn"
const BENCH_SCENE := "res://stations/apprentice_bench/apprentice_bench.tscn"

var _layer: CanvasLayer
var _money_label: Label
var _status: Label
var _amount: LineEdit
var _rep_label: Label
var _rep_amount: LineEdit
var _rep_tier: OptionButton
var _cut_type: OptionButton
var _cut_variant: OptionButton
var _sew_type: OptionButton
var _trial: CanvasLayer
var _upg_panel: PanelContainer
var _main_scroll: ScrollContainer
var _main_box: VBoxContainer
var _upg_boxes := {}  # upgrade id -> CheckBox
var _reno_panel: PanelContainer
var _reno_status: Label
var _reno_boxes := {}  # project id -> CheckBox


func _ready() -> void:
	if not OS.is_debug_build():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_upg_panel.visible = not _upg_panel.visible
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
		(_upg_boxes[id] as CheckBox).set_pressed_no_signal(Upgrades.has(id))


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


## Skip to dawn for every project currently under way (nights_left > 0), and nothing else.
func _finish_building_now() -> void:
	var state: Dictionary = Renovation.save_state()
	var done: Array = state.get("done", [])
	var building: Dictionary = state.get("building", {})
	var spots: Dictionary = state.get("spots", {})
	var finished: Array[String] = []
	for id: String in building.keys():
		if int(building[id]) > 0:
			finished.append(id)
	for id in finished:
		done.append(id)
		building.erase(id)
		spots.erase(id)
	state["done"] = done
	state["building"] = building
	state["spots"] = spots
	Renovation.restore(state)
	if finished.is_empty():
		_note("no builders are out tonight")
	else:
		_note("builders finished %d job(s)" % finished.size())


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
	_reno_panel.visible = not _reno_panel.visible
	_refresh_renovation()


func _refresh_renovation() -> void:
	if _reno_status != null:
		_reno_status.text = _reno_status_text()
	for id: String in _reno_boxes:
		(_reno_boxes[id] as CheckBox).set_pressed_no_signal(Renovation.is_done(id))


## Mark every id in `ids` done for free, and drop them from "building"/"spots" — built
## from save_state()/restore() so nothing else in the save is disturbed.
func _finish_ids(ids: Array[String]) -> void:
	var state: Dictionary = Renovation.save_state()
	var done: Array = state.get("done", [])
	var building: Dictionary = state.get("building", {})
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


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 250  # above the post-process filter so it stays crisp
	_layer.visible = false
	add_child(_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_layer.add_child(margin)

	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(columns)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(panel)
	_upg_panel = _build_upgrades(sb)
	columns.add_child(_upg_panel)
	_reno_panel = _build_renovation(sb)
	columns.add_child(_reno_panel)

	# The panel outgrew the screen: its sections scroll, capped to the window height.
	_main_scroll = ScrollContainer.new()
	_main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_main_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(232, 0)
	_main_scroll.add_child(box)
	_main_box = box

	_heading(box, "DEBUG  ·  F3 to close")

	var money := _section(box, "Money")
	_money_label = _make_label("", 16, LABEL)
	money.add_child(_money_label)
	var mrow := _row(money)
	_button(mrow, "+100", _add_money.bind(100))
	_button(mrow, "+1k", _add_money.bind(1000))
	_button(mrow, "-100", _add_money.bind(-100))
	var srow := _row(money)
	_amount = LineEdit.new()
	_amount.placeholder_text = "amount"
	_amount.custom_minimum_size = Vector2(96, 0)
	srow.add_child(_amount)
	_button(srow, "Set", _set_money)

	var rep := _section(box, "Reputation")
	_rep_label = _make_label("", 16, LABEL)
	rep.add_child(_rep_label)
	var rrow := _row(rep)
	_button(rrow, "+10", _add_reputation.bind(10))
	_button(rrow, "+50", _add_reputation.bind(50))
	_button(rrow, "-10", _add_reputation.bind(-10))
	var rset := _row(rep)
	_rep_amount = LineEdit.new()
	_rep_amount.placeholder_text = "points"
	_rep_amount.custom_minimum_size = Vector2(96, 0)
	rset.add_child(_rep_amount)
	_button(rset, "Set", _set_reputation)
	var rtier := _row(rep)
	rtier.add_child(_make_label("Rank", 13, LABEL))
	_rep_tier = OptionButton.new()
	for t: Dictionary in Reputation.TIERS:
		_rep_tier.add_item("%s (%d)" % [t["name"], int(t["at"])])
	_rep_tier.item_selected.connect(_set_reputation_tier)
	rtier.add_child(_rep_tier)

	var cust := _section(box, "Customers")
	var crow := _row(cust)
	_button(crow, "Call customer", _call_customer)
	_button(crow, "Clear", _clear_customers)

	var tickets := _section(box, "Tickets")
	var trow := _row(tickets)
	_button(trow, "Add", _add_ticket)
	_button(trow, "Solve 1st", _solve_first)
	var trow2 := _row(tickets)
	_button(trow2, "Solve all", _solve_all)
	_button(trow2, "Expire 1st", _expire_first)
	var trow3 := _row(tickets)
	_button(trow3, "Ready + pickup", _ready_for_pickup)

	var cut := _section(box, "Cutting minigame")
	var cut_row := _row(cut)
	cut_row.add_child(_make_label("Piece", 13, LABEL))
	_cut_type = OptionButton.new()
	for item in ["Random", "Shirt", "Pants", "Jacket"]:
		_cut_type.add_item(item)
	cut_row.add_child(_cut_type)
	var try_row := _row(cut)
	try_row.add_child(_make_label("Try", 13, LABEL))
	for v in CutVariants.NAMES.size():
		_button(try_row, "v%d" % (v + 1), _try_cut.bind(v))
	var use_row := _row(cut)
	use_row.add_child(_make_label("Worktable", 13, LABEL))
	_cut_variant = OptionButton.new()
	for v in CutVariants.NAMES:
		_cut_variant.add_item(v)
	_cut_variant.selected = CutVariants.current()
	_cut_variant.item_selected.connect(_set_cut_variant)
	use_row.add_child(_cut_variant)

	var sew := _section(box, "Sewing minigame")
	var sew_row := _row(sew)
	sew_row.add_child(_make_label("Piece", 13, LABEL))
	_sew_type = OptionButton.new()
	for item in ["Random", "Shirt", "Pants", "Jacket"]:
		_sew_type.add_item(item)
	sew_row.add_child(_sew_type)
	var sew_try := _row(sew)
	sew_try.add_child(_make_label("Try", 13, LABEL))
	for v in SewVariants.NAMES.size():
		_button(sew_try, "v%d" % (v + 1), _try_sew.bind(v))
	var sew_use := _row(sew)
	sew_use.add_child(_make_label("Machine", 13, LABEL))
	var sew_pick := OptionButton.new()
	for v in SewVariants.NAMES:
		sew_pick.add_item(v)
	sew_pick.selected = SewVariants.current()
	sew_pick.item_selected.connect(_set_sew_variant)
	sew_use.add_child(sew_pick)

	var comfort := _row(sew)
	comfort.add_child(_make_label("Also", 13, LABEL))
	_button(comfort, "Press", _try_press)
	_button(comfort, "Coffee", _try_coffee.bind(false))
	_button(comfort, "Espresso", _try_coffee.bind(true))

	var upg := _section(box, "Upgrades & deliveries")
	var urow := _row(upg)
	_button(urow, "Upgrades ▸", _toggle_upgrades)
	_button(urow, "Deliver now", _deliver_now)
	var spawn_row := _row(upg)
	_button(spawn_row, "Spawn coffee", _spawn_station.bind(COFFEE_SCENE))
	_button(spawn_row, "Spawn iron", _spawn_station.bind(IRON_SCENE))
	var percy_row := _row(upg)
	_button(percy_row, "Spawn Percy", _spawn_station.bind(BENCH_SCENE))
	_button(percy_row, "Percy +5 jobs", _train_apprentice)

	var shift := _section(box, "Shift")
	var shrow := _row(shift)
	_button(shrow, "End shift", _end_shift)
	_button(shrow, "Next day", _new_day)

	var reno := _section(box, "Renovation")
	_reno_status = _make_label("", 12, LABEL)
	_reno_status.custom_minimum_size = Vector2(220, 0)
	_reno_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	reno.add_child(_reno_status)
	var rn_row1 := _row(reno)
	_button(rn_row1, "Finish next job", _finish_next_job)
	_button(rn_row1, "Builders finish tonight's work", _finish_building_now)
	var rn_row2 := _row(reno)
	_button(rn_row2, "Renovate everything", _renovate_everything)
	_button(rn_row2, "…and own the room upgrades", _renovate_everything_and_upgrades)
	var rn_row3 := _row(reno)
	_button(rn_row3, "Reset renovations", _reset_renovation)
	_button(rn_row3, "Projects ▸", _toggle_renovation)
	var rn_rooms1 := _row(reno)
	var rn_rooms2 := _row(reno)
	var rn_i := 0
	for room: String in Renovation.ROOMS:
		if room == "front":
			continue
		var room_name := str((Renovation.ROOMS[room] as Dictionary).get("name", room))
		var target := rn_rooms1 if rn_i < 2 else rn_rooms2
		_button(target, "Open %s" % room_name, _open_room.bind(room))
		rn_i += 1

	_status = _make_label("", 12, Color(0.7, 0.75, 0.85))
	box.add_child(_status)

	_refresh_money()
	_refresh_reputation()
	_refresh_renovation()


## The upgrade list, as a second column: a tick per upgrade, grouped as the phone groups
## them, granted or taken away for free.
func _build_upgrades(sb: StyleBoxFlat) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_heading(box, "UPGRADES")
	var row := _row(box)
	_button(row, "All", _set_all_upgrades.bind(true))
	_button(row, "None", _set_all_upgrades.bind(false))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var category := ""
	for id: String in Upgrades.all_ids():
		var d := Upgrades.data(id)
		if str(d.get("category", "")) != category:
			category = str(d.get("category", ""))
			list.add_child(_make_label(category, 12, HEADING))
		var tick := CheckBox.new()
		tick.text = "%s  (T%d)" % [d.get("name", id), int(d.get("tier", 0))]
		tick.add_theme_font_size_override("font_size", 13)
		tick.toggled.connect(_set_upgrade.bind(id))
		list.add_child(tick)
		_upg_boxes[id] = tick
	return panel


## The renovation checklist, as a third column: a tick per project, grouped by room in
## story order. Ticking one also ticks what it needs; un-ticking one un-ticks everything
## that (transitively) needs it.
func _build_renovation(sb: StyleBoxFlat) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_heading(box, "RENOVATION")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	var room := ""
	for id: String in Renovation.PROJECTS:
		var d := Renovation.data(id)
		if str(d.get("room", "")) != room:
			room = str(d.get("room", ""))
			var room_name := str((Renovation.ROOMS.get(room, {}) as Dictionary).get("name", room))
			list.add_child(_make_label(room_name, 12, HEADING))
		var tick := CheckBox.new()
		tick.text = str(d.get("name", id))
		tick.add_theme_font_size_override("font_size", 13)
		tick.toggled.connect(_set_project.bind(id))
		list.add_child(tick)
		_reno_boxes[id] = tick
	return panel


func _toggle() -> void:
	_layer.visible = not _layer.visible
	GameState.input_locked = _layer.visible
	if _layer.visible:
		_refresh_money()
		_refresh_renovation()
		_fit_main()


## As tall as its sections, but never past the bottom of the window.
func _fit_main() -> void:
	var content := _main_box.get_combined_minimum_size()
	var room := get_viewport().get_visible_rect().size.y - 60.0
	_main_scroll.custom_minimum_size = Vector2(content.x + 14.0, minf(content.y, room))


func _refresh_money() -> void:
	if _money_label != null:
		_money_label.text = "Balance:  $%d" % GameState.money


func _refresh_reputation() -> void:
	if _rep_label != null:
		_rep_label.text = "%d pts  ·  %s" % [Reputation.points, Reputation.tier_name()]
		_rep_tier.select(Reputation.tier())


func _note(text: String) -> void:
	if _status != null:
		_status.text = text


# --- Small UI builders -----------------------------------------------------


func _customer_manager() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "CustomerManager", true, false)
	return found[0] if not found.is_empty() else null


func _heading(parent: Node, text: String) -> void:
	var lbl := _make_label(text, 16, HEADING)
	parent.add_child(lbl)


func _section(parent: Node, title: String) -> VBoxContainer:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 4)
	parent.add_child(sec)
	sec.add_child(_make_label(title, 12, HEADING))
	return sec


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl
