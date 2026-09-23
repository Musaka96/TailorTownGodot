extends Node

## Dev-only Sound Review panel (F7, debug builds only), owned by the debug menu. Lists every
## sound in the Sfx library with the moment it fires, a Play button, a 1–5 rating and a
## short note, so the owner can rate the whole library and we know which files to redo.
## Ratings live in user://playtest/sound_ratings.json; the report is markdown, copied to
## the clipboard or saved next to it. Built entirely in code as its own CanvasLayer.

const PANEL_BG := Color(0.10, 0.11, 0.15, 0.94)
const HEADING := Color(0.62, 0.78, 1.0)
const LABEL := Color(0.90, 0.92, 0.98)
const DIR := "user://playtest"
const RATINGS_PATH := "user://playtest/sound_ratings.json"
const REPORT_PATH := "user://playtest/sound_report.md"
const LOOPS := [
	"scissors_glide",
	"iron_glide",
	"grinder",
	"pour",
	"sew_machine_loop",
	"ambience_loop",
]
const MUSIC := ["music_stitch_shop_stroll", "music_thread_and_thimble"]
## [group, key, when it fires in the game]
const CATALOG: Array = [
	["UI", "menu_open", "A station menu opens (worktable, shelf, rack, phone)."],
	["UI", "page_turn", "Handbook / newspaper / story note page; flipping the door sign."],
	["UI", "error", "Shop-closed buzz; a menu action refused (no money, wrong item, full)."],
	["UI", "ui_move", "Menu cursor moves."],
	["UI", "ui_confirm", "Menu confirm."],
	["UI", "ui_cancel", "Menu back / close."],
	[
		"Customers & shop",
		"door_chime",
		"A customer arrives and waits at the front desk (also a phone delivery box landing).",
	],
	[
		"Customers & shop",
		"door_open",
		"The shop door swings open (positional, on the door).",
	],
	["Customers & shop", "door_close", "The shop door swings shut."],
	[
		"Customers & shop",
		"new_order_ping",
		"The pickup day arrives: the customer is sent back for the suit (order_due).",
	],
	[
		"Customers & shop",
		"order_complete",
		"The suit is finished on the rack (order_ready).",
	],
	["Customers & shop", "happy", "Customer pleased: suit accepted, good street pitch."],
	["Customers & shop", "unhappy", "Customer displeased; an order expired."],
	["Customers & shop", "coins", "Getting paid on fulfilment; phone purchases."],
	["Customers & shop", "pin_in", "New order pinned on the cork board; goal tag; wordmark."],
	[
		"Customers & shop",
		"pin_out",
		"Order taken off the board when fulfilled; sewing pedal.",
	],
	["Customers & shop", "phone_order", "Placing a cloth order on the phone."],
	[
		"Customers & shop",
		"fabric_unroll",
		"Bolt delivered / unrolled at the apprentice bench.",
	],
	["Customers & shop", "mentor_blip", "Mr. Hemming's talk syllables (random of 5)."],
	[
		"Handling & movement",
		"footstep_wood",
		"Player steps on wood (random of 3, every 0.5 s).",
	],
	["Handling & movement", "footstep_rug", "Player steps on the rug."],
	["Handling & movement", "pickup", "Pick up an item (hand, worktable, trash)."],
	["Handling & movement", "putdown", "Put an item down."],
	[
		"Handling & movement",
		"drawer",
		"Item stored in / taken from a shelf; some menus.",
	],
	["Handling & movement", "cloth_rustle", "Cloth handled on the cut bench; some menus."],
	["Handling & movement", "chalk", "Worktable marking menu."],
	["Handling & movement", "tape", "Tape measure menu."],
	["Cutting", "snip", "A cut on the cutting bench / apprentice bench."],
	["Cutting", "scissors_run", "A long scissor run."],
	["Cutting", "scissors_glide", "Cutting v2: blades hissing through cloth (loop)."],
	["Sewing", "stitch", "Hand stitch."],
	["Sewing", "sew_machine", "Machine burst on the sewing menu."],
	["Sewing", "sew_machine_loop", "Machine running during a seam (loop)."],
	["Sewing", "sew_tap", "Pedal tap."],
	["Sewing", "sew_stitch_good", "A good stitch."],
	["Sewing", "sew_stitch_perfect", "A perfect stitch."],
	["Pressing & coffee", "iron_glide", "Iron gliding (loop)."],
	["Pressing & coffee", "steam_hiss", "Steam burst / scorch moment."],
	["Pressing & coffee", "scorch", "Cloth burnt."],
	["Pressing & coffee", "coffee_pour", "Coffee machine pours a cup."],
	["Pressing & coffee", "grinder", "Espresso grinder (loop)."],
	["Pressing & coffee", "tamp", "Tamp the portafilter."],
	["Pressing & coffee", "pour", "Espresso pour (loop)."],
	["Minigame juice", "juice_note", "Each perfect in a streak, pitched up a scale."],
	["Minigame juice", "juice_top", "Streak cap reached."],
	["Minigame juice", "juice_drop", "Streak broken."],
	["Minigame juice", "juice_stamp", "Verdict stamp at the end."],
	["Renovation by hand", "reno_scoop", "Clearing a room by hand: scooping up a junk heap."],
	[
		"Renovation by hand",
		"reno_tumble",
		"Clearing a room by hand: the heap's bits hopping off into the sack.",
	],
	["Renovation by hand", "reno_whip", "Clearing a room by hand: a dust sheet whipped off."],
	[
		"Renovation by hand",
		"reno_creak",
		"Clearing a room by hand: a boarded-up plank prised off.",
	],
	[
		"Renovation by hand",
		"reno_clatter",
		"Clearing a room by hand: a plank clattering to the floor.",
	],
	[
		"Renovation by hand",
		"reno_tick",
		"Clearing a room by hand: one job done (progress tick).",
	],
	[
		"Renovation by hand",
		"reno_open",
		"Clearing a room by hand: the project finished and a room opened.",
	],
	[
		"Renovation by hand",
		"reno_done",
		"Clearing a room by hand: the project finished (no new room).",
	],
	["Builders' show", "reno_knock", "Builders knock."],
	["Builders' show", "reno_hammer", "Hammering."],
	["Builders' show", "reno_saw", "Sawing."],
	["Builders' show", "reno_drill", "Drilling."],
	["Builders' show", "reno_roller", "Paint roller."],
	["Builders' show", "reno_poof", "Dust poof; delivery box lands."],
	["Builders' show", "reno_reveal", "The finished room revealed."],
	["Day & world", "day_start", "Shift starts (morning)."],
	["Day & world", "day_end", "Shift ends (closing time)."],
	["Day & world", "curtain_close", "Curtain closes over a scene change."],
	["Day & world", "curtain_open", "Curtain opens."],
	["Day & world", "sign_drop", "Main-menu sign drops."],
	["Day & world", "sign_hoist", "Main-menu sign hoisted."],
	["Day & world", "sign_sew", "Wordmark underline stitched, per stitch."],
	["Day & world", "ambience_loop", "Faint shop room tone from boot (loop)."],
	["Music", "music_stitch_shop_stroll", "Shop theme."],
	["Music", "music_thread_and_thimble", "Main-menu theme."],
]

var _layer: CanvasLayer
var _status: Label
var _scroll: ScrollContainer
var _box: VBoxContainer
var _ratings := {}  # key -> {"rating": int, "note": String}
var _rows := {}  # key -> {"play": Button, "group": ButtonGroup, "note": LineEdit}
var _loops_on := {}  # loop key -> true, for every loop this panel started
var _music_key := ""  # the track this panel started, "" when none
var _was_locked := false


func _ready() -> void:
	if not OS.is_debug_build():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_build()


func _input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("sound_review"):
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	if _layer == null:
		return
	if _layer.visible:
		close()
	else:
		open()


func open() -> void:
	if _layer == null or _layer.visible:
		return
	_layer.visible = true
	_was_locked = GameState.input_locked
	GameState.input_locked = true
	_fit()
	_fit.call_deferred()


func close() -> void:
	if _layer == null or not _layer.visible:
		return
	_stop_all()
	_layer.visible = false
	GameState.input_locked = _was_locked


# --- Playback --------------------------------------------------------------


func _play(key: String) -> void:
	if key in MUSIC:
		if _music_key == key:
			Sfx.stop_music()
			_music_key = ""
		else:
			Sfx.play_music(key)
			_music_key = key
	elif key in LOOPS:
		if _loops_on.has(key):
			Sfx.stop_loop(key)
			_loops_on.erase(key)
		else:
			Sfx.start_loop(key)
			_loops_on[key] = true
	else:
		Sfx.play(key, 0.0, 1.0, 1.0)
	_note("played %s" % key)
	_refresh_play_buttons()


func _stop_all() -> void:
	for key: String in _loops_on:
		Sfx.stop_loop(key)
	_loops_on.clear()
	if _music_key != "":
		Sfx.stop_music()
		_music_key = ""
	_refresh_play_buttons()


func _refresh_play_buttons() -> void:
	for key: String in _rows:
		var btn: Button = _rows[key]["play"]
		btn.text = _play_label(key)


func _play_label(key: String) -> String:
	if key in MUSIC:
		return "Stop" if _music_key == key else "Music"
	if key in LOOPS:
		return "Stop" if _loops_on.has(key) else "Loop"
	return "Play"


# --- Ratings ---------------------------------------------------------------


func _on_rate(_on: bool, key: String, group: ButtonGroup) -> void:
	var pressed := group.get_pressed_button() as Button
	var rating := int(pressed.text) if pressed != null else 0
	_entry(key)["rating"] = rating
	_save()
	_note("%s rated %d" % [key, rating] if rating > 0 else "%s unrated" % key)


func _on_note(text: String, key: String) -> void:
	_entry(key)["note"] = text
	_save()


func _entry(key: String) -> Dictionary:
	if not _ratings.has(key):
		_ratings[key] = {"rating": 0, "note": ""}
	return _ratings[key]


func _clear_ratings() -> void:
	for key: String in _rows:
		var group: ButtonGroup = _rows[key]["group"]
		for btn: BaseButton in group.get_buttons():
			btn.set_pressed_no_signal(false)
		var note: LineEdit = _rows[key]["note"]
		note.text = ""
	_ratings.clear()
	_save()
	_note("ratings cleared")


func _load() -> void:
	if not FileAccess.file_exists(RATINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RATINGS_PATH))
	if not parsed is Dictionary:
		return
	for key: String in parsed:
		var raw: Variant = parsed[key]
		if raw is Dictionary:
			_ratings[key] = {
				"rating": int(raw.get("rating", 0)),
				"note": str(raw.get("note", "")),
			}


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var out := {}
	for key: String in _ratings:
		var e: Dictionary = _ratings[key]
		if int(e["rating"]) > 0 or str(e["note"]) != "":
			out[key] = e
	var file := FileAccess.open(RATINGS_PATH, FileAccess.WRITE)
	if file == null:
		_note("could not write %s" % RATINGS_PATH)
		return
	file.store_string(JSON.stringify(out, "\t"))


# --- Report ----------------------------------------------------------------


## Markdown table, worst-rated first, unrated last; same text for Copy and Save.
func _report() -> String:
	var rows: Array = []
	var rated := 0
	for i in CATALOG.size():
		var key: String = CATALOG[i][1]
		var e: Dictionary = _ratings.get(key, {})
		var rating := int(e.get("rating", 0))
		if rating > 0:
			rated += 1
		rows.append([rating if rating > 0 else 99, i, key, e.get("note", "")])
	rows.sort_custom(_worst_first)
	var when := Time.get_datetime_string_from_system(false, true)
	var lines: Array[String] = [
		"# Sound review, %s (rated %d / %d)" % [when, rated, CATALOG.size()],
		"",
		"| sound | rating | note | fires when |",
		"|---|---|---|---|",
	]
	for r: Array in rows:
		var rating_text := "–" if int(r[0]) == 99 else str(r[0])
		var moment: String = CATALOG[int(r[1])][2]
		lines.append("| %s | %s | %s | %s |" % [r[2], rating_text, _cell(str(r[3])), _cell(moment)])
	return "\n".join(lines) + "\n"


## Lowest rating first; ties keep catalog order.
func _worst_first(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	return a[1] < b[1]


func _cell(text: String) -> String:
	return text.replace("|", "\\|").replace("\n", " ")


func _copy_report() -> void:
	DisplayServer.clipboard_set(_report())
	_note("report copied to the clipboard")


func _save_report() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_note("could not write %s" % REPORT_PATH)
		return
	file.store_string(_report())
	_note("saved %s" % ProjectSettings.globalize_path(REPORT_PATH))


func _open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	OS.shell_open(ProjectSettings.globalize_path(DIR))


# --- Build -----------------------------------------------------------------


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 251  # just above the debug menu
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
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(panel)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)

	_heading(_box, "SOUND REVIEW  ·  F7 to close")
	_status = _make_label("", 12, Color(0.7, 0.75, 0.85))
	_box.add_child(_status)
	var bar := _row(_box)
	_button(bar, "Stop all", _stop_all)
	_button(bar, "Copy report", _copy_report)
	_button(bar, "Save report", _save_report)
	_button(bar, "Open folder", _open_folder)
	_button(bar, "Clear ratings", _clear_ratings)

	var sec: VBoxContainer = null
	var group_name := ""
	for entry: Array in CATALOG:
		if entry[0] != group_name:
			group_name = entry[0]
			sec = _section(_box, group_name)
		_sound_row(sec, entry[1], entry[2])
	_note("%d sounds" % CATALOG.size())


func _sound_row(parent: Node, key: String, moment: String) -> void:
	var saved: Dictionary = _ratings.get(key, {})
	var row := _row(parent)
	var play := _button(row, _play_label(key), _play.bind(key))
	play.custom_minimum_size = Vector2(64, 0)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var name_lbl := _make_label(key, 13, HEADING)
	name_lbl.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_lbl)
	var when_lbl := _make_label(moment, 12, LABEL)
	when_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	when_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(when_lbl)

	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for n in range(1, 6):
		var btn := Button.new()
		btn.text = str(n)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(30, 0)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_pressed_color", HEADING)
		btn.add_theme_color_override("font_hover_pressed_color", HEADING)
		btn.set_pressed_no_signal(int(saved.get("rating", 0)) == n)
		btn.toggled.connect(_on_rate.bind(key, group))
		stars.add_child(btn)

	var note := LineEdit.new()
	note.placeholder_text = "note"
	note.custom_minimum_size = Vector2(130, 0)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.text = str(saved.get("note", ""))
	note.text_changed.connect(_on_note.bind(key))
	row.add_child(note)
	_rows[key] = {"play": play, "group": group, "note": note}


## As tall as its rows, but never past the bottom of the window.
func _fit() -> void:
	var content := _box.get_combined_minimum_size()
	var room := get_viewport().get_visible_rect().size.y - 60.0
	_scroll.custom_minimum_size = Vector2(content.x + 14.0, minf(content.y, room))


func _note(text: String) -> void:
	if _status != null:
		_status.text = text


# --- Small UI builders -----------------------------------------------------


func _heading(parent: Node, text: String) -> void:
	parent.add_child(_make_label(text, 16, HEADING))


func _section(parent: Node, title: String) -> VBoxContainer:
	parent.add_child(HSeparator.new())
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
