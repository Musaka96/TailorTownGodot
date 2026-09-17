class_name MentorDialog
extends Control

## The tutorial's mentor — an old master tailor on a TV portrait beside a chalk-green
## speech board. He handles the welcome, general advice and the longer "why"
## explanations (dress codes, reputation...); concrete steps are left to the goal tag.
##
## say() takes one or more pages. Each page types out (his mouth moves and cartoon
## blips play); E / Enter / a click first finishes the page, then moves on. When the
## last page is dismissed `finished` fires with 0 (E / primary) or 1 (Esc / secondary,
## only offered when a secondary label is given).

signal finished(choice: int)

const MENTOR_NAME := "Mr. Hemming"
const MENTOR_ROLE := "Master tailor"
const WIDTH := 780.0
const PORTRAIT := Vector2(168, 192)
const CHARS_PER_SEC := 62.0
const BLIP_EVERY := 3  # letters between talk blips
const PAUSES := {".": 0.20, "!": 0.20, "?": 0.20, ",": 0.07, ":": 0.10, "\n": 0.12}

# The mentor's look (character data, not UI styling).
const LOOK_SKIN := Color(0.93, 0.79, 0.68)  # ui-check-ignore: skin data
const LOOK_HAIR := Color(0.86, 0.86, 0.84)  # ui-check-ignore: hair data
const LOOK_HEAD := 0
const LOOK_HAIR_STYLE := 1

var _pages := PackedStringArray()
var _page := 0
var _shown := 0.0
var _hold := 0.0
var _letters := 0
var _typing := false
var _has_secondary := false
var _primary := "Continue"
var _time := 0.0

var _portrait: CustomerPortrait
var _board: PanelContainer
var _text: RichTextLabel
var _page_label: Label
var _cue: Label
var _primary_label: Label
var _secondary_box: Control
var _secondary_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


## Speak `pages` in order. `primary` labels the E prompt on the last page; a non-empty
## `secondary` adds an Esc choice (e.g. "No thanks").
func say(pages: PackedStringArray, primary := "Continue", secondary := "") -> void:
	_pages = pages
	_page = 0
	_has_secondary = secondary != ""
	_primary = primary
	_secondary_label.text = secondary
	visible = true
	_portrait.set_live(true)
	_start_page()


func is_speaking() -> bool:
	return visible


func hide_dialog() -> void:
	visible = false
	_typing = false
	if _portrait != null:
		_portrait.set_live(false)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_cue.modulate.a = 0.0 if _typing else 0.55 + 0.45 * sin(_time * 5.0)
	if not _typing:
		return
	if _hold > 0.0:
		_hold -= delta
		return
	var total := _text.get_total_character_count()
	var before := int(_shown)
	_shown = minf(_shown + CHARS_PER_SEC * delta, float(total))
	var now := int(_shown)
	var parsed := _text.get_parsed_text()
	for i in range(before, now):
		var ch := parsed[i] if i < parsed.length() else ""
		if ch.strip_edges() != "":
			_letters += 1
			if _letters % BLIP_EVERY == 0:
				Sfx.play_single("mentor_blip", -8.0, 0.9, 1.15)
		if PAUSES.has(ch):
			_hold = PAUSES[ch]
			_shown = float(i + 1)
			now = i + 1
			break
	_text.visible_characters = now
	if now >= total:
		_end_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_on_confirm()
		get_viewport().set_input_as_handled()
	elif _is_cancel(event):
		# Esc only answers the secondary choice; otherwise swallow it so the pause menu
		# can't unpause the game while he's talking.
		if _has_secondary and not _typing:
			_close(1)
		get_viewport().set_input_as_handled()


func _is_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")


func _on_board_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_confirm()


func _on_confirm() -> void:
	if _typing:
		# First press: reveal the rest of the page at once.
		_text.visible_characters = -1
		_end_typing()
		return
	if _page + 1 < _pages.size():
		_page += 1
		_start_page()
	else:
		_close(0)


func _close(choice: int) -> void:
	hide_dialog()
	Sfx.play("ui_confirm" if choice == 0 else "ui_cancel", -4.0)
	finished.emit(choice)


func _start_page() -> void:
	_text.text = _pages[_page]
	_text.visible_characters = 0
	_shown = 0.0
	_hold = 0.0
	_letters = 0
	_typing = true
	_portrait.set_talking(true)
	var last := _page + 1 >= _pages.size()
	_page_label.text = "%d / %d" % [_page + 1, _pages.size()] if _pages.size() > 1 else ""
	_primary_label.text = _primary if last else "Next"
	_secondary_box.visible = false


func _end_typing() -> void:
	_typing = false
	_portrait.set_talking(false)
	var last := _page + 1 >= _pages.size()
	_secondary_box.visible = last and _has_secondary


# --- Build -----------------------------------------------------------------


func _build() -> void:
	var holder := HBoxContainer.new()
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_bottom = -Style.S4
	holder.custom_minimum_size = Vector2(WIDTH, 0)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", -Style.S2)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var port_col := VBoxContainer.new()
	port_col.alignment = BoxContainer.ALIGNMENT_END
	port_col.add_theme_constant_override("separation", -Style.S3)
	port_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(port_col)
	_portrait = CustomerPortrait.new()
	_portrait.custom_minimum_size = PORTRAIT
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port_col.add_child(_portrait)
	_portrait.configure_look(_look())
	port_col.add_child(_nameplate())

	_board = PanelContainer.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_SHRINK_END
	_board.add_theme_stylebox_override("panel", _board_style())
	_board.gui_input.connect(_on_board_input)
	holder.add_child(_board)
	_board.add_child(_board_content())


func _board_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Style.S2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 118)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", Style.CHALK)
	_text.add_theme_font_size_override("normal_font_size", 17)
	_text.add_theme_font_size_override("bold_font_size", 17)
	_text.add_theme_font_override("bold_font", Style.bold_font())
	_text.add_theme_constant_override("line_separation", 3)
	box.add_child(_text)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", Style.S3)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	_page_label = _small_label("", Style.CREAM_DARK)
	foot.add_child(_page_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)
	_secondary_box = _key_prompt("Esc")
	_secondary_label = _secondary_box.get_child(1) as Label
	foot.add_child(_secondary_box)
	var primary := _key_prompt("E")
	_primary_label = primary.get_child(1) as Label
	foot.add_child(primary)
	_cue = _small_label("▼", Style.BRASS)
	foot.add_child(_cue)
	return box


func _nameplate() -> Control:
	var plate := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.BRASS
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Style.WALNUT
	sb.content_margin_left = Style.S2
	sb.content_margin_right = Style.S2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	plate.add_theme_stylebox_override("panel", sb)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	plate.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = MENTOR_NAME
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", Style.bold_font())
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Style.WALNUT)
	col.add_child(name_lbl)
	var role := _small_label(MENTOR_ROLE, Style.WALNUT)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role)
	return plate


func _board_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.FOREST
	sb.set_corner_radius_all(18)
	sb.corner_radius_bottom_left = 4  # the corner nearest the mentor, like a speech tail
	sb.set_border_width_all(4)
	sb.border_color = Style.WALNUT
	sb.content_margin_left = Style.S4 + Style.S2
	sb.content_margin_right = Style.S4
	sb.content_margin_top = Style.S3 + 2
	sb.content_margin_bottom = Style.S2 + 2
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb


func _key_prompt(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Style.S1 + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Style.keycap(key))
	var lbl := _small_label("", Style.CHALK)
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)
	return row


func _small_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Grey-haired, bespectacled, in a forest tweed.
func _look() -> Dictionary:
	var green := 0
	for i in MaterialFactory.color_count():
		if MaterialFactory.color_name(i) == "Forest":
			green = i
	var suit := MaterialFactory.make(Enums.Fabric.TWEED, Enums.Pattern.SOLID, green, 1.0)
	return {
		"head": LOOK_HEAD,
		"hair": LOOK_HAIR_STYLE,
		"skin": LOOK_SKIN,
		"hair_color": LOOK_HAIR,
		"eyes": "brown",
		"glasses": "round",
		"suit": suit,
	}
