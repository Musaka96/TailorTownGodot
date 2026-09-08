extends Control

## The morning paper — THE TAILOR'S GAZETTE. A modal broadsheet that slides up at
## the start of each day (EventBus.newspaper_ready) and can be reread with the
## "newspaper" key. It lays out the day's edition from the News manager: a masthead
## and dateline, the stories (lead first) in a scrolling column, and two standing
## boxes — the running fashion trend (match it for extra reputation) and the city's
## social calendar of upcoming events. Read-only; content comes from News.
##
## Built entirely in code from a bare Control (ui.gd._build_newspaper), so no scene
## has to be regenerated to add it.

var _panel: PanelContainer
var _dateline: Label
var _stories: VBoxContainer
var _fashion_body: Label
var _events_body: Label
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	EventBus.newspaper_ready.connect(_on_newspaper_ready)


func open() -> void:
	if News == null or News.current_edition.is_empty():
		return
	GameState.input_locked = true
	_fill()
	visible = true
	Sfx.play("page_turn")


func close() -> void:
	visible = false
	GameState.input_locked = false
	Sfx.play("page_turn")


func _on_newspaper_ready(_day: int) -> void:
	open()


# --- Layout ----------------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.PAPER
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3)
	sb.border_color = Style.WALNUT
	sb.set_content_margin_all(Style.S4)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", Style.S2)
	_panel.add_child(body)

	var masthead := Label.new()
	masthead.text = "THE TAILOR'S GAZETTE"
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead.add_theme_font_override("font", Style.bold_font())
	masthead.add_theme_font_size_override("font_size", 36)
	masthead.add_theme_color_override("font_color", Style.INK)
	body.add_child(masthead)

	_dateline = Label.new()
	_dateline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dateline.add_theme_font_size_override("font_size", 13)
	_dateline.add_theme_color_override("font_color", Style.INK_SOFT)
	body.add_child(_dateline)

	body.add_child(_rule(3, Style.INK))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 300)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)

	_stories = VBoxContainer.new()
	_stories.custom_minimum_size = Vector2(700, 0)
	_stories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stories.add_theme_constant_override("separation", Style.S3)
	_scroll.add_child(_stories)

	body.add_child(_rule(2, Style.CREAM_DARK))

	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", Style.S3)
	body.add_child(boxes)
	_fashion_body = _make_box(boxes, "THE ATELIER SET", Style.BRASS)
	_events_body = _make_box(boxes, "SOCIAL CALENDAR", Style.BURGUNDY)

	var hint := Label.new()
	hint.text = "Esc · fold away      ▲ ▼ · read on"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Style.INK_SOFT)
	body.add_child(hint)


func _rule(thickness: int, col: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = col
	line.custom_minimum_size = Vector2(0, thickness)
	return line


## A bordered standing box (fashion / events); returns its autowrapping body label.
func _make_box(parent: HBoxContainer, title: String, accent: Color) -> Label:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(330, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CARD
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = accent
	sb.set_content_margin_all(Style.S3)
	box.add_theme_stylebox_override("panel", sb)
	parent.add_child(box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S1)
	box.add_child(col)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", Style.bold_font())
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", accent)
	col.add_child(head)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Style.INK)
	col.add_child(body)
	return body


# --- Fill from the edition -------------------------------------------------


func _fill() -> void:
	var day := _day()
	_dateline.text = "Day %d  ·  %s" % [day, _rank()]
	for child in _stories.get_children():
		child.queue_free()
	var edition := News.edition()
	for i in edition.size():
		_stories.add_child(_story(edition[i], i == 0))
	_fashion_body.text = _fashion_text()
	_events_body.text = _events_text(day)
	_scroll.scroll_vertical = 0


## One article: an optional coloured kicker, a headline (bigger for the lead), body.
func _story(ev: NewsEvent, lead: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Style.S1)
	var kicker := _kicker(ev)
	if kicker != "":
		var k := Label.new()
		k.text = kicker
		k.add_theme_font_override("font", Style.bold_font())
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", _kicker_color(ev))
		col.add_child(k)
	var head := Label.new()
	head.text = ev.headline
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_override("font", Style.bold_font())
	head.add_theme_font_size_override("font_size", 24 if lead else 18)
	head.add_theme_color_override("font_color", Style.INK)
	col.add_child(head)
	if ev.body != "":
		var text := Label.new()
		text.text = ev.body
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 15 if lead else 14)
		text.add_theme_color_override("font_color", Style.INK_SOFT)
		col.add_child(text)
	return col


func _kicker(ev: NewsEvent) -> String:
	match ev.kind:
		NewsEvent.Kind.FASHION:
			return "IN FASHION"
		NewsEvent.Kind.EVENT:
			return "CITY EVENT · DAY %d" % ev.event_day
	return ""


func _kicker_color(ev: NewsEvent) -> Color:
	return Style.BURGUNDY if ev.kind == NewsEvent.Kind.EVENT else Style.BRASS


func _fashion_text() -> String:
	var trend: NewsEvent = News.current_fashion
	if trend == null:
		return "No firm trend just yet — dress them as you see fit."
	var wants: Array[String] = []
	if trend.fashion_pattern >= 0:
		wants.append(Enums.pattern_name(trend.fashion_pattern))
	if trend.fashion_fabric >= 0:
		wants.append(Enums.fabric_name(trend.fashion_fabric))
	if wants.is_empty():
		return trend.headline
	var joined := ", ".join(wants)
	return "In favour: %s. Work it in for extra standing (+%d)." % [joined, trend.fashion_bonus]


func _events_text(day: int) -> String:
	var events := News.upcoming_events(day)
	if events.is_empty():
		return "The calendar's clear for now."
	var lines: Array[String] = []
	for ev in events:
		var away := ev.event_day - day
		var when := "today" if away <= 0 else ("tomorrow" if away == 1 else "in %d days" % away)
		lines.append(
			"· Day %d (%s) — %s" % [ev.event_day, Enums.occasion_name(ev.event_occasion), when]
		)
	return "\n".join(lines)


# --- Access + input --------------------------------------------------------


func _day() -> int:
	return Shift.day if Shift != null else 1


func _rank() -> String:
	return Reputation.tier_name() if Reputation != null else "Unknown"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("newspaper") and not GameState.input_locked:
			open()
			get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("newspaper")
		or event.is_action_pressed("pause")
		or event.is_action_pressed("ui_cancel")
		or event.is_action_pressed("interact")
	):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= 60
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += 60
		get_viewport().set_input_as_handled()
