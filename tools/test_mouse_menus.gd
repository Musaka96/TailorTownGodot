extends SceneTree

## Headless test for driving the in-game menus with the mouse (ui/craft/mouse_pick.gd):
## pointing at a row selects it, a click on a row confirms it (or only selects, where
## selecting is all there is), a click on a chapter tab turns to it, a right click backs
## out like Esc, and the wheel scrolls the lists. Real mouse events are pushed through
## the viewport at the cards' on-screen centres, so the GUI's own picking is tested too.
## Needs a real window: a headless viewport never hands mouse events to its Controls.
## Park the window off-screen so the desk's own mouse can't wander into it:
##   godot --path . --position -5000,-5000 --script res://tools/test_mouse_menus.gd

var _failures: Array[String] = []
var _ui: Node
var _player: Node
var _at := Vector2.ZERO


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_mouse_menus: needs a window (headless GUI takes no mouse) — run without")
		print("  --headless, e.g. --position -5000,-5000")
		quit(1)
		return
	change_scene_to_file("res://main.tscn")
	for _i in 4:
		await process_frame
	_ui = root.get_node("UI")
	if _ui.newspaper != null:
		_ui.newspaper.close()
	_player = get_first_node_in_group("player")
	await _test_handbook()
	await _test_orders()
	await _test_phone()
	await _test_suit_builder()
	await _test_customer_request()
	await _test_story_note()
	_finish()


# --- Handbook ------------------------------------------------------------------------


func _test_handbook() -> void:
	print("Handbook")
	var book: Control = _ui.handbook
	_ui.open_handbook(_player)
	await _frames(4)
	_report_stops(book)
	var index: VBoxContainer = book.get("_index")
	_check(index.get_child_count() >= 3, "(setup) the first chapter has 3+ topics")
	await _move_to(index.get_child(2))
	_check(int(book.get("_topic")) == 2, "pointing at topic 3 selects it")
	# The rebuilt index puts a fresh card under the resting pointer: it must not re-pick.
	await _frames(3)
	_check(int(book.get("_topic")) == 2, "the rebuilt index doesn't steal it back")
	await _click(index.get_child(0))
	_check(int(book.get("_topic")) == 0, "clicking topic 1 selects it")
	var tabs: HBoxContainer = book.get("_tabs")
	await _move_to(tabs.get_child(1))
	_check(int(book.get("_chapter")) == 0, "pointing at a chapter tab doesn't turn to it")
	await _click(tabs.get_child(1))
	_check(int(book.get("_chapter")) == 1, "clicking chapter tab 2 turns to it")
	await _click(tabs.get_child(0))
	_check(int(book.get("_chapter")) == 0, "clicking chapter tab 1 turns back")

	# The wheel over a long article scrolls it.
	book.set("_topic", _longest_topic(book))
	book.call("_refresh")
	await _frames(4)
	var art: ScrollContainer = book.get("_art_scroll")
	var bar := art.get_v_scroll_bar()
	_check(bar.max_value - bar.page > 40.0, "(setup) the article is longer than the page")
	await _wheel(art, MOUSE_BUTTON_WHEEL_DOWN)
	_check(art.scroll_vertical > 0, "the wheel scrolls the article")
	var index_scroll: ScrollContainer = book.get("_index_scroll")
	var ibar := index_scroll.get_v_scroll_bar()
	if ibar.max_value - ibar.page > 10.0:
		await _wheel(index_scroll, MOUSE_BUTTON_WHEEL_DOWN)
		_check(index_scroll.scroll_vertical > 0, "the wheel scrolls the topic index")

	await _click(book.get("_body"), MOUSE_BUTTON_RIGHT)
	_check(not book.visible, "a right click closes the book")
	_check(not paused, "and the shop runs again")


func _longest_topic(book: Control) -> int:
	var entries: Array = (book.get("_chapters") as Array)[0]["entries"]
	var best := 0
	for i in entries.size():
		if str(entries[i]["body"]).length() > str(entries[best]["body"]).length():
			best = i
	return best


# --- Orders board --------------------------------------------------------------------


func _test_orders() -> void:
	print("Orders board")
	var orders: Node = root.get_node("Orders")
	var suit := {"fabric": 0, "pattern": 1, "color": 0, "style_idx": 0}
	while orders.active.size() < 3:
		orders.create_order("Mr. Test", {2: suit, 1: suit}, 300, Color.WHITE)
	var board: Control = _ui.orders_menu
	board.call("open", _player)
	await _frames(4)
	_report_stops(board)
	var list: VBoxContainer = board.get("_list")
	await _move_to(list.get_child(2))
	_check(int(board.get("_sel")) == 2, "pointing at ticket 3 selects it")
	await _click(list.get_child(1))
	_check(int(board.get("_sel")) == 1, "clicking ticket 2 selects it")
	_check(board.visible, "(the board is read-only: a click only selects)")
	# A keyboard step with the pointer resting on a ticket keeps the keyboard's choice.
	await _press("move_back")
	_check(int(board.get("_sel")) == 2, "S still steps with the pointer at rest")
	await _frames(3)
	_check(int(board.get("_sel")) == 2, "and the resting pointer doesn't take it back")
	await _click(list.get_child(0), MOUSE_BUTTON_RIGHT)
	_check(not board.visible, "a right click closes the board")
	board.call("open", _player)
	await _frames(4)
	var flows := board.find_children("*", "HFlowContainer", true, false)
	var pills: Array = (flows[flows.size() - 1] as Node).get_children()  # the hint bar
	await _click(pills[pills.size() - 1])
	_check(not board.visible, "clicking the Esc pill closes it too")


# --- Phone ---------------------------------------------------------------------------


func _test_phone() -> void:
	print("Phone")
	var menu: Control = _ui.phone_order
	var phone: Node = current_scene.find_child("Phone", true, false)
	menu.call("open", phone, _player)
	await _frames(4)
	_report_stops(menu)
	var rows: VBoxContainer = menu.get("_rows")
	await _move_to(rows.get_child(1))
	_check(int(menu.get("_row")) == 1, "pointing at hub card 2 selects it")
	await _click(rows.get_child(1))
	_check(int(menu.get("_screen")) == 3, "clicking Shop Upgrades opens it")  # Screen.UPGRADES
	await _frames(3)
	var scroll: ScrollContainer = menu.get("_list_scroll")
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value - bar.page > 10.0:
		var before := scroll.scroll_vertical
		await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
		_check(scroll.scroll_vertical != before, "the wheel scrolls the upgrades list")
	var panel: Control = menu.get("_panel")
	await _click(panel, MOUSE_BUTTON_RIGHT)
	_check(int(menu.get("_screen")) == 0, "a right click steps back to the hub")
	await _click(rows.get_child(0))
	_check(int(menu.get("_screen")) == 1, "clicking Order Textiles opens the suppliers")
	var contacts: VBoxContainer = menu.get("_contacts")
	await _click(contacts.get_child(1))  # [0] is the header; the first mill is open
	_check(int(menu.get("_screen")) == 2, "clicking an open supplier calls it")
	# The order form: a click on the right of a "‹ value ›" steps it like D.
	await _frames(2)
	var fabric_before: int = menu.get("_color")
	await _move_to(rows.get_child(1))
	_check(int(menu.get("_row")) == 1, "pointing at the Colour row selects it")
	await _frames(2)
	var value := _value_label(rows.get_child(1))
	if value != null:
		var font := value.get_theme_font("font")
		var size := value.get_theme_font_size("font_size")
		var w := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var r := value.get_global_rect()
		await _click_at(r.position + Vector2(w * 0.8, r.size.y * 0.5))  # the "›" end
		_check(int(menu.get("_color")) != fabric_before, "a click on the value steps it")
		_check(int(menu.get("_screen")) == 2, "and orders nothing")
	else:
		_check(false, "(setup) the Colour row has a value label")
	await _click(panel, MOUSE_BUTTON_RIGHT)
	_check(int(menu.get("_screen")) == 1, "a right click backs out to the suppliers")
	await _click(panel, MOUSE_BUTTON_RIGHT)
	await _click(panel, MOUSE_BUTTON_RIGHT)
	_check(not menu.visible, "right clicks hang the phone up")


# --- Suit builder (the mirror) -------------------------------------------------------


func _test_suit_builder() -> void:
	print("Suit builder")
	var menu: Control = _ui.suit_builder
	var mirror: Node = current_scene.find_child("Mirror", true, false)
	menu.call("open", mirror, _player)  # nobody seated: free design
	await _frames(4)
	_report_stops(menu)
	var rows: VBoxContainer = menu.get("_rows")
	var strip := rows.get_child(0) as PartTabs
	_check(strip != null, "(setup) the first row is the part tabs")
	if strip == null:
		menu.call("close")
		return
	await _click_at(strip.tab_rect(0).get_center())  # the suit (jacket) tab
	_check(int(menu.get("_part_sel")) == 0, "clicking the suit tab turns to the jacket")
	await _frames(2)
	strip = rows.get_child(0) as PartTabs
	# Trousers linked to the jacket (the default): only the suit and shirt have tabs.
	_check(strip.parts.size() == 2, "linked trousers have no tab of their own")
	await _click_at(strip.tab_rect(1).get_center())  # the shirt tab
	_check(int(menu.get("_part_sel")) == 1, "clicking the shirt tab turns to it")
	await _frames(2)
	strip = rows.get_child(0) as PartTabs
	var first := strip.tab_rect(-1)  # (on screen already)
	var left := Vector2(first.position.x - 8.0, first.get_center().y)  # the ‹ chevron
	await _click_at(left)
	_check(int(menu.get("_part_sel")) == 0, "clicking the ‹ chevron steps back a part")

	# Colour: row 2 (Part, Fabric, Colour, Pattern, Style).
	var design: Dictionary = menu.get("_design")
	var part: int = int(menu.call("_type"))
	var colour: int = int(design[part]["color"])
	await _move_to(rows.get_child(2))
	_check(int(menu.get("_row")) == 2, "pointing at the Colour row selects it")
	await _frames(2)
	await _click_value(rows.get_child(2), 0.85)
	var next_colour: int = int(menu.get("_design")[part]["color"])
	_check(next_colour != colour, "a click on the right of the colour steps to the next")
	await _frames(2)
	await _click_value(rows.get_child(2), 0.15)
	_check(int(menu.get("_design")[part]["color"]) == colour, "a click on its left steps back")
	await _frames(2)
	await _wheel(_value_label(rows.get_child(2)), MOUSE_BUTTON_WHEEL_DOWN)
	_check(int(menu.get("_design")[part]["color"]) == colour, "the wheel never steps a value")
	# Style (the cut): the fifth row steps the same way.
	var style: int = int(design[part]["style_idx"])
	await _click_value(rows.get_child(4), 0.85)
	var styles := Enums.styles_for(part).size()
	var want := (style + 1) % styles
	_check(int(menu.get("_design")[part]["style_idx"]) == want, "the cut steps on a click too")
	# Trousers (the suit tab's last row): unlinked, they get a tab of their own.
	await _frames(2)
	await _click_value(rows.get_child(5), 0.85)
	await _frames(2)
	_check(not bool(menu.get("_linked")), "a click on the trousers row unlinks them")
	var tabs := rows.get_child(0) as PartTabs
	_check(tabs != null and tabs.parts.size() == 3, "unlinked trousers get their own tab")

	# The E pill confirms (free design: it saves the design).
	var bar: Control = menu.get("_hint_bar")
	var pills := bar.get_child(0).get_child(0).get_children()
	await _click(pills[2])
	_check(str(menu.get("_status")).contains("saved"), "clicking the E pill confirms")
	await _click(rows, MOUSE_BUTTON_RIGHT)
	_check(not menu.visible, "a right click closes the mirror")


## Click a row's value at `frac` of the way across its text (0 = the ‹ end, 1 = the › end).
func _click_value(card: Node, frac: float) -> void:
	var value := _value_label(card)
	if value == null:
		_check(false, "(setup) the row has a value label")
		return
	var font := value.get_theme_font("font")
	var size := value.get_theme_font_size("font_size")
	var w := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := value.get_global_rect()
	await _click_at(r.position + Vector2(w * frac, r.size.y * 0.5))


# --- Customer bubble -----------------------------------------------------------------


func _test_customer_request() -> void:
	print("Customer bubble")
	var menu: Control = _ui.customer_request
	menu.call("open", null, _player)  # a browser: one choice, take the fitting
	await _frames(4)
	_report_stops(menu)
	var cards: Array = menu.get("_cards")
	_check(cards.size() >= 1, "(setup) there is a choice to click")
	if cards.is_empty():
		menu.call("close")
		return
	await _click(cards[0])
	_check(not menu.visible, "clicking a choice answers with it")
	menu.call("open", null, _player)
	await _frames(4)
	await _click(menu.get("_panel"), MOUSE_BUTTON_RIGHT)
	_check(not menu.visible, "a right click is 'later'")


# --- Grandpa's letters ---------------------------------------------------------------


func _test_story_note() -> void:
	print("Story note")
	var note: Control = _ui.story_note
	note.call("open", "A letter", "Dear boy,\n\nMind the shop.")
	await create_timer(0.5).timeout  # past the guard that stops the opening press closing it
	_report_stops(note)
	await _click(note.get("_panel"), MOUSE_BUTTON_RIGHT)
	_check(not note.visible, "a right click folds the letter away")


func _value_label(card: Node) -> Label:
	for node in card.find_children("*", "Label", true, false):
		if (node as Label).mouse_filter == Control.MOUSE_FILTER_PASS:
			return node as Label
	return null


# --- Mouse ---------------------------------------------------------------------------


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _move_to(c: Control) -> void:
	await _move_at(_center(c))


func _move_at(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _at
	_at = pos
	root.push_input(ev, true)
	await _frames(3)


func _click(c: Control, button := MOUSE_BUTTON_LEFT) -> void:
	await _click_at(_center(c), button)


func _click_at(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _move_at(pos)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		root.push_input(ev, true)
	await _frames(3)


func _wheel(c: Control, button: int) -> void:
	await _move_at(_center(c))
	for _i in 3:
		for pressed: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = _at
			ev.global_position = _at
			ev.button_index = button
			ev.pressed = pressed
			ev.factor = 1.0
			root.push_input(ev, true)
	await _frames(3)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)
	await _frames(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	root.push_input(ev)
	await _frames(2)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## Anything still STOPping the mouse inside an open menu (it would eat a right click).
func _report_stops(menu: Control) -> void:
	var stops: Array[String] = []
	for node in [menu] + menu.find_children("*", "Control", true, false):
		var c := node as Control
		if c.is_visible_in_tree() and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			if not (c is BaseButton or c is Range):
				stops.append("%s (%s)" % [menu.get_path_to(c), c.get_class()])
	_check(stops.is_empty(), "nothing in the menu stops the mouse %s" % str(stops))


func _check(condition: bool, label: String) -> void:
	if label == "":
		return
	if condition:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("test_mouse_menus: ALL PASS")
		quit(0)
	else:
		print("test_mouse_menus: %d FAILURE(S)" % _failures.size())
		quit(1)
